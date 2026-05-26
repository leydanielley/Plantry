// =============================================
// GROWLOG - Database Migration Manager
// =============================================

import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/version_manager.dart';
import 'package:growlog_app/utils/backup_progress_notifier.dart';
import 'package:growlog_app/services/interfaces/i_backup_service.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/migrations/scripts/all_migrations.dart';
import 'package:growlog_app/database/schema_registry.dart';

// =============================================
// STUCK-DB RECOVERY TYPES (P2 / Issue #12)
// =============================================

/// Describes the state of the database at app startup.
enum DbStartupState {
  /// DB is on expected schema, no intervention needed.
  healthy,

  /// Migration must run normally (oldVersion < newVersion, no prior stuck).
  migrationNeeded,

  /// in_progress or timeout flag found — re-run needed.
  stuckInProgress,

  /// Schema drift: user_version matches but tables/columns are missing.
  schemaDrift,

  /// Recovery completely failed — read-only + dialog required.
  unrecoverable,
}

/// Result of the startup diagnosis.
class DbStartupDiagnosis {
  final DbStartupState state;

  /// PRAGMA user_version from SQLite.
  final int actualVersion;

  /// kCurrentDbVersion from DatabaseHelper.
  final int expectedVersion;

  /// Log detail for support, may be null for healthy state.
  final String? details;

  const DbStartupDiagnosis({
    required this.state,
    required this.actualVersion,
    required this.expectedVersion,
    this.details,
  });

  @override
  String toString() =>
      'DbStartupDiagnosis(state: $state, actual: $actualVersion, '
      'expected: $expectedVersion, details: $details)';
}

/// Sealed-class result of a recovery attempt.
sealed class RecoveryResult {
  const RecoveryResult();
}

class RecoverySuccess extends RecoveryResult {
  final int recoveredToVersion;
  const RecoverySuccess({required this.recoveredToVersion});
}

class RecoveryFailed extends RecoveryResult {
  final String reason;
  final bool dataExportAvailable;
  final String? exportPath;
  const RecoveryFailed({
    required this.reason,
    required this.dataExportAvailable,
    this.exportPath,
  });
}

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
  /// [timeout] Maximum time to wait for migration (default: 10 minutes, to handle large databases)
  /// Per-migration timeout — each individual migration script gets this budget.
  /// Large DBs (100k+ logs) may need the full 10 min for a single ALTER TABLE.
  static const Duration _perMigrationTimeout = Duration(minutes: 10);

  /// Hard cap on the total migration run regardless of migration count.
  /// Prevents an absurdly long wait when upgrading across many versions.
  static const Duration _maxTotalTimeout = Duration(minutes: 60);

  Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion, {
    Duration timeout = const Duration(minutes: 10),
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

    // Pre-flight check: verify schema definition exists for target version.
    // Ab minRequiredSchemaVersion ist eine SchemaDefinition Pflicht — sonst
    // läuft die Migration ohne Sicherheitsnetz und ein Bug bleibt unerkannt
    // bis die App auf der korrupten DB crasht (Bug H2 aus dem Review).
    final hasSchemaDefinition = SchemaRegistry.getSchema(newVersion) != null;
    if (!hasSchemaDefinition) {
      if (newVersion >= SchemaRegistry.minRequiredSchemaVersion) {
        AppLogger.error(
          'MigrationManager',
          '❌ No schema definition for v$newVersion — refuse to migrate',
          'Add SchemaRegistry.schemaV$newVersion before shipping.',
        );
        throw MigrationException(
          'Migration aborted: SchemaRegistry has no definition for v$newVersion. '
          'Add it to lib/database/schema_registry.dart before deploying.',
          oldVersion: oldVersion,
          newVersion: newVersion,
          error: 'Missing schema definition',
        );
      }
      AppLogger.warning(
        'MigrationManager',
        '⚠️ No schema definition for v$newVersion (legacy gap v21-v35)',
        'Validation will be skipped — accepted only for historical migrations.',
      );
    }

    // Step 1: Create automatic backup before migration.
    // Backup must succeed unless the database is empty (fresh install).
    String? backupPath;
    try {
      backupPath = await _createPreMigrationBackup(db);
      AppLogger.info(
        'MigrationManager',
        '✅ Pre-migration backup created',
        backupPath,
      );

      final isValid = await _verifyBackup(backupPath);
      if (!isValid) {
        throw Exception(
          'Backup verification failed! File exists but appears corrupted or incomplete.',
        );
      }
      AppLogger.info('MigrationManager', '✅ Backup verified successfully');
    } catch (e, stackTrace) {
      AppLogger.error(
        'MigrationManager',
        '❌ Failed to create pre-migration backup',
        e,
        stackTrace,
      );

      // Delete partial/corrupt backup file to avoid a future restore
      // mistaking it for a valid backup. Wenn DELETE fehlschlägt → loggen,
      // sonst landen verwaiste Half-Backups im Ordner und können später
      // einen Restore in einen unklaren State führen.
      if (backupPath != null) {
        try {
          final f = File(backupPath);
          if (await f.exists()) await f.delete();
        } catch (cleanupError) {
          AppLogger.warning(
            'MigrationManager',
            'Failed to delete corrupt pre-migration backup',
            cleanupError,
          );
        }
      }

      // Check if database has any data
      final hasData = await _databaseHasData(db);

      if (hasData) {
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

    // Step 3: Run migrations sequentially inside a transaction (with timeout).
    // Schema validation happens INSIDE the transaction so it can be rolled back on failure.
    try {
      await db
          .transaction((txn) async {
            int currentStep = 0;
            final totalSteps = migrationsToRun.length;

            // 3a. Run all migrations
            for (final migration in migrationsToRun) {
              currentStep++;
              final progress = '[$currentStep/$totalSteps]';

              AppLogger.info(
                'MigrationManager',
                '⏳ $progress Running migration v${migration.version}',
                migration.description,
              );

              try {
                // Run migration with per-migration timeout.
                // Using the class-level constant rather than the caller-supplied
                // timeout so every migration gets a predictable, uniform budget.
                await migration
                    .up(txn)
                    .timeout(
                      _perMigrationTimeout,
                      onTimeout: () {
                        AppLogger.error(
                          'MigrationManager',
                          '⏱️ Migration v${migration.version} timeout after ${_perMigrationTimeout.inMinutes}min',
                        );
                        throw TimeoutException(
                          'Migration v${migration.version} took too long',
                          _perMigrationTimeout,
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

            AppLogger.info(
              'MigrationManager',
              '🎉 All migrations completed successfully',
              'Database now at v$newVersion',
            );

            // 3b. Validate schema INSIDE transaction (before commit)
            if (hasSchemaDefinition) {
              AppLogger.info(
                'MigrationManager',
                '🔍 Validating schema for v$newVersion BEFORE commit...',
              );

              final schemaValid = await SchemaRegistry.validateSchema(
                txn,
                newVersion,
                strict:
                    false, // Allow extra columns for backwards compatibility
              );

              if (!schemaValid) {
                AppLogger.error(
                  'MigrationManager',
                  '❌ Schema validation failed! Transaction will rollback.',
                );
                throw MigrationException(
                  'Schema validation failed for v$newVersion. '
                  'Transaction has been rolled back. Database remains at v$oldVersion.',
                  oldVersion: oldVersion,
                  newVersion: newVersion,
                  error: 'Schema validation failed',
                );
              }

              AppLogger.info(
                'MigrationManager',
                '✅ Schema validation passed for v$newVersion',
              );
            } else {
              AppLogger.warning(
                'MigrationManager',
                '⚠️ Skipping schema validation for v$newVersion (no schema definition)',
              );
              AppLogger.warning(
                'MigrationManager',
                'Consider adding schema definition to SchemaRegistry for better validation.',
              );
            }

            // 3c. Mark migration as completed (only reached if validation passed)
            await VersionManager.markMigrationCompleted(dbVersion: newVersion);

            // Transaction commits here
          })
          .timeout(
            // Total budget = per-migration budget × count, capped at the hard max.
            // This ensures that upgrading across many placeholder versions
            // (e.g. v20 → v44) does not consume an unreasonable amount of time
            // while still giving each real migration its full per-step budget.
            () {
              final computed = _perMigrationTimeout * migrationsToRun.length;
              return computed.inMilliseconds < _maxTotalTimeout.inMilliseconds
                  ? computed
                  : _maxTotalTimeout;
            }(),
            onTimeout: () {
              AppLogger.error('MigrationManager', '⏱️ Total migration timeout');
              throw TimeoutException('Overall migration timeout');
            },
          );

      AppLogger.info(
        'MigrationManager',
        '✅ Migration transaction committed successfully',
      );
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

  /// Verify backup file is valid and complete
  ///
  /// Checks:
  /// 1. File exists
  /// 2. File size > 0
  /// 3. ZIP structure is valid
  /// 4. data.json exists in ZIP
  ///
  /// Returns true if backup is valid, false otherwise
  Future<bool> _verifyBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);

      // Check 1: File exists
      if (!await backupFile.exists()) {
        AppLogger.error(
          'MigrationManager',
          'Backup file does not exist',
          backupPath,
        );
        return false;
      }

      // Check 2: File size > 0
      final fileSize = await backupFile.length();
      if (fileSize == 0) {
        AppLogger.error('MigrationManager', 'Backup file is empty (0 bytes)');
        return false;
      }

      // Check 3: ZIP structure is valid
      try {
        final bytes = await backupFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        if (archive.isEmpty) {
          AppLogger.error('MigrationManager', 'Backup ZIP is empty (no files)');
          return false;
        }

        // Check 4: data.json exists
        final hasDataJson = archive.any(
          (file) => file.name.endsWith('data.json'),
        );
        if (!hasDataJson) {
          AppLogger.error('MigrationManager', 'Backup missing data.json');
          return false;
        }

        AppLogger.debug(
          'MigrationManager',
          'Backup verified: ${fileSize ~/ 1024}KB, ${archive.length} files',
        );
        return true;
      } catch (e) {
        AppLogger.error('MigrationManager', 'Backup ZIP is corrupted', e);
        return false;
      }
    } catch (e) {
      AppLogger.error('MigrationManager', 'Backup verification failed', e);
      return false;
    }
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
  /// Uses orElse to safely return null instead of throwing
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

// =============================================
// MIGRATION MANAGER — RECOVERY EXTENSION (P2)
// =============================================

/// Stuck-DB detection and recovery logic.
///
/// All methods operate on an already-opened [Database] instance.
/// Call [diagnoseStartupState] after openDatabase(), before returning
/// the DB to the caller.
extension MigrationManagerRecovery on MigrationManager {
  // SharedPreferences key for retry counter (persists across app kills).
  static const String _keyRetryCount = 'migration_retry_count';
  static const int _maxRetries = 2;

  // ----------------------------------------------------------------
  // 1. DIAGNOSIS
  // ----------------------------------------------------------------

  /// Analyses the DB state at app startup.
  ///
  /// Priority order (from Design-Note Sektion a):
  ///   1. SharedPreferences migration_status (in_progress | timeout)
  ///   2. migration_start_time elapsed > threshold (belt-and-suspenders)
  ///   3. PRAGMA user_version vs. expectedVersion
  ///   4. SchemaRegistry.validateSchema() (drift without version diff)
  ///
  /// [db]              Already-opened database instance.
  /// [expectedVersion] kCurrentDbVersion from DatabaseHelper.
  Future<DbStartupDiagnosis> diagnoseStartupState(
    Database db,
    int expectedVersion,
  ) async {
    AppLogger.info(
      'MigrationManagerRecovery',
      '🔍 Diagnosing DB startup state (expected v$expectedVersion)...',
    );

    // --- Marker 1 + 2: SharedPreferences status flag ---
    String? migrationStatus;
    try {
      // Use VersionManager helpers to avoid re-implementing SharedPreferences
      // access. isMigrationInProgress() already handles the elapsed-time check
      // and flips status to 'timeout' when appropriate.
      final inProgress = await VersionManager.isMigrationInProgress();
      final hasFailure = await VersionManager.hasRecentMigrationFailure();

      if (inProgress) {
        // Still within the timeout window → treat as stuck anyway because
        // we are in _initDB, not inside a running migrate() call.
        migrationStatus = 'in_progress';
      } else if (hasFailure) {
        // Covers 'timeout' and 'failed' states.
        migrationStatus = 'failed_or_timeout';
      }
    } catch (e) {
      AppLogger.warning(
        'MigrationManagerRecovery',
        'Could not read SharedPreferences migration status',
        e,
      );
    }

    // --- Marker 3: PRAGMA user_version ---
    int actualVersion = 0;
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      actualVersion = (result.firstOrNull?['user_version'] as int?) ?? 0;
    } catch (e) {
      AppLogger.error(
        'MigrationManagerRecovery',
        'Cannot read PRAGMA user_version',
        e,
      );
      return DbStartupDiagnosis(
        state: DbStartupState.unrecoverable,
        actualVersion: 0,
        expectedVersion: expectedVersion,
        details: 'PRAGMA user_version unreadable: $e',
      );
    }

    AppLogger.info(
      'MigrationManagerRecovery',
      'DB state: actual=v$actualVersion expected=v$expectedVersion '
      'prefs_status=$migrationStatus',
    );

    // Stuck-in-progress detection: flag set + version not yet at target.
    if ((migrationStatus == 'in_progress' ||
            migrationStatus == 'failed_or_timeout') &&
        actualVersion < expectedVersion) {
      return DbStartupDiagnosis(
        state: DbStartupState.stuckInProgress,
        actualVersion: actualVersion,
        expectedVersion: expectedVersion,
        details: 'SharedPreferences migration_status=$migrationStatus, '
            'DB still at v$actualVersion',
      );
    }

    // Normal migration needed (fresh install upgrade path).
    if (actualVersion < expectedVersion && migrationStatus == null) {
      return DbStartupDiagnosis(
        state: DbStartupState.migrationNeeded,
        actualVersion: actualVersion,
        expectedVersion: expectedVersion,
      );
    }

    // --- Marker 4: Schema drift (version matches, but schema is off) ---
    if (actualVersion == expectedVersion) {
      bool schemaDefinitionExists = false;
      try {
        schemaDefinitionExists =
            SchemaRegistry.getSchema(expectedVersion) != null;
      } catch (e) {
        AppLogger.warning(
          'MigrationManagerRecovery',
          'SchemaRegistry.getSchema($expectedVersion) threw during diagnosis',
          e,
        );
        // Cannot validate schema — treat as healthy to avoid false positives.
        schemaDefinitionExists = false;
      }

      if (schemaDefinitionExists) {
        try {
          final schemaValid = await SchemaRegistry.validateSchema(
            db,
            expectedVersion,
            strict: false,
          );

          if (!schemaValid) {
            AppLogger.warning(
              'MigrationManagerRecovery',
              '⚠️ Schema drift detected at v$actualVersion — validation failed',
            );
            return DbStartupDiagnosis(
              state: DbStartupState.schemaDrift,
              actualVersion: actualVersion,
              expectedVersion: expectedVersion,
              details: 'user_version=$actualVersion but schema validation failed',
            );
          }
        } catch (e) {
          AppLogger.warning(
            'MigrationManagerRecovery',
            'Schema validation threw during diagnosis',
            e,
          );
          // Treat as drift — non-fatal, recovery can attempt repair.
          return DbStartupDiagnosis(
            state: DbStartupState.schemaDrift,
            actualVersion: actualVersion,
            expectedVersion: expectedVersion,
            details: 'Schema validation error: $e',
          );
        }
      }

      // Version matches, schema valid (or no schema def for this version) → healthy.
      AppLogger.info(
        'MigrationManagerRecovery',
        '✅ DB startup state: healthy (v$actualVersion)',
      );
      return DbStartupDiagnosis(
        state: DbStartupState.healthy,
        actualVersion: actualVersion,
        expectedVersion: expectedVersion,
      );
    }

    // actualVersion > expectedVersion: downgrade scenario, handled by onDowngrade.
    AppLogger.warning(
      'MigrationManagerRecovery',
      'actualVersion ($actualVersion) > expectedVersion ($expectedVersion) — downgrade scenario',
    );
    return DbStartupDiagnosis(
      state: DbStartupState.healthy,
      actualVersion: actualVersion,
      expectedVersion: expectedVersion,
      details: 'Downgrade scenario — handled by onDowngrade',
    );
  }

  // ----------------------------------------------------------------
  // 2. RECOVERY
  // ----------------------------------------------------------------

  /// Attempts recovery for a stuck-state diagnosis.
  ///
  /// Strategy (from Design-Note Sektion b):
  ///   Option A: Re-run migration (primary, up to [maxRetries] attempts).
  ///   Option B: repairSchemaDrift() for schemaDrift without version diff.
  ///   If all options exhausted → [RecoveryFailed] with dataExportAvailable flag.
  ///
  /// [db]        Opened database instance.
  /// [diagnosis] Result of [diagnoseStartupState].
  /// [maxRetries] Maximum re-run attempts across app starts (default: 2).
  Future<RecoveryResult> attemptRecovery(
    Database db,
    DbStartupDiagnosis diagnosis, {
    int maxRetries = _maxRetries,
  }) async {
    AppLogger.warning(
      'MigrationManagerRecovery',
      '🔧 Attempting recovery for state: ${diagnosis.state}',
    );

    // --- Schema drift (Option B only) ---
    if (diagnosis.state == DbStartupState.schemaDrift) {
      AppLogger.info(
        'MigrationManagerRecovery',
        'Schema drift: attempting ADD COLUMN repair...',
      );
      final repaired = await repairSchemaDrift(db, diagnosis.expectedVersion);
      if (repaired) {
        // Clear any stale retry counter on success.
        await _clearRetryCount();
        await VersionManager.markMigrationCompleted(
          dbVersion: diagnosis.expectedVersion,
        );
        AppLogger.info(
          'MigrationManagerRecovery',
          '✅ Schema drift repaired via ADD COLUMN',
        );
        return RecoverySuccess(recoveredToVersion: diagnosis.expectedVersion);
      }
      AppLogger.error(
        'MigrationManagerRecovery',
        '❌ Schema drift repair failed — marking unrecoverable',
      );
      return const RecoveryFailed(
        reason: 'Schema drift repair failed (ADD COLUMN unsuccessful)',
        dataExportAvailable: false,
      );
    }

    // --- stuckInProgress: Option A — re-run migration ---
    if (diagnosis.state == DbStartupState.stuckInProgress) {
      final retryCount = await _readRetryCount();
      AppLogger.info(
        'MigrationManagerRecovery',
        'Retry count: $retryCount / $maxRetries',
      );

      if (retryCount >= maxRetries) {
        AppLogger.error(
          'MigrationManagerRecovery',
          '❌ Max retries ($maxRetries) exhausted — unrecoverable',
        );
        return RecoveryFailed(
          reason:
              'Migration re-run failed $maxRetries times. '
              'A bug in the migration script is likely.',
          dataExportAvailable: false,
        );
      }

      // Increment retry counter BEFORE the attempt so a kill during migrate()
      // counts as a failed attempt on next startup.
      await _incrementRetryCount();

      try {
        AppLogger.info(
          'MigrationManagerRecovery',
          '🔄 Re-running migration v${diagnosis.actualVersion} → v${diagnosis.expectedVersion} '
          '(attempt ${retryCount + 1}/$maxRetries)',
        );

        await migrate(
          db,
          diagnosis.actualVersion,
          diagnosis.expectedVersion,
        );

        // Success — clear retry counter.
        await _clearRetryCount();
        AppLogger.info(
          'MigrationManagerRecovery',
          '✅ Migration re-run succeeded',
        );
        return RecoverySuccess(
          recoveredToVersion: diagnosis.expectedVersion,
        );
      } catch (e, stack) {
        AppLogger.error(
          'MigrationManagerRecovery',
          '❌ Migration re-run attempt ${retryCount + 1} failed',
          e,
          stack,
        );
        // Retry counter was already incremented. Next app start will check again.
        return RecoveryFailed(
          reason: 'Migration re-run attempt ${retryCount + 1} failed: $e',
          dataExportAvailable: false,
        );
      }
    }

    // Fallthrough: unexpected state — treat as unrecoverable.
    return RecoveryFailed(
      reason: 'Unexpected diagnosis state: ${diagnosis.state}',
      dataExportAvailable: false,
    );
  }

  // ----------------------------------------------------------------
  // 3. SCHEMA DRIFT REPAIR
  // ----------------------------------------------------------------

  /// Repairs schema drift by adding missing columns via ALTER TABLE.
  ///
  /// Only handles ADD COLUMN scenarios (DROP/RENAME not supported in SQLite).
  /// Returns true if all missing columns were added successfully.
  Future<bool> repairSchemaDrift(Database db, int targetVersion) async {
    SchemaDefinition? schemaDef;
    try {
      schemaDef = SchemaRegistry.getSchema(targetVersion);
    } catch (e) {
      AppLogger.warning(
        'MigrationManagerRecovery',
        'SchemaRegistry.getSchema($targetVersion) threw — cannot repair drift',
        e,
      );
      return false;
    }

    if (schemaDef == null) {
      AppLogger.warning(
        'MigrationManagerRecovery',
        'No schema definition for v$targetVersion — cannot repair drift',
      );
      return false;
    }

    bool allRepaired = true;

    for (final entry in schemaDef.requiredTables.entries) {
      final tableName = entry.key;
      final requiredColumns = entry.value;

      // Read current columns.
      List<Map<String, Object?>> existingColsResult;
      try {
        existingColsResult = await db.rawQuery(
          'PRAGMA table_info($tableName)',
        );
      } catch (e) {
        AppLogger.error(
          'MigrationManagerRecovery',
          'Cannot read table_info for $tableName',
          e,
        );
        allRepaired = false;
        continue;
      }

      final existingColumns = existingColsResult
          .map((r) => r['name'] as String)
          .toSet();

      final missingColumns = requiredColumns.difference(existingColumns);

      for (final col in missingColumns) {
        try {
          AppLogger.info(
            'MigrationManagerRecovery',
            'Adding missing column: $tableName.$col',
          );
          // SQLite does not support NOT NULL without DEFAULT in ADD COLUMN.
          // Use TEXT type with NULL allowed — the migration script should
          // have done the correct type; this is a repair-only fallback.
          await db.execute(
            'ALTER TABLE $tableName ADD COLUMN $col TEXT',
          );
          AppLogger.info(
            'MigrationManagerRecovery',
            '✅ Added $tableName.$col',
          );
        } catch (e) {
          AppLogger.error(
            'MigrationManagerRecovery',
            '❌ Failed to add $tableName.$col',
            e,
          );
          allRepaired = false;
        }
      }
    }

    return allRepaired;
  }

  // ----------------------------------------------------------------
  // 4. RETRY COUNTER HELPERS
  // ----------------------------------------------------------------

  Future<int> _readRetryCount() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getInt(_keyRetryCount) ?? 0;
    } catch (e) {
      AppLogger.warning(
        'MigrationManagerRecovery',
        'Cannot read retry count',
        e,
      );
      return 0;
    }
  }

  Future<void> _incrementRetryCount() async {
    try {
      final prefs = await _getPrefs();
      final current = prefs.getInt(_keyRetryCount) ?? 0;
      await prefs.setInt(_keyRetryCount, current + 1);
      AppLogger.info(
        'MigrationManagerRecovery',
        'Retry count incremented to ${current + 1}',
      );
    } catch (e) {
      AppLogger.warning(
        'MigrationManagerRecovery',
        'Cannot increment retry count',
        e,
      );
    }
  }

  Future<void> _clearRetryCount() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyRetryCount);
      AppLogger.info(
        'MigrationManagerRecovery',
        'Retry count cleared',
      );
    } catch (e) {
      AppLogger.warning(
        'MigrationManagerRecovery',
        'Cannot clear retry count',
        e,
      );
    }
  }

  Future<SharedPreferences> _getPrefs() => SharedPreferences.getInstance();
}
