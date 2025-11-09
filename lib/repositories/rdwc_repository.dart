// =============================================
// GROWLOG - RDWC System Repository
// =============================================

import '../database/database_helper.dart';
import '../models/rdwc_system.dart';
import '../models/rdwc_log.dart';
import '../models/rdwc_log_fertilizer.dart';
import '../models/rdwc_recipe.dart';
import '../utils/app_logger.dart';
import 'interfaces/i_rdwc_repository.dart';

class RdwcRepository implements IRdwcRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
  Future<List<RdwcSystem>> getSystemsByRoom(int roomId, {bool includeArchived = false}) async {
    try {
      final db = await _dbHelper.database;
      final where = includeArchived
          ? 'room_id = ?'
          : 'room_id = ? AND archived = ?';
      final whereArgs = includeArchived
          ? [roomId]
          : [roomId, 0];

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
  Future<List<RdwcSystem>> getSystemsByGrow(int growId, {bool includeArchived = false}) async {
    try {
      final db = await _dbHelper.database;
      final where = includeArchived
          ? 'grow_id = ?'
          : 'grow_id = ? AND archived = ?';
      final whereArgs = includeArchived
          ? [growId]
          : [growId, 0];

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
      AppLogger.info('RdwcRepository', 'Updated RDWC system', 'ID: ${system.id}');
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
      AppLogger.info('RdwcRepository', 'Updated system level', 'ID: $systemId, Level: $newLevel L');
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
      AppLogger.info('RdwcRepository', '${archived ? "Archived" : "Unarchived"} system', 'ID: $systemId');
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error archiving system', e);
      rethrow;
    }
  }

  /// Delete RDWC system (and all its logs via CASCADE)
  @override
  Future<int> deleteSystem(int systemId) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        'rdwc_systems',
        where: 'id = ?',
        whereArgs: [systemId],
      );
      AppLogger.info('RdwcRepository', 'Deleted RDWC system and its logs', 'ID: $systemId');
      return count;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error deleting RDWC system', e);
      rethrow;
    }
  }

  // ==========================================
  // RDWC LOGS (Water Addback Tracking)
  // ==========================================

  /// Get all logs for a system
  @override
  Future<List<RdwcLog>> getLogsBySystem(int systemId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_logs',
        where: 'system_id = ?',
        whereArgs: [systemId],
        orderBy: 'log_date DESC',
      );

      return maps.map((map) => RdwcLog.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading RDWC logs', e);
      return [];
    }
  }

  /// Get recent logs for a system (last N logs)
  @override
  Future<List<RdwcLog>> getRecentLogs(int systemId, {int limit = 10}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_logs',
        where: 'system_id = ?',
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
  @override
  Future<int> createLog(RdwcLog log) async {
    try {
      final db = await _dbHelper.database;

      // Insert log
      final logId = await db.insert('rdwc_logs', log.toMap());
      AppLogger.info('RdwcRepository', 'Created RDWC log', 'ID: $logId');

      // Update system level if levelAfter is provided
      if (log.levelAfter != null) {
        await updateSystemLevel(log.systemId, log.levelAfter!);
      }

      return logId;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error creating RDWC log', e);
      rethrow;
    }
  }

  /// Update RDWC log
  @override
  Future<int> updateLog(RdwcLog log) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.update(
        'rdwc_logs',
        log.toMap(),
        where: 'id = ?',
        whereArgs: [log.id],
      );
      AppLogger.info('RdwcRepository', 'Updated RDWC log', 'ID: ${log.id}');

      // Delete old fertilizers for this log (will be re-added by caller if needed)
      // This prevents duplicate fertilizers when updating a log
      if (log.id != null) {
        await db.delete(
          'rdwc_log_fertilizers',
          where: 'rdwc_log_id = ?',
          whereArgs: [log.id],
        );
        AppLogger.info('RdwcRepository', 'Cleared old fertilizers for log', 'ID: ${log.id}');
      }

      // Update system level if levelAfter changed
      if (log.levelAfter != null) {
        await updateSystemLevel(log.systemId, log.levelAfter!);
      }

      return count;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error updating RDWC log', e);
      rethrow;
    }
  }

  /// Delete RDWC log
  @override
  Future<int> deleteLog(int logId) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        'rdwc_logs',
        where: 'id = ?',
        whereArgs: [logId],
      );
      AppLogger.info('RdwcRepository', 'Deleted RDWC log', 'ID: $logId');
      return count;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error deleting RDWC log', e);
      rethrow;
    }
  }

  /// Calculate average daily water consumption for a system
  @override
  Future<double?> getAverageDailyConsumption(int systemId, {int days = 7}) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final result = await db.rawQuery('''
        SELECT AVG(water_consumed) as avg_consumption
        FROM rdwc_logs
        WHERE system_id = ?
          AND water_consumed IS NOT NULL
          AND log_date >= ?
          AND log_type = 'ADDBACK'
      ''', [systemId, cutoffDate.toIso8601String()]);

      if (result.isEmpty || result.first['avg_consumption'] == null) {
        return null;
      }

      return (result.first['avg_consumption'] as num).toDouble();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error calculating average consumption', e);
      return null;
    }
  }

  /// Get total water added in a time period
  @override
  Future<double> getTotalWaterAdded(int systemId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final db = await _dbHelper.database;
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final result = await db.rawQuery('''
        SELECT SUM(water_added) as total
        FROM rdwc_logs
        WHERE system_id = ?
          AND water_added IS NOT NULL
          AND log_date >= ?
          AND log_date <= ?
      ''', [systemId, start.toIso8601String(), end.toIso8601String()]);

      if (result.isEmpty || result.first['total'] == null) {
        return 0.0;
      }

      return (result.first['total'] as num).toDouble();
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error calculating total water added', e);
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
      AppLogger.info('RdwcRepository', 'Added fertilizer to RDWC log', 'ID: $id');
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
      AppLogger.info('RdwcRepository', 'Removed fertilizer from RDWC log', 'ID: $fertilizerId');
      return count;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error removing fertilizer from log', e);
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
      AppLogger.error('RdwcRepository', 'Error loading log with fertilizers', e);
      return null;
    }
  }

  /// Get recent logs with fertilizers loaded
  @override
  Future<List<RdwcLog>> getRecentLogsWithFertilizers(int systemId, {int limit = 10}) async {
    try {
      final logs = await getRecentLogs(systemId, limit: limit);
      final logsWithFertilizers = <RdwcLog>[];

      for (final log in logs) {
        if (log.id != null) {
          final fertilizers = await getLogFertilizers(log.id!);
          logsWithFertilizers.add(log.copyWith(fertilizers: fertilizers));
        } else {
          logsWithFertilizers.add(log);
        }
      }

      return logsWithFertilizers;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error loading logs with fertilizers', e);
      return [];
    }
  }

  // ==========================================
  // v8: RDWC RECIPES (Expert Mode)
  // ==========================================

  /// Get all RDWC recipes
  @override
  Future<List<RdwcRecipe>> getAllRecipes() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rdwc_recipes',
        orderBy: 'created_at DESC',
      );

      final recipes = <RdwcRecipe>[];
      for (final map in maps) {
        final recipe = RdwcRecipe.fromMap(map);
        final fertilizers = await getRecipeFertilizers(recipe.id!);
        recipes.add(recipe.copyWith(fertilizers: fertilizers));
      }

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
      final id = await db.insert('rdwc_recipe_fertilizers', recipeFertilizer.toMap());
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
  @override
  Future<int> createRecipe(RdwcRecipe recipe) async {
    try {
      final db = await _dbHelper.database;

      // Insert recipe
      final recipeId = await db.insert('rdwc_recipes', recipe.toMap());
      AppLogger.info('RdwcRepository', 'Created recipe', 'ID: $recipeId');

      // Insert fertilizers
      for (final fert in recipe.fertilizers) {
        final fertWithRecipeId = RecipeFertilizer(
          recipeId: recipeId,
          fertilizerId: fert.fertilizerId,
          mlPerLiter: fert.mlPerLiter,
        );
        await db.insert('rdwc_recipe_fertilizers', fertWithRecipeId.toMap());
      }

      return recipeId;
    } catch (e) {
      AppLogger.error('RdwcRepository', 'Error creating recipe', e);
      rethrow;
    }
  }

  /// Update recipe
  @override
  Future<int> updateRecipe(RdwcRecipe recipe) async {
    try {
      final db = await _dbHelper.database;

      // Update recipe
      final count = await db.update(
        'rdwc_recipes',
        recipe.toMap(),
        where: 'id = ?',
        whereArgs: [recipe.id],
      );

      // Delete old fertilizers
      await db.delete(
        'rdwc_recipe_fertilizers',
        where: 'recipe_id = ?',
        whereArgs: [recipe.id],
      );

      // Insert new fertilizers
      for (final fert in recipe.fertilizers) {
        await db.insert('rdwc_recipe_fertilizers', fert.toMap());
      }

      AppLogger.info('RdwcRepository', 'Updated recipe', 'ID: ${recipe.id}');
      return count;
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
  Future<Map<String, double>> getDailyConsumption(int systemId, {int days = 7}) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final result = await db.rawQuery('''
        SELECT
          DATE(log_date) as date,
          SUM(water_consumed) as total_consumed
        FROM rdwc_logs
        WHERE system_id = ?
          AND water_consumed IS NOT NULL
          AND water_consumed > 0
          AND log_date >= ?
        GROUP BY DATE(log_date)
        ORDER BY log_date DESC
      ''', [systemId, cutoffDate.toIso8601String()]);

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
  Future<Map<String, dynamic>> getConsumptionStats(int systemId, {int days = 7}) async {
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
      return {
        'average': 0.0,
        'total': 0.0,
        'max': 0.0,
        'min': 0.0,
        'days': 0,
      };
    }
  }

  // ==========================================
  // v8: DRIFT ANALYSIS (Expert Mode)
  // ==========================================

  /// Get EC drift analysis
  @override
  Future<Map<String, dynamic>> getEcDriftAnalysis(int systemId, {int days = 7}) async {
    try {
      final logs = await getRecentLogs(systemId, limit: days * 5); // ~5 logs per day estimate

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
  Future<Map<String, dynamic>> getPhDriftAnalysis(int systemId, {int days = 7}) async {
    try {
      final logs = await getRecentLogs(systemId, limit: days * 5); // ~5 logs per day estimate

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
