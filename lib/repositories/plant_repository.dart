// =============================================
// GROWLOG - Plant Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/plant.dart';
import '../utils/validators.dart';
import '../utils/app_logger.dart';

class PlantRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Alle Pflanzen laden (nicht archiviert) mit Pagination
  Future<List<Plant>> findAll({int? limit, int? offset}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'plants',
        where: 'archived = ?',
        whereArgs: [0],
        orderBy: 'id DESC',
        limit: limit,
        offset: offset,
      );

      return maps.map((map) => Plant.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('PlantRepository', 'Failed to load plants', e, stackTrace);
      return []; // Return empty list on error
    }
  }

  /// Pflanze nach ID laden
  Future<Plant?> findById(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'plants',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return Plant.fromMap(maps.first);
    } catch (e, stackTrace) {
      AppLogger.error('PlantRepository', 'Failed to load plant by id', e, stackTrace);
      return null;
    }
  }

  /// Pflanzen nach Room laden
  Future<List<Plant>> findByRoom(int roomId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'plants',
        where: 'room_id = ? AND archived = ?',
        whereArgs: [roomId, 0],
        orderBy: 'id DESC',
      );

      return maps.map((map) => Plant.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('PlantRepository', 'Failed to load plants by room', e, stackTrace);
      return [];
    }
  }

  /// Pflanze speichern (INSERT oder UPDATE)
  /// ✅ FIX: Recalculates log day_numbers wenn seed_date ändert
  Future<Plant> save(Plant plant) async {
    try {
      final db = await _dbHelper.database;

      if (plant.id == null) {
        // INSERT
        final id = await db.insert('plants', plant.toMap());
        return plant.copyWith(id: id);
      } else {
        // UPDATE - Check if seed date or phase start changed
        final oldPlant = await findById(plant.id!);

        if (oldPlant != null) {
          final seedDateChanged = oldPlant.seedDate != plant.seedDate;
          final phaseStartChanged = oldPlant.phaseStartDate != plant.phaseStartDate;

          // ✅ v10: Check for phase history date changes
          final vegDateChanged = oldPlant.vegDate != plant.vegDate;
          final bloomDateChanged = oldPlant.bloomDate != plant.bloomDate;
          final harvestDateChanged = oldPlant.harvestDate != plant.harvestDate;
          final anyPhaseDateChanged = vegDateChanged || bloomDateChanged || harvestDateChanged;

          // Update plant
          await db.update(
            'plants',
            plant.toMap(),
            where: 'id = ?',
            whereArgs: [plant.id],
          );

          // Recalculate log day_numbers if seed date changed
          if (seedDateChanged && plant.seedDate != null) {
            await recalculateLogDayNumbers(plant.id!, plant.seedDate!);
          }

          // ✅ v10: Recalculate ALL phase data if any phase date changed
          if (anyPhaseDateChanged) {
            await recalculateAllPhaseDayNumbers(plant.id!, plant);
          }
          // Fallback to old logic if only phaseStartDate changed (backward compatibility)
          else if (phaseStartChanged && plant.phaseStartDate != null) {
            await recalculatePhaseDayNumbers(plant.id!, plant.phaseStartDate!);
          }
        } else {
          // Old plant not found, just update
          await db.update(
            'plants',
            plant.toMap(),
            where: 'id = ?',
            whereArgs: [plant.id],
          );
        }

        return plant;
      }
    } catch (e, stackTrace) {
      AppLogger.error('PlantRepository', 'Failed to save plant', e, stackTrace);
      rethrow;
    }
  }

  /// Pflanze löschen
  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'plants',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      AppLogger.error('PlantRepository', 'Failed to delete plant', e, stackTrace);
      rethrow;
    }
  }

  /// Pflanze archivieren
  Future<int> archive(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'plants',
      {'archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Pflanze aktualisieren (UPDATE only)
  Future<int> update(Plant plant) async {
    if (plant.id == null) {
      throw Exception('Plant ID cannot be null for update');
    }
    final db = await _dbHelper.database;
    return await db.update(
      'plants',
      plant.toMap(),
      where: 'id = ?',
      whereArgs: [plant.id],
    );
  }

  /// Anzahl Pflanzen
  Future<int> count() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM plants WHERE archived = 0');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('PlantRepository', 'Failed to count plants', e, stackTrace);
      return 0;
    }
  }

  /// ✅ FIX: Recalculate all log day_numbers for a plant
  /// Called when seed date changes
  Future<void> recalculateLogDayNumbers(int plantId, DateTime seedDate) async {
    final db = await _dbHelper.database;
    AppLogger.debug('PlantRepo', 'Recalculating day_numbers for plant', 'plantId=$plantId');

    // Get all logs for this plant
    final logs = await db.query(
      'plant_logs',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'log_date ASC',
    );

    int updated = 0;
    int deleted = 0;

    for (final log in logs) {
      final logDateStr = log['log_date'] as String;
      final logDate = DateTime.parse(logDateStr);

      // Check if log is before new seed date
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);
      final seedDay = DateTime(seedDate.year, seedDate.month, seedDate.day);

      if (logDay.isBefore(seedDay)) {
        // Delete invalid logs (before seed date)
        await db.delete('plant_logs', where: 'id = ?', whereArgs: [log['id']]);
        deleted++;
        AppLogger.debug('PlantRepo', 'Deleted log (before seed date)', 'logId=${log['id']}');
      } else {
        // Recalculate day_number
        final newDayNumber = Validators.calculateDayNumber(logDate, seedDate);

        await db.update(
          'plant_logs',
          {'day_number': newDayNumber},
          where: 'id = ?',
          whereArgs: [log['id']],
        );
        updated++;
      }
    }

    AppLogger.info('PlantRepo', '✅ Updated logs and deleted invalid logs', 'updated=$updated, deleted=$deleted');
  }

  /// ✅ FIX: Recalculate all phase_day_numbers for a plant
  /// Called when phase start date changes
  Future<void> recalculatePhaseDayNumbers(int plantId, DateTime phaseStartDate) async {
    final db = await _dbHelper.database;
    AppLogger.debug('PlantRepo', 'Recalculating phase_day_numbers for plant', 'plantId=$plantId');

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

      // Only update logs that are after (or on) phase start date
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

    AppLogger.info('PlantRepo', '✅ Updated phase_day_numbers', 'count=$updated');
  }

  /// ✅ v10: Recalculate ALL phase and phase_day_number for ALL logs based on phase history
  /// This is called when vegDate, bloomDate, or harvestDate changes
  Future<void> recalculateAllPhaseDayNumbers(int plantId, Plant plant) async {
    final db = await _dbHelper.database;
    AppLogger.debug('PlantRepo', 'Recalculating ALL phase data for plant', 'plantId=$plantId');

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
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);

      // Determine which phase this log belongs to based on phase dates
      String? newPhase;
      int? newPhaseDayNumber;

      // Check phases in reverse order (harvest → bloom → veg → seedling)
      if (plant.harvestDate != null) {
        final harvestDay = DateTime(
          plant.harvestDate!.year,
          plant.harvestDate!.month,
          plant.harvestDate!.day,
        );
        if (!logDay.isBefore(harvestDay)) {
          newPhase = 'HARVEST';
          newPhaseDayNumber = Validators.calculateDayNumber(logDate, plant.harvestDate!);
        }
      }

      if (newPhase == null && plant.bloomDate != null) {
        final bloomDay = DateTime(
          plant.bloomDate!.year,
          plant.bloomDate!.month,
          plant.bloomDate!.day,
        );
        if (!logDay.isBefore(bloomDay)) {
          newPhase = 'BLOOM';
          newPhaseDayNumber = Validators.calculateDayNumber(logDate, plant.bloomDate!);
        }
      }

      if (newPhase == null && plant.vegDate != null) {
        final vegDay = DateTime(
          plant.vegDate!.year,
          plant.vegDate!.month,
          plant.vegDate!.day,
        );
        if (!logDay.isBefore(vegDay)) {
          newPhase = 'VEG';
          newPhaseDayNumber = Validators.calculateDayNumber(logDate, plant.vegDate!);
        }
      }

      // If no specific phase date is set, default to SEEDLING
      if (newPhase == null && plant.seedDate != null) {
        newPhase = 'SEEDLING';
        newPhaseDayNumber = Validators.calculateDayNumber(logDate, plant.seedDate!);
      }

      // Update log with new phase and phase_day_number
      if (newPhase != null) {
        await db.update(
          'plant_logs',
          {
            'phase': newPhase,
            'phase_day_number': newPhaseDayNumber,
          },
          where: 'id = ?',
          whereArgs: [log['id']],
        );
        updated++;

        AppLogger.debug(
          'PlantRepo',
          'Updated log ${log['id']}: $logDate → $newPhase (Day $newPhaseDayNumber)',
        );
      }
    }

    AppLogger.info('PlantRepo', '✅ Recalculated ALL phase data', 'updated=$updated logs');
  }

  /// Get count of logs for a plant (used to show warning before seed date change)
  Future<int> getLogCount(int plantId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM plant_logs WHERE plant_id = ?',
      [plantId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get plants by RDWC System ID
  Future<List<Plant>> findByRdwcSystem(int systemId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'plants',
        where: 'rdwc_system_id = ? AND archived = ?',
        whereArgs: [systemId, 0],
        orderBy: 'bucket_number ASC',
      );

      return maps.map((map) => Plant.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('PlantRepository', 'Failed to load plants by RDWC system', e, stackTrace);
      return [];
    }
  }
}
