// =============================================
// GROWLOG - Fertilizer Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart'; // ✅ PHASE 2 FIX: Standardized error handling

class FertilizerRepository
    with RepositoryErrorHandler
    implements IFertilizerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  String get repositoryName => 'FertilizerRepository';

  /// Alle Dünger laden
  /// ✅ PHASE 2: Uses standardized error handling (returns empty list on error)
  /// ✅ CRITICAL FIX: Added limit parameter to prevent memory overflow
  @override
  Future<List<Fertilizer>> findAll({int? limit}) async {
    return handleQuery(
      operation: () async {
        final db = await _dbHelper.database;
        final maps = await db.query(
          'fertilizers',
          orderBy: 'name ASC',
          limit: limit ?? 1000, // Reasonable default limit
        );
        return maps.map((map) => Fertilizer.fromMap(map)).toList();
      },
      operationName: 'findAll',
      defaultValue: [],
    );
  }

  /// Dünger nach ID laden
  /// ✅ PHASE 2: Uses standardized error handling (returns null on error)
  @override
  Future<Fertilizer?> findById(int id) async {
    return handleQuery(
      operation: () async {
        final db = await _dbHelper.database;
        final maps = await db.query(
          'fertilizers',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (maps.isEmpty) return null;
        return Fertilizer.fromMap(maps.first);
      },
      operationName: 'findById',
      defaultValue: null,
      context: {'id': id},
    );
  }

  /// Dünger speichern (INSERT oder UPDATE)
  /// ✅ PHASE 2: Uses standardized error handling (rethrows on error)
  @override
  Future<Fertilizer> save(Fertilizer fertilizer) async {
    return handleMutation(
      operation: () async {
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
      },
      operationName: fertilizer.id == null ? 'insert' : 'update',
      context: {'name': fertilizer.name},
    );
  }

  /// Prüft ob Dünger in aktiven Rezepten verwendet wird.
  /// Historische Logs blockieren das Löschen NICHT — nur Rezepte.
  @override
  Future<bool> isInUse(int id) async {
    return handleQuery(
      operation: () async {
        final db = await _dbHelper.database;
        final recipeCount =
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM rdwc_recipe_fertilizers WHERE fertilizer_id = ?',
                [id],
              ),
            ) ??
            0;
        return recipeCount > 0;
      },
      operationName: 'isInUse',
      defaultValue: false,
      context: {'id': id},
    );
  }

  /// Gibt detaillierte Nutzungs-Statistik zurück
  @override
  Future<Map<String, int>> getUsageDetails(int id) async {
    final db = await _dbHelper.database;

    return {
      'recipes':
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM rdwc_recipe_fertilizers WHERE fertilizer_id = ?',
              [id],
            ),
          ) ??
          0,
      'rdwc_logs':
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM rdwc_log_fertilizers WHERE fertilizer_id = ?',
              [id],
            ),
          ) ??
          0,
      'plant_logs':
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM log_fertilizers WHERE fertilizer_id = ?',
              [id],
            ),
          ) ??
          0,
    };
  }

  /// Dünger löschen.
  /// Blockiert wenn der Dünger noch in aktiven Rezepten verwendet wird.
  /// Historische Log-Verknüpfungen (rdwc_log_fertilizers, log_fertilizers)
  /// werden automatisch mitgelöscht — die Logs selbst bleiben erhalten.
  @override
  Future<int> delete(int id) async {
    return handleMutation(
      operation: () async {
        final db = await _dbHelper.database;

        // Only recipes hard-block deletion
        final recipeCount =
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM rdwc_recipe_fertilizers WHERE fertilizer_id = ?',
                [id],
              ),
            ) ??
            0;

        if (recipeCount > 0) {
          throw RepositoryException.conflict(
            'Dünger kann nicht gelöscht werden. '
            'Er wird noch in $recipeCount Rezept${recipeCount > 1 ? 'en' : ''} verwendet. '
            'Bitte zuerst aus den Rezepten entfernen.',
          );
        }

        // Clean up historical log references (logs themselves remain intact)
        await db.delete('rdwc_log_fertilizers', where: 'fertilizer_id = ?', whereArgs: [id]);
        await db.delete('log_fertilizers', where: 'fertilizer_id = ?', whereArgs: [id]);

        return await db.delete('fertilizers', where: 'id = ?', whereArgs: [id]);
      },
      operationName: 'delete',
      context: {'id': id},
    );
  }

  /// Anzahl Dünger
  /// ✅ PHASE 2: Uses standardized error handling (returns 0 on error)
  @override
  Future<int> count() async {
    return handleQuery(
      operation: () async {
        final db = await _dbHelper.database;
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM fertilizers',
        );
        return Sqflite.firstIntValue(result) ?? 0;
      },
      operationName: 'count',
      defaultValue: 0,
    );
  }
}
