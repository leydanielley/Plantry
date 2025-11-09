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
  /// ✅ FIX v11: Check if fertilizer is in use before deleting
  /// Throws an exception with helpful message if fertilizer is still referenced
  @override
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;

    // Check if fertilizer is in use
    final usageDetails = await getUsageDetails(id);
    final totalUsage = usageDetails.values.reduce((a, b) => a + b);

    if (totalUsage > 0) {
      // Build helpful error message
      final parts = <String>[];
      if (usageDetails['recipes']! > 0) {
        parts.add('${usageDetails['recipes']} Rezept${usageDetails['recipes']! > 1 ? 'en' : ''}');
      }
      if (usageDetails['rdwc_logs']! > 0) {
        parts.add('${usageDetails['rdwc_logs']} RDWC-Log${usageDetails['rdwc_logs']! > 1 ? 's' : ''}');
      }
      if (usageDetails['plant_logs']! > 0) {
        parts.add('${usageDetails['plant_logs']} Pflanzen-Log${usageDetails['plant_logs']! > 1 ? 's' : ''}');
      }

      throw Exception(
        'Dünger kann nicht gelöscht werden. '
        'Er wird noch in ${parts.join(', ')} verwendet. '
        'Bitte entfernen Sie zuerst alle Verwendungen.',
      );
    }

    // Safe to delete
    return await db.delete(
      'fertilizers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Alle Dünger löschen
  @override
  Future<int> deleteAll() async {
    final db = await _dbHelper.database;
    return await db.delete('fertilizers');
  }

  /// Alle Dünger einer bestimmten Marke löschen (z.B. 'HydroBuddy')
  @override
  Future<int> deleteByBrand(String brand) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'fertilizers',
      where: 'brand = ?',
      whereArgs: [brand],
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
