// =============================================
// GROWLOG - Harvest Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class HarvestRepository with RepositoryErrorHandler implements IHarvestRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  String get repositoryName => 'HarvestRepository';

  /// Harvest erstellen
  ///
  /// Erstellt einen neuen Harvest-Eintrag für eine Pflanze.
  /// Die Pflanze sollte vor dem Aufruf dieser Methode bereits in Phase HARVEST sein.
  @override
  Future<int> createHarvest(Harvest harvest) async {
    return handleMutation(
      operation: () async {
        final db = await _dbHelper.database;
        final harvestMap = harvest.toMap();
        return await db.insert('harvests', harvestMap);
      },
      operationName: 'createHarvest',
      context: {'plant_id': harvest.plantId},
    );
  }

  /// Harvest aktualisieren
  ///
  /// Aktualisiert einen existierenden Harvest-Eintrag.
  /// Hat keine Auswirkungen auf den Pflanzenstatus.
  @override
  Future<int> updateHarvest(Harvest harvest) async {
    return handleMutation(
      operation: () async {
        final db = await _dbHelper.database;
        return await db.update(
          'harvests',
          harvest.copyWith(updatedAt: DateTime.now()).toMap(),
          where: 'id = ?',
          whereArgs: [harvest.id],
        );
      },
      operationName: 'updateHarvest',
      context: {'id': harvest.id},
    );
  }

  /// Harvest löschen
  ///
  /// ⚠️ WICHTIGES VERHALTEN: Setzt Pflanze zurück auf BLOOM-Phase!
  ///
  /// Business-Logik:
  /// - Löscht den Harvest-Eintrag aus der Datenbank
  /// - Setzt die zugehörige Pflanze zurück auf Phase 'BLOOM'
  /// - Ermöglicht Korrektur von versehentlich erstellten Ernten
  ///
  /// Anwendungsfälle:
  /// ✅ Harvest wurde versehentlich zu früh angelegt
  /// ✅ Falsche Daten wurden erfasst und sollen neu eingegeben werden
  /// ✅ Pflanze soll weiter blühen (z.B. nach Teil-Ernte)
  ///
  /// ⚠️ ACHTUNG: Alle Harvest-Daten (Gewichte, Drying/Curing-Daten) gehen verloren!
  @override
  Future<int> deleteHarvest(int id) async {
    return handleMutation(
      operation: () async {
        final db = await _dbHelper.database;

        return await db.transaction((txn) async {
          // Step 1: Get harvest to find plant_id
          final harvestMaps = await txn.query(
            'harvests',
            where: 'id = ?',
            whereArgs: [id],
          );

          if (harvestMaps.isEmpty) {
            throw RepositoryException.notFound('Harvest', id);
          }

          final plantId = harvestMaps.first['plant_id'] as int;

          // Step 2: Delete harvest
          final deleteCount = await txn.delete(
            'harvests',
            where: 'id = ?',
            whereArgs: [id],
          );

          // Step 3: Reset plant to BLOOM phase
          await txn.update(
            'plants',
            {'phase': 'BLOOM'},
            where: 'id = ?',
            whereArgs: [plantId],
          );

          return deleteCount;
        });
      },
      operationName: 'deleteHarvest',
      context: {'id': id},
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
  /// ✅ CRITICAL FIX: Added limit parameter to prevent memory overflow
  @override
  Future<List<Harvest>> getAllHarvests({int? limit}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'harvests',
      orderBy: 'harvest_date DESC',
      limit: limit ?? 1000,  // Reasonable default limit
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
