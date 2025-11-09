// =============================================
// GROWLOG - Harvest Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/harvest.dart';
import 'interfaces/i_harvest_repository.dart';

class HarvestRepository implements IHarvestRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Harvest erstellen
  @override
  Future<int> createHarvest(Harvest harvest) async {
    final db = await _dbHelper.database;
    final harvestMap = harvest.toMap();

    try {
      final id = await db.insert('harvests', harvestMap);
      return id;
    } catch (e) {
      rethrow;
    }
  }

  /// Harvest aktualisieren
  @override
  Future<int> updateHarvest(Harvest harvest) async {
    final db = await _dbHelper.database;
    return await db.update(
      'harvests',
      harvest.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [harvest.id],
    );
  }

  /// Harvest löschen
  @override
  Future<int> deleteHarvest(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'harvests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Harvest nach ID abrufen
  @override
  Future<Harvest?> getHarvestById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'harvests',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Harvest.fromMap(maps.first);
  }

  /// Harvest für eine Pflanze abrufen
  @override
  Future<Harvest?> getHarvestByPlantId(int plantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'harvests',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'harvest_date DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Harvest.fromMap(maps.first);
  }

  /// Alle Harvests abrufen
  @override
  Future<List<Harvest>> getAllHarvests() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'harvests',
      orderBy: 'harvest_date DESC',
    );

    return maps.map((map) => Harvest.fromMap(map)).toList();
  }

  /// Harvests nach Grow-ID abrufen (via Plants)
  @override
  Future<List<Harvest>> getHarvestsByGrowId(int growId) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT h.* FROM harvests h
      INNER JOIN plants p ON h.plant_id = p.id
      WHERE p.grow_id = ?
      ORDER BY h.harvest_date DESC
    ''', [growId]);

    return maps.map((map) => Harvest.fromMap(map)).toList();
  }

  /// In Trocknung befindliche Harvests
  @override
  Future<List<Harvest>> getDryingHarvests() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'harvests',
      where: 'drying_start_date IS NOT NULL AND drying_end_date IS NULL',
      orderBy: 'drying_start_date DESC',
    );

    return maps.map((map) => Harvest.fromMap(map)).toList();
  }

  /// In Curing befindliche Harvests
  @override
  Future<List<Harvest>> getCuringHarvests() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'harvests',
      where: 'curing_start_date IS NOT NULL AND curing_end_date IS NULL',
      orderBy: 'curing_start_date DESC',
    );

    return maps.map((map) => Harvest.fromMap(map)).toList();
  }

  /// Abgeschlossene Harvests
  @override
  Future<List<Harvest>> getCompletedHarvests() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'harvests',
      where: 'dry_weight IS NOT NULL AND drying_end_date IS NOT NULL AND curing_end_date IS NOT NULL',
      orderBy: 'harvest_date DESC',
    );

    return maps.map((map) => Harvest.fromMap(map)).toList();
  }

  /// Gesamt-Ertrag berechnen (Trockengewicht)
  @override
  Future<double> getTotalYield() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(dry_weight) as total FROM harvests WHERE dry_weight IS NOT NULL',
    );

    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  /// Durchschnittlicher Ertrag pro Pflanze
  @override
  Future<double> getAverageYield() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT AVG(dry_weight) as average FROM harvests WHERE dry_weight IS NOT NULL',
    );

    final average = result.first['average'];
    return average != null ? (average as num).toDouble() : 0.0;
  }

  /// Anzahl Ernten
  @override
  Future<int> getHarvestCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM harvests');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Harvest mit Plant-Daten (JOIN)
  @override
  Future<Map<String, dynamic>?> getHarvestWithPlant(int harvestId) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT
        h.*,
        p.name as plant_name,
        p.strain as plant_strain,
        p.breeder as plant_breeder
      FROM harvests h
      INNER JOIN plants p ON h.plant_id = p.id
      WHERE h.id = ?
    ''', [harvestId]);

    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Alle Harvests mit Plant-Daten
  @override
  Future<List<Map<String, dynamic>>> getAllHarvestsWithPlants() async {
    final db = await _dbHelper.database;
    
    final maps = await db.rawQuery('''
      SELECT 
        h.*,
        p.name as plant_name,
        p.strain as plant_strain,
        p.breeder as plant_breeder,
        p.seed_type as plant_seed_type
      FROM harvests h
      INNER JOIN plants p ON h.plant_id = p.id
      ORDER BY h.harvest_date DESC
    ''');

    return maps;
  }
}
