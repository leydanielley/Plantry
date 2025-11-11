// =============================================
// GROWLOG - Update Cleanup
// Handles cleanup tasks after app updates
// =============================================

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/version_manager.dart';
import 'package:growlog_app/helpers/image_cache_helper.dart';

class UpdateCleanup {
  /// Perform cleanup tasks after update
  static Future<void> performPostUpdateCleanup() async {
    try {
      final updateInfo = await VersionManager.getUpdateInfo();

      if (!updateInfo.isUpdate) {
        return; // No update, no cleanup needed
      }

      AppLogger.info('UpdateCleanup', '🧹 Starting post-update cleanup...');

      // Cleanup based on version change
      await _versionSpecificCleanup(updateInfo);

      // General cleanup tasks
      await _cleanupOldThumbnails();
      await _cleanupTempFiles();
      await _cleanupOldBackups();

      AppLogger.info('UpdateCleanup', '✅ Post-update cleanup completed');
    } catch (e) {
      AppLogger.error('UpdateCleanup', 'Error during cleanup', e);
      // Don't fail the app if cleanup fails
    }
  }

  /// Version-specific cleanup tasks
  static Future<void> _versionSpecificCleanup(UpdateInfo updateInfo) async {
    try {
      // Example: Clear thumbnails on major version upgrade
      if (_isMajorVersionUpdate(
        updateInfo.previousVersion,
        updateInfo.currentVersion,
      )) {
        AppLogger.info(
          'UpdateCleanup',
          'Major version update - clearing caches',
        );
        await ImageCacheHelper().clearDiskCache();
      }

      // Add more version-specific cleanups here
      // Example:
      // if (updateInfo.previousVersion == '0.7.0' && updateInfo.currentVersion.startsWith('0.8')) {
      //   await _migrateOldPhotoStructure();
      // }
    } catch (e) {
      AppLogger.error('UpdateCleanup', 'Version-specific cleanup failed', e);
    }
  }

  /// Check if this is a major version update (e.g., 0.7.x → 0.8.x)
  static bool _isMajorVersionUpdate(String? oldVersion, String newVersion) {
    if (oldVersion == null) return false;

    try {
      final oldParts = oldVersion.split('+')[0].split('.');
      final newParts = newVersion.split('+')[0].split('.');

      if (oldParts.length < 2 || newParts.length < 2) return false;

      // Check major and minor version
      return oldParts[0] != newParts[0] || oldParts[1] != newParts[1];
    } catch (e) {
      return false;
    }
  }

  /// Clean up old thumbnails (older than 60 days)
  static Future<void> _cleanupOldThumbnails() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // ✅ FIX: Use path.join for cross-platform compatibility (Windows uses backslash)
      final thumbDir = Directory(path.join(appDir.path, 'thumbnails'));

      if (!await thumbDir.exists()) {
        return;
      }

      final now = DateTime.now();
      int deletedCount = 0;

      await for (final entity in thumbDir.list()) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);

            if (age.inDays > 60) {
              await entity.delete();
              deletedCount++;
            }
          } catch (e) {
            // Skip files we can't delete
          }
        }
      }

      if (deletedCount > 0) {
        AppLogger.info('UpdateCleanup', 'Deleted $deletedCount old thumbnails');
      }
    } catch (e) {
      AppLogger.error('UpdateCleanup', 'Failed to cleanup thumbnails', e);
    }
  }

  /// Clean up temp files
  static Future<void> _cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();

      if (!await tempDir.exists()) {
        return;
      }

      int deletedCount = 0;

      await for (final entity in tempDir.list()) {
        try {
          // Delete old export directories
          if (entity is Directory && entity.path.contains('plantry_export_')) {
            await entity.delete(recursive: true);
            deletedCount++;
          }

          // Delete old temp files
          if (entity is File) {
            final stat = await entity.stat();
            final age = DateTime.now().difference(stat.modified);

            if (age.inDays > 7) {
              await entity.delete();
              deletedCount++;
            }
          }
        } catch (e) {
          // Skip files/dirs we can't delete
        }
      }

      if (deletedCount > 0) {
        AppLogger.info(
          'UpdateCleanup',
          'Deleted $deletedCount temp files/dirs',
        );
      }
    } catch (e) {
      AppLogger.error('UpdateCleanup', 'Failed to cleanup temp files', e);
    }
  }

  /// Clean up old backup files (keep last 5)
  static Future<void> _cleanupOldBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // Find all backup ZIP files
      final backups = <FileSystemEntity>[];
      await for (final entity in appDir.list()) {
        if (entity is File &&
            entity.path.endsWith('.zip') &&
            entity.path.contains('plantry_backup_')) {
          backups.add(entity);
        }
      }

      if (backups.length <= 5) {
        return; // Keep all if 5 or fewer
      }

      // Sort by modification time (newest first)
      backups.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // Delete old backups (keep first 5)
      int deletedCount = 0;
      for (int i = 5; i < backups.length; i++) {
        try {
          await backups[i].delete();
          deletedCount++;
        } catch (e) {
          // Skip files we can't delete
        }
      }

      if (deletedCount > 0) {
        AppLogger.info(
          'UpdateCleanup',
          'Deleted $deletedCount old backups (kept 5 most recent)',
        );
      }
    } catch (e) {
      AppLogger.error('UpdateCleanup', 'Failed to cleanup old backups', e);
    }
  }

  /// Estimate cleanup savings
  static Future<int> estimateCleanupSize() async {
    int totalBytes = 0;

    try {
      // Old thumbnails
      final appDir = await getApplicationDocumentsDirectory();
      // ✅ FIX: Use path.join for cross-platform compatibility (Windows uses backslash)
      final thumbDir = Directory(path.join(appDir.path, 'thumbnails'));

      if (await thumbDir.exists()) {
        final now = DateTime.now();
        await for (final entity in thumbDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);

            if (age.inDays > 60) {
              totalBytes += stat.size;
            }
          }
        }
      }

      // Temp files
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            final age = DateTime.now().difference(stat.modified);

            if (age.inDays > 7) {
              totalBytes += stat.size;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('UpdateCleanup', 'Failed to estimate cleanup size', e);
    }

    return totalBytes;
  }
}
