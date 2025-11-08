// =============================================
// GROWLOG - Database Recovery
// Handles database corruption and recovery
// =============================================

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../utils/app_logger.dart';

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

      AppLogger.info('DatabaseRecovery', 'Corrupted database backed up to: $backupPath');
      return true;
    } catch (e) {
      AppLogger.error('DatabaseRecovery', 'Failed to backup corrupted database', e);
      return false;
    }
  }

  /// Delete corrupted database and start fresh
  static Future<bool> deleteCorruptedDatabase(String dbPath) async {
    try {
      // ✅ CRITICAL FIX: Verify backup exists before deleting original
      final backupCreated = await backupCorruptedDatabase(dbPath);

      if (!backupCreated) {
        AppLogger.error('DatabaseRecovery', '❌ Backup creation failed - REFUSING to delete original DB!');
        return false; // Do NOT delete if backup failed
      }

      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.info('DatabaseRecovery', 'Corrupted database deleted (backup exists)');
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
      AppLogger.error('DatabaseRecovery', 'Failed to delete corrupted database', e);
      return false;
    }
  }

  /// Full recovery process
  static Future<DatabaseRecoveryResult> performRecovery(String dbPath) async {
    AppLogger.warning('DatabaseRecovery', '🔧 Starting database recovery process...');

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

    // Step 3: Backup and delete corrupted database
    AppLogger.warning('DatabaseRecovery', 'Step 2: Repair failed, creating fresh database...');
    final deleted = await deleteCorruptedDatabase(dbPath);

    if (deleted) {
      AppLogger.info('DatabaseRecovery', '✅ Fresh database will be created');
      return DatabaseRecoveryResult.recreated(
        'Corrupted database removed. A fresh database will be created. '
        'Note: Previous data may be lost. Check backups if available.',
      );
    } else {
      AppLogger.error('DatabaseRecovery', '❌ Recovery failed completely');
      return DatabaseRecoveryResult.failed('Could not recover database');
    }
  }

  /// Export database to JSON (emergency backup)
  static Future<String?> exportToJSON(Database db) async {
    try {
      // This would export all tables to JSON
      // Implementation would be similar to BackupService
      AppLogger.info('DatabaseRecovery', 'Emergency JSON export not yet implemented');
      return null;
    } catch (e) {
      AppLogger.error('DatabaseRecovery', 'JSON export failed', e);
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

enum DatabaseRecoveryStatus {
  success,
  recreated,
  failed,
}
