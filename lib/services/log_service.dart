// =============================================
// GROWLOG - Log Service (IMPROVED!)
// Service-Layer für komplexe Log-Operationen
// =============================================

import 'dart:io';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/log_fertilizer.dart';
import 'package:growlog_app/models/photo.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/safe_parsers.dart';
import 'package:growlog_app/services/interfaces/i_log_service.dart';

// Service-Layer für alle Log-Operationen
// Vorteile:
// - Kapselt komplexe Multi-Step-Operationen
// - Nutzt Transactions für Atomicity (ACID)
// - Zentrale Business-Logic statt Code-Duplizierung
// - Input-Validierung & besseres Error Handling
// - Bessere Testbarkeit
class LogService implements ILogService {
  final DatabaseHelper _dbHelper;
  final IPlantRepository _plantRepo;

  LogService(this._dbHelper, this._plantRepo);

  /// Validiert Log-Daten vor dem Speichern
  void _validateLog(PlantLog log, Plant plant) {
    if (log.plantId <= 0) {
      throw ArgumentError('Ungültige Plant ID: ${log.plantId}');
    }

    if (log.dayNumber < 1) {
      throw ArgumentError('Day Number muss >= 1 sein: ${log.dayNumber}');
    }

    // ✅ FIX BUG #3: Prevent logs on archived plants
    if (plant.phase == PlantPhase.archived) {
      throw ArgumentError(
        'Pflanze "${plant.name}" ist archiviert. '
        'Logs können nicht zu archivierten Pflanzen hinzugefügt werden. '
        'Bitte reaktiviere die Pflanze zuerst.',
      );
    }

    // ✅ NEUE VALIDIERUNG: Log-Datum vs. Pflanz-Datum
    final dateError = Validators.validateLogDate(
      logDate: log.logDate,
      seedDate: plant.seedDate,
      phaseStartDate: plant.phaseStartDate,
    );
    if (dateError != null) {
      throw ArgumentError(dateError);
    }

    // Validiere pH Werte
    if (log.phIn != null && (log.phIn! < 0 || log.phIn! > 14)) {
      throw ArgumentError('pH In außerhalb Bereich: ${log.phIn}');
    }
    if (log.phOut != null && (log.phOut! < 0 || log.phOut! > 14)) {
      throw ArgumentError('pH Out außerhalb Bereich: ${log.phOut}');
    }

    // Validiere EC Werte
    if (log.ecIn != null && (log.ecIn! < 0 || log.ecIn! > 10)) {
      throw ArgumentError('EC In außerhalb Bereich: ${log.ecIn}');
    }
    if (log.ecOut != null && (log.ecOut! < 0 || log.ecOut! > 10)) {
      throw ArgumentError('EC Out außerhalb Bereich: ${log.ecOut}');
    }

    // Validiere Umgebungswerte
    if (log.temperature != null &&
        (log.temperature! < -50 || log.temperature! > 100)) {
      throw ArgumentError('Temperatur außerhalb Bereich: ${log.temperature}');
    }
    if (log.humidity != null && (log.humidity! < 0 || log.humidity! > 100)) {
      throw ArgumentError(
        'Luftfeuchtigkeit außerhalb Bereich: ${log.humidity}',
      );
    }

    // Validiere Container-Werte
    if (log.containerSize != null && log.containerSize! <= 0) {
      throw ArgumentError(
        'Container-Größe muss positiv sein: ${log.containerSize}',
      );
    }
    if (log.systemReservoirSize != null && log.systemReservoirSize! <= 0) {
      throw ArgumentError(
        'Reservoir-Größe muss positiv sein: ${log.systemReservoirSize}',
      );
    }
    if (log.systemBucketCount != null && log.systemBucketCount! <= 0) {
      throw ArgumentError(
        'Bucket-Anzahl muss positiv sein: ${log.systemBucketCount}',
      );
    }
  }

  /// Validiert Fertilizer-Daten
  void _validateFertilizers(Map<int, double> fertilizers) {
    for (final entry in fertilizers.entries) {
      if (entry.key <= 0) {
        throw ArgumentError('Ungültige Fertilizer ID: ${entry.key}');
      }
      if (entry.value < 0) {
        throw ArgumentError('Fertilizer-Menge muss >= 0 sein: ${entry.value}');
      }
      if (entry.value > 10000) {
        throw ArgumentError(
          'Fertilizer-Menge zu groß (max 10000ml): ${entry.value}',
        );
      }
    }
  }

  /// Validiert Photo-Pfade
  /// ✅ HIGH FIX: Added try-catch to handle TOCTOU race (file deleted between checks)
  Future<void> _validatePhotos(List<String> photoPaths) async {
    for (final path in photoPaths) {
      final file = File(path);

      try {
        // ✅ FIX: Combined existence check and size check to minimize TOCTOU window
        if (!await file.exists()) {
          throw ArgumentError('Foto-Datei existiert nicht: $path');
        }

        // Prüfe Dateigröße (max 50MB)
        final size = await file.length();
        if (size > 50 * 1024 * 1024) {
          throw ArgumentError('Foto zu groß (max 50MB): $path');
        }
      } catch (e) {
        // ✅ FIX: Handle TOCTOU race - file could be deleted between exists() and length()
        if (e is FileSystemException) {
          throw ArgumentError(
            'Foto-Datei nicht zugänglich oder wurde gelöscht: $path',
          );
        }
        rethrow;
      }
    }
  }

  /// Single Log speichern mit allen Relationen (Fertilizers + Photos)
  /// VORHER: Viele einzelne Calls in add_log_screen
  /// NACHHER: Eine Transaction für alles!
  @override
  Future<PlantLog> saveSingleLog({
    required Plant plant,
    required PlantLog log,
    required Map<int, double> fertilizers,
    required List<String> photoPaths,
    PlantPhase? newPhase,
  }) async {
    // ✅ BUG FIX #7b: dayNumber automatisch berechnen für Sicherheit!
    int correctedDayNumber = log.dayNumber;
    if (plant.seedDate != null) {
      correctedDayNumber = Validators.calculateDayNumber(
        log.logDate,
        plant.seedDate!,
      );
    }

    // ✅ v13: phase & phaseDayNumber berechnen
    int? phaseDayNumber;
    // Use phase-specific date instead of deprecated phaseStartDate
    DateTime? phaseStartDate;
    switch (plant.phase) {
      case PlantPhase.veg:
        phaseStartDate = plant.vegDate;
        break;
      case PlantPhase.bloom:
        phaseStartDate = plant.bloomDate;
        break;
      case PlantPhase.harvest:
        phaseStartDate = plant.harvestDate;
        break;
      case PlantPhase.seedling:
      case PlantPhase.archived:
        phaseStartDate = plant.seedDate;
        break;
    }
    if (phaseStartDate != null) {
      phaseDayNumber = Validators.calculateDayNumber(
        log.logDate,
        phaseStartDate,
      );
    }

    // Korrigierter Log mit richtigem dayNumber & phase
    final correctedLog = log.copyWith(
      dayNumber: correctedDayNumber,
      phase: plant.phase,
      phaseDayNumber: phaseDayNumber,
    );

    // Input-Validierung
    _validateLog(correctedLog, plant);
    _validateFertilizers(fertilizers);
    if (photoPaths.isNotEmpty) {
      await _validatePhotos(photoPaths);
    }

    final db = await _dbHelper.database;

    // ALLES in einer Transaction = ACID garantiert
    try {
      return await db.transaction((txn) async {
        PlantLog savedLog = correctedLog;

        // 1. Log speichern
        if (correctedLog.id == null) {
          final id = await txn.insert('plant_logs', correctedLog.toMap());
          savedLog = correctedLog.copyWith(id: id);
        } else {
          await txn.update(
            'plant_logs',
            correctedLog.toMap(),
            where: 'id = ?',
            whereArgs: [correctedLog.id],
          );
        }

        final logId = savedLog.id!;

        // 2. Fertilizers speichern (Batch)
        if (fertilizers.isNotEmpty) {
          final batch = txn.batch();

          // Alte löschen
          batch.delete(
            'log_fertilizers',
            where: 'log_id = ?',
            whereArgs: [logId],
          );

          // Neue einfügen
          for (final entry in fertilizers.entries) {
            final logFert = LogFertilizer(
              logId: logId,
              fertilizerId: entry.key,
              amount: entry.value,
              unit: 'ml',
            );
            batch.insert('log_fertilizers', logFert.toMap());
          }

          await batch.commit(noResult: true);
        }

        // 3. Photos speichern (Batch)
        if (photoPaths.isNotEmpty) {
          final batch = txn.batch();
          for (final photoPath in photoPaths) {
            final photo = Photo(logId: logId, filePath: photoPath);
            batch.insert('photos', photo.toMap());
          }
          await batch.commit(noResult: true);
        }

        // 4. Plant Updates (bei TRANSPLANT oder PHASE_CHANGE)
        if (correctedLog.actionType == ActionType.transplant) {
          final updatedPlant = plant.copyWith(
            currentContainerSize: correctedLog.containerSize,
            currentSystemSize: correctedLog.systemReservoirSize,
          );
          await txn.update(
            'plants',
            updatedPlant.toMap(),
            where: 'id = ?',
            whereArgs: [plant.id],
          );
        }

        if (correctedLog.actionType == ActionType.phaseChange &&
            newPhase != null) {
          final updatedPlant = plant.copyWith(
            phase: newPhase,
            phaseStartDate: correctedLog.logDate,
          );
          await txn.update(
            'plants',
            updatedPlant.toMap(),
            where: 'id = ?',
            whereArgs: [plant.id],
          );
        }

        return savedLog;
      });
    } catch (e) {
      // Bessere Fehlerbehandlung
      throw Exception('Fehler beim Speichern des Logs: $e');
    }
  }

  /// Bulk Log speichern für mehrere Pflanzen
  /// Performance: Nutzt Batch + Transaction!
  /// WICHTIG: Berechnet dayNumber individuell pro Pflanze basierend auf seedDate!
  @override
  Future<List<int>> saveBulkLog({
    required List<int> plantIds,
    required DateTime logDate,
    required ActionType actionType,
    double? waterAmount,
    double? phIn,
    double? ecIn,
    double? phOut,
    double? ecOut,
    double? temperature,
    double? humidity,
    bool runoff = false,
    bool cleanse = false,
    String? note,
    required Map<int, double> fertilizers,
    required List<String> photoPaths,
    PlantPhase? newPhase,
  }) async {
    if (plantIds.isEmpty) {
      throw ArgumentError('Keine Plant IDs angegeben');
    }

    // Validierung
    _validateFertilizers(fertilizers);
    if (photoPaths.isNotEmpty) {
      await _validatePhotos(photoPaths);
    }

    final db = await _dbHelper.database;
    final createdLogIds = <int>[];

    try {
      await db.transaction((txn) async {
        final logBatch = txn.batch();

        // ✅ FIX: Lade alle Pflanzen um seedDate und name zu bekommen
        final plantMaps = await txn.query(
          'plants',
          where: 'id IN (${plantIds.map((_) => '?').join(',')})',
          whereArgs: plantIds,
        );

        // ✅ FIX: Erstelle Maps für seedDate und name
        final plantSeedDates = <int, DateTime>{};
        final plantNames = <int, String>{};
        for (final plantMap in plantMaps) {
          final plantId = plantMap['id'] as int;
          plantNames[plantId] = plantMap['name'] as String;

          final seedDateStr = plantMap['seed_date'] as String?;
          if (seedDateStr != null) {
            // ✅ HIGH FIX: Use SafeParsers to prevent crashes from corrupted DB data
            plantSeedDates[plantId] = SafeParsers.parseDateTime(
              seedDateStr,
              fallback: DateTime.now(),
              context: 'PlantSeedDate',
            );
          }
        }

        // ✅ FIX BUG #3: Validiere dass keine archivierten Pflanzen dabei sind
        for (final plantMap in plantMaps) {
          final plantId = plantMap['id'] as int;
          final plantName = plantNames[plantId] ?? 'Unknown';
          final phase = plantMap['phase'] as String;

          if (phase.toUpperCase() == 'ARCHIVED') {
            throw ArgumentError(
              'Pflanze "$plantName" ist archiviert. '
              'Logs können nicht zu archivierten Pflanzen hinzugefügt werden.',
            );
          }
        }

        // ✅ FIX BUG #4: Validiere Datum mit besseren Fehlermeldungen
        final logDay = DateTime(logDate.year, logDate.month, logDate.day);
        for (final entry in plantSeedDates.entries) {
          final plantId = entry.key;
          final plantName = plantNames[plantId] ?? 'Unknown';
          final seedDay = DateTime(
            entry.value.year,
            entry.value.month,
            entry.value.day,
          );

          if (logDay.isBefore(seedDay)) {
            throw ArgumentError(
              'Log-Datum liegt vor dem Pflanz-Datum für Pflanze "$plantName" (#$plantId)',
            );
          }
        }

        // 1. Logs für alle Pflanzen erstellen (Batch)
        for (final plantId in plantIds) {
          // Lade Pflanze für Phase-Info
          // ✅ FIX: Add orElse to prevent StateError crash
          final plantMap = plantMaps.firstWhere(
            (p) => p['id'] == plantId,
            orElse: () => throw Exception('Plant not found: $plantId'),
          );
          final plantPhase = PlantPhase.values.byName(
            plantMap['phase'].toString().toLowerCase(),
          );
          final phaseStartDateStr = plantMap['phase_start_date'] as String?;

          // ✅ FIX: Berechne dayNumber individuell pro Pflanze!
          int dayNumber = 1;
          final seedDate = plantSeedDates[plantId];
          if (seedDate != null) {
            // ✅ Nur Datums-Teil vergleichen (ohne Uhrzeit!)
            final logDay = DateTime(logDate.year, logDate.month, logDate.day);
            final seedDay = DateTime(
              seedDate.year,
              seedDate.month,
              seedDate.day,
            );

            dayNumber = logDay.difference(seedDay).inDays + 1;

            // ✅ CRITICAL FIX: Enforce reasonable bounds (10 years max grow cycle)
            const maxReasonableDays = 3650; // 10 years
            if (dayNumber < 1) {
              AppLogger.warning(
                'LogService',
                'Log date before seed date, clamping to day 1',
              );
              dayNumber = 1;
            } else if (dayNumber > maxReasonableDays) {
              AppLogger.error(
                'LogService',
                'Day number too large ($dayNumber). Check seed date (${seedDate.toIso8601String()}) vs log date (${logDate.toIso8601String()})',
              );
              throw ArgumentError(
                'Day number too large ($dayNumber). Please check seed date vs log date.',
              );
            }
          }

          // ✅ v13: phaseDayNumber berechnen
          int? phaseDayNumber;
          if (phaseStartDateStr != null) {
            // ✅ HIGH FIX: Use SafeParsers to prevent crashes from corrupted DB data
            final phaseStartDate = SafeParsers.parseDateTime(
              phaseStartDateStr,
              fallback: logDate,
              context: 'PhaseStartDate',
            );
            phaseDayNumber = Validators.calculateDayNumber(
              logDate,
              phaseStartDate,
            );
          }

          final log = PlantLog(
            plantId: plantId,
            dayNumber: dayNumber, // ✅ Individuell berechnet!
            logDate: logDate,
            actionType: actionType,
            phase: plantPhase, // ✅ v13
            phaseDayNumber: phaseDayNumber, // ✅ v13
            waterAmount: waterAmount,
            phIn: phIn,
            ecIn: ecIn,
            phOut: phOut,
            ecOut: ecOut,
            temperature: temperature,
            humidity: humidity,
            runoff: runoff,
            cleanse: cleanse,
            note: note,
          );
          logBatch.insert('plant_logs', log.toMap());
        }

        final logResults = await logBatch.commit();

        // IDs sammeln
        for (var result in logResults) {
          if (result is int) {
            createdLogIds.add(result);
          }
        }

        // 2. Fertilizers für alle Logs (Batch)
        if (fertilizers.isNotEmpty && createdLogIds.isNotEmpty) {
          final fertBatch = txn.batch();

          for (final logId in createdLogIds) {
            for (final entry in fertilizers.entries) {
              final logFert = LogFertilizer(
                logId: logId,
                fertilizerId: entry.key,
                amount: entry.value,
                unit: 'ml',
              );
              fertBatch.insert('log_fertilizers', logFert.toMap());
            }
          }

          await fertBatch.commit(noResult: true);
        }

        // 3. Photos für alle Logs (Batch)
        if (photoPaths.isNotEmpty && createdLogIds.isNotEmpty) {
          final photoBatch = txn.batch();

          for (final logId in createdLogIds) {
            for (final photoPath in photoPaths) {
              final photo = Photo(logId: logId, filePath: photoPath);
              photoBatch.insert('photos', photo.toMap());
            }
          }

          await photoBatch.commit(noResult: true);
        }

        // 4. Phase Change für alle Pflanzen
        if (actionType == ActionType.phaseChange && newPhase != null) {
          final plantBatch = txn.batch();

          for (final plantId in plantIds) {
            plantBatch.rawUpdate(
              'UPDATE plants SET phase = ?, phase_start_date = ? WHERE id = ?',
              [newPhase.name, logDate.toIso8601String(), plantId],
            );
          }

          await plantBatch.commit(noResult: true);
        }
      });

      return createdLogIds;
    } catch (e) {
      throw Exception('Fehler beim Bulk-Speichern: $e');
    }
  }

  /// Log mit allen Details laden (inkl. Fertilizers + Photos)
  /// Nutzt JOIN Query für maximale Performance!
  @override
  Future<Map<String, dynamic>?> getLogWithDetails(int logId) async {
    try {
      final db = await _dbHelper.database;

      // JOIN Query für Log + Fertilizers + Photos
      const query = '''
        SELECT 
          pl.*,
          lf.id as lf_id,
          lf.fertilizer_id,
          lf.amount as fert_amount,
          lf.unit as fert_unit,
          f.name as fert_name,
          f.brand as fert_brand,
          f.npk as fert_npk,
          p.id as photo_id,
          p.file_path as photo_path,
          p.created_at as photo_created_at
        FROM plant_logs pl
        LEFT JOIN log_fertilizers lf ON pl.id = lf.log_id
        LEFT JOIN fertilizers f ON lf.fertilizer_id = f.id
        LEFT JOIN photos p ON pl.id = p.log_id
        WHERE pl.id = ?
        ORDER BY lf.id, p.id
      ''';

      final maps = await db.rawQuery(query, [logId]);

      if (maps.isEmpty) return null;

      // Erste Row = Log Daten
      final log = PlantLog.fromMap(maps.first);

      final fertilizers = <Map<String, dynamic>>[];
      final photos = <Map<String, dynamic>>[];

      final seenFertIds = <int>{};
      final seenPhotoIds = <int>{};

      for (final map in maps) {
        // Fertilizer sammeln (ohne Duplikate)
        if (map['lf_id'] != null) {
          final fertId = map['lf_id'] as int;
          if (!seenFertIds.contains(fertId)) {
            seenFertIds.add(fertId);
            fertilizers.add({
              'id': fertId,
              'fertilizer_id': map['fertilizer_id'],
              'amount': map['fert_amount'],
              'unit': map['fert_unit'],
              'name': map['fert_name'],
              'brand': map['fert_brand'],
              'npk': map['fert_npk'],
            });
          }
        }

        // Photos sammeln (ohne Duplikate)
        if (map['photo_id'] != null) {
          final photoId = map['photo_id'] as int;
          if (!seenPhotoIds.contains(photoId)) {
            seenPhotoIds.add(photoId);
            photos.add({
              'id': photoId,
              'log_id': logId,
              'file_path': map['photo_path'],
              'created_at': map['photo_created_at'],
            });
          }
        }
      }

      return {'log': log, 'fertilizers': fertilizers, 'photos': photos};
    } catch (e) {
      throw Exception('Fehler beim Laden des Logs: $e');
    }
  }

  /// Log kopieren (mit allen Relationen)
  /// Nutzen: "Letzten Log kopieren" Feature
  @override
  Future<PlantLog?> copyLog({
    required int sourceLogId,
    required int targetPlantId,
    required DateTime newDate, // ✅ dayNumber wird berechnet!
  }) async {
    try {
      final sourceData = await getLogWithDetails(sourceLogId);

      if (sourceData == null) return null;

      final sourceLog = sourceData['log'] as PlantLog;
      final sourceFertilizers =
          sourceData['fertilizers'] as List<Map<String, dynamic>>;

      // ✅ Plant laden um seedDate zu bekommen
      final plant = await _plantRepo.findById(targetPlantId);
      if (plant == null) return null;

      // ✅ dayNumber berechnen basierend auf newDate!
      int dayNumber = 1;
      if (plant.seedDate != null) {
        dayNumber = Validators.calculateDayNumber(newDate, plant.seedDate!);
      }

      // ✅ v13: phaseDayNumber berechnen
      int? phaseDayNumber;
      if (plant.phaseStartDate != null) {
        phaseDayNumber = Validators.calculateDayNumber(
          newDate,
          plant.phaseStartDate!,
        );
      }

      // Neuer Log mit kopierten Daten
      final newLog = PlantLog(
        plantId: targetPlantId,
        dayNumber: dayNumber, // ✅ Berechnet!
        logDate: newDate,
        actionType: sourceLog.actionType,
        phase: plant.phase, // ✅ v13
        phaseDayNumber: phaseDayNumber, // ✅ v13
        waterAmount: sourceLog.waterAmount,
        phIn: sourceLog.phIn,
        ecIn: sourceLog.ecIn,
        phOut: sourceLog.phOut,
        ecOut: sourceLog.ecOut,
        temperature: sourceLog.temperature,
        humidity: sourceLog.humidity,
        runoff: sourceLog.runoff,
        cleanse: sourceLog.cleanse,
        note: sourceLog.note,
        containerSize: sourceLog.containerSize,
        containerMediumAmount: sourceLog.containerMediumAmount,
        containerDrainage: sourceLog.containerDrainage,
        containerDrainageMaterial: sourceLog.containerDrainageMaterial,
        systemReservoirSize: sourceLog.systemReservoirSize,
        systemBucketCount: sourceLog.systemBucketCount,
        systemBucketSize: sourceLog.systemBucketSize,
      );

      // Fertilizers Map erstellen
      final fertilizersMap = <int, double>{};
      for (final fert in sourceFertilizers) {
        fertilizersMap[fert['fertilizer_id'] as int] = (fert['amount'] as num)
            .toDouble();
      }

      // Photos werden NICHT kopiert (macht keinen Sinn)
      // ✅ plant bereits geladen oben!

      return await saveSingleLog(
        plant: plant,
        log: newLog,
        fertilizers: fertilizersMap,
        photoPaths: [],
      );
    } catch (e) {
      throw Exception('Fehler beim Kopieren des Logs: $e');
    }
  }

  /// Log löschen (mit allen Relationen)
  /// CASCADE DELETE funktioniert durch Foreign Keys!
  @override
  Future<void> deleteLog(int logId) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        // Foreign Keys löschen automatisch:
        // - log_fertilizers (ON DELETE CASCADE)
        // - photos (ON DELETE CASCADE)
        await txn.delete('plant_logs', where: 'id = ?', whereArgs: [logId]);
      });
    } catch (e) {
      throw Exception('Fehler beim Löschen des Logs: $e');
    }
  }

  /// Mehrere Logs löschen (Batch)
  @override
  Future<void> deleteLogs(List<int> logIds) async {
    if (logIds.isEmpty) return;

    try {
      final db = await _dbHelper.database;
      final placeholders = List.filled(logIds.length, '?').join(',');

      await db.transaction((txn) async {
        await txn.delete(
          'plant_logs',
          where: 'id IN ($placeholders)',
          whereArgs: logIds,
        );
      });
    } catch (e) {
      throw Exception('Fehler beim Löschen der Logs: $e');
    }
  }
}
