// =============================================
// GROWLOG - PlantLog Repository (OPTIMIZED)
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/plant_log.dart';
import '../utils/safe_parsers.dart';
import 'interfaces/i_plant_log_repository.dart';
import 'photo_repository.dart';
import 'repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class PlantLogRepository with RepositoryErrorHandler implements IPlantLogRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PhotoRepository _photoRepository = PhotoRepository();

  @override
  String get repositoryName => 'PlantLogRepository';

  /// Alle Logs einer Pflanze laden mit Pagination
  @override
  Future<List<PlantLog>> findByPlant(int plantId, {int? limit, int? offset}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'plant_logs',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'day_number DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => PlantLog.fromMap(map)).toList();
  }

  /// Log nach ID laden
  @override
  Future<PlantLog?> findById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'plant_logs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return PlantLog.fromMap(maps.first);
  }

  /// ✅ FIX: Batch-Query für mehrere Logs (verhindert N+1 Problem!)
  /// Nutzen: Photo Gallery lädt alle Logs auf einmal statt einzeln
  @override
  Future<List<PlantLog>> findByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    
    final db = await _dbHelper.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    
    final maps = await db.query(
      'plant_logs',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    return maps.map((map) => PlantLog.fromMap(map)).toList();
  }

  /// Log speichern (INSERT oder UPDATE)
  @override
  Future<PlantLog> save(PlantLog log) async {
    final db = await _dbHelper.database;

    if (log.id == null) {
      // INSERT
      final id = await db.insert('plant_logs', log.toMap());
      return log.copyWith(id: id);
    } else {
      // UPDATE
      await db.update(
        'plant_logs',
        log.toMap(),
        where: 'id = ?',
        whereArgs: [log.id],
      );
      return log;
    }
  }

  /// Log löschen (mit Cascading Delete für Fotos)
  /// ✅ FIX: Deletes photos (filesystem + DB) before deleting log
  @override
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;

    // Use transaction to ensure atomicity
    return await db.transaction((txn) async {
      // 1. Delete all photos for this log (filesystem + DB)
      //    This must be done BEFORE deleting the log, otherwise
      //    we can't query which photos belong to this log
      // ✅ MEDIUM FIX: Use transaction-safe method to prevent nested transaction deadlock
      await _photoRepository.deleteByLogIdInTransaction(txn, id);

      // 2. Delete log_fertilizers (handled by DB CASCADE)

      // 3. Delete the log itself
      return await txn.delete(
        'plant_logs',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Letzten Log einer Pflanze laden
  @override
  Future<PlantLog?> findLastLog(int plantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'plant_logs',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'day_number DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return PlantLog.fromMap(maps.first);
  }

  /// Letzten Log einer Pflanze laden
  @override
  Future<PlantLog?> getLastLogForPlant(int plantId) async {
    return await findLastLog(plantId);
  }

  /// Tag-Nummer für Pflanze basierend auf Datum
  /// WICHTIG: Berechnet echte Tage seit seedDate!
  /// [forDate] - Optional: Für welches Datum (default: heute)
  @override
  Future<int> getNextDayNumber(int plantId, {DateTime? forDate}) async {
    final db = await _dbHelper.database;
    
    // Plant holen um seedDate zu bekommen
    final plantMaps = await db.query(
      'plants',
      where: 'id = ?',
      whereArgs: [plantId],
      limit: 1,
    );
    
    if (plantMaps.isEmpty) return 1;
    
    final seedDateStr = plantMaps.first['seed_date'] as String?;
    if (seedDateStr == null) return 1;

    // ✅ HIGH FIX: Use SafeParsers to prevent crashes from corrupted DB data
    final seedDate = SafeParsers.parseDateTime(
      seedDateStr,
      fallback: DateTime.now(),
      context: 'PlantLogRepository.getNextDayNumber',
    );
    final targetDate = forDate ?? DateTime.now();
    
    // ✅ Nur Datums-Teil vergleichen (ohne Uhrzeit!)
    final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final seedDay = DateTime(seedDate.year, seedDate.month, seedDate.day);
    
    // Berechne Tage seit seedDate
    final daysSinceSeed = targetDay.difference(seedDay).inDays + 1; // +1 weil Tag 1 = Start
    
    return daysSinceSeed > 0 ? daysSinceSeed : 1;
  }

  /// Anzahl Logs einer Pflanze
  @override
  Future<int> countByPlant(int plantId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM plant_logs WHERE plant_id = ?',
      [plantId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Recent Activity Feed - Letzte Logs über alle Pflanzen
  @override
  Future<List<PlantLog>> getRecentActivity({int limit = 20}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'plant_logs',
      orderBy: 'log_date DESC',
      limit: limit,
    );

    return maps.map((map) => PlantLog.fromMap(map)).toList();
  }

  /// Recent Activity für bestimmte Aktionen
  @override
  Future<List<PlantLog>> getRecentActivityByAction({
    required List<String> actionTypes,
    int limit = 20,
  }) async {
    final db = await _dbHelper.database;
    final placeholders = actionTypes.map((_) => '?').join(',');
    
    final maps = await db.query(
      'plant_logs',
      where: 'action_type IN ($placeholders)',
      whereArgs: actionTypes,
      orderBy: 'log_date DESC',
      limit: limit,
    );

    return maps.map((map) => PlantLog.fromMap(map)).toList();
  }
  
  /// Logs mit Details laden (JOIN statt N+1)
  /// Performance: Lädt Logs + Fertilizers + Photos in EINER Query!
  /// VORHER: 1 Query für Logs + N Queries für Fertilizers = N+1 Problem
  /// NACHHER: 1 JOIN Query = massiv schneller!
  @override
  Future<List<Map<String, dynamic>>> getLogsWithDetails(int plantId) async {
    final db = await _dbHelper.database;
    
    // JOIN Query für Logs + LogFertilizers + Fertilizers
    // Nutzt den idx_log_fertilizers_lookup Index!
    const query = '''
      SELECT 
        pl.*,
        lf.id as lf_id,
        lf.fertilizer_id,
        lf.amount as fert_amount,
        lf.unit as fert_unit,
        f.name as fert_name,
        f.brand as fert_brand,
        f.npk as fert_npk
      FROM plant_logs pl
      LEFT JOIN log_fertilizers lf ON pl.id = lf.log_id
      LEFT JOIN fertilizers f ON lf.fertilizer_id = f.id
      WHERE pl.plant_id = ?
      ORDER BY pl.day_number DESC, lf.id
    ''';
    
    final maps = await db.rawQuery(query, [plantId]);
    
    // Gruppieren nach Log
    final logsMap = <int, Map<String, dynamic>>{};
    
    for (final map in maps) {
      final logId = map['id'] as int;
      
      // Log noch nicht verarbeitet? Dann erstellen
      if (!logsMap.containsKey(logId)) {
        logsMap[logId] = {
          'log': PlantLog.fromMap(map),
          'fertilizers': <Map<String, dynamic>>[],
        };
      }
      
      // Fertilizer hinzufügen (falls vorhanden)
      if (map['lf_id'] != null) {
        // ✅ FIX: Cast to avoid dynamic call error
        (logsMap[logId]!['fertilizers'] as List<Map<String, dynamic>>).add({
          'id': map['lf_id'],
          'fertilizer_id': map['fertilizer_id'],
          'amount': map['fert_amount'],
          'unit': map['fert_unit'],
          'name': map['fert_name'],
          'brand': map['fert_brand'],
          'npk': map['fert_npk'],
        });
      }
    }
    
    return logsMap.values.toList();
  }
  
  /// Batch Insert für Bulk-Logs
  /// Nutzen: Beim Anlegen mehrerer Logs gleichzeitig (z.B. Bulk-Log)
  @override
  Future<List<int>> saveBatch(List<PlantLog> logs) async {
    if (logs.isEmpty) return [];
    
    final db = await _dbHelper.database;
    final ids = <int>[];
    
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final log in logs) {
        if (log.id == null) {
          // INSERT
          batch.insert('plant_logs', log.toMap());
        } else {
          // UPDATE
          batch.update(
            'plant_logs',
            log.toMap(),
            where: 'id = ?',
            whereArgs: [log.id],
          );
        }
      }
      
      final results = await batch.commit();
      
      // IDs sammeln (nur bei INSERT)
      for (var i = 0; i < results.length; i++) {
        if (logs[i].id == null && results[i] is int) {
          ids.add(results[i] as int);
        }
      }
    });
    
    return ids;
  }
  
  /// Batch Delete
  /// Nutzen: Beim Löschen mehrerer Logs auf einmal
  @override
  Future<void> deleteBatch(List<int> logIds) async {
    if (logIds.isEmpty) return;
    
    final db = await _dbHelper.database;
    final placeholders = List.filled(logIds.length, '?').join(',');
    
    await db.delete(
      'plant_logs',
      where: 'id IN ($placeholders)',
      whereArgs: logIds,
    );
  }
}
