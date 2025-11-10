// =============================================
// GROWLOG - Room Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/room.dart';
import '../utils/app_logger.dart';
import 'interfaces/i_room_repository.dart';

class RoomRepository implements IRoomRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Alle Räume laden
  @override
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
  @override
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
  @override
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

  /// Raum löschen mit Cascade-Update
  /// ✅ FIX: Unlinks all related records before deleting room to prevent orphaned data
  ///
  /// Updates (sets room_id to NULL):
  /// 1. Hardware linked to this room
  /// 2. Plants linked to this room
  /// 3. RDWC systems linked to this room
  /// 4. Finally deletes the room itself
  @override
  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;

      // Use transaction for atomic cascade delete
      return await db.transaction((txn) async {
        AppLogger.info('RoomRepo', 'Starting cascade delete for room', 'roomId=$id');

        // Step 1: Unlink all hardware in this room
        final hardwareCount = await txn.update(
          'hardware',
          {'room_id': null},
          where: 'room_id = ?',
          whereArgs: [id],
        );

        // Step 2: Unlink all plants in this room
        final plantCount = await txn.update(
          'plants',
          {'room_id': null},
          where: 'room_id = ?',
          whereArgs: [id],
        );

        // Step 3: Unlink all RDWC systems in this room
        final systemCount = await txn.update(
          'rdwc_systems',
          {'room_id': null},
          where: 'room_id = ?',
          whereArgs: [id],
        );

        // Step 4: Finally delete the room itself
        final deletedRoom = await txn.delete(
          'rooms',
          where: 'id = ?',
          whereArgs: [id],
        );

        AppLogger.info(
          'RoomRepo',
          '✅ Cascade delete completed',
          'room=$deletedRoom, hardware=$hardwareCount, plants=$plantCount, systems=$systemCount',
        );

        return deletedRoom;
      });
    } catch (e, stackTrace) {
      AppLogger.error('RoomRepository', 'Failed to delete room with cascade', e, stackTrace);
      rethrow;
    }
  }

  /// Anzahl Räume
  @override
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
