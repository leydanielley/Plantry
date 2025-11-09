// =============================================
// GROWLOG - Hardware Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/hardware.dart';
import 'interfaces/i_hardware_repository.dart';

class HardwareRepository implements IHardwareRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Alle Hardware-Items für einen Raum laden
  @override
  Future<List<Hardware>> findByRoom(int roomId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'hardware',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'type ASC, name ASC',
    );

    return maps.map((map) => Hardware.fromMap(map)).toList();
  }

  /// Alle aktiven Hardware-Items für einen Raum laden
  @override
  Future<List<Hardware>> findActiveByRoom(int roomId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'hardware',
      where: 'room_id = ? AND active = ?',
      whereArgs: [roomId, 1],
      orderBy: 'type ASC, name ASC',
    );

    return maps.map((map) => Hardware.fromMap(map)).toList();
  }

  /// Hardware nach ID laden
  @override
  Future<Hardware?> findById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'hardware',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Hardware.fromMap(maps.first);
  }

  /// Alle Hardware-Items laden (über alle Räume)
  @override
  Future<List<Hardware>> findAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'hardware',
      orderBy: 'room_id ASC, type ASC, name ASC',
    );

    return maps.map((map) => Hardware.fromMap(map)).toList();
  }

  /// Hardware speichern (INSERT oder UPDATE)
  @override
  Future<Hardware> save(Hardware hardware) async {
    try {
      final db = await _dbHelper.database;

      if (hardware.id == null) {
        // INSERT
        final id = await db.insert(
          'hardware',
          hardware.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
        return hardware.copyWith(id: id);
      } else {
        // UPDATE
        await db.update(
          'hardware',
          hardware.toMap(),
          where: 'id = ?',
          whereArgs: [hardware.id],
        );
        return hardware;
      }
    } catch (e) {
      // ERROR saving hardware
      rethrow;
    }
  }

  /// Hardware löschen
  @override
  Future<int> delete(int id) async {
   final db = await _dbHelper.database;
    return await db.delete(
      'hardware',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hardware deaktivieren (statt löschen)
  @override
  Future<int> deactivate(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'hardware',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hardware aktivieren
  @override
  Future<int> activate(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'hardware',
      {'active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Anzahl Hardware-Items für einen Raum
  @override
  Future<int> countByRoom(int roomId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM hardware WHERE room_id = ? AND active = 1',
      [roomId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Gesamte Wattzahl für einen Raum berechnen
  @override
  Future<int> getTotalWattageByRoom(int roomId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(wattage * quantity) as total FROM hardware WHERE room_id = ? AND active = 1 AND wattage IS NOT NULL',
      [roomId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
