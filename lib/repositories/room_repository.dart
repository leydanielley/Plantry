// =============================================
// GROWLOG - Room Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/room.dart';
import '../utils/app_logger.dart';

class RoomRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Alle Räume laden
  Future<List<Room>> findAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('rooms', orderBy: 'name ASC');
      return maps.map((map) => Room.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('RoomRepository', 'Failed to load rooms', e, stackTrace);
      return [];
    }
  }

  /// Raum nach ID laden
  Future<Room?> findById(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rooms',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return Room.fromMap(maps.first);
    } catch (e, stackTrace) {
      AppLogger.error('RoomRepository', 'Failed to load room by id', e, stackTrace);
      return null;
    }
  }

  /// Raum speichern (INSERT oder UPDATE)
  Future<Room> save(Room room) async {
    try {
      final db = await _dbHelper.database;

      if (room.id == null) {
        // INSERT
        final id = await db.insert('rooms', room.toMap());
        return room.copyWith(id: id);
      } else {
        // UPDATE
        await db.update(
          'rooms',
          room.toMap(),
          where: 'id = ?',
          whereArgs: [room.id],
        );
        return room;
      }
    } catch (e, stackTrace) {
      AppLogger.error('RoomRepository', 'Failed to save room', e, stackTrace);
      rethrow;
    }
  }

  /// Raum löschen
  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'rooms',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      AppLogger.error('RoomRepository', 'Failed to delete room', e, stackTrace);
      rethrow;
    }
  }

  /// Anzahl Räume
  Future<int> count() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM rooms');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('RoomRepository', 'Failed to count rooms', e, stackTrace);
      return 0;
    }
  }
}
