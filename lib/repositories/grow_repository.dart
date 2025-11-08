// =============================================
// GROWLOG - Grow Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../models/grow.dart';
import '../database/database_helper.dart';
import '../utils/validators.dart';
import '../utils/app_logger.dart';

class GrowRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;


  /// Alle Grows abrufen (nicht archiviert)
  Future<List<Grow>> getAll({bool includeArchived = false}) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps;

      if (includeArchived) {
        maps = await db.query('grows', orderBy: 'start_date DESC');
      } else {
        maps = await db.query(
          'grows',
          where: 'archived = ?',
          whereArgs: [0],
          orderBy: 'start_date DESC',
        );
      }

      return List.generate(maps.length, (i) => Grow.fromMap(maps[i]));
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to load grows', e, stackTrace);
      return [];
    }
  }

  /// Grow nach ID abrufen
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
  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;

      // Erst Pflanzen von diesem Grow trennen
      await db.update(
        'plants',
        {'grow_id': null},
        where: 'grow_id = ?',
        whereArgs: [id],
      );

      // Dann Grow löschen
      return await db.delete(
        'grows',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      AppLogger.error('GrowRepository', 'Failed to delete grow', e, stackTrace);
      rethrow;
    }
  }

  /// Grow archivieren
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
  /// ✅ FIX BUG #2: Now recalculates phase_day_numbers for existing logs
  Future<void> updatePhaseForAllPlants(int growId, String newPhase) async {
    final db = await _dbHelper.database;
    final newPhaseStartDate = DateTime.now().toIso8601String().split('T')[0];
    final phaseStartDate = DateTime.parse(newPhaseStartDate);

    AppLogger.debug('GrowRepo', 'Updating phase for all plants', 'growId=$growId, newPhase=$newPhase');

    // 1. Get all plant IDs in this grow
    final plantMaps = await db.query(
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

    // 2. Update all plants' phase and phase_start_date
    await db.update(
      'plants',
      {
        'phase': newPhase.toUpperCase(),
        'phase_start_date': newPhaseStartDate,
      },
      where: 'grow_id = ?',
      whereArgs: [growId],
    );

    AppLogger.info('GrowRepo', 'Updated plants to new phase', 'count=${plantIds.length}, phase=$newPhase');

    // 3. ✅ FIX: Recalculate phase_day_numbers for ALL plants
    int totalLogsUpdated = 0;
    for (final plantId in plantIds) {
      final logsUpdated = await _recalculatePhaseDayNumbers(plantId, phaseStartDate);
      totalLogsUpdated += logsUpdated;
    }

    AppLogger.info('GrowRepo', '✅ Updated phase for plants and recalculated logs', 'plants=${plantIds.length}, logs=$totalLogsUpdated');
  }

  /// ✅ FIX BUG #2: Helper method to recalculate phase day numbers
  /// Called when phase changes for plants in a grow
  Future<int> _recalculatePhaseDayNumbers(int plantId, DateTime phaseStartDate) async {
    final db = await _dbHelper.database;

    // Get all logs for this plant
    final logs = await db.query(
      'plant_logs',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'log_date ASC',
    );

    int updated = 0;

    for (final log in logs) {
      final logDateStr = log['log_date'] as String;
      final logDate = DateTime.parse(logDateStr);

      // Only update logs that are on or after phase start date
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);
      final phaseDay = DateTime(phaseStartDate.year, phaseStartDate.month, phaseStartDate.day);

      if (!logDay.isBefore(phaseDay)) {
        // Recalculate phase_day_number
        final newPhaseDayNumber = Validators.calculateDayNumber(logDate, phaseStartDate);

        await db.update(
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
