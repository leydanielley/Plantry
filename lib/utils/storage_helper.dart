// =============================================
// GROWLOG - Storage Helper
// Checks available storage before file operations
// =============================================

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'app_logger.dart';

class StorageHelper {
  static const int _minRequiredBytes = 100 * 1024 * 1024; // 100 MB minimum
  static const int _criticalThreshold = 50 * 1024 * 1024; // 50 MB critical

  /// Check if enough storage is available
  /// Returns true if enough space, false otherwise
  static Future<bool> hasEnoughStorage({int? bytesNeeded}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      // Try to get available space using df command
      final result = await Process.run('df', [dir.path]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            // Available space is typically in column 3 (in KB)
            final availableKB = int.tryParse(parts[3]) ?? 0;
            final availableBytes = availableKB * 1024;

            final required = bytesNeeded ?? _minRequiredBytes;
            final hasSpace = availableBytes > required;

            if (!hasSpace) {
              AppLogger.warning(
                'StorageHelper',
                'Insufficient storage: ${(availableBytes / 1024 / 1024).toStringAsFixed(1)}MB available, ${(required / 1024 / 1024).toStringAsFixed(1)}MB required',
              );
            }

            return hasSpace;
          }
        }
      }

      // Fallback: assume enough space if we can't determine
      AppLogger.warning('StorageHelper', 'Could not determine storage, assuming sufficient');
      return true;
    } catch (e) {
      AppLogger.error('StorageHelper', 'Error checking storage', e);
      // Fail open - don't block user if we can't check
      return true;
    }
  }

  /// Get available storage in bytes
  static Future<int> getAvailableStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final result = await Process.run('df', [dir.path]);

      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final availableKB = int.tryParse(parts[3]) ?? 0;
            return availableKB * 1024;
          }
        }
      }
    } catch (e) {
      AppLogger.error('StorageHelper', 'Error getting available storage', e);
    }

    return _minRequiredBytes; // Safe default
  }

  /// Check if storage is in critical state
  static Future<bool> isStorageCritical() async {
    final available = await getAvailableStorage();
    return available < _criticalThreshold;
  }

  /// Get human-readable storage info
  static Future<String> getStorageInfo() async {
    final available = await getAvailableStorage();
    final mb = (available / 1024 / 1024).toStringAsFixed(1);

    if (available < _criticalThreshold) {
      return 'Kritisch: ${mb}MB verfügbar';
    } else if (available < _minRequiredBytes) {
      return 'Niedrig: ${mb}MB verfügbar';
    } else {
      return '${mb}MB verfügbar';
    }
  }

  /// Calculate directory size
  static Future<int> getDirectorySize(Directory dir) async {
    try {
      int totalSize = 0;

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            // Skip files we can't access
          }
        }
      }

      return totalSize;
    } catch (e) {
      AppLogger.error('StorageHelper', 'Error calculating directory size', e);
      return 0;
    }
  }

  /// Clean up old thumbnails if storage is low
  static Future<void> cleanupIfNeeded() async {
    try {
      if (await isStorageCritical()) {
        AppLogger.info('StorageHelper', 'Storage critical - cleaning up thumbnails');

        final appDir = await getApplicationDocumentsDirectory();
        final thumbDir = Directory('${appDir.path}/thumbnails');

        if (await thumbDir.exists()) {
          // Delete thumbnails older than 30 days
          final now = DateTime.now();
          int deletedCount = 0;

          await for (final entity in thumbDir.list()) {
            if (entity is File) {
              final stat = await entity.stat();
              final age = now.difference(stat.modified);

              if (age.inDays > 30) {
                await entity.delete();
                deletedCount++;
              }
            }
          }

          AppLogger.info('StorageHelper', 'Cleaned up $deletedCount old thumbnails');
        }
      }
    } catch (e) {
      AppLogger.error('StorageHelper', 'Error during cleanup', e);
    }
  }
}
