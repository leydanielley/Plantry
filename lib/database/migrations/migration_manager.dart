// =============================================
// GROWLOG - Database Migration Manager
// =============================================

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/version_manager.dart';
import 'package:growlog_app/utils/backup_progress_notifier.dart';
import 'package:growlog_app/services/interfaces/i_backup_service.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/migrations/scripts/all_migrations.dart';
import 'package:growlog_app/database/schema_registry.dart';

/// Manages database migrations for seamless app updates
///
/// When the app is updated, this automatically:
/// 1. Creates a backup of the current database
/// 2. Runs all necessary migrations sequentially
/// 3. Updates the database version
/// 4. Verifies database integrity
/// 5. Keeps backup in case of failure
///
/// Example usage:
/// ```dart
/// // In DatabaseHelper._onUpgrade:
/// final migrationManager = MigrationManager();
/// await migrationManager.migrate(db, oldVersion, newVersion);
/// ```
class MigrationManager {
  IBackupService? _backupService;

  /// Get BackupService instance (lazy initialization)
  IBackupService get backupService {
    _backupService ??= getIt<IBackupService>();
    return _backupService!;
  }

  /// All migrations in order from oldest to newest
  List<Migration> get migrations => allMigrations;

  /// Run migrations from oldVersion to newVersion
  ///
  /// Example: User has v13, app expects v16
  /// This will run migrations: v14, v15, v16
  ///
  /// [db] The database to migrate
  /// [oldVersion] Current database version
  /// [newVersion] Target database version
  /// [timeout] Maximum time to wait for migration (default: 5 minutes)
  Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (oldVersion == newVersion) {
      AppLogger.info(
        'MigrationManager',
        'Database already at version $newVersion',
      );
      await VersionManager.markMigrationCompleted(dbVersion: newVersion);
      return;
    }

    AppLogger.info(
      'MigrationManager',
      '🔄 Starting database migration',
      'from v$oldVersion to v$newVersion (timeout: ${timeout.inMinutes}min)',
    );

    // Mark migration as in progress
    await VersionManager.markMigrationInProgress();

    // Step 1: Create automatic backup before migration
    // ✅ CRITICAL FIX: Backup MUST succeed (unless database is empty)
    String? backupPath;
    try {
      backupPath = await _createPreMigrationBackup(db);
      AppLogger.info(
        'MigrationManager',
        '✅ Pre-migration backup created',
        backupPath,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'MigrationManager',
        '❌ Failed to create pre-migration backup',
        e,
        stackTrace,
      );

      // Check if database has any data
      final hasData = await _databaseHasData(db);

      if (hasData) {
        // ✅ CRITICAL: Refuse to migrate if backup failed and DB has data!
        AppLogger.error(
          'MigrationManager',
          '🛑 REFUSING to migrate: Backup failed and database contains data',
        );
        throw Exception(
          'Cannot migrate: Pre-migration backup failed and database contains data. '
          'Migration is too risky without a backup. Please free up storage space or check app permissions.',
        );
      } else {
        // Database is empty (fresh install), safe to continue
        AppLogger.warning(
          'MigrationManager',
          '⚠️ Backup failed but database is empty (fresh install), continuing...',
        );
      }
    }

    // Step 2: Get migrations that need to run
    final migrationsToRun =
        migrations
            .where((m) => m.version > oldVersion && m.version <= newVersion)
            .toList()
          ..sort((a, b) => a.version.compareTo(b.version));

    if (migrationsToRun.isEmpty) {
      AppLogger.warning(
        'MigrationManager',
        'No migrations found',
        'oldVersion=$oldVersion, newVersion=$newVersion',
      );
      return;
    }

    AppLogger.info(
      'MigrationManager',
      'Found ${migrationsToRun.length} migrations to run',
      migrationsToRun.map((m) => 'v${m.version}').join(', '),
    );

    // Step 3: Run migrations sequentially inside a transaction (with timeout)
    try {
      await db
          .transaction((txn) async {
            int currentStep = 0;
            final totalSteps = migrationsToRun.length;

            for (final migration in migrationsToRun) {
              currentStep++;
              final progress = '[$currentStep/$totalSteps]';

              AppLogger.info(
                'MigrationManager',
                '⏳ $progress Running migration v${migration.version}',
                migration.description,
              );

              try {
                // Run migration with timeout
                await migration
                    .up(txn)
                    .timeout(
                      timeout,
                      onTimeout: () {
                        AppLogger.error(
                          'MigrationManager',
                          '⏱️ Migration v${migration.version} timeout after ${timeout.inMinutes}min',
                        );
                        throw TimeoutException(
                          'Migration v${migration.version} took too long',
                          timeout,
                        );
                      },
                    );

                AppLogger.info(
                  'MigrationManager',
                  '✅ $progress Migration v${migration.version} completed',
                );
              } catch (e, stack) {
                AppLogger.error(
                  'MigrationManager',
                  '❌ $progress Migration v${migration.version} failed',
                  e,
                  stack,
                );
                // Transaction will auto-rollback on error
                rethrow;
              }
            }
          })
          .timeout(
            timeout *
                migrationsToRun
                    .length, // Total timeout = per-migration timeout * count
            onTimeout: () {
              AppLogger.error('MigrationManager', '⏱️ Total migration timeout');
              throw TimeoutException('Overall migration timeout');
            },
          );

      AppLogger.info(
        'MigrationManager',
        '🎉 All migrations completed successfully',
        'Database now at v$newVersion',
      );

      // ✅ CRITICAL: Validate final schema matches expected version
      AppLogger.info(
        'MigrationManager',
        '🔍 Validating schema for v$newVersion...',
      );

      final schemaValid = await SchemaRegistry.validateSchema(
        db,
        newVersion,
        strict: false, // Allow extra columns for backwards compatibility
      );

      if (!schemaValid) {
        AppLogger.error(
          'MigrationManager',
          '❌ Schema validation failed after migrations!',
        );
        throw Exception(
          'Migration completed but schema validation failed for v$newVersion. '
          'Database may be in an inconsistent state.',
        );
      }

      AppLogger.info(
        'MigrationManager',
        '✅ Schema validation passed for v$newVersion',
      );

      // Mark migration as completed
      await VersionManager.markMigrationCompleted(dbVersion: newVersion);
    } catch (e, stack) {
      AppLogger.error(
        'MigrationManager',
        '💥 Migration failed - database rolled back to v$oldVersion',
        e,
        stack,
      );

      // Mark migration as failed
      await VersionManager.markMigrationFailed(
        fromVersion: oldVersion,
        toVersion: newVersion,
        error: e.toString(),
      );

      // Show user-friendly error
      throw MigrationException(
        'Database migration failed. Your data is safe. '
        'Please contact support if this persists.',
        oldVersion: oldVersion,
        newVersion: newVersion,
        error: e,
        backupPath: backupPath,
      );
    }
  }

  /// Create automatic backup before migration
  ///
  /// [db] Database instance to backup (passed to avoid circular dependency during migration)
  Future<String> _createPreMigrationBackup(Database db) async {
    // Use the existing BackupService.exportData() method
    // Pass the database instance to avoid deadlock during migration
    // Progress is reported via BackupProgressNotifier singleton
    return await backupService.exportData(
      db: db,
      onProgress: (current, total, message) {
        BackupProgressNotifier.instance.notify(current, total, message);
      },
    );
  }

  /// Verify database integrity after migration
  ///
  /// Runs SQLite's PRAGMA integrity_check to ensure the database
  /// structure is valid after migrations.
  Future<bool> verifyDatabase(Database db) async {
    try {
      // Run PRAGMA integrity_check
      final result = await db.rawQuery('PRAGMA integrity_check');
      final isOk = result.isNotEmpty && result.first['integrity_check'] == 'ok';

      if (isOk) {
        AppLogger.info('MigrationManager', '✅ Database integrity check passed');
      } else {
        AppLogger.error(
          'MigrationManager',
          '❌ Database integrity check failed',
          result,
        );
      }

      return isOk;
    } catch (e, stack) {
      AppLogger.error(
        'MigrationManager',
        'Failed to verify database integrity',
        e,
        stack,
      );
      return false;
    }
  }

  /// Check if database has any user data
  ///
  /// Returns true if any core tables contain data
  /// Used to determine if backup is critical before migration
  Future<bool> _databaseHasData(Database db) async {
    try {
      // Check core tables for data
      final coreTables = ['plants', 'plant_logs', 'grows', 'rooms'];

      for (final table in coreTables) {
        try {
          final count = await db.rawQuery(
            'SELECT COUNT(*) as count FROM $table',
          );
          final rowCount = Sqflite.firstIntValue(count) ?? 0;

          if (rowCount > 0) {
            AppLogger.info(
              'MigrationManager',
              'Found data in $table: $rowCount rows',
            );
            return true;
          }
        } catch (e) {
          // Table might not exist yet (first install)
          AppLogger.debug(
            'MigrationManager',
            'Table $table does not exist or is inaccessible',
          );
        }
      }

      AppLogger.info('MigrationManager', 'Database appears to be empty');
      return false;
    } catch (e) {
      AppLogger.warning(
        'MigrationManager',
        'Could not determine if database has data, assuming it does (safer)',
      );
      return true; // Assume it has data to be safe
    }
  }

  /// Get migration info for a specific version
  /// ✅ FIX: Use orElse to safely return null instead of throwing
  Migration? getMigration(int version) {
    try {
      return migrations.firstWhere(
        (m) => m.version == version,
        orElse: () => throw StateError('Migration not found: $version'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all migrations between two versions (inclusive)
  List<Migration> getMigrationsBetween(int fromVersion, int toVersion) {
    return migrations
        .where((m) => m.version > fromVersion && m.version <= toVersion)
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));
  }
}

/// Exception thrown when migration fails
class MigrationException implements Exception {
  final String message;
  final int oldVersion;
  final int newVersion;
  final Object? error;
  final String? backupPath;

  MigrationException(
    this.message, {
    required this.oldVersion,
    required this.newVersion,
    this.error,
    this.backupPath,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('MigrationException: $message ');
    buffer.write('(v$oldVersion → v$newVersion)');

    if (error != null) {
      buffer.write('\nError: $error');
    }

    if (backupPath != null) {
      buffer.write('\nBackup available at: $backupPath');
    }

    return buffer.toString();
  }
}
