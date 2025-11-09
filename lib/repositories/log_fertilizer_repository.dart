// =============================================
// GROWLOG - LogFertilizer Repository (OPTIMIZED)
// =============================================

import '../database/database_helper.dart';
import '../models/log_fertilizer.dart';
import 'interfaces/i_log_fertilizer_repository.dart';

class LogFertilizerRepository implements ILogFertilizerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Speichern (Insert/Update)
  @override
  Future<int> save(LogFertilizer logFertilizer) async {
    final db = await _dbHelper.database;
    
    if (logFertilizer.id == null) {
      return await db.insert('log_fertilizers', logFertilizer.toMap());
    } else {
      await db.update(
        'log_fertilizers',
        logFertilizer.toMap(),
        where: 'id = ?',
        whereArgs: [logFertilizer.id],
      );
      return logFertilizer.id!;
    }
  }

  /// ✅ OPTIMIZED: Batch save - mehrere Dünger für einen Log
  /// VORHER: Loop mit einzelnen INSERT
  /// NACHHER: Transaction + Batch für maximale Performance
  @override
  Future<void> saveForLog(int logId, List<LogFertilizer> fertilizers) async {
    if (fertilizers.isEmpty) return;
    
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // Erst alte löschen
      await txn.delete('log_fertilizers', where: 'log_id = ?', whereArgs: [logId]);
      
      // ✅ NEU: Batch statt Loop!
      final batch = txn.batch();
      for (final fertilizer in fertilizers) {
        batch.insert('log_fertilizers', fertilizer.toMap());
      }
      await batch.commit(noResult: true); // noResult=true ist schneller!
    });
  }

  /// ✅ NEU: Batch-Methode für mehrere Logs auf einmal
  /// Nutzen: Beim Bulk-Log-Speichern oder beim Kopieren von Logs
  @override
  Future<void> saveForLogs(List<int> logIds, Map<int, List<LogFertilizer>> fertilizersPerLog) async {
    if (logIds.isEmpty) return;
    
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      // Alte löschen (Batch)
      for (final logId in logIds) {
        batch.delete('log_fertilizers', where: 'log_id = ?', whereArgs: [logId]);
      }
      
      // Neue einfügen (Batch)
      for (final logId in logIds) {
        final fertilizers = fertilizersPerLog[logId];
        if (fertilizers != null) {
          for (final fert in fertilizers) {
            batch.insert('log_fertilizers', fert.toMap());
          }
        }
      }
      
      await batch.commit(noResult: true);
    });
  }

  /// Finde alle für einen Log
  @override
  Future<List<LogFertilizer>> findByLog(int logId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'log_fertilizers',
      where: 'log_id = ?',
      whereArgs: [logId],
    );
    return maps.map((map) => LogFertilizer.fromMap(map)).toList();
  }

  /// ✅ NEU: Finde LogFertilizers für mehrere Logs auf einmal
  /// Performance: Nutzt den idx_log_fertilizers_lookup Index!
  /// Nutzen: Lädt alle Dünger für eine Liste von Logs in EINER Query
  @override
  Future<Map<int, List<LogFertilizer>>> findByLogs(List<int> logIds) async {
    if (logIds.isEmpty) return {};
    
    final db = await _dbHelper.database;
    
    // SQL IN clause für batch lookup
    final placeholders = List.filled(logIds.length, '?').join(',');
    final maps = await db.query(
      'log_fertilizers',
      where: 'log_id IN ($placeholders)',
      whereArgs: logIds,
      orderBy: 'log_id, id', // Sortiert für effizientes Grouping
    );
    
    // Gruppieren nach log_id
    final result = <int, List<LogFertilizer>>{};
    for (final map in maps) {
      final logId = map['log_id'] as int;
      final fert = LogFertilizer.fromMap(map);
      
      if (result[logId] == null) {
        result[logId] = [];
      }
      result[logId]!.add(fert);
    }
    
    return result;
  }

  /// Löschen
  @override
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete('log_fertilizers', where: 'id = ?', whereArgs: [id]);
  }

  /// Lösche alle für einen Log
  @override
  Future<void> deleteByLog(int logId) async {
    final db = await _dbHelper.database;
    await db.delete('log_fertilizers', where: 'log_id = ?', whereArgs: [logId]);
  }
  
  /// ✅ NEU: Lösche für mehrere Logs (Batch)
  @override
  Future<void> deleteByLogs(List<int> logIds) async {
    if (logIds.isEmpty) return;
    
    final db = await _dbHelper.database;
    final placeholders = List.filled(logIds.length, '?').join(',');
    await db.delete(
      'log_fertilizers',
      where: 'log_id IN ($placeholders)',
      whereArgs: logIds,
    );
  }
}
