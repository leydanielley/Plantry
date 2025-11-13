// =============================================
// GROWLOG - RDWC System Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/rdwc_log_fertilizer.dart';
import 'package:growlog_app/models/rdwc_recipe.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class RdwcRepository with RepositoryErrorHandler implements IRdwcRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  String get repositoryName => 'RdwcRepository';

  // ==========================================
  // RDWC SYSTEMS
  // ==========================================

  /// Get all RDWC systems
  @override
  Future<List<RdwcSystem>> getAllSystems({bool includeArchived = false}) async {
    try {
      final db = await _dbHelper.database;
      final where = includeArchived ? null : 'archived = ?';
      final whereArgs = includeArchived ? null : [0];

      final maps = await db.query(
        'rdwc_systems',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => RdwcSystem.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading RDWC systems', e);
      return [];
    }
  }

  /// Get systems by room
  @override
  Future<List<RdwcSystem>> getSystemsByRoom(
    int roomId, {
    bool includeArchived = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      final where = includeArchived
          ? 'room_id = ?'
          : 'room_id = ? AND archived = ?';
      final whereArgs = includeArchived ? [roomId] : [roomId, 0];

      final maps = await db.query(
        'rdwc_systems',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => RdwcSystem.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading systems by room', e);
      return [];
    }
  }

  /// Get systems by grow
  @override
  Future<List<RdwcSystem>> getSystemsByGrow(
    int growId, {
    bool includeArchived = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      final where = includeArchived
          ? 'grow_id = ?'
          : 'grow_id = ? AND archived = ?';
      final whereArgs = includeArchived ? [growId] : [growId, 0];

      final maps = await db.query(
        'rdwc_systems',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => RdwcSystem.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading systems by grow', e);
      return [];
    }
  }

  /// Get system by ID
  @override
  Future<RdwcSystem?> getSystemById(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_systems',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return RdwcSystem.fromMap(maps.first);
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading system by ID', e);
      return null;
    }
  }

  /// Create new RDWC system
  @override
  Future<int> createSystem(RdwcSystem system) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('rdwc_systems', system.toMap());
      AppLogger.info('RdwcRepository', 'Created RDWC system', 'ID: $id');
      return id;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error creating RDWC system', e);
      rethrow;
    }
  }

  /// Update RDWC system
  @override
  Future<int> updateSystem(RdwcSystem system) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.update(
        'rdwc_systems',
        system.toMap(),
        where: 'id = ?',
        whereArgs: [system.id],
      );
      AppLogger.info(
        'RdwcRepository',
        'Updated RDWC system',
        'ID: ${system.id}',
      );
      return count;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error updating RDWC system', e);
      rethrow;
    }
  }

  /// Update system water level
  @override
  Future<void> updateSystemLevel(int systemId, double newLevel) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'rdwc_systems',
        {'current_level': newLevel},
        where: 'id = ?',
        whereArgs: [systemId],
      );
      AppLogger.info(
        'RdwcRepository',
        'Updated system level',
        'ID: $systemId, Level: $newLevel L',
      );
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error updating system level', e);
      rethrow;
    }
  }

  /// Archive/unarchive system
  @override
  Future<void> archiveSystem(int systemId, bool archived) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'rdwc_systems',
        {'archived': archived ? 1 : 0},
        where: 'id = ?',
        whereArgs: [systemId],
      );
      AppLogger.info(
        'RdwcRepository',
        '${archived ? "Archived" : "Unarchived"} system',
        'ID: $systemId',
      );
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error archiving system', e);
      rethrow;
    }
  }

  /// Delete RDWC system (and all its logs via CASCADE)
  ///
  /// ⚠️ WICHTIGES VERHALTEN: Pflanzen und Räume im System werden NICHT gelöscht!
  ///
  /// Architektonische Entscheidung:
  /// - RDWC System ist ein Container-Objekt (wie Grow, Room)
  /// - Beim Löschen wird `plants.rdwc_system_id` und `rooms.rdwc_system_id` auf NULL gesetzt
  /// - Pflanzen und Räume bleiben mit allen Daten erhalten
  ///
  /// Vorteile dieses Designs:
  /// ✅ Datensicherheit: Versehentliches Löschen ist umkehrbar
  /// ✅ Flexibilität: Pflanzen/Räume können später neu zugeordnet werden
  /// ✅ Konsistenz: Gleiches Verhalten wie Grow/Room
  /// 🔒 SOFT DELETE: Archive RDWC system instead of deleting
  /// After migration v14, this method archives the system and its logs
  /// Use deleteSystemPermanently() for actual deletion
  @override
  Future<int> deleteSystem(int systemId) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        AppLogger.info(
          'RdwcRepo',
          'Archiving RDWC system (soft delete)',
          'systemId=$systemId',
        );

        // Archive all logs for this system
        await txn.update(
          'rdwc_logs',
          {'archived': 1},
          where: 'system_id = ?',
          whereArgs: [systemId],
        );

        // Archive the system itself
        final result = await txn.update(
          'rdwc_systems',
          {'archived': 1},
          where: 'id = ?',
          whereArgs: [systemId],
        );

        AppLogger.info(
          'RdwcRepo',
          '✅ RDWC system archived (soft delete completed)',
        );
        return result;
      });
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Failed to archive RDWC system', e);
      rethrow;
    }
  }

  /// ✅ RESTORE: Restores archived RDWC system and all its logs
  Future<int> restoreSystem(int systemId) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        AppLogger.info(
          'RdwcRepo',
          'Restoring RDWC system from archive',
          'systemId=$systemId',
        );

        // Restore all logs for this system
        await txn.update(
          'rdwc_logs',
          {'archived': 0},
          where: 'system_id = ?',
          whereArgs: [systemId],
        );

        // Restore the system itself
        final result = await txn.update(
          'rdwc_systems',
          {'archived': 0},
          where: 'id = ?',
          whereArgs: [systemId],
        );

        AppLogger.info('RdwcRepo', '✅ RDWC system restored from archive');
        return result;
      });
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Failed to restore RDWC system', e);
      rethrow;
    }
  }

  /// Get all archived systems
  Future<List<RdwcSystem>> getArchivedSystems() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_systems',
        where: 'archived = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      return maps.map((map) => RdwcSystem.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Failed to load archived systems', e);
      return [];
    }
  }

  /// ⚠️ PERMANENT DELETE: Deletes RDWC system and ALL related data
  /// This is irreversible! Use with caution.
  ///
  /// Deletion order:
  /// 1. Detach plants from system
  /// 2. Delete log fertilizers
  /// 3. Delete logs
  /// 4. Delete system itself
  Future<int> deleteSystemPermanently(int systemId) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        AppLogger.warning(
          'RdwcRepo',
          '⚠️ PERMANENT DELETE: Starting cascading delete',
          'systemId=$systemId',
        );

        // Step 1: Detach all plants from this system
        await txn.update(
          'plants',
          {'rdwc_system_id': null, 'bucket_number': null},
          where: 'rdwc_system_id = ?',
          whereArgs: [systemId],
        );

        // Step 2: Get all log IDs for this system
        final logs = await txn.query(
          'rdwc_logs',
          columns: ['id'],
          where: 'system_id = ?',
          whereArgs: [systemId],
        );
        final logIds = logs.map((log) => log['id'] as int).toList();

        int deletedLogFertilizers = 0;

        // Step 3: Delete all log_fertilizers for these logs
        if (logIds.isNotEmpty) {
          for (final logId in logIds) {
            final count = await txn.delete(
              'rdwc_log_fertilizers',
              where: 'rdwc_log_id = ?',
              whereArgs: [logId],
            );
            deletedLogFertilizers += count;
          }
        }

        // Step 4: Delete all logs
        final deletedLogs = await txn.delete(
          'rdwc_logs',
          where: 'system_id = ?',
          whereArgs: [systemId],
        );

        // Step 5: Finally, delete the system itself
        final deletedSystem = await txn.delete(
          'rdwc_systems',
          where: 'id = ?',
          whereArgs: [systemId],
        );

        AppLogger.warning(
          'RdwcRepo',
          '⚠️ PERMANENT DELETE completed',
          'system=$deletedSystem, logs=$deletedLogs, fertilizers=$deletedLogFertilizers',
        );

        return deletedSystem;
      });
    } catch (e) {
      AppLogger.error(
        'RdwcRepository',
        'Failed to permanently delete system',
        e,
      );
      rethrow;
    }
  }

  /// Get count of related data for a system (for delete warning dialog)
  @override
  Future<Map<String, int>> getSystemRelatedDataCounts(int systemId) async {
    try {
      final db = await _dbHelper.database;

      // Count logs (exclude archived)
      final logsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM rdwc_logs WHERE system_id = ? AND archived = 0',
        [systemId],
      );
      final logsCount = Sqflite.firstIntValue(logsResult) ?? 0;

      // Count plants attached to system
      final plantsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM plants WHERE rdwc_system_id = ?',
        [systemId],
      );
      final plantsCount = Sqflite.firstIntValue(plantsResult) ?? 0;

      return {'logs': logsCount, 'plants': plantsCount};
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Failed to count related data', e);
      return {'logs': 0, 'plants': 0};
    }
  }

  // ==========================================
  // RDWC LOGS (Water Addback Tracking)
  // ==========================================

  /// Get all logs for a system (excluding archived)
  @override
  /// ✅ FIX: Add limit parameter to prevent loading thousands of logs
  /// ✅ v14: Filter archived logs by default
  Future<List<RdwcLog>> getLogsBySystem(
    int systemId, {
    int? limit,
    bool includeArchived = false,
  }) async {
    try {
      final db = await _dbHelper.database;

      final whereClause = includeArchived
          ? 'system_id = ?'
          : 'system_id = ? AND archived = 0';

      final maps = await db.query(
        'rdwc_logs',
        where: whereClause,
        whereArgs: [systemId],
        orderBy: 'log_date DESC',
        limit: limit, // ✅ FIX: Add LIMIT clause
      );

      return maps.map((map) => RdwcLog.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading RDWC logs', e);
      return [];
    }
  }

  /// Get recent logs for a system (last N logs)
  /// ✅ v14: Excludes archived logs by default
  @override
  Future<List<RdwcLog>> getRecentLogs(int systemId, {int limit = 10}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_logs',
        where: 'system_id = ? AND archived = 0',
        whereArgs: [systemId],
        orderBy: 'log_date DESC',
        limit: limit,
      );

      return maps.map((map) => RdwcLog.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading recent logs', e);
      return [];
    }
  }

  /// Get latest log for a system
  @override
  Future<RdwcLog?> getLatestLog(int systemId) async {
    try {
      final logs = await getRecentLogs(systemId, limit: 1);
      return logs.isNotEmpty ? logs.first : null;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading latest log', e);
      return null;
    }
  }

  /// Create new RDWC log and update system level
  /// ✅ FIX v11: Use transaction for atomic operation
  @override
  Future<int> createLog(RdwcLog log) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        // 1. Insert log
        final logId = await txn.insert('rdwc_logs', log.toMap());
        AppLogger.info('RdwcRepository', 'Created RDWC log', 'ID: $logId');

        // 2. Update system level if levelAfter is provided
        if (log.levelAfter != null) {
          await txn.update(
            'rdwc_systems',
            {'current_level': log.levelAfter},
            where: 'id = ?',
            whereArgs: [log.systemId],
          );
          AppLogger.info(
            'RdwcRepository',
            'Updated system level',
            'ID: ${log.systemId}, Level: ${log.levelAfter} L',
          );
        }

        return logId;
      });
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error creating RDWC log', e);
      rethrow;
    }
  }

  /// Update RDWC log
  /// ✅ FIX v11: Use transaction for atomic operation
  @override
  Future<int> updateLog(RdwcLog log) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        // 1. Update log
        final count = await txn.update(
          'rdwc_logs',
          log.toMap(),
          where: 'id = ?',
          whereArgs: [log.id],
        );
        AppLogger.info('RdwcRepository', 'Updated RDWC log', 'ID: ${log.id}');

        // 2. Delete old fertilizers for this log (will be re-added by caller if needed)
        // This prevents duplicate fertilizers when updating a log
        if (log.id != null) {
          await txn.delete(
            'rdwc_log_fertilizers',
            where: 'rdwc_log_id = ?',
            whereArgs: [log.id],
          );
          AppLogger.info(
            'RdwcRepository',
            'Cleared old fertilizers for log',
            'ID: ${log.id}',
          );
        }

        // 3. Update system level if levelAfter changed
        if (log.levelAfter != null) {
          await txn.update(
            'rdwc_systems',
            {'current_level': log.levelAfter},
            where: 'id = ?',
            whereArgs: [log.systemId],
          );
          AppLogger.info(
            'RdwcRepository',
            'Updated system level',
            'ID: ${log.systemId}, Level: ${log.levelAfter} L',
          );
        }

        return count;
      });
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error updating RDWC log', e);
      rethrow;
    }
  }

  /// Archive RDWC log (Soft-Delete)
  /// ✅ SOFT-DELETE: Archives log instead of deleting (archived = 1)
  /// ✅ PHASE 3: Wrapped in transaction for data integrity (archive + update must be atomic)
  @override
  Future<int> deleteLog(int logId) async {
    try {
      final db = await _dbHelper.database;

      // Use transaction to ensure atomic operation
      return await db.transaction((txn) async {
        // Get system ID before archiving the log
        final logResult = await txn.query(
          'rdwc_logs',
          columns: ['system_id'],
          where: 'id = ?',
          whereArgs: [logId],
        );

        if (logResult.isEmpty) {
          AppLogger.warning(
            'RdwcRepository',
            'Log not found for archiving',
            'ID: $logId',
          );
          return 0;
        }

        final systemId = logResult.first['system_id'] as int;

        // Archive the log (Soft-Delete)
        final count = await txn.update(
          'rdwc_logs',
          {'archived': 1},
          where: 'id = ?',
          whereArgs: [logId],
        );

        // Update system level to the most recent remaining NON-ARCHIVED log's levelAfter
        final mostRecentLog = await txn.query(
          'rdwc_logs',
          where: 'system_id = ? AND level_after IS NOT NULL AND archived = 0',
          whereArgs: [systemId],
          orderBy: 'log_date DESC, id DESC',
          limit: 1,
        );

        if (mostRecentLog.isNotEmpty) {
          final newLevel = mostRecentLog.first['level_after'] as double;
          // Inline update within transaction instead of calling method
          await txn.update(
            'rdwc_systems',
            {'current_level': newLevel}, // ✅ FIXED: correct column name
            where: 'id = ?',
            whereArgs: [systemId],
          );
          AppLogger.info(
            'RdwcRepository',
            'Updated system level after log archiving',
            'SystemID: $systemId, NewLevel: $newLevel L',
          );
        } else {
          // ✅ FIX: No non-archived logs remaining - set level to 0 (no data) instead of max capacity
          // Resetting to max capacity is incorrect as it implies the system is full
          await txn.update(
            'rdwc_systems',
            {'current_level': 0.0}, // ✅ FIXED: correct column name
            where: 'id = ?',
            whereArgs: [systemId],
          );
          AppLogger.info(
            'RdwcRepository',
            'Reset system level to 0 (no non-archived logs remaining)',
            'SystemID: $systemId',
          );
        }

        AppLogger.info('RdwcRepository', 'Archived RDWC log', 'ID: $logId');
        return count;
      });
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error archiving RDWC log', e);
      rethrow;
    }
  }

  /// Permanently delete RDWC log
  /// ⚠️ DANGER: Real deletion! Use only after warning + backup
  Future<int> deleteLogPermanently(int logId) async {
    try {
      final db = await _dbHelper.database;

      // Use transaction to ensure atomic operation
      return await db.transaction((txn) async {
        // Get system ID before deleting the log
        final logResult = await txn.query(
          'rdwc_logs',
          columns: ['system_id'],
          where: 'id = ?',
          whereArgs: [logId],
        );

        if (logResult.isEmpty) {
          AppLogger.warning(
            'RdwcRepository',
            'Log not found for permanent deletion',
            'ID: $logId',
          );
          return 0;
        }

        final systemId = logResult.first['system_id'] as int;

        // Delete fertilizer associations first (RESTRICT constraint)
        await txn.delete(
          'rdwc_log_fertilizers',
          where: 'rdwc_log_id = ?',
          whereArgs: [logId],
        );

        // Delete the log permanently
        final count = await txn.delete(
          'rdwc_logs',
          where: 'id = ?',
          whereArgs: [logId],
        );

        // Update system level to the most recent remaining log's levelAfter
        final mostRecentLog = await txn.query(
          'rdwc_logs',
          where: 'system_id = ? AND level_after IS NOT NULL AND archived = 0',
          whereArgs: [systemId],
          orderBy: 'log_date DESC, id DESC',
          limit: 1,
        );

        if (mostRecentLog.isNotEmpty) {
          final newLevel = mostRecentLog.first['level_after'] as double;
          await txn.update(
            'rdwc_systems',
            {'current_level': newLevel},
            where: 'id = ?',
            whereArgs: [systemId],
          );
          AppLogger.info(
            'RdwcRepository',
            'Updated system level after permanent log deletion',
            'SystemID: $systemId, NewLevel: $newLevel L',
          );
        } else {
          await txn.update(
            'rdwc_systems',
            {'current_level': 0.0},
            where: 'id = ?',
            whereArgs: [systemId],
          );
          AppLogger.info(
            'RdwcRepository',
            'Reset system level to 0 (no logs remaining)',
            'SystemID: $systemId',
          );
        }

        AppLogger.info(
          'RdwcRepository',
          'Permanently deleted RDWC log',
          'ID: $logId',
        );
        return count;
      });
    } catch (e) {
      AppLogger.error(
        'RdwcRepository',
        'Error permanently deleting RDWC log',
        e,
      );
      rethrow;
    }
  }

  /// Calculate average daily water consumption for a system
  @override
  Future<double?> getAverageDailyConsumption(
    int systemId, {
    int days = 7,
  }) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final result = await db.rawQuery(
        '''
        SELECT AVG(water_consumed) as avg_consumption
        FROM rdwc_logs
        WHERE system_id = ?
          AND water_consumed IS NOT NULL
          AND log_date >= ?
          AND log_type = 'ADDBACK'
          AND archived = 0
      ''',
        [systemId, cutoffDate.toIso8601String()],
      );

      if (result.isEmpty || result.first['avg_consumption'] == null) {
        return null;
      }

      return (result.first['avg_consumption'] as num).toDouble();
    } catch (e) {
      AppLogger.error(
        'RdwcRepository',
        'Error calculating average consumption',
        e,
      );
      return null;
    }
  }

  /// Get total water added in a time period
  @override
  Future<double> getTotalWaterAdded(
    int systemId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await _dbHelper.database;
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final result = await db.rawQuery(
        '''
        SELECT SUM(water_added) as total
        FROM rdwc_logs
        WHERE system_id = ?
          AND water_added IS NOT NULL
          AND log_date >= ?
          AND log_date <= ?
          AND archived = 0
      ''',
        [systemId, start.toIso8601String(), end.toIso8601String()],
      );

      if (result.isEmpty || result.first['total'] == null) {
        return 0.0;
      }

      return (result.first['total'] as num).toDouble();
    } catch (e) {
      AppLogger.error(
        'RdwcRepository',
        'Error calculating total water added',
        e,
      );
      return 0.0;
    }
  }

  // ==========================================
  // v8: RDWC LOG FERTILIZERS (Expert Mode)
  // ==========================================

  /// Add fertilizer to an RDWC log
  @override
  Future<int> addFertilizerToLog(RdwcLogFertilizer fertilizer) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('rdwc_log_fertilizers', fertilizer.toMap());
      AppLogger.info(
        'RdwcRepository',
        'Added fertilizer to RDWC log',
        'ID: $id',
      );
      return id;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error adding fertilizer to log', e);
      rethrow;
    }
  }

  /// Remove fertilizer from an RDWC log
  @override
  Future<int> removeFertilizerFromLog(int fertilizerId) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        'rdwc_log_fertilizers',
        where: 'id = ?',
        whereArgs: [fertilizerId],
      );
      AppLogger.info(
        'RdwcRepository',
        'Removed fertilizer from RDWC log',
        'ID: $fertilizerId',
      );
      return count;
    } catch (e) {
      AppLogger.error(
        'RdwcRepository',
        'Error removing fertilizer from log',
        e,
      );
      rethrow;
    }
  }

  /// Get all fertilizers for an RDWC log
  @override
  Future<List<RdwcLogFertilizer>> getLogFertilizers(int rdwcLogId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_log_fertilizers',
        where: 'rdwc_log_id = ?',
        whereArgs: [rdwcLogId],
        orderBy: 'created_at ASC',
      );

      return maps.map((map) => RdwcLogFertilizer.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading log fertilizers', e);
      return [];
    }
  }

  /// Get RDWC log with fertilizers loaded
  @override
  Future<RdwcLog?> getLogWithFertilizers(int logId) async {
    try {
      final db = await _dbHelper.database;

      // Get log
      final logMaps = await db.query(
        'rdwc_logs',
        where: 'id = ?',
        whereArgs: [logId],
        limit: 1,
      );

      if (logMaps.isEmpty) return null;

      final log = RdwcLog.fromMap(logMaps.first);

      // Get fertilizers
      final fertilizers = await getLogFertilizers(logId);

      // Return log with fertilizers
      return log.copyWith(fertilizers: fertilizers);
    } catch (e) {
      AppLogger.error(
        'RdwcRepository',
        'Error loading log with fertilizers',
        e,
      );
      return null;
    }
  }

  /// Get recent logs with fertilizers loaded
  /// ✅ FIX: Optimized to prevent N+1 query problem using single JOIN
  @override
  Future<List<RdwcLog>> getRecentLogsWithFertilizers(
    int systemId, {
    int limit = 10,
  }) async {
    try {
      final db = await _dbHelper.database;

      // Single JOIN query instead of N+1 queries
      final maps = await db.rawQuery(
        '''
        SELECT
          rl.*,
          rlf.id as rlf_id,
          rlf.fertilizer_id,
          rlf.amount,
          rlf.amount_type,
          f.name as fert_name,
          f.brand as fert_brand,
          f.npk as fert_npk
        FROM rdwc_logs rl
        LEFT JOIN rdwc_log_fertilizers rlf ON rl.id = rlf.rdwc_log_id
        LEFT JOIN fertilizers f ON rlf.fertilizer_id = f.id
        WHERE rl.system_id = ? AND rl.archived = 0
        ORDER BY rl.log_date DESC, rl.id DESC
        LIMIT ?
      ''',
        // ✅ MEDIUM PRIORITY FIX: Reduced multiplier from 10 to 3
        // Previous: limit * 10 was too aggressive (100 logs → 1000 rows)
        // New: limit * 3 is more reasonable (average 3 fertilizers per log)
        // Still allows logs with multiple fertilizers while reducing over-fetch
        [systemId, limit * 3],
      );

      // Group results by log_id
      final logMap = <int, Map<String, dynamic>>{};
      final fertilizerMap = <int, List<Map<String, dynamic>>>{};

      for (final row in maps) {
        final logId = row['id'] as int;

        // Store log data (only once per log_id)
        if (!logMap.containsKey(logId)) {
          logMap[logId] = {
            'id': row['id'],
            'system_id': row['system_id'],
            'log_date': row['log_date'],
            'log_type': row['log_type'],
            'level_before': row['level_before'],
            'level_after': row['level_after'],
            'water_added': row['water_added'],
            'water_temp': row['water_temp'],
            'ph_before': row['ph_before'],
            'ph_after': row['ph_after'],
            'ec_before': row['ec_before'],
            'ec_after': row['ec_after'],
            'notes': row['notes'],
            'created_at': row['created_at'],
          };
          fertilizerMap[logId] = [];
        }

        // Add fertilizer if present
        if (row['rlf_id'] != null) {
          fertilizerMap[logId]!.add({
            'id': row['rlf_id'],
            'fertilizer_id': row['fertilizer_id'],
            'amount': row['amount'],
            'amount_type': row['amount_type'],
            'name': row['fert_name'],
            'brand': row['fert_brand'],
            'npk': row['fert_npk'],
          });
        }
      }

      // Convert to RdwcLog objects
      final logs = <RdwcLog>[];
      for (final logId in logMap.keys.take(limit)) {
        final logData = logMap[logId];
        if (logData == null) continue; // ✅ FIX: Skip if logData is null

        final log = RdwcLog.fromMap(logData);

        // Convert fertilizer maps to RdwcLogFertilizer objects
        final fertilizers =
            (fertilizerMap[logId] ?? []) // ✅ FIX: Use ?? [] for safety
                .map((fMap) => RdwcLogFertilizer.fromMap(fMap))
                .toList();

        logs.add(log.copyWith(fertilizers: fertilizers));
      }

      return logs;
    } catch (e) {
      AppLogger.error(
        'RdwcRepository',
        'Error loading logs with fertilizers',
        e,
      );
      return [];
    }
  }

  // ==========================================
  // v8: RDWC RECIPES (Expert Mode)
  // ==========================================

  /// Get all RDWC recipes
  /// ✅ CRITICAL FIX: Rewritten to eliminate N+1 query problem
  /// Old: 1 recipe query + N fertilizer queries (100 recipes = 101 queries!)
  /// New: 1 recipe query + 1 JOIN query (100 recipes = 2 queries)
  @override
  Future<List<RdwcRecipe>> getAllRecipes() async {
    try {
      final db = await _dbHelper.database;

      // Step 1: Load all recipes
      final recipeMaps = await db.query(
        'rdwc_recipes',
        orderBy: 'created_at DESC',
      );

      if (recipeMaps.isEmpty) return [];

      // Step 2: Load ALL recipe fertilizers in ONE query using IN clause
      final recipeIds = recipeMaps.map((m) => m['id']).toList();
      final placeholders = List.filled(recipeIds.length, '?').join(',');

      final fertilizerMaps = await db.rawQuery('''
        SELECT * FROM rdwc_recipe_fertilizers
        WHERE recipe_id IN ($placeholders)
        ORDER BY recipe_id, id ASC
      ''', recipeIds);

      // Step 3: Group fertilizers by recipe_id
      final fertilizersMap = <int, List<RecipeFertilizer>>{};
      for (final map in fertilizerMaps) {
        final recipeId = map['recipe_id'] as int;
        final fertilizer = RecipeFertilizer.fromMap(map);

        if (!fertilizersMap.containsKey(recipeId)) {
          fertilizersMap[recipeId] = [];
        }
        fertilizersMap[recipeId]!.add(fertilizer);
      }

      // Step 4: Combine recipes with their fertilizers
      final recipes = <RdwcRecipe>[];
      for (final map in recipeMaps) {
        final recipe = RdwcRecipe.fromMap(map);
        final fertilizers = fertilizersMap[recipe.id] ?? [];
        recipes.add(recipe.copyWith(fertilizers: fertilizers));
      }

      AppLogger.info(
        'RdwcRepository',
        'Loaded ${recipes.length} recipes with fertilizers (2 queries)',
      );
      return recipes;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading recipes', e);
      return [];
    }
  }

  /// Get recipe by ID
  @override
  Future<RdwcRecipe?> getRecipeById(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_recipes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      final recipe = RdwcRecipe.fromMap(maps.first);
      final fertilizers = await getRecipeFertilizers(id);

      return recipe.copyWith(fertilizers: fertilizers);
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading recipe', e);
      return null;
    }
  }

  /// Get fertilizers for a recipe
  @override
  Future<List<RecipeFertilizer>> getRecipeFertilizers(int recipeId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_recipe_fertilizers',
        where: 'recipe_id = ?',
        whereArgs: [recipeId],
        orderBy: 'id ASC',
      );

      return maps.map((map) => RecipeFertilizer.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading recipe fertilizers', e);
      return [];
    }
  }

  /// Create recipe fertilizer entry
  @override
  Future<int> createRecipeFertilizer(RecipeFertilizer recipeFertilizer) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert(
        'rdwc_recipe_fertilizers',
        recipeFertilizer.toMap(),
      );
      AppLogger.info('RdwcRepository', 'Created recipe fertilizer', 'ID: $id');
      return id;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error creating recipe fertilizer', e);
      rethrow;
    }
  }

  /// Delete recipe fertilizer entry
  @override
  Future<int> deleteRecipeFertilizer(int id) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        'rdwc_recipe_fertilizers',
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.info('RdwcRepository', 'Deleted recipe fertilizer', 'ID: $id');
      return count;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error deleting recipe fertilizer', e);
      rethrow;
    }
  }

  /// Create new recipe
  /// ✅ FIX v11: Use transaction for atomic operation
  @override
  Future<int> createRecipe(RdwcRecipe recipe) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        // 1. Insert recipe
        final recipeId = await txn.insert('rdwc_recipes', recipe.toMap());
        AppLogger.info('RdwcRepository', 'Created recipe', 'ID: $recipeId');

        // 2. Insert all fertilizers
        for (final fert in recipe.fertilizers) {
          final fertWithRecipeId = RecipeFertilizer(
            recipeId: recipeId,
            fertilizerId: fert.fertilizerId,
            mlPerLiter: fert.mlPerLiter,
          );
          await txn.insert('rdwc_recipe_fertilizers', fertWithRecipeId.toMap());
        }

        return recipeId;
      });
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error creating recipe', e);
      rethrow;
    }
  }

  /// Update recipe
  /// ✅ FIX v11: Use transaction for atomic operation
  @override
  Future<int> updateRecipe(RdwcRecipe recipe) async {
    try {
      final db = await _dbHelper.database;

      return await db.transaction((txn) async {
        // 1. Update recipe
        final count = await txn.update(
          'rdwc_recipes',
          recipe.toMap(),
          where: 'id = ?',
          whereArgs: [recipe.id],
        );

        // 2. Delete old fertilizers
        await txn.delete(
          'rdwc_recipe_fertilizers',
          where: 'recipe_id = ?',
          whereArgs: [recipe.id],
        );

        // 3. Insert new fertilizers
        for (final fert in recipe.fertilizers) {
          await txn.insert('rdwc_recipe_fertilizers', fert.toMap());
        }

        AppLogger.info('RdwcRepository', 'Updated recipe', 'ID: ${recipe.id}');
        return count;
      });
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error updating recipe', e);
      rethrow;
    }
  }

  /// Delete recipe
  @override
  Future<int> deleteRecipe(int recipeId) async {
    try {
      final db = await _dbHelper.database;

      // Fertilizers will be deleted automatically (ON DELETE CASCADE)
      final count = await db.delete(
        'rdwc_recipes',
        where: 'id = ?',
        whereArgs: [recipeId],
      );

      AppLogger.info('RdwcRepository', 'Deleted recipe', 'ID: $recipeId');
      return count;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error deleting recipe', e);
      rethrow;
    }
  }

  // ==========================================
  // v8: CONSUMPTION TRACKING (Expert Mode)
  // ==========================================

  /// Get daily water consumption for the last N days
  @override
  Future<Map<String, double>> getDailyConsumption(
    int systemId, {
    int days = 7,
  }) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final result = await db.rawQuery(
        '''
        SELECT
          DATE(log_date) as date,
          SUM(water_consumed) as total_consumed
        FROM rdwc_logs
        WHERE system_id = ?
          AND water_consumed IS NOT NULL
          AND water_consumed > 0
          AND log_date >= ?
          AND archived = 0
        GROUP BY DATE(log_date)
        ORDER BY log_date DESC
      ''',
        [systemId, cutoffDate.toIso8601String()],
      );

      final Map<String, double> consumption = {};
      for (final row in result) {
        final date = row['date'] as String;
        final consumed = (row['total_consumed'] as num).toDouble();
        consumption[date] = consumed;
      }

      return consumption;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error getting daily consumption', e);
      return {};
    }
  }

  /// Get consumption statistics
  @override
  Future<Map<String, dynamic>> getConsumptionStats(
    int systemId, {
    int days = 7,
  }) async {
    try {
      final dailyConsumption = await getDailyConsumption(systemId, days: days);

      if (dailyConsumption.isEmpty) {
        return {
          'average': 0.0,
          'total': 0.0,
          'max': 0.0,
          'min': 0.0,
          'days': 0,
        };
      }

      final values = dailyConsumption.values.toList();
      // ✅ FIX: Additional safety check before reduce
      if (values.isEmpty) {
        return {
          'average': 0.0,
          'total': 0.0,
          'max': 0.0,
          'min': 0.0,
          'days': 0,
        };
      }
      final total = values.reduce((a, b) => a + b);
      final average = total / values.length;
      final max = values.reduce((a, b) => a > b ? a : b);
      final min = values.reduce((a, b) => a < b ? a : b);

      return {
        'average': average,
        'total': total,
        'max': max,
        'min': min,
        'days': values.length,
        'daily': dailyConsumption,
      };
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error getting consumption stats', e);
      return {'average': 0.0, 'total': 0.0, 'max': 0.0, 'min': 0.0, 'days': 0};
    }
  }

  // ==========================================
  // v8: DRIFT ANALYSIS (Expert Mode)
  // ==========================================

  /// Get EC drift analysis
  @override
  Future<Map<String, dynamic>> getEcDriftAnalysis(
    int systemId, {
    int days = 7,
  }) async {
    try {
      final logs = await getRecentLogs(
        systemId,
        limit: days * 5,
      ); // ~5 logs per day estimate

      final drifts = <double>[];
      for (final log in logs) {
        if (log.ecDrift != null) {
          drifts.add(log.ecDrift!);
        }
      }

      if (drifts.isEmpty) {
        return {
          'average': 0.0,
          'max': 0.0,
          'min': 0.0,
          'trend': 'no_data',
          'count': 0,
        };
      }

      final average = drifts.reduce((a, b) => a + b) / drifts.length;
      final max = drifts.reduce((a, b) => a > b ? a : b);
      final min = drifts.reduce((a, b) => a < b ? a : b);

      String trend;
      if (average > 0.1) {
        trend = 'increasing';
      } else if (average < -0.1) {
        trend = 'decreasing';
      } else {
        trend = 'stable';
      }

      return {
        'average': average,
        'max': max,
        'min': min,
        'trend': trend,
        'count': drifts.length,
      };
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error analyzing EC drift', e);
      return {
        'average': 0.0,
        'max': 0.0,
        'min': 0.0,
        'trend': 'error',
        'count': 0,
      };
    }
  }

  /// Get pH drift analysis
  @override
  Future<Map<String, dynamic>> getPhDriftAnalysis(
    int systemId, {
    int days = 7,
  }) async {
    try {
      final logs = await getRecentLogs(
        systemId,
        limit: days * 5,
      ); // ~5 logs per day estimate

      final drifts = <double>[];
      for (final log in logs) {
        if (log.phDrift != null) {
          drifts.add(log.phDrift!);
        }
      }

      if (drifts.isEmpty) {
        return {
          'average': 0.0,
          'max': 0.0,
          'min': 0.0,
          'trend': 'no_data',
          'count': 0,
        };
      }

      final average = drifts.reduce((a, b) => a + b) / drifts.length;
      final max = drifts.reduce((a, b) => a > b ? a : b);
      final min = drifts.reduce((a, b) => a < b ? a : b);

      String trend;
      if (average > 0.2) {
        trend = 'increasing';
      } else if (average < -0.2) {
        trend = 'decreasing';
      } else {
        trend = 'stable';
      }

      return {
        'average': average,
        'max': max,
        'min': min,
        'trend': trend,
        'count': drifts.length,
      };
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error analyzing pH drift', e);
      return {
        'average': 0.0,
        'max': 0.0,
        'min': 0.0,
        'trend': 'error',
        'count': 0,
      };
    }
  }
}
