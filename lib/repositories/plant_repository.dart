// =============================================
// GROWLOG - Plant Repository
// =============================================

import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/safe_parsers.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';
import 'package:growlog_app/config/database_config.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class PlantRepository with RepositoryErrorHandler implements IPlantRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  String get repositoryName => 'PlantRepository';

  /// Alle Pflanzen laden (nicht archiviert) mit Pagination
  @override
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
      AppLogger.error(
        'PlantRepository',
        'Failed to load plants',
        e,
        stackTrace,
      );
      return []; // Return empty list on error
    }
  }

  /// Pflanze nach ID laden
  @override
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
      AppLogger.error(
        'PlantRepository',
        'Failed to load plant by id',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Pflanzen nach Room laden
  @override
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
      AppLogger.error(
        'PlantRepository',
        'Failed to load plants by room',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// ✅ FIX: Added method to load plants by grow
  @override
  Future<List<Plant>> findByGrow(int growId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'plants',
        where: 'grow_id = ? AND archived = ?',
        whereArgs: [growId, 0],
        orderBy: 'id DESC',
      );

      return maps.map((map) => Plant.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to load plants by grow',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// Pflanze speichern (INSERT oder UPDATE)
  /// ✅ FIX: Recalculates log day_numbers wenn seed_date ändert
  @override
  Future<Plant> save(Plant plant) async {
    try {
      // ✅ FIX #5: Validate bucket uniqueness for RDWC plants
      if (plant.rdwcSystemId != null && plant.bucketNumber != null) {
        final bucketOccupied = await isBucketOccupied(
          plant.rdwcSystemId!,
          plant.bucketNumber!,
          excludePlantId: plant.id, // Exclude self for UPDATE
        );

        if (bucketOccupied) {
          throw RepositoryException.conflict(
            'Bucket ${plant.bucketNumber} im RDWC-System ist bereits belegt. '
            'Bitte wählen Sie einen anderen Bucket.',
          );
        }
      }

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
          final phaseStartChanged =
              oldPlant.phaseStartDate != plant.phaseStartDate;

          // ✅ v10: Check for phase history date changes
          final vegDateChanged = oldPlant.vegDate != plant.vegDate;
          final bloomDateChanged = oldPlant.bloomDate != plant.bloomDate;
          final harvestDateChanged = oldPlant.harvestDate != plant.harvestDate;
          final anyPhaseDateChanged =
              vegDateChanged || bloomDateChanged || harvestDateChanged;

          // ✅ FIX: Recalculate ALL log data if ANY date changes
          // This ensures consistency: seedDate changes affect phases too!
          final anyDateChanged =
              seedDateChanged || anyPhaseDateChanged || phaseStartChanged;

          // ✅ CRITICAL FIX: Warn user before deleting logs
          if (seedDateChanged && plant.seedDate != null) {
            final logsToDelete = await countLogsToBeDeleted(
              plant.id!,
              plant.seedDate!,
            );
            if (logsToDelete > 0) {
              AppLogger.warning(
                'PlantRepository',
                'Seed date change will delete $logsToDelete logs',
                'plantId=${plant.id}, oldDate=${oldPlant.seedDate}, newDate=${plant.seedDate}',
              );
              throw Exception(
                'SEED_DATE_CHANGE_WARNING: Changing seed date will delete $logsToDelete log(s). '
                'This action cannot be undone. Please confirm in the UI before proceeding.',
              );
            }
          }

          // ✅ FIX v11: All updates in transaction for consistency
          await db
              .transaction((txn) async {
                // 1. Update plant
                await txn.update(
                  'plants',
                  plant.toMap(),
                  where: 'id = ?',
                  whereArgs: [plant.id],
                );

                // 2. Recalculate log data if any date changed
                if (anyDateChanged && plant.seedDate != null) {
                  await _recalculateAllLogDataInTransaction(
                    txn,
                    plant.id!,
                    plant,
                  );
                }
              })
              .timeout(
                DatabaseConfig.complexTransactionTimeout,
                onTimeout: () => throw TimeoutException(
                  'Plant update transaction timeout after ${DatabaseConfig.complexTransactionTimeout.inSeconds}s',
                ),
              );
        } else {
          // ✅ LOW PRIORITY BUG FIX: Log warning instead of silently updating when old plant not found
          AppLogger.warning(
            'PlantRepository',
            'Old plant not found for update (ID: ${plant.id}). Updating without recalculation.',
          );
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

  /// 🔒 SOFT DELETE: Archive plant instead of deleting
  /// After migration v14, this method archives the plant and its logs
  /// Use deletePermanently() for actual deletion
  @override
  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;

      // Archive plant and all its logs
      return await db.transaction((txn) async {
        AppLogger.info(
          'PlantRepo',
          'Archiving plant (soft delete)',
          'plantId=$id',
        );

        // Archive all plant logs
        await txn.update(
          'plant_logs',
          {'archived': 1},
          where: 'plant_id = ?',
          whereArgs: [id],
        );

        // Archive the plant itself
        final result = await txn.update(
          'plants',
          {'archived': 1},
          where: 'id = ?',
          whereArgs: [id],
        );

        AppLogger.info('PlantRepo', '✅ Plant archived (soft delete completed)');
        return result;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to archive plant',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// ✅ RESTORE: Restores archived plant and all its logs
  Future<int> restore(int id) async {
    try {
      final db = await _dbHelper.database;

      // Restore plant and all its logs
      return await db.transaction((txn) async {
        AppLogger.info(
          'PlantRepo',
          'Restoring plant from archive',
          'plantId=$id',
        );

        // Restore all plant logs
        await txn.update(
          'plant_logs',
          {'archived': 0},
          where: 'plant_id = ?',
          whereArgs: [id],
        );

        // Restore the plant itself
        final result = await txn.update(
          'plants',
          {'archived': 0},
          where: 'id = ?',
          whereArgs: [id],
        );

        AppLogger.info('PlantRepo', '✅ Plant restored from archive');
        return result;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to restore plant',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all archived plants
  Future<List<Plant>> findArchived({int? limit, int? offset}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'plants',
        where: 'archived = ?',
        whereArgs: [1],
        orderBy: 'id DESC',
        limit: limit,
        offset: offset,
      );

      return maps.map((map) => Plant.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to load archived plants',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// ⚠️ PERMANENT DELETE: Deletes plant and ALL related data
  /// This is irreversible! Use with caution.
  ///
  /// After migration v14, you must manually delete related data first
  /// due to RESTRICT constraints. This method handles that.
  ///
  /// Deletion order (to respect foreign key constraints):
  /// 1. Log fertilizers
  /// 2. Photos
  /// 3. Plant logs
  /// 4. Harvests
  /// 5. Plant itself
  Future<int> deletePermanently(int id) async {
    try {
      final db = await _dbHelper.database;

      return await db
          .transaction((txn) async {
            AppLogger.warning(
              'PlantRepo',
              '⚠️ PERMANENT DELETE: Starting cascading delete',
              'plantId=$id',
            );

            // Step 1: Get all log IDs for this plant
            final logs = await txn.query(
              'plant_logs',
              columns: ['id'],
              where: 'plant_id = ?',
              whereArgs: [id],
            );
            final logIds = logs.map((log) => log['id'] as int).toList();

            int deletedLogFertilizers = 0;
            int deletedPhotos = 0;
            int deletedPhotoFiles = 0;
            final List<String> failedPhotoDeletes = [];

            if (logIds.isNotEmpty) {
              for (final logId in logIds) {
                // Delete log_fertilizers first (FK to plant_logs)
                final fertCount = await txn.delete(
                  'log_fertilizers',
                  where: 'log_id = ?',
                  whereArgs: [logId],
                );
                deletedLogFertilizers += fertCount;

                // Get photo records
                final photos = await txn.query(
                  'photos',
                  where: 'log_id = ?',
                  whereArgs: [logId],
                );

                // Delete physical photo files
                for (final photo in photos) {
                  try {
                    final filePath = photo['image_path'] as String;
                    final file = File(filePath);
                    if (await file.exists()) {
                      await file.delete();
                      deletedPhotoFiles++;
                    } else {
                      // File doesn't exist - log warning but don't fail
                      AppLogger.warning(
                        'PlantRepo',
                        'Photo file not found (already deleted?): $filePath',
                      );
                    }
                  } catch (e) {
                    // Collect failed deletes to abort transaction
                    final filePath = photo['image_path'] as String;
                    failedPhotoDeletes.add(filePath);
                    AppLogger.error(
                      'PlantRepo',
                      'Failed to delete photo file: $filePath',
                      e,
                    );
                  }
                }

                // Delete photo records
                final photoCount = await txn.delete(
                  'photos',
                  where: 'log_id = ?',
                  whereArgs: [logId],
                );
                deletedPhotos += photoCount;
              }
            }

            // ✅ CRITICAL FIX: Abort transaction if photo file deletion failed
            if (failedPhotoDeletes.isNotEmpty) {
              final errorMsg =
                  'Failed to delete ${failedPhotoDeletes.length} photo files:\n'
                  '${failedPhotoDeletes.take(5).join("\n")}'
                  '${failedPhotoDeletes.length > 5 ? "\n... and ${failedPhotoDeletes.length - 5} more" : ""}';
              AppLogger.error('PlantRepo', errorMsg);
              throw Exception(
                'Cannot permanently delete plant: Failed to delete photo files. '
                'This prevents orphaned files in filesystem. Please check file permissions.',
              );
            }

            // Step 2: Delete all plant logs
            final deletedLogs = await txn.delete(
              'plant_logs',
              where: 'plant_id = ?',
              whereArgs: [id],
            );

            // Step 3: Delete all harvests
            final deletedHarvests = await txn.delete(
              'harvests',
              where: 'plant_id = ?',
              whereArgs: [id],
            );

            // Step 4: Finally, delete the plant itself
            final deletedPlant = await txn.delete(
              'plants',
              where: 'id = ?',
              whereArgs: [id],
            );

            AppLogger.warning(
              'PlantRepo',
              '⚠️ PERMANENT DELETE completed',
              'plant=$deletedPlant, logs=$deletedLogs, harvests=$deletedHarvests, '
                  'photos=$deletedPhotos, photoFiles=$deletedPhotoFiles, fertilizers=$deletedLogFertilizers',
            );

            return deletedPlant;
          })
          .timeout(
            DatabaseConfig.heavyOperationTimeout,
            onTimeout: () => throw TimeoutException(
              'Permanent delete transaction timeout after ${DatabaseConfig.heavyOperationTimeout.inSeconds}s',
            ),
          );
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to permanently delete plant',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of related data for a plant (for delete warning dialog)
  @override
  Future<Map<String, int>> getRelatedDataCounts(int plantId) async {
    try {
      final db = await _dbHelper.database;

      // Count logs
      final logsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM plant_logs WHERE plant_id = ?',
        [plantId],
      );
      final logsCount = Sqflite.firstIntValue(logsResult) ?? 0;

      // Count photos (via logs)
      final photosResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count FROM photos
        WHERE log_id IN (SELECT id FROM plant_logs WHERE plant_id = ?)
      ''',
        [plantId],
      );
      final photosCount = Sqflite.firstIntValue(photosResult) ?? 0;

      // Count harvests
      final harvestsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM harvests WHERE plant_id = ?',
        [plantId],
      );
      final harvestsCount = Sqflite.firstIntValue(harvestsResult) ?? 0;

      return {
        'logs': logsCount,
        'photos': photosCount,
        'harvests': harvestsCount,
      };
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to count related data',
        e,
        stackTrace,
      );
      return {'logs': 0, 'photos': 0, 'harvests': 0};
    }
  }

  /// Pflanze archivieren
  @override
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
  @override
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
  @override
  Future<int> count() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM plants WHERE archived = 0',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to count plants',
        e,
        stackTrace,
      );
      return 0;
    }
  }

  /// ✅ NEW: Count how many logs would be deleted if seedDate changes
  /// This allows UI to warn user before data loss
  @override
  Future<int> countLogsToBeDeleted(int plantId, DateTime newSeedDate) async {
    try {
      final db = await _dbHelper.database;
      final seedDay = DateTime(
        newSeedDate.year,
        newSeedDate.month,
        newSeedDate.day,
      );

      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM plant_logs
        WHERE plant_id = ?
          AND DATE(log_date) < DATE(?)
      ''',
        [plantId, seedDay.toIso8601String()],
      );

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      AppLogger.error('PlantRepository', 'Error counting logs to delete', e);
      return 0;
    }
  }

  /// ✅ REFACTOR: Extract phase determination logic for better maintainability
  /// Determines which phase a log falls into based on plant's phase dates
  /// Returns Map with 'phase' (String) and 'phaseDayNumber' (int)
  Map<String, dynamic> _determinePhaseForLog(DateTime logDate, Plant plant) {
    final logDay = DateTime(logDate.year, logDate.month, logDate.day);

    // Check phases in reverse chronological order (harvest → bloom → veg → seedling)

    // Check harvest phase
    if (plant.harvestDate != null) {
      final harvestDay = DateTime(
        plant.harvestDate!.year,
        plant.harvestDate!.month,
        plant.harvestDate!.day,
      );
      if (!logDay.isBefore(harvestDay)) {
        return {
          'phase': 'HARVEST',
          'phaseDayNumber': Validators.calculateDayNumber(
            logDate,
            plant.harvestDate!,
          ),
        };
      }
    }

    // Check bloom phase
    if (plant.bloomDate != null) {
      final bloomDay = DateTime(
        plant.bloomDate!.year,
        plant.bloomDate!.month,
        plant.bloomDate!.day,
      );
      if (!logDay.isBefore(bloomDay)) {
        return {
          'phase': 'BLOOM',
          'phaseDayNumber': Validators.calculateDayNumber(
            logDate,
            plant.bloomDate!,
          ),
        };
      }
    }

    // Check veg phase
    if (plant.vegDate != null) {
      final vegDay = DateTime(
        plant.vegDate!.year,
        plant.vegDate!.month,
        plant.vegDate!.day,
      );
      if (!logDay.isBefore(vegDay)) {
        return {
          'phase': 'VEG',
          'phaseDayNumber': Validators.calculateDayNumber(
            logDate,
            plant.vegDate!,
          ),
        };
      }
    }

    // Default to seedling phase
    // ✅ BUG FIX: Handle missing seedDate gracefully (return 0 instead of null)
    if (plant.seedDate == null) {
      return {'phase': 'SEEDLING', 'phaseDayNumber': 0};
    }
    return {
      'phase': 'SEEDLING',
      'phaseDayNumber': Validators.calculateDayNumber(logDate, plant.seedDate!),
    };
  }

  /// ✅ FIX v11: Comprehensive log recalculation with transaction
  /// This method handles ALL log recalculations in a single transaction:
  /// 1. Deletes logs before seedDate
  /// 2. Recalculates day_number for all remaining logs
  /// 3. Recalculates phase and phase_day_number based on phase dates
  ///
  /// Called when ANY date changes (seedDate, vegDate, bloomDate, harvestDate, phaseStartDate)
  Future<void> recalculateAllLogData(int plantId, Plant plant) async {
    final db = await _dbHelper.database;

    // Use transaction for data integrity
    await db.transaction((txn) async {
      await _recalculateAllLogDataInTransaction(txn, plantId, plant);
    });
  }

  /// Internal helper: Recalculate log data within an existing transaction
  /// This allows safe use when already inside a transaction (called from save())
  ///
  /// ⚠️ CRITICAL TRANSACTION SAFETY (BUG #1.2):
  /// This method MUST receive a DatabaseExecutor (transaction) parameter
  /// to avoid nested transactions. SQLite does NOT support nested transactions.
  ///
  /// ALWAYS pass the `txn` parameter from the parent transaction.
  Future<void> _recalculateAllLogDataInTransaction(
    DatabaseExecutor txn,
    int plantId,
    Plant plant,
  ) async {
    AppLogger.debug(
      'PlantRepo',
      'Starting comprehensive log recalculation',
      'plantId=$plantId',
    );

    // Get all logs for this plant
    final logs = await txn.query(
      'plant_logs',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'log_date ASC',
    );

    int deleted = 0;
    int updated = 0;

    for (final log in logs) {
      final logDateStr = log['log_date'] as String;
      // ✅ HIGH FIX: Use SafeParsers to prevent crashes from corrupted DB data
      final logDate = SafeParsers.parseDateTime(
        logDateStr,
        fallback: DateTime.now(),
        context: 'PlantRepository.recalculateDayNumbers',
      );
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);

      if (plant.seedDate == null) {
        AppLogger.error(
          'PlantRepo',
          'Plant has no seedDate, skipping log recalculation',
          Exception('Missing seedDate'),
        );
        continue;
      }

      final seedDay = DateTime(
        plant.seedDate!.year,
        plant.seedDate!.month,
        plant.seedDate!.day,
      );

      // Step 1: Delete logs before seedDate
      if (logDay.isBefore(seedDay)) {
        await txn.delete('plant_logs', where: 'id = ?', whereArgs: [log['id']]);
        deleted++;
        AppLogger.debug(
          'PlantRepo',
          'Deleted log before seedDate',
          'logId=${log['id']}',
        );
        continue;
      }

      // Step 2: Calculate day_number
      final newDayNumber = Validators.calculateDayNumber(
        logDate,
        plant.seedDate!,
      );

      // Step 3: Determine phase and phase_day_number using extracted helper
      final phaseInfo = _determinePhaseForLog(logDate, plant);
      final newPhase = phaseInfo['phase'] as String;
      // ✅ CRITICAL FIX: Handle null phaseDayNumber safely (can be null if seedDate is missing)
      final newPhaseDayNumber = phaseInfo['phaseDayNumber'] as int? ?? 0;

      // Step 4: Update log with all recalculated data
      await txn.update(
        'plant_logs',
        {
          'day_number': newDayNumber,
          'phase': newPhase,
          'phase_day_number': newPhaseDayNumber,
        },
        where: 'id = ?',
        whereArgs: [log['id']],
      );
      updated++;

      AppLogger.debug(
        'PlantRepo',
        'Updated log ${log['id']}: day=$newDayNumber, phase=$newPhase, phaseDay=$newPhaseDayNumber',
      );
    }

    AppLogger.info(
      'PlantRepo',
      '✅ Comprehensive log recalculation completed',
      'updated=$updated, deleted=$deleted',
    );
  }

  /// Get count of logs for a plant (used to show warning before seed date change)
  @override
  Future<int> getLogCount(int plantId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM plant_logs WHERE plant_id = ?',
      [plantId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get plants by RDWC System ID
  @override
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
      AppLogger.error(
        'PlantRepository',
        'Failed to load plants by RDWC system',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// ✅ FIX #5: Check if RDWC bucket is occupied
  /// Returns true if bucket is occupied by a non-archived plant
  /// [excludePlantId] - Optional: exclude specific plant ID (for UPDATE validation)
  Future<bool> isBucketOccupied(
    int systemId,
    int bucketNumber, {
    int? excludePlantId,
  }) async {
    try {
      final db = await _dbHelper.database;

      // Build WHERE clause
      String whereClause = 'rdwc_system_id = ? AND bucket_number = ? AND archived = 0';
      List<dynamic> whereArgs = [systemId, bucketNumber];

      // Exclude specific plant ID if provided (for UPDATE validation)
      if (excludePlantId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excludePlantId);
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM plants WHERE $whereClause',
        whereArgs,
      );

      final count = Sqflite.firstIntValue(result) ?? 0;
      return count > 0;
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to check bucket occupation',
        e,
        stackTrace,
      );
      return false; // Conservative: assume not occupied if check fails
    }
  }

  /// ✅ DATA LOSS PREVENTION: Find orphaned plants
  /// Returns plants that have NO grow_id AND NO room_id
  /// These plants were likely "lost" when their grow/room was deleted with ON DELETE SET NULL
  @override
  Future<List<Plant>> findOrphans() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'plants',
        where: 'grow_id IS NULL AND room_id IS NULL AND archived = ?',
        whereArgs: [0],
        orderBy: 'created_at DESC',
      );

      AppLogger.info(
        'PlantRepository',
        'Found ${maps.length} orphaned plants',
      );

      return maps.map((map) => Plant.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlantRepository',
        'Failed to load orphaned plants',
        e,
        stackTrace,
      );
      return [];
    }
  }
}
