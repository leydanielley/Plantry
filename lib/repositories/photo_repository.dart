// =============================================
// GROWLOG - Photo Repository
// =============================================

import 'dart:io';
import '../models/photo.dart';
import '../database/database_helper.dart';
import '../utils/app_logger.dart';
import 'interfaces/i_photo_repository.dart';

class PhotoRepository implements IPhotoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Foto speichern mit Validierung
  @override
  Future<int> save(Photo photo) async {
    // Photo-Validierung
    _validatePhoto(photo);
    
    final db = await _dbHelper.database;
    
    if (photo.id == null) {
      // Neues Foto erstellen
      return await db.insert('photos', photo.toMap());
    } else {
      // Bestehendes Foto aktualisieren
      await db.update(
        'photos',
        photo.toMap(),
        where: 'id = ?',
        whereArgs: [photo.id],
      );
      return photo.id!;
    }
  }
  
  /// Photo-Validierung
  void _validatePhoto(Photo photo) {
    if (photo.logId <= 0) {
      throw ArgumentError('Ungültige Log ID: ${photo.logId}');
    }
    
    if (photo.filePath.isEmpty) {
      throw ArgumentError('Foto-Pfad darf nicht leer sein');
    }
    
    // Prüfe ob Pfad valide ist
    if (!photo.filePath.contains('/') && !photo.filePath.contains('\\')) {
      throw ArgumentError('Ungültiger Foto-Pfad: ${photo.filePath}');
    }
  }

  /// Alle Fotos für einen Log abrufen
  @override
  Future<List<Photo>> getPhotosByLogId(int logId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'photos',
      where: 'log_id = ?',
      whereArgs: [logId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => Photo.fromMap(maps[i]));
  }

  /// ✅ PERFORMANCE FIX: Batch-Query für mehrere Logs (verhindert N+1 Problem!)
  /// Nutzen: Lädt alle Photos für eine Liste von Logs in EINER Query
  @override
  Future<Map<int, List<Photo>>> getPhotosByLogIds(List<int> logIds) async {
    if (logIds.isEmpty) return {};

    try {
      final db = await _dbHelper.database;

      // SQL IN clause für batch lookup
      final placeholders = List.filled(logIds.length, '?').join(',');
      final maps = await db.query(
        'photos',
        where: 'log_id IN ($placeholders)',
        whereArgs: logIds,
        orderBy: 'log_id, created_at DESC',
      );

      // Gruppieren nach log_id
      final result = <int, List<Photo>>{};
      for (final map in maps) {
        final logId = map['log_id'] as int;
        final photo = Photo.fromMap(map);

        if (result[logId] == null) {
          result[logId] = [];
        }
        result[logId]!.add(photo);
      }

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('PhotoRepository', 'Failed to load photos by log ids', e, stackTrace);
      return {};
    }
  }

  /// Foto nach ID abrufen
  @override
  Future<Photo?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'photos',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Photo.fromMap(maps.first);
  }

  /// Foto löschen (für Legacy-Code)
  /// ✅ FIX BUG #1: Deletes file from disk AND database
  @override
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;

    // 1. First, get photo to find file path
    final photo = await getById(id);

    if (photo != null) {
      // 2. Delete physical file
      try {
        final file = File(photo.filePath);
        if (await file.exists()) {
          await file.delete();
          AppLogger.info('PhotoRepo', '✅ Deleted file', photo.filePath);
        } else {
          AppLogger.warning('PhotoRepo', 'File already missing', photo.filePath);
        }
      } catch (e) {
        AppLogger.warning('PhotoRepo', 'Failed to delete file', e);
        // Continue anyway to at least remove DB record
      }
    }

    // 3. Then delete DB record
    return await db.delete(
      'photos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Foto löschen (mit klarerem Namen)
  @override
  Future<int> deletePhoto(int id) async {
    return await delete(id);
  }

  /// Alle Fotos für eine Pflanze abrufen (über Logs) mit Pagination
  @override
  Future<List<Photo>> getPhotosByPlantId(int plantId, {int? limit, int? offset}) async {
    final db = await _dbHelper.database;
    
    // Join mit logs Tabelle um alle Fotos einer Pflanze zu bekommen
    String query = '''
  SELECT photos.* FROM photos
  INNER JOIN plant_logs ON photos.log_id = plant_logs.id
  WHERE plant_logs.plant_id = ?
  ORDER BY photos.created_at DESC
''';
    
    List<dynamic> args = [plantId];
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }
    
    if (offset != null) {
      query += ' OFFSET ?';
      args.add(offset);
    }
    
    final maps = await db.rawQuery(query, args);

    return List.generate(maps.length, (i) => Photo.fromMap(maps[i]));
  }

  /// Alle Fotos löschen die zu einem Log gehören
  /// ✅ FIX BUG #1: Deletes files from disk AND database
  @override
  Future<void> deleteByLogId(int logId) async {
    final db = await _dbHelper.database;

    // 1. Get all photos for this log
    final photos = await getPhotosByLogId(logId);

    // 2. Delete all files
    for (final photo in photos) {
      try {
        final file = File(photo.filePath);
        if (await file.exists()) {
          await file.delete();
          AppLogger.info('PhotoRepo', '✅ Deleted file', photo.filePath);
        } else {
          AppLogger.warning('PhotoRepo', 'File already missing', photo.filePath);
        }
      } catch (e) {
        AppLogger.warning('PhotoRepo', 'Failed to delete file', e);
        // Continue to delete other files
      }
    }

    // 3. Delete DB records
    await db.delete(
      'photos',
      where: 'log_id = ?',
      whereArgs: [logId],
    );
  }
}
