// =============================================
// GROWLOG - Log Service (IMPROVED!)
// Service-Layer für komplexe Log-Operationen
// =============================================

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';
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

  /// ✅ FR-B-014: Lock serialises the photo-validation + DB-write critical
  /// section so the TOCTOU window between `_validatePhotos` and the actual
  /// insert cannot be widened by a concurrent writer. The check itself is
  /// still best-effort against an external file mutation (see `_validatePhotos`
  /// doc), but at least no second `saveSingleLog`/`saveBulkLog` can race.
  final Lock _photoLock = Lock();

  /// ✅ FR-B-005 / QA-004: Override for the application documents directory
  /// used for photo staging + final placement. Tests inject a temp dir here
  /// because `path_provider` has no platform binding in unit tests.
  final Future<Directory> Function()? _docsDirOverride;

  LogService(
    this._dbHelper,
    this._plantRepo, {
    Future<Directory> Function()? docsDirOverride,
  }) : _docsDirOverride = docsDirOverride;

  /// Subdirectory under documents/ where finalised photos live.
  static const String photosSubdir = 'photos';

  /// Subdirectory under documents/photos/ where in-flight photos stage.
  /// Files older than [_staleStagingMaxAge] can be cleaned via
  /// [cleanStalePhotoStaging] on startup.
  static const String stagingSubdir = '.staging';

  /// Files left behind in `.staging` older than this are considered abandoned
  /// (crash mid-save) and can be reaped by [cleanStalePhotoStaging].
  static const Duration _staleStagingMaxAge = Duration(hours: 1);

  Future<Directory> _appDocsDir() async {
    final override = _docsDirOverride;
    if (override != null) return override();
    return getApplicationDocumentsDirectory();
  }

  /// ✅ FR-B-005 / QA-004: Cleanup hook for staging files that survived a
  /// crash mid-save. Intended to be called once on app startup. Best-effort —
  /// failures are logged but never thrown.
  Future<void> cleanStalePhotoStaging() async {
    try {
      final docs = await _appDocsDir();
      final staging = Directory(
        p.join(docs.path, photosSubdir, stagingSubdir),
      );
      if (!await staging.exists()) return;

      final cutoff = DateTime.now().subtract(_staleStagingMaxAge);
      await for (final entity in staging.list()) {
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            if (entity is Directory) {
              await entity.delete(recursive: true);
            } else {
              await entity.delete();
            }
            AppLogger.info(
              'LogService',
              'Reaped stale photo staging entry: ${entity.path}',
            );
          }
        } catch (e) {
          AppLogger.warning(
            'LogService',
            'Could not reap staging entry ${entity.path}: $e',
          );
        }
      }
    } catch (e) {
      AppLogger.warning('LogService', 'cleanStalePhotoStaging failed: $e');
    }
  }

  /// Represents one staged photo: a temp copy that still needs to be moved
  /// into [finalPath] after the DB transaction commits successfully.
  static final List<_StagedPhoto> _emptyStaged = const <_StagedPhoto>[];

  /// Copies each source path into a fresh staging subdir and returns the
  /// staged + final path pairs. The DB row is later inserted with [finalPath];
  /// after a successful commit the staged file is renamed to [finalPath]
  /// (a single filesystem-level move — atomic on the same volume).
  ///
  /// Caller MUST invoke [_cleanupStaged] in any error path before re-throwing,
  /// otherwise staged files leak.
  Future<List<_StagedPhoto>> _stagePhotos(List<String> sourcePaths) async {
    if (sourcePaths.isEmpty) return _emptyStaged;

    final docs = await _appDocsDir();
    final photosDir = Directory(p.join(docs.path, photosSubdir));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final stagingRoot = Directory(p.join(photosDir.path, stagingSubdir));
    if (!await stagingRoot.exists()) {
      await stagingRoot.create(recursive: true);
    }

    // Unique per-call staging subdir so concurrent saves don't collide.
    final runId =
        '${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(sourcePaths)}';
    final stagingRun = Directory(p.join(stagingRoot.path, runId));
    await stagingRun.create(recursive: true);

    final staged = <_StagedPhoto>[];
    try {
      for (final source in sourcePaths) {
        final sourceFile = File(source);
        // _validatePhotos has already run under the same lock, but defend
        // against the source disappearing between validation and staging.
        if (!await sourceFile.exists()) {
          throw ArgumentError('Foto-Quelldatei nicht mehr vorhanden: $source');
        }
        final basename = p.basename(source);
        final stagedPath = p.join(stagingRun.path, basename);
        // Final filename = timestamp + basename, lives in <docs>/photos/.
        // Generated up-front so the DB row inserted in the transaction matches
        // the rename target after commit.
        final finalName =
            '${DateTime.now().microsecondsSinceEpoch}_$basename';
        final finalPath = p.join(photosDir.path, finalName);

        await sourceFile.copy(stagedPath);
        staged.add(
          _StagedPhoto(stagedPath: stagedPath, finalPath: finalPath),
        );
      }
    } catch (_) {
      // Partial-failure cleanup: remove what we managed to copy before rethrow.
      await _cleanupStaged(staged);
      try {
        if (await stagingRun.exists()) {
          await stagingRun.delete(recursive: true);
        }
      } catch (_) {/* best-effort */}
      rethrow;
    }
    return staged;
  }

  /// Move every staged file to its [finalPath]. Returns the list of finalised
  /// paths actually committed (may be shorter than [staged] only if a rename
  /// failed; in that case the partial set is rolled back by the caller).
  Future<void> _commitStaged(List<_StagedPhoto> staged) async {
    for (final entry in staged) {
      final stagedFile = File(entry.stagedPath);
      try {
        await stagedFile.rename(entry.finalPath);
      } on FileSystemException {
        // Different volume / rename not supported — fall back to copy+delete.
        await stagedFile.copy(entry.finalPath);
        try {
          await stagedFile.delete();
        } catch (_) {/* best-effort */}
      }
    }
    // Remove the now-empty per-run staging directory.
    if (staged.isNotEmpty) {
      try {
        await Directory(p.dirname(staged.first.stagedPath))
            .delete(recursive: true);
      } catch (_) {/* best-effort */}
    }
  }

  /// Delete every staged file. Used on DB failure to prevent orphan files.
  Future<void> _cleanupStaged(List<_StagedPhoto> staged) async {
    for (final entry in staged) {
      try {
        final f = File(entry.stagedPath);
        if (await f.exists()) await f.delete();
      } catch (e) {
        AppLogger.warning(
          'LogService',
          'Could not delete staged photo ${entry.stagedPath}: $e',
        );
      }
    }
    if (staged.isNotEmpty) {
      try {
        final runDir = Directory(p.dirname(staged.first.stagedPath));
        if (await runDir.exists()) await runDir.delete(recursive: true);
      } catch (_) {/* best-effort */}
    }
  }

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
  ///
  /// TOCTOU contract: The check is a best-effort guard. A file can be removed
  /// between the exists() call and the length() call (or between this validation
  /// and the subsequent DB write). This is accepted behaviour — the catch block
  /// below surfaces a clear user-facing error in that case, and the DB write
  /// will also fail safely because the path will be invalid. A hard re-check
  /// under a shared filesystem lock is not practical in Flutter.
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

  /// ✅ FIX #1: Update phase-specific dates in plants table when phase changes
  /// Only sets dates if they are currently null (idempotent behavior)
  /// This fixes the bug where phase changes only updated deprecated phase_start_date
  Future<void> _updatePlantPhaseDate(
    DatabaseExecutor db,
    int plantId,
    PlantPhase newPhase,
    DateTime logDate,
  ) async {
    // Get current plant to check existing dates
    final plantMaps = await db.query(
      'plants',
      where: 'id = ?',
      whereArgs: [plantId],
    );

    if (plantMaps.isEmpty) {
      AppLogger.warning(
        'LogService',
        'Cannot update phase date - plant not found: $plantId',
      );
      return;
    }

    final plant = plantMaps.first;
    final Map<String, dynamic> updates = {};

    // Only update if date is null (don't overwrite existing dates)
    switch (newPhase) {
      case PlantPhase.veg:
        if (plant['veg_date'] == null) {
          updates['veg_date'] = logDate.toIso8601String();
          AppLogger.info(
            'LogService',
            'Setting veg_date for plant $plantId to ${logDate.toIso8601String()}',
          );
        }
        break;
      case PlantPhase.bloom:
        if (plant['bloom_date'] == null) {
          updates['bloom_date'] = logDate.toIso8601String();
          AppLogger.info(
            'LogService',
            'Setting bloom_date for plant $plantId to ${logDate.toIso8601String()}',
          );
        }
        break;
      case PlantPhase.harvest:
        if (plant['harvest_date'] == null) {
          updates['harvest_date'] = logDate.toIso8601String();
          AppLogger.info(
            'LogService',
            'Setting harvest_date for plant $plantId to ${logDate.toIso8601String()}',
          );
        }
        break;
      case PlantPhase.seedling:
      case PlantPhase.archived:
      case PlantPhase.unknown:
        // No phase-specific date for seedling/archived/unknown
        break;
    }

    if (updates.isNotEmpty) {
      await db.update('plants', updates, where: 'id = ?', whereArgs: [plantId]);
      AppLogger.info(
        'LogService',
        '✅ Updated plant $plantId phase dates: $updates',
      );
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
    // ✅ Validate INPUT dayNumber before auto-calculation
    if (log.dayNumber < 1) {
      throw ArgumentError('Day Number muss >= 1 sein: ${log.dayNumber}');
    }

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
        phaseStartDate = plant.vegDate ?? plant.phaseStartDate;
        break;
      case PlantPhase.bloom:
        phaseStartDate = plant.bloomDate ?? plant.phaseStartDate;
        break;
      case PlantPhase.harvest:
        phaseStartDate = plant.harvestDate ?? plant.phaseStartDate;
        break;
      case PlantPhase.seedling:
      case PlantPhase.archived:
      case PlantPhase.unknown:
        phaseStartDate = plant.seedDate ?? plant.phaseStartDate;
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

    // Input-Validierung (alles, was den Filesystem-Zustand NICHT prüft, kann
    // ausserhalb des Locks laufen).
    _validateLog(correctedLog, plant);
    _validateFertilizers(fertilizers);

    final db = await _dbHelper.database;

    // ✅ FR-B-014: Photo-Validierung + DB-Write laufen unter einem gemeinsamen
    // Lock, damit zwei parallele Saves nicht ihre TOCTOU-Fenster verschränken.
    // ✅ FR-B-005 / QA-004: Photos werden zuerst in ein .staging-Verzeichnis
    // kopiert. Erst NACH erfolgreichem DB-Commit wird das stagedFile in das
    // finale Verzeichnis umbenannt; bei DB-Fehlern werden alle Staged-Dateien
    // wieder weggeräumt – kein Orphan im Dateisystem, kein verwaister DB-Row.
    try {
      return await _photoLock.synchronized(() async {
        if (photoPaths.isNotEmpty) {
          await _validatePhotos(photoPaths);
        }

        final List<_StagedPhoto> staged = await _stagePhotos(photoPaths);

        PlantLog result;
        try {
          // ALLES in einer Transaction = ACID garantiert
          result = await db.transaction((txn) async {
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

        // 3. Photos speichern (Batch) – nutzt den FINALEN Pfad (wird nach
        // erfolgreicher Transaktion durch rename(staged → final) erreicht).
        if (staged.isNotEmpty) {
          final batch = txn.batch();
          for (final s in staged) {
            final photo = Photo(logId: logId, filePath: s.finalPath);
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

          // ✅ FIX #1: Update phase-specific dates (vegDate, bloomDate, harvestDate)
          await _updatePlantPhaseDate(
            txn,
            plant.id!,
            newPhase,
            correctedLog.logDate,
          );
        }

        return savedLog;
      });
        } catch (_) {
          // DB-Insert ist gescheitert – staged Photos wieder weg, sonst
          // entstehen Orphan-Dateien ohne dazugehörigen DB-Row.
          await _cleanupStaged(staged);
          rethrow;
        }

        // Erst NACH erfolgreichem DB-Commit: staging → final. Rename ist
        // (auf gleicher Partition) atomar – kein halber Zustand möglich.
        await _commitStaged(staged);
        return result;
      });
    } catch (e) {
      // Bessere Fehlerbehandlung. ArgumentErrors aus der Validierung dürfen
      // nicht in eine generische Exception verpackt werden, damit Aufrufer
      // sie weiterhin erkennen können.
      if (e is ArgumentError) rethrow;
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

    // Validierung (filesystem-unabhängig kann ausserhalb des Locks bleiben)
    _validateFertilizers(fertilizers);

    final db = await _dbHelper.database;
    final createdLogIds = <int>[];

    try {
      // ✅ FR-B-014: Photo-Validierung + DB-Write laufen unter dem gleichen
      // Lock wie saveSingleLog – ein einziges Bulk- und ein einziges Single-Save
      // können nicht gleichzeitig in das TOCTOU-Fenster laufen.
      // ✅ FR-B-005 / QA-004: Staging-then-commit. Erst kopieren wir in
      // .staging/, fügen DB-Rows mit dem FINALEN Pfad ein und benennen erst
      // nach Commit um. Schlägt die Transaktion fehl, sind alle Kopien weg.
      await _photoLock.synchronized(() async {
        if (photoPaths.isNotEmpty) {
          await _validatePhotos(photoPaths);
        }

        final List<_StagedPhoto> staged = await _stagePhotos(photoPaths);

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
          // Use phase-specific date instead of deprecated phase_start_date
          int? phaseDayNumber;
          String? phaseStartDateStr;

          switch (plantPhase) {
            case PlantPhase.veg:
              phaseStartDateStr =
                  plantMap['veg_date'] as String? ??
                  plantMap['phase_start_date'] as String?;
              break;
            case PlantPhase.bloom:
              phaseStartDateStr =
                  plantMap['bloom_date'] as String? ??
                  plantMap['phase_start_date'] as String?;
              break;
            case PlantPhase.harvest:
              phaseStartDateStr =
                  plantMap['harvest_date'] as String? ??
                  plantMap['phase_start_date'] as String?;
              break;
            case PlantPhase.seedling:
            case PlantPhase.archived:
            case PlantPhase.unknown:
              phaseStartDateStr =
                  plantMap['seed_date'] as String? ??
                  plantMap['phase_start_date'] as String?;
              break;
          }

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
        for (final result in logResults) {
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

        // 3. Photos für alle Logs (Batch) – die finalen Pfade kommen aus dem
        // Staging-Step weiter oben. Jeder Bulk-Plant teilt sich die gleichen
        // physischen Dateien (gleiche file_path-Werte für mehrere log_ids ist
        // gewolltes Bulk-Verhalten und existiert in dieser Codebase bereits).
        if (staged.isNotEmpty && createdLogIds.isNotEmpty) {
          final photoBatch = txn.batch();

          for (final logId in createdLogIds) {
            for (final s in staged) {
              final photo = Photo(logId: logId, filePath: s.finalPath);
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
              [newPhase.name.toUpperCase(), logDate.toIso8601String(), plantId],
            );

            // ✅ FIX #1: Update phase-specific dates (vegDate, bloomDate, harvestDate)
            // Must be done individually (not in batch) to check existing dates
            await _updatePlantPhaseDate(txn, plantId, newPhase, logDate);
          }

          await plantBatch.commit(noResult: true);
        }
      });
        } catch (_) {
          // DB-Fehler → staged Photos sofort weg, damit kein Orphan zurück-
          // bleibt. Anschliessend Original-Fehler weiterreichen.
          await _cleanupStaged(staged);
          rethrow;
        }

        // Transaktion ist sauber durch – jetzt die Dateien sichtbar machen.
        await _commitStaged(staged);
      });

      return createdLogIds;
    } catch (e) {
      // ✅ Re-throw ArgumentErrors directly (for validation errors)
      if (e is ArgumentError) {
        rethrow;
      }
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
  /// Löscht Log und alle zugehörigen Relationen
  @override
  Future<void> deleteLog(int logId) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        // ✅ Explicitly delete related records first (instead of relying on CASCADE)
        // Delete fertilizers
        await txn.delete(
          'log_fertilizers',
          where: 'log_id = ?',
          whereArgs: [logId],
        );

        // Delete photos
        await txn.delete('photos', where: 'log_id = ?', whereArgs: [logId]);

        // Finally delete the log itself
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
        // ✅ Explicitly delete related records first (instead of relying on CASCADE)
        // Delete fertilizers
        await txn.delete(
          'log_fertilizers',
          where: 'log_id IN ($placeholders)',
          whereArgs: logIds,
        );

        // Delete photos
        await txn.delete(
          'photos',
          where: 'log_id IN ($placeholders)',
          whereArgs: logIds,
        );

        // Finally delete the logs
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

/// Internal value type used by the staging-then-commit photo flow.
/// Each entry maps a copy living under `<documents>/photos/.staging/<run>/`
/// to its eventual location under `<documents>/photos/` once the DB row
/// has committed successfully.
class _StagedPhoto {
  final String stagedPath;
  final String finalPath;
  const _StagedPhoto({required this.stagedPath, required this.finalPath});
}
