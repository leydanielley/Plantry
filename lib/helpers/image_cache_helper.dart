// =============================================
// GROWLOG - Image Cache Helper
// Optimiert Bilder-Laden mit Caching & Thumbnails
// =============================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../utils/app_logger.dart';

class ImageCacheHelper {
  static final ImageCacheHelper _instance = ImageCacheHelper._internal();
  factory ImageCacheHelper() => _instance;
  ImageCacheHelper._internal();

  // Cache für bereits geladene Thumbnails
  final Map<String, Uint8List> _memoryCache = {};
  static const int maxCacheSize = 50; // Max 50 Thumbnails im Memory

  // Thumbnail-Verzeichnis
  Future<Directory> get _thumbnailDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${appDir.path}/thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  /// Thumbnail-Pfad für ein Bild generieren
  Future<String> _getThumbnailPath(String originalPath) async {
    final thumbDir = await _thumbnailDir;
    final fileName = path.basename(originalPath);
    final thumbName = 'thumb_$fileName';
    return '${thumbDir.path}/$thumbName';
  }

  /// Thumbnail generieren (nur falls noch nicht existiert)
  Future<File?> generateThumbnail(
    String originalPath, {
    int maxWidth = 400,
    int quality = 85,
  }) async {
    try {
      final thumbPath = await _getThumbnailPath(originalPath);
      final thumbFile = File(thumbPath);

      // Thumbnail existiert bereits?
      if (await thumbFile.exists()) {
        return thumbFile;
      }

      // Original-Datei existiert?
      if (!await File(originalPath).exists()) {
        return null;
      }

      // Thumbnail erstellen
      final result = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        thumbPath,
        minWidth: maxWidth,
        quality: quality,
      );

      if (result == null) return null;

      return File(result.path);
    } catch (e) {
      AppLogger.error('ImageCacheHelper', 'Error generating thumbnail', e);
      return null;
    }
  }

  /// Thumbnail laden (aus Memory Cache oder Disk)
  Future<Uint8List?> loadThumbnail(String originalPath) async {
    // 1. Check Memory Cache
    if (_memoryCache.containsKey(originalPath)) {
      return _memoryCache[originalPath];
    }

    // 2. Check Disk Cache
    final thumbPath = await _getThumbnailPath(originalPath);
    final thumbFile = File(thumbPath);

    if (await thumbFile.exists()) {
      final bytes = await thumbFile.readAsBytes();
      
      // In Memory Cache speichern
      _addToCache(originalPath, bytes);
      
      return bytes;
    }

    // 3. Thumbnail generieren
    final thumb = await generateThumbnail(originalPath);
    if (thumb != null) {
      final bytes = await thumb.readAsBytes();
      _addToCache(originalPath, bytes);
      return bytes;
    }

    return null;
  }

  /// Zum Memory Cache hinzufügen (mit LRU-Logik)
  void _addToCache(String key, Uint8List data) {
    if (_memoryCache.length >= maxCacheSize) {
      // Ältesten Eintrag entfernen
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = data;
  }

  /// Cache leeren
  void clearMemoryCache() {
    _memoryCache.clear();
  }

  /// Alle Thumbnails löschen
  Future<void> clearDiskCache() async {
    try {
      final thumbDir = await _thumbnailDir;
      if (await thumbDir.exists()) {
        await thumbDir.delete(recursive: true);
      }
      clearMemoryCache();
    } catch (e) {
      AppLogger.error('ImageCacheHelper', 'Error clearing disk cache', e);
    }
  }
}
