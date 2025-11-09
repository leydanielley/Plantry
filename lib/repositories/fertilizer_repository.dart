// =============================================
// GROWLOG - Fertilizer Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/fertilizer.dart';
import 'interfaces/i_fertilizer_repository.dart';

class FertilizerRepository implements IFertilizerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Alle Dünger laden
  @override
  Future<List<Fertilizer>> findAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('fertilizers', orderBy: 'name ASC');
    return maps.map((map) => Fertilizer.fromMap(map)).toList();
  }

  /// Dünger nach ID laden
  @override
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
  @override
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

  /// Prüft ob Dünger in Verwendung ist (Rezepte, Logs, etc.)
  @override
  Future<bool> isInUse(int id) async {
    final db = await _dbHelper.database;

    // Check RDWC recipes
    final recipeCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM rdwc_recipe_fertilizers WHERE fertilizer_id = ?',
        [id],
      ),
    ) ?? 0;

    // Check RDWC logs
    final rdwcLogCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM rdwc_log_fertilizers WHERE fertilizer_id = ?',
        [id],
      ),
    ) ?? 0;

    // Check plant logs
    final plantLogCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM log_fertilizers WHERE fertilizer_id = ?',
        [id],
      ),
    ) ?? 0;

    return (recipeCount + rdwcLogCount + plantLogCount) > 0;
  }

  /// Gibt detaillierte Nutzungs-Statistik zurück
  @override
  Future<Map<String, int>> getUsageDetails(int id) async {
    final db = await _dbHelper.database;

    return {
      'recipes': Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM rdwc_recipe_fertilizers WHERE fertilizer_id = ?',
          [id],
        ),
      ) ?? 0,
      'rdwc_logs': Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM rdwc_log_fertilizers WHERE fertilizer_id = ?',
          [id],
        ),
      ) ?? 0,
      'plant_logs': Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM log_fertilizers WHERE fertilizer_id = ?',
          [id],
        ),
      ) ?? 0,
    };
  }

  /// Dünger löschen
  @override
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'fertilizers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Anzahl Dünger
  @override
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM fertilizers');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
