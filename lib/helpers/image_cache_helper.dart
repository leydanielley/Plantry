// =============================================
// GROWLOG - Image Cache Helper
// Optimiert Bilder-Laden mit Caching & Thumbnails
// =============================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:synchronized/synchronized.dart';
import 'package:growlog_app/utils/app_logger.dart';

class ImageCacheHelper {
  static final ImageCacheHelper _instance = ImageCacheHelper._internal();
  factory ImageCacheHelper() => _instance;
  ImageCacheHelper._internal();

  // Cache für bereits geladene Thumbnails
  final Map<String, Uint8List> _memoryCache = {};

  // ✅ CRITICAL FIX: Add Lock to prevent race conditions on cache access
  final _cacheLock = Lock();

  // ✅ FIX: Byte-based limit statt count-based (verhindert OOM auf Low-End Devices)
  static const int maxCacheSizeBytes = 50 * 1024 * 1024; // 50 MB max
  int _currentCacheSizeBytes = 0;

  // Thumbnail-Verzeichnis
  Future<Directory> get _thumbnailDir async {
    final appDir = await getApplicationDocumentsDirectory();
    // ✅ FIX: Use path.join instead of string interpolation for cross-platform compatibility
    final thumbDir = Directory(path.join(appDir.path, 'thumbnails'));
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
    // ✅ FIX: Use path.join instead of string interpolation for cross-platform compatibility
    return path.join(thumbDir.path, thumbName);
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
  /// ✅ CRITICAL FIX: Made async and wrapped in Lock to prevent race conditions
  Future<void> _addToCache(String key, Uint8List data) async {
    await _cacheLock.synchronized(() {
      final dataSize = data.length;

      // ✅ FIX: Validate byte counter integrity BEFORE loop
      if (_currentCacheSizeBytes < 0) {
        AppLogger.error(
          'ImageCacheHelper',
          'Byte counter corrupted, clearing cache',
        );
        clearMemoryCache();
        return;
      }

      // ✅ FIX: Validate dataSize is reasonable
      if (dataSize > maxCacheSizeBytes) {
        AppLogger.warning(
          'ImageCacheHelper',
          'Image too large for cache ($dataSize bytes), skipping',
        );
        return;
      }

      // ✅ FIX: Evict based on byte size, not count
      // ✅ FIX: Add iteration limit to prevent infinite loop if byte tracking is incorrect
      int evictionCount = 0;
      const maxEvictions = 1000; // Safety limit

      // Remove oldest entries until enough space available
      while (_currentCacheSizeBytes + dataSize > maxCacheSizeBytes &&
          _memoryCache.isNotEmpty &&
          evictionCount < maxEvictions) {
        final oldestKey = _memoryCache.keys.first;
        final oldestData = _memoryCache.remove(oldestKey);
        if (oldestData != null) {
          _currentCacheSizeBytes -= oldestData.length;
        }
        evictionCount++;
      }

      // ✅ FIX: If we hit max evictions, clear entire cache and reset tracking
      if (evictionCount >= maxEvictions) {
        AppLogger.warning(
          'ImageCacheHelper',
          'Hit max eviction limit ($maxEvictions), clearing entire cache',
        );
        clearMemoryCache();
      }

      // Add new entry
      _memoryCache[key] = data;
      _currentCacheSizeBytes += dataSize;

      AppLogger.info(
        'ImageCacheHelper',
        'Cache: ${_memoryCache.length} items, ${(_currentCacheSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
      );
    });
  }

  /// Cache leeren
  void clearMemoryCache() {
    _memoryCache.clear();
    _currentCacheSizeBytes = 0; // Reset byte counter
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
