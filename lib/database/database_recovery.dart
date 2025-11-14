// =============================================
// GROWLOG - Database Recovery
// Handles database corruption and recovery
// =============================================

import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/app_version.dart';
import 'package:growlog_app/config/backup_config.dart';

class DatabaseRecovery {
  /// Check if database is corrupted
  static Future<bool> isDatabaseCorrupted(String dbPath) async {
    try {
      final db = await openDatabase(dbPath, readOnly: true);

      // Try a simple query
      await db.rawQuery('PRAGMA integrity_check');

      await db.close();
      return false;
    } catch (e) {
      AppLogger.error('DatabaseRecovery', 'Database appears corrupted', e);
      return true;
    }
  }

  /// Attempt to repair database
  static Future<bool> attemptRepair(String dbPath) async {
    try {
      AppLogger.info('DatabaseRecovery', 'Attempting database repair...');

      final db = await openDatabase(dbPath);

      // Try PRAGMA commands to repair
      await db.execute('PRAGMA integrity_check');
      await db.execute('VACUUM');
      await db.execute('REINDEX');

      await db.close();

      AppLogger.info('DatabaseRecovery', '✅ Database repaired successfully');
      return true;
    } catch (e) {
      AppLogger.error('DatabaseRecovery', 'Database repair failed', e);
      return false;
    }
  }

  /// Create backup of corrupted database
  static Future<bool> backupCorruptedDatabase(String dbPath) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) {
        return false;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '$dbPath.corrupted.$timestamp';

      await file.copy(backupPath);

      AppLogger.info(
        'DatabaseRecovery',
        'Corrupted database backed up to: $backupPath',
      );
      return true;
    } catch (e) {
      AppLogger.error(
        'DatabaseRecovery',
        'Failed to backup corrupted database',
        e,
      );
      return false;
    }
  }

  /// Delete corrupted database and start fresh
  static Future<bool> deleteCorruptedDatabase(String dbPath) async {
    try {
      // ✅ CRITICAL FIX: Verify backup exists before deleting original
      final backupCreated = await backupCorruptedDatabase(dbPath);

      if (!backupCreated) {
        AppLogger.error(
          'DatabaseRecovery',
          '❌ Backup creation failed - REFUSING to delete original DB!',
        );
        return false; // Do NOT delete if backup failed
      }

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.info(
          'DatabaseRecovery',
          'Corrupted database deleted (backup exists)',
        );
      }

      // Also delete any journal/wal files
      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }

      final shmFile = File('$dbPath-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      return true;
    } catch (e) {
      AppLogger.error(
        'DatabaseRecovery',
        'Failed to delete corrupted database',
        e,
      );
      return false;
    }
  }

  /// Full recovery process
  static Future<DatabaseRecoveryResult> performRecovery(String dbPath) async {
    AppLogger.warning(
      'DatabaseRecovery',
      '🔧 Starting database recovery process...',
    );

    // Step 1: Check if database is actually corrupted
    final isCorrupted = await isDatabaseCorrupted(dbPath);
    if (!isCorrupted) {
      AppLogger.info('DatabaseRecovery', '✅ Database is healthy');
      return DatabaseRecoveryResult.success('Database is healthy');
    }

    // Step 2: Try to repair
    AppLogger.info('DatabaseRecovery', 'Step 1: Attempting repair...');
    final repaired = await attemptRepair(dbPath);
    if (repaired) {
      // Verify repair worked
      final stillCorrupted = await isDatabaseCorrupted(dbPath);
      if (!stillCorrupted) {
        AppLogger.info('DatabaseRecovery', '✅ Database repaired successfully');
        return DatabaseRecoveryResult.success('Database repaired');
      }
    }

    // Step 3: Emergency JSON export (last resort before deletion)
    AppLogger.warning(
      'DatabaseRecovery',
      'Step 2: Repair failed, attempting emergency data export...',
    );
    String? emergencyBackupPath;

    try {
      // Try to open the corrupted database and export what we can
      final corruptedDb = await openDatabase(dbPath, readOnly: true);
      emergencyBackupPath = await exportToJSON(corruptedDb);
      await corruptedDb.close();
    } catch (e) {
      AppLogger.error(
        'DatabaseRecovery',
        'Emergency export failed - DB cannot be opened',
        e,
      );
      // ✅ CRITICAL FIX: Do NOT delete without backup!
      // If we can't even open the DB, try filesystem backup
      try {
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          final backupDir = Directory('/storage/emulated/0/Download/Plantry Backups/Emergency');
          if (!await backupDir.exists()) {
            await backupDir.create(recursive: true);
          }
          final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
          final backupPath = '${backupDir.path}/corrupted_db_$timestamp.db';
          await dbFile.copy(backupPath);
          emergencyBackupPath = backupPath;
          AppLogger.info('DatabaseRecovery', '✅ Filesystem backup created: $backupPath');
        }
      } catch (backupError) {
        AppLogger.error(
          'DatabaseRecovery',
          '❌ Filesystem backup also failed',
          backupError,
        );
        // REFUSE to delete without any backup!
        return DatabaseRecoveryResult.failed(
          'Cannot create emergency backup. Database cannot be safely deleted.\n\n'
          'Your data is preserved but the app cannot start.\n'
          'Please contact support or manually backup the database file.',
        );
      }
    }

    // Step 4: Backup and delete corrupted database
    AppLogger.warning('DatabaseRecovery', 'Step 3: Creating fresh database...');

    // ✅ SAFETY CHECK: Verify we have a backup before deletion
    if (emergencyBackupPath == null) {
      AppLogger.error(
        'DatabaseRecovery',
        '🛑 REFUSING to delete database without emergency backup',
      );
      return DatabaseRecoveryResult.failed(
        'Emergency backup failed. Cannot safely delete database.\n\n'
        'Your data is preserved. Please check storage permissions.',
      );
    }

    final deleted = await deleteCorruptedDatabase(dbPath);

    if (deleted) {
      // We know emergencyBackupPath is not null due to safety check above
      final message = 'Corrupted database removed. A fresh database will be created.'
          '\n\n✅ Emergency backup saved to:\n$emergencyBackupPath\n\n'
          'You can manually recover data from this JSON file if needed.';

      AppLogger.info(
        'DatabaseRecovery',
        '✅ Emergency backup available at: $emergencyBackupPath',
      );
      AppLogger.info('DatabaseRecovery', '✅ Fresh database will be created');
      return DatabaseRecoveryResult.recreated(message);
    } else {
      AppLogger.error('DatabaseRecovery', '❌ Recovery failed completely');
      return DatabaseRecoveryResult.failed('Could not recover database');
    }
  }

  /// Export database to JSON (emergency backup before deletion)
  ///
  /// This is the "last resort" emergency backup that saves data from a corrupted
  /// database to a JSON file before it gets deleted. This gives users a chance
  /// to manually recover data if the corruption only affects structure, not content.
  ///
  /// Returns the path to the exported JSON file, or null if export failed.
  static Future<String?> exportToJSON(Database db) async {
    try {
      AppLogger.warning(
        'DatabaseRecovery',
        '🚨 Attempting emergency JSON export...',
      );

      // Create emergency backup directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final emergencyDir = Directory(
        path.join(documentsDir.path, 'growlog_emergency_backups'),
      );

      if (!await emergencyDir.exists()) {
        await emergencyDir.create(recursive: true);
      }

      // Build JSON backup structure
      final Map<String, dynamic> emergencyBackup = {
        'version': BackupConfig.backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': AppVersion.version,
        'exportType': 'emergency_recovery',
        'reason': 'Database corruption detected',
        'data': {},
      };

      // Try to export each table (even from corrupted DB)
      const tables = BackupConfig.exportTables;
      int successfulTables = 0;
      int failedTables = 0;

      for (final table in tables) {
        try {
          final data = await db.query(table);
          // ✅ CRITICAL FIX: Cast to avoid dynamic call error
          (emergencyBackup['data'] as Map<String, dynamic>)[table] = data;
          successfulTables++;
          AppLogger.debug(
            'DatabaseRecovery',
            'Emergency export: $table (${data.length} rows)',
          );
        } catch (e) {
          // Table might be corrupted or inaccessible
          failedTables++;
          // ✅ CRITICAL FIX: Cast to avoid dynamic call error
          (emergencyBackup['data'] as Map<String, dynamic>)[table] = [];
          AppLogger.warning(
            'DatabaseRecovery',
            'Emergency export failed for table: $table',
            e,
          );
        }
      }

      // Save JSON file
      final jsonFile = File(
        path.join(emergencyDir.path, 'emergency_backup_$timestamp.json'),
      );
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(emergencyBackup),
      );

      AppLogger.info(
        'DatabaseRecovery',
        '✅ Emergency JSON export complete: $successfulTables/${tables.length} tables saved, $failedTables failed',
      );
      AppLogger.info(
        'DatabaseRecovery',
        'Emergency backup saved to: ${jsonFile.path}',
      );

      return jsonFile.path;
    } catch (e) {
      AppLogger.error('DatabaseRecovery', 'Emergency JSON export failed', e);
      return null;
    }
  }
}

/// Result of database recovery operation
class DatabaseRecoveryResult {
  final DatabaseRecoveryStatus status;
  final String message;

  const DatabaseRecoveryResult._(this.status, this.message);

  factory DatabaseRecoveryResult.success(String message) =>
      DatabaseRecoveryResult._(DatabaseRecoveryStatus.success, message);

  factory DatabaseRecoveryResult.recreated(String message) =>
      DatabaseRecoveryResult._(DatabaseRecoveryStatus.recreated, message);

  factory DatabaseRecoveryResult.failed(String message) =>
      DatabaseRecoveryResult._(DatabaseRecoveryStatus.failed, message);

  bool get isSuccess => status == DatabaseRecoveryStatus.success;
  bool get wasRecreated => status == DatabaseRecoveryStatus.recreated;
  bool get hasFailed => status == DatabaseRecoveryStatus.failed;
}

enum DatabaseRecoveryStatus { success, recreated, failed }
