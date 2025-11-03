// =============================================
// GROWLOG - Fertilizer Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/fertilizer.dart';

class FertilizerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Alle Dünger laden
  Future<List<Fertilizer>> findAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('fertilizers', orderBy: 'name ASC');
    return maps.map((map) => Fertilizer.fromMap(map)).toList();
  }

  /// Dünger nach ID laden
  Future<Fertilizer?> findById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fertilizers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Fertilizer.fromMap(maps.first);
  }

  /// Dünger speichern (INSERT oder UPDATE)
  Future<Fertilizer> save(Fertilizer fertilizer) async {
    final db = await _dbHelper.database;

    if (fertilizer.id == null) {
      // INSERT
      final id = await db.insert('fertilizers', fertilizer.toMap());
      return fertilizer.copyWith(id: id);
    } else {
      // UPDATE
      await db.update(
        'fertilizers',
        fertilizer.toMap(),
        where: 'id = ?',
        whereArgs: [fertilizer.id],
      );
      return fertilizer;
    }
  }

  /// Dünger löschen
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'fertilizers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Anzahl Dünger
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM fertilizers');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
