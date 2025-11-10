// =============================================
// GROWLOG - Version Manager
// Tracks app versions and detects updates
// =============================================

import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';
import 'app_version.dart';

class VersionManager {
  // ✅ AUDIT FIX: Extracted timeout constants
  static const String _keyLastVersion = 'last_app_version';
  static const String _keyLastDbVersion = 'last_db_version';
  static const String _keyUpdateTimestamp = 'last_update_timestamp';
  static const String _keyMigrationStatus = 'migration_status';
  static const String _keyFailedMigrations = 'failed_migrations';

  // Timeout constants
  static const int _migrationTimeoutMinutes = 30; // Migration timeout threshold

  /// Current app version (from pubspec.yaml via AppVersion)
  /// ✅ AUTO-SYNC: Version wird aus app_version.dart geladen
  static String get currentVersion => AppVersion.version;

  /// Save current version
  static Future<void> saveCurrentVersion({int? dbVersion}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_keyLastVersion, currentVersion);
      await prefs.setInt(_keyUpdateTimestamp, DateTime.now().millisecondsSinceEpoch);

      if (dbVersion != null) {
        await prefs.setInt(_keyLastDbVersion, dbVersion);
      }

      AppLogger.info('VersionManager', 'Version saved: $currentVersion (DB: $dbVersion)');
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to save version', e);
    }
  }

  /// Get last saved version
  static Future<String?> getLastVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastVersion);
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to get last version', e);
      return null;
    }
  }

  /// Get last database version
  static Future<int?> getLastDbVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyLastDbVersion);
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to get last DB version', e);
      return null;
    }
  }

  /// Check if this is first launch
  static Future<bool> isFirstLaunch() async {
    final lastVersion = await getLastVersion();
    return lastVersion == null;
  }

  /// Check if app was updated
  static Future<bool> wasUpdated() async {
    final lastVersion = await getLastVersion();
    if (lastVersion == null) return false;

    final isUpdated = lastVersion != currentVersion;

    if (isUpdated) {
      AppLogger.info('VersionManager', 'Update detected: $lastVersion → $currentVersion');
    }

    return isUpdated;
  }

  /// Get update info
  static Future<UpdateInfo> getUpdateInfo() async {
    final lastVersion = await getLastVersion();
    final lastDbVersion = await getLastDbVersion();
    final isFirst = lastVersion == null;
    final isUpdate = !isFirst && lastVersion != currentVersion;

    return UpdateInfo(
      isFirstLaunch: isFirst,
      isUpdate: isUpdate,
      previousVersion: lastVersion,
      currentVersion: currentVersion,
      previousDbVersion: lastDbVersion,
    );
  }

  /// Mark migration as in progress
  static Future<void> markMigrationInProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMigrationStatus, 'in_progress');
      await prefs.setInt('migration_start_time', DateTime.now().millisecondsSinceEpoch);

      AppLogger.info('VersionManager', 'Migration marked as in progress');
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to mark migration in progress', e);
    }
  }

  /// Mark migration as completed
  static Future<void> markMigrationCompleted({required int dbVersion}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMigrationStatus, 'completed');
      await prefs.remove('migration_start_time');

      await saveCurrentVersion(dbVersion: dbVersion);

      AppLogger.info('VersionManager', 'Migration marked as completed (DB v$dbVersion)');
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to mark migration completed', e);
    }
  }

  /// Mark migration as failed
  static Future<void> markMigrationFailed({
    required int fromVersion,
    required int toVersion,
    required String error,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMigrationStatus, 'failed');

      // Track failed migrations
      final failed = prefs.getStringList(_keyFailedMigrations) ?? [];
      failed.add('$fromVersion→$toVersion: $error');
      await prefs.setStringList(_keyFailedMigrations, failed);

      AppLogger.error('VersionManager', 'Migration marked as failed: $fromVersion→$toVersion');
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to mark migration as failed', e);
    }
  }

  /// Check if migration is in progress
  static Future<bool> isMigrationInProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = prefs.getString(_keyMigrationStatus);

      if (status == 'in_progress') {
        // ✅ FIX: Check if migration started more than N minutes ago
        // (Increased from 10 min to allow for legitimate long migrations)
        final startTime = prefs.getInt('migration_start_time');
        if (startTime != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
          final timeoutMs = _migrationTimeoutMinutes * 60 * 1000;
          if (elapsed > timeoutMs) {
            // Migration stuck for too long
            AppLogger.error('VersionManager', 'Migration appears stuck (>$_migrationTimeoutMinutes min)');
            await prefs.setString(_keyMigrationStatus, 'timeout');
            return false;
          }
        }

        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to check migration status', e);
      return false;
    }
  }

  /// Get failed migrations
  static Future<List<String>> getFailedMigrations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_keyFailedMigrations) ?? [];
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to get failed migrations', e);
      return [];
    }
  }

  /// Clear failed migrations
  static Future<void> clearFailedMigrations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFailedMigrations);
      await prefs.remove(_keyMigrationStatus);

      AppLogger.info('VersionManager', 'Failed migrations cleared');
    } catch (e) {
      AppLogger.error('VersionManager', 'Failed to clear failed migrations', e);
    }
  }

  /// Log version info
  static Future<void> logVersionInfo() async {
    final info = await getUpdateInfo();

    AppLogger.info('VersionManager', '═══════════════════════════════');
    AppLogger.info('VersionManager', 'Version Info:');
    AppLogger.info('VersionManager', '  Current: ${info.currentVersion}');
    AppLogger.info('VersionManager', '  Previous: ${info.previousVersion ?? "N/A"}');
    AppLogger.info('VersionManager', '  First Launch: ${info.isFirstLaunch}');
    AppLogger.info('VersionManager', '  Is Update: ${info.isUpdate}');
    AppLogger.info('VersionManager', '  DB Version: ${info.previousDbVersion ?? "N/A"}');
    AppLogger.info('VersionManager', '═══════════════════════════════');

    if (info.isUpdate) {
      final failed = await getFailedMigrations();
      if (failed.isNotEmpty) {
        AppLogger.warning('VersionManager', 'Failed migrations history:');
        for (final f in failed) {
          AppLogger.warning('VersionManager', '  - $f');
        }
      }
    }
  }
}

/// Update information
class UpdateInfo {
  final bool isFirstLaunch;
  final bool isUpdate;
  final String? previousVersion;
  final String currentVersion;
  final int? previousDbVersion;

  const UpdateInfo({
    required this.isFirstLaunch,
    required this.isUpdate,
    this.previousVersion,
    required this.currentVersion,
    this.previousDbVersion,
  });

  /// Get version change description
  String get changeDescription {
    if (isFirstLaunch) return 'Erste Installation';
    if (isUpdate) return 'Update: $previousVersion → $currentVersion';
    return 'Keine Änderung';
  }
}
