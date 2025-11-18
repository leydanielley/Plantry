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
  /// Check if database appears empty or corrupted (sign of failed migration)
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

      final isEmpty = (plantsCount ?? 0) == 0 &&
          (logsCount ?? 0) == 0 &&
          (growsCount ?? 0) == 0;

      if (isEmpty) {
        AppLogger.warning(
          'AutoRecoveryHelper',
          '⚠️ Database appears empty: plants=$plantsCount, logs=$logsCount, grows=$growsCount',
        );
      }

      // Database is considered "empty" if all core tables are empty
      return isEmpty;
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

  /// Check if database has missing critical columns
  /// (sign of incomplete migration)
  static Future<bool> hasMissingColumns(Database db) async {
    try {
      // Check plants table for v18+ columns
      final plantsColumns = await db.rawQuery('PRAGMA table_info(plants)');
      final columnNames = plantsColumns.map((c) => c['name'] as String).toSet();

      final requiredColumns = {
        'breeder',
        'feminized',
        'phase',
        'veg_date',
        'bloom_date',
        'harvest_date',
      };

      final missing = requiredColumns.difference(columnNames);

      if (missing.isNotEmpty) {
        AppLogger.warning(
          'AutoRecoveryHelper',
          '⚠️ Missing columns in plants table: ${missing.join(", ")}',
        );
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.warning(
        'AutoRecoveryHelper',
        'Could not check for missing columns',
        e,
      );
      return false;
    }
  }

  /// Find the most recent pre-migration backup
  /// Searches multiple locations for maximum recovery chances
  static Future<String?> findLatestBackup() async {
    try {
      final List<File> allBackupFiles = [];

      final documentsDir = await getApplicationDocumentsDirectory();

      // Location 1: Regular backups directory
      final backupsDir = Directory(
        path.join(documentsDir.path, 'plantry_backups'),
      );

      if (await backupsDir.exists()) {
        final files = await backupsDir
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.zip'))
            .cast<File>()
            .toList();
        allBackupFiles.addAll(files);
        AppLogger.info(
          'AutoRecoveryHelper',
          'Found ${files.length} backup(s) in plantry_backups',
        );
      }

      // Location 2: Emergency backups directory
      final emergencyDir = Directory(
        path.join(documentsDir.path, 'growlog_emergency_backups'),
      );

      if (await emergencyDir.exists()) {
        final files = await emergencyDir
            .list()
            .where((entity) =>
                entity is File &&
                (entity.path.endsWith('.zip') || entity.path.endsWith('.json')))
            .cast<File>()
            .toList();
        allBackupFiles.addAll(files);
        AppLogger.info(
          'AutoRecoveryHelper',
          'Found ${files.length} emergency backup(s)',
        );
      }

      // Location 3: Download folder (user might have manual backups there)
      try {
        final downloadDir = Directory('/storage/emulated/0/Download/Plantry Backups');
        if (await downloadDir.exists()) {
          final files = await downloadDir
              .list()
              .where((entity) =>
                  entity is File &&
                  (entity.path.endsWith('.zip') ||
                      entity.path.endsWith('.json')))
              .cast<File>()
              .toList();
          allBackupFiles.addAll(files);
          AppLogger.info(
            'AutoRecoveryHelper',
            'Found ${files.length} backup(s) in Download folder',
          );
        }
      } catch (e) {
        // Ignore permission errors for Download folder
        AppLogger.debug(
          'AutoRecoveryHelper',
          'Could not access Download folder: $e',
        );
      }

      if (allBackupFiles.isEmpty) {
        AppLogger.info('AutoRecoveryHelper', 'No backup files found anywhere');
        return null;
      }

      // Sort by modification time (newest first)
      allBackupFiles.sort((a, b) {
        final aModified = a.statSync().modified;
        final bModified = b.statSync().modified;
        return bModified.compareTo(aModified);
      });

      final latestBackup = allBackupFiles.first.path;
      AppLogger.info(
        'AutoRecoveryHelper',
        'Found latest backup: ${path.basename(latestBackup)}',
      );
      AppLogger.info(
        'AutoRecoveryHelper',
        'Total backups found: ${allBackupFiles.length}',
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
  ///
  /// ✅ FIXED: Only triggers when CURRENT migration failed
  /// (NOT when historical migrations failed or on fresh installs)
  static Future<RecoveryInfo> shouldOfferRecovery(Database db) async {
    try {
      // Check 1: Was there a CURRENT migration failure?
      // ✅ FIX: Now only checks current migration status (not history)
      final migrationFailed = await VersionManager.hasRecentMigrationFailure();

      // Check 2: Is this a fresh install?
      // ✅ FIX: Don't trigger recovery on fresh installs
      final isFirstLaunch = await VersionManager.isFirstLaunch();

      // Check 3: Is the database empty?
      final dbEmpty = await isDatabaseEmpty(db);

      // Check 4: Are there missing columns?
      final missingCols = await hasMissingColumns(db);

      // Check 5: Is there a recent backup available?
      final backupPath = await findLatestBackup();

      // ✅ FIX: Updated logic to prevent false positives
      // Only offer recovery if:
      // 1. Current migration failed (not historical), OR
      // 2. DB is empty AND it's NOT a fresh install AND backup exists, OR
      // 3. Missing columns AND backup exists
      final shouldRecover = migrationFailed ||
          (dbEmpty && !isFirstLaunch && backupPath != null) ||
          (missingCols && backupPath != null);

      if (shouldRecover) {
        AppLogger.warning(
          'AutoRecoveryHelper',
          '⚠️ Recovery recommended:',
          'Migration failed: $migrationFailed, '
              'DB empty: $dbEmpty, '
              'Fresh install: $isFirstLaunch, '
              'Missing columns: $missingCols, '
              'Backup available: ${backupPath != null}',
        );
      } else {
        AppLogger.info(
          'AutoRecoveryHelper',
          '✅ No recovery needed:',
          'Migration failed: $migrationFailed, '
              'DB empty: $dbEmpty, '
              'Fresh install: $isFirstLaunch, '
              'Missing columns: $missingCols',
        );
      }

      return RecoveryInfo(
        shouldRecover: shouldRecover,
        migrationFailed: migrationFailed,
        databaseEmpty: dbEmpty,
        missingColumns: missingCols,
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
        missingColumns: false,
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
  final bool missingColumns;
  final bool backupAvailable;
  final String? backupPath;

  RecoveryInfo({
    required this.shouldRecover,
    required this.migrationFailed,
    required this.databaseEmpty,
    required this.missingColumns,
    required this.backupAvailable,
    required this.backupPath,
  });

  String get reasonMessage {
    final reasons = <String>[];
    if (migrationFailed) reasons.add('Migration failed');
    if (databaseEmpty) reasons.add('Database appears empty');
    if (missingColumns) reasons.add('Missing critical columns');
    if (!backupAvailable) reasons.add('No backup available');

    return reasons.join(', ');
  }
}
