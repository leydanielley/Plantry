// =============================================
// GROWLOG - Storage Helper
// Checks available storage before file operations
// =============================================

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:growlog_app/utils/app_logger.dart';

class StorageHelper {
  // ✅ AUDIT FIX: Storage threshold constants already properly extracted
  static const int _minRequiredBytes = 100 * 1024 * 1024; // 100 MB minimum
  static const int _criticalThreshold = 50 * 1024 * 1024; // 50 MB critical
  // Note: _maxPhotoSizeBytes reserved for future photo validation feature
  // static const int _maxPhotoSizeBytes = 50 * 1024 * 1024; // 50 MB max photo size
  static const int _thumbnailAgeDays =
      30; // Delete thumbnails older than 30 days
  static const int _bytesPerKb = 1024;

  /// Check if enough storage is available
  /// Returns true if enough space, false otherwise
  ///
  /// ⚠️ PLATFORM LIMITATION: iOS doesn't allow df command due to sandboxing
  /// On iOS, this method returns true (assumes sufficient storage) since we
  /// can't reliably check available disk space without native platform channels
  static Future<bool> hasEnoughStorage({int? bytesNeeded}) async {
    try {
      // ✅ MEDIUM FIX: Platform detection - iOS doesn't support df command
      if (Platform.isIOS) {
        AppLogger.debug(
          'StorageHelper',
          'iOS: Skipping storage check (not supported), assuming sufficient',
        );
        return true; // Fail open on iOS
      }

      final dir = await getApplicationDocumentsDirectory();

      // Try to get available space using df command (Android/Linux/macOS/Windows)
      final result = await Process.run('df', [dir.path]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            // Available space is typically in column 3 (in KB)
            final availableKB = int.tryParse(parts[3]) ?? 0;
            final availableBytes = availableKB * _bytesPerKb;

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
      AppLogger.warning(
        'StorageHelper',
        'Could not determine storage, assuming sufficient',
      );
      return true;
    } catch (e) {
      AppLogger.error('StorageHelper', 'Error checking storage', e);
      // Fail open - don't block user if we can't check
      return true;
    }
  }

  /// Get available storage in bytes
  ///
  /// ⚠️ PLATFORM LIMITATION: iOS doesn't support df command
  /// Returns minimum required bytes (100MB) on iOS as a safe default
  static Future<int> getAvailableStorage() async {
    try {
      // ✅ MEDIUM FIX: Platform detection - iOS doesn't support df command
      if (Platform.isIOS) {
        AppLogger.debug(
          'StorageHelper',
          'iOS: Cannot determine storage, returning safe default',
        );
        return _minRequiredBytes; // Conservative default for iOS
      }

      final dir = await getApplicationDocumentsDirectory();
      final result = await Process.run('df', [dir.path]);

      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final availableKB = int.tryParse(parts[3]) ?? 0;
            return availableKB * _bytesPerKb;
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

      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
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
        AppLogger.info(
          'StorageHelper',
          'Storage critical - cleaning up thumbnails',
        );

        final appDir = await getApplicationDocumentsDirectory();
        // ✅ FIX: Use path.join instead of string interpolation for cross-platform compatibility
        final thumbDir = Directory(path.join(appDir.path, 'thumbnails'));

        if (await thumbDir.exists()) {
          // Delete thumbnails older than 30 days
          final now = DateTime.now();
          int deletedCount = 0;

          await for (final entity in thumbDir.list()) {
            if (entity is File) {
              final stat = await entity.stat();
              final age = now.difference(stat.modified);

              if (age.inDays > _thumbnailAgeDays) {
                await entity.delete();
                deletedCount++;
              }
            }
          }

          AppLogger.info(
            'StorageHelper',
            'Cleaned up $deletedCount old thumbnails',
          );
        }
      }
    } catch (e) {
      AppLogger.error('StorageHelper', 'Error during cleanup', e);
    }
  }
}
