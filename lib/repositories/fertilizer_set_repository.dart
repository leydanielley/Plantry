// =============================================
// GROWLOG - FertilizerSet Repository
// =============================================

import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/fertilizer_set.dart';

class FertilizerSetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Alle Sets laden (neueste zuerst), inkl. Anzahl der enthaltenen Dünger
  Future<List<FertilizerSet>> findAll() async {
    final db = await _dbHelper.database;
    final sets = await db.query('fertilizer_sets', orderBy: 'created_at DESC');

    final result = <FertilizerSet>[];
    for (final s in sets) {
      final id = s['id'] as int;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM fertilizer_set_items WHERE set_id = ?',
        [id],
      );
      final count = (countResult.first['cnt'] as int?) ?? 0;
      result.add(FertilizerSet.fromMap(s, itemCount: count));
    }
    return result;
  }

  /// Items eines Sets laden
  Future<List<FertilizerSetItem>> findItems(int setId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'fertilizer_set_items',
      where: 'set_id = ?',
      whereArgs: [setId],
    );
    return rows.map(FertilizerSetItem.fromMap).toList();
  }

  /// Neues Set speichern mit seinen Items
  Future<FertilizerSet> save(String name, Map<int, double> fertilizers) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final setId = await txn.insert('fertilizer_sets', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final entry in fertilizers.entries) {
        await txn.insert('fertilizer_set_items', {
          'set_id': setId,
          'fertilizer_id': entry.key,
          'amount': entry.value,
        });
      }
      return FertilizerSet(
        id: setId,
        name: name,
        createdAt: DateTime.now(),
        itemCount: fertilizers.length,
      );
    });
  }

  /// Set löschen (CASCADE löscht Items automatisch)
  Future<void> delete(int setId) async {
    final db = await _dbHelper.database;
    await db.delete('fertilizer_sets', where: 'id = ?', whereArgs: [setId]);
  }
}
