// =============================================
// GROWLOG - Grow Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/safe_parsers.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class GrowRepository with RepositoryErrorHandler implements IGrowRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  String get repositoryName => 'GrowRepository';


  /// Alle Grows abrufen (nicht archiviert)
  /// ✅ CRITICAL FIX: Added limit parameter to prevent memory overflow
  @override
  Future<List<Grow>> getAll({bool includeArchived = false, int? limit}) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps;

      if (includeArchived) {
        maps = await db.query(
          'grows',
          orderBy: 'start_date DESC',
          limit: limit ?? 1000,  // Reasonable default limit
        );
      } else {
        maps = await db.query(
          'grows',
          where: 'archived = ?',
          whereArgs: [0],
          orderBy: 'start_date DESC',
          limit: limit ?? 1000,  // Reasonable default limit
        );
      }

      return List.generate(maps.length, (i) => Grow.fromMap(maps[i]));
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to load grows', e, stackTrace);
      return [];
    }
  }

  /// Grow nach ID abrufen
  @override
  Future<Grow?> getById(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'grows',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return Grow.fromMap(maps.first);
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to load grow by id', e, stackTrace);
      return null;
    }
  }

  /// Neuen Grow erstellen
  @override
  Future<int> create(Grow grow) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert('grows', grow.toMap());
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to create grow', e, stackTrace);
      rethrow;
    }
  }

  /// Grow aktualisieren
  @override
  Future<int> update(Grow grow) async {
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'grows',
        grow.toMap(),
        where: 'id = ?',
        whereArgs: [grow.id],
      );
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to update grow', e, stackTrace);
      rethrow;
    }
  }

  /// Grow löschen
  ///
  /// ⚠️ WICHTIGES VERHALTEN: Pflanzen im Grow werden NICHT gelöscht!
  ///
  /// Architektonische Entscheidung:
  /// - Grow ist ein Container-Objekt (wie Room, RDWC-System)
  /// - Beim Löschen wird `plants.grow_id` auf NULL gesetzt (ON DELETE SET NULL)
  /// - Pflanzen bleiben mit allen Logs, Fotos und Ernten erhalten
  ///
  /// Vorteile dieses Designs:
  /// ✅ Datensicherheit: Versehentliches Löschen ist umkehrbar
  /// ✅ Flexibilität: Pflanzen können später neu zugeordnet werden
  /// ✅ Konsistenz: Gleiches Verhalten wie Room/RDWC-System
  /// ✅ Historienschutz: Wertvolle Wachstumsdaten bleiben erhalten
  ///
  /// Alternative Operationen:
  /// - Zum Abschließen eines Grow-Zyklus: archive(id) verwenden
  /// - Zum vollständigen Löschen einer Pflanze: PlantRepository.delete() verwenden
  ///
  /// ✅ FIX v11: Use transaction to prevent race condition
  @override
  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        // 1. First, detach all plants from this grow
        await txn.update(
          'plants',
          {'grow_id': null},
          where: 'grow_id = ?',
          whereArgs: [id],
        );

        // 2. Then delete the grow itself
        return await txn.delete(
          'grows',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to delete grow', e, stackTrace);
      rethrow;
    }
  }

  /// Grow archivieren
  @override
  Future<int> archive(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'grows',
      {'archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Grow wiederherstellen
  @override
  Future<int> unarchive(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'grows',
      {'archived': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Anzahl Pflanzen in einem Grow
  @override
  Future<int> getPlantCount(int growId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM plants WHERE grow_id = ?',
        [growId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to get plant count', e, stackTrace);
      return 0;
    }
  }

  /// ✅ FIX BUG #1: Batch-Query für Plant Counts (verhindert N+1 Problem!)
  /// Gibt Map zurück: {growId: plantCount}
  @override
  Future<Map<int, int>> getPlantCountsForGrows(List<int> growIds) async {
    try {
      final db = await _dbHelper.database;

      if (growIds.isEmpty) return {};

      // Prepared Statement mit Platzhaltern
      final placeholders = List.filled(growIds.length, '?').join(',');
      final result = await db.rawQuery('''
        SELECT grow_id, COUNT(*) as count
        FROM plants
        WHERE grow_id IN ($placeholders)
        GROUP BY grow_id
      ''', growIds);

      // Map erstellen: growId → count
      final counts = <int, int>{};
      for (var row in result) {
        counts[row['grow_id'] as int] = row['count'] as int;
      }

      return counts;
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to get plant counts', e, stackTrace);
      return {};
    }
  }

  /// Phase für alle Pflanzen in einem Grow ändern
  /// ✅ FIX v11: Use transaction to prevent race condition and improve performance
  @override
  Future<void> updatePhaseForAllPlants(int growId, String newPhase) async {
    final db = await _dbHelper.database;
    final newPhaseStartDate = DateTime.now().toIso8601String().split('T')[0];
    // ✅ HIGH FIX: Use SafeParsers to prevent crashes from invalid date strings
    final phaseStartDate = SafeParsers.parseDateTime(
      newPhaseStartDate,
      fallback: DateTime.now(),
      context: 'GrowRepository.updatePhaseForAllPlants',
    );

    AppLogger.debug('GrowRepo', 'Updating phase for all plants', 'growId=$growId, newPhase=$newPhase');

    await db.transaction((txn) async {
      // 1. Get all plant IDs in this grow
      final plantMaps = await txn.query(
        'plants',
        columns: ['id', 'name'],
        where: 'grow_id = ?',
        whereArgs: [growId],
      );

      final plantIds = plantMaps.map((m) => m['id'] as int).toList();

      if (plantIds.isEmpty) {
        AppLogger.info('GrowRepo', 'No plants found in grow', 'growId=$growId');
        return;
      }

      // 2. Update all plants' phase and phase_start_date (single batch update)
      await txn.update(
        'plants',
        {
          'phase': newPhase.toUpperCase(),
          'phase_start_date': newPhaseStartDate,
        },
        where: 'grow_id = ?',
        whereArgs: [growId],
      );

      AppLogger.info('GrowRepo', 'Updated plants to new phase', 'count=${plantIds.length}, phase=$newPhase');

      // 3. ✅ FIX: Recalculate phase_day_numbers for ALL plants (in transaction)
      int totalLogsUpdated = 0;
      for (final plantId in plantIds) {
        final logsUpdated = await _recalculatePhaseDayNumbersInTransaction(txn, plantId, phaseStartDate);
        totalLogsUpdated += logsUpdated;
      }

      AppLogger.info('GrowRepo', '✅ Updated phase for plants and recalculated logs', 'plants=${plantIds.length}, logs=$totalLogsUpdated');
    });
  }

  /// ✅ FIX v11: Helper method to recalculate phase day numbers within a transaction
  /// Called when phase changes for plants in a grow
  Future<int> _recalculatePhaseDayNumbersInTransaction(
    DatabaseExecutor txn,
    int plantId,
    DateTime phaseStartDate,
  ) async {
    // Get all logs for this plant
    final logs = await txn.query(
      'plant_logs',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'log_date ASC',
    );

    int updated = 0;

    for (final log in logs) {
      final logDateStr = log['log_date'] as String;
      // ✅ HIGH FIX: Use SafeParsers to prevent crashes from corrupted DB data
      final logDate = SafeParsers.parseDateTime(
        logDateStr,
        fallback: DateTime.now(),
        context: 'GrowRepository.updatePhaseForAllPlants.logDate',
      );

      // Only update logs that are on or after phase start date
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);
      final phaseDay = DateTime(phaseStartDate.year, phaseStartDate.month, phaseStartDate.day);

      if (!logDay.isBefore(phaseDay)) {
        // Recalculate phase_day_number
        final newPhaseDayNumber = Validators.calculateDayNumber(logDate, phaseStartDate);

        await txn.update(
          'plant_logs',
          {'phase_day_number': newPhaseDayNumber},
          where: 'id = ?',
          whereArgs: [log['id']],
        );
        updated++;
      }
    }

    return updated;
  }
}
