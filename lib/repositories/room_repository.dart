// =============================================
// GROWLOG - Room Repository
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class RoomRepository with RepositoryErrorHandler implements IRoomRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  String get repositoryName => 'RoomRepository';

  /// Alle Räume laden
  /// ✅ CRITICAL FIX: Added limit parameter to prevent memory overflow
  @override
  Future<List<Room>> findAll({int? limit}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'rooms',
        orderBy: 'name ASC',
        limit: limit ?? 1000, // Reasonable default limit
      );
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
      AppLogger.error(
        'RoomRepository',
        'Failed to load room by id',
        e,
        stackTrace,
      );
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

  /// Prüft ob Raum in Verwendung ist
  @override
  Future<bool> isInUse(int id) async {
    try {
      final db = await _dbHelper.database;

      // Check plants
      final plantCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM plants WHERE room_id = ?', [
              id,
            ]),
          ) ??
          0;

      // Check grows (indirekt über plants in grows)
      final growCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(DISTINCT grow_id) FROM plants WHERE room_id = ? AND grow_id IS NOT NULL',
              [id],
            ),
          ) ??
          0;

      // Check hardware
      final hardwareCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM hardware WHERE room_id = ?',
              [id],
            ),
          ) ??
          0;

      // Check RDWC systems
      final systemCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM rdwc_systems WHERE room_id = ?',
              [id],
            ),
          ) ??
          0;

      return (plantCount + growCount + hardwareCount + systemCount) > 0;
    } catch (e, stackTrace) {
      AppLogger.error(
        'RoomRepository',
        'Failed to check room usage',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Gibt detaillierte Nutzungs-Statistik zurück
  @override
  Future<Map<String, int>> getUsageDetails(int id) async {
    try {
      final db = await _dbHelper.database;

      return {
        'plants':
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM plants WHERE room_id = ?',
                [id],
              ),
            ) ??
            0,
        'grows':
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(DISTINCT grow_id) FROM plants WHERE room_id = ? AND grow_id IS NOT NULL',
                [id],
              ),
            ) ??
            0,
        'hardware':
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM hardware WHERE room_id = ?',
                [id],
              ),
            ) ??
            0,
        'rdwc_systems':
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM rdwc_systems WHERE room_id = ?',
                [id],
              ),
            ) ??
            0,
      };
    } catch (e, stackTrace) {
      AppLogger.error(
        'RoomRepository',
        'Failed to get room usage details',
        e,
        stackTrace,
      );
      return {'plants': 0, 'grows': 0, 'hardware': 0, 'rdwc_systems': 0};
    }
  }

  /// Raum löschen
  ///
  /// ⚠️ WICHTIG: Blockiert Löschung wenn Raum in Verwendung ist!
  ///
  /// Die Methode prüft ob der Raum noch verwendet wird von:
  /// - Pflanzen
  /// - Grows (über plants.grow_id)
  /// - Hardware
  /// - RDWC-Systemen
  ///
  /// Wenn der Raum in Verwendung ist, wird eine RepositoryException geworfen.
  /// Der Benutzer muss diese Elemente zuerst manuell verschieben oder löschen.
  ///
  /// Architektonische Entscheidung:
  /// ❌ KEINE automatische Kaskadierung - verhindert versehentlichen Datenverlust
  /// ✅ Explizite Benutzer-Aktion erforderlich für maximale Kontrolle
  @override
  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;

      // Check if room is in use
      final usageDetails = await getUsageDetails(id);
      final totalUsage = usageDetails.values.reduce((a, b) => a + b);

      if (totalUsage > 0) {
        // Build helpful error message
        final parts = <String>[];
        if (usageDetails['plants']! > 0) {
          parts.add(
            '${usageDetails['plants']} Pflanze${usageDetails['plants']! > 1 ? 'n' : ''}',
          );
        }
        if (usageDetails['grows']! > 0) {
          parts.add(
            '${usageDetails['grows']} Grow${usageDetails['grows']! > 1 ? 's' : ''}',
          );
        }
        if (usageDetails['hardware']! > 0) {
          parts.add(
            '${usageDetails['hardware']} Hardware-Gerät${usageDetails['hardware']! > 1 ? 'e' : ''}',
          );
        }
        if (usageDetails['rdwc_systems']! > 0) {
          parts.add(
            '${usageDetails['rdwc_systems']} RDWC-System${usageDetails['rdwc_systems']! > 1 ? 'e' : ''}',
          );
        }

        throw RepositoryException.conflict(
          'Raum kann nicht gelöscht werden. '
          'Er enthält noch ${parts.join(', ')}. '
          'Bitte verschieben oder löschen Sie diese Elemente zuerst.',
        );
      }

      // Safe to delete
      return await db.delete('rooms', where: 'id = ?', whereArgs: [id]);
    } catch (e, stackTrace) {
      AppLogger.error('RoomRepository', 'Failed to delete room', e, stackTrace);
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
