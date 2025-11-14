// =============================================
// GROWLOG - Automatic Recovery Helper
// Detects failed migrations and offers automatic backup restoration
// =============================================

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/version_manager.dart';
import 'package:growlog_app/services/interfaces/i_backup_service.dart';
import 'package:growlog_app/di/service_locator.dart';

/// Automatic recovery system that detects failed migrations
/// and offers to restore from pre-migration backups
class AutoRecoveryHelper {
  /// Check if database appears empty (sign of failed migration)
  static Future<bool> isDatabaseEmpty(Database db) async {
    try {
      // Check if critical tables have data
      final plantsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM plants WHERE archived = 0'),
      );
      final logsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM plant_logs WHERE archived = 0'),
      );
      final growsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM grows WHERE archived = 0'),
      );

      // Database is considered "empty" if all core tables are empty
      return (plantsCount ?? 0) == 0 &&
          (logsCount ?? 0) == 0 &&
          (growsCount ?? 0) == 0;
    } catch (e) {
      AppLogger.warning(
        'AutoRecoveryHelper',
        'Could not check if database is empty',
        e,
      );
      // If we can't check, assume it's not empty (safe default)
      return false;
    }
  }

  /// Find the most recent pre-migration backup
  static Future<String?> findLatestBackup() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupsDir = Directory(
        path.join(documentsDir.path, 'plantry_backups'),
      );

      if (!await backupsDir.exists()) {
        AppLogger.info('AutoRecoveryHelper', 'No backups directory found');
        return null;
      }

      // Get all .zip files in backups directory
      final files = await backupsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.zip'))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        AppLogger.info('AutoRecoveryHelper', 'No backup files found');
        return null;
      }

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aModified = a.statSync().modified;
        final bModified = b.statSync().modified;
        return bModified.compareTo(aModified);
      });

      final latestBackup = files.first.path;
      AppLogger.info(
        'AutoRecoveryHelper',
        'Found latest backup: ${path.basename(latestBackup)}',
      );

      return latestBackup;
    } catch (e) {
      AppLogger.error('AutoRecoveryHelper', 'Failed to find latest backup', e);
      return null;
    }
  }

  /// Check if we should offer auto-recovery
  ///
  /// Returns recovery info with backup path if recovery is recommended
  static Future<RecoveryInfo> shouldOfferRecovery(Database db) async {
    try {
      // Check 1: Was there a recent migration failure?
      final migrationFailed = await VersionManager.hasRecentMigrationFailure();

      // Check 2: Is the database empty?
      final dbEmpty = await isDatabaseEmpty(db);

      // Check 3: Is there a recent backup available?
      final backupPath = await findLatestBackup();

      final shouldRecover = migrationFailed || (dbEmpty && backupPath != null);

      if (shouldRecover) {
        AppLogger.warning(
          'AutoRecoveryHelper',
          '⚠️ Recovery recommended:',
          'Migration failed: $migrationFailed, DB empty: $dbEmpty, Backup available: ${backupPath != null}',
        );
      }

      return RecoveryInfo(
        shouldRecover: shouldRecover,
        migrationFailed: migrationFailed,
        databaseEmpty: dbEmpty,
        backupAvailable: backupPath != null,
        backupPath: backupPath,
      );
    } catch (e) {
      AppLogger.error(
        'AutoRecoveryHelper',
        'Error checking recovery status',
        e,
      );
      return RecoveryInfo(
        shouldRecover: false,
        migrationFailed: false,
        databaseEmpty: false,
        backupAvailable: false,
        backupPath: null,
      );
    }
  }

  /// Perform automatic recovery by restoring latest backup
  static Future<bool> performAutoRecovery(String backupPath) async {
    try {
      AppLogger.info(
        'AutoRecoveryHelper',
        '🔄 Starting automatic recovery...',
        'Backup: ${path.basename(backupPath)}',
      );

      final backupService = getIt<IBackupService>();

      // Import the backup
      await backupService.importData(backupPath);

      AppLogger.info('AutoRecoveryHelper', '✅ Automatic recovery successful!');

      // Clear migration failure flag
      await VersionManager.clearFailedMigrations();

      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'AutoRecoveryHelper',
        '❌ Automatic recovery failed',
        e,
        stackTrace,
      );
      return false;
    }
  }
}

/// Information about recovery status
class RecoveryInfo {
  final bool shouldRecover;
  final bool migrationFailed;
  final bool databaseEmpty;
  final bool backupAvailable;
  final String? backupPath;

  RecoveryInfo({
    required this.shouldRecover,
    required this.migrationFailed,
    required this.databaseEmpty,
    required this.backupAvailable,
    required this.backupPath,
  });

  String get reasonMessage {
    final reasons = <String>[];
    if (migrationFailed) reasons.add('Migration failed');
    if (databaseEmpty) reasons.add('Database appears empty');
    if (!backupAvailable) reasons.add('No backup available');

    return reasons.join(', ');
  }
}
