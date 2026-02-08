// =============================================
// GROWLOG - Safe Table Rebuild Helper
// Atomic table rebuilds with guaranteed rollback
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Safe table rebuild utilities for migrations
///
/// Provides atomic table rebuild operations that guarantee data integrity
/// by using proper transaction handling and validation.
///
/// WHY THIS EXISTS:
/// Manual DROP TABLE + RENAME TABLE patterns are dangerous because:
/// 1. If app crashes between DROP and RENAME, table is lost forever
/// 2. No automatic rollback on partial failure
/// 3. Hard to validate before/after state
///
/// This helper ensures:
/// - Atomic operations (all-or-nothing)
/// - Automatic rollback on any error
/// - Pre/post validation
/// - Detailed logging
class SafeTableRebuild {
  /// Atomically rebuild a table with new schema
  ///
  /// This is the SAFE way to change table structure when you can't use ALTER TABLE.
  ///
  /// Example:
  /// ```dart
  /// await SafeTableRebuild.rebuildTable(
  ///   txn,
  ///   tableName: 'plant_logs',
  ///   newTableDdl: 'CREATE TABLE plant_logs_new (...)',
  ///   dataMigration: 'INSERT INTO plant_logs_new (...) SELECT ... FROM plant_logs',
  ///   indexes: [
  ///     'CREATE INDEX idx_logs_plant ON plant_logs(plant_id)',
  ///   ],
  /// );
  /// ```
  ///
  /// IMPORTANT: Must be called within an existing transaction!
  ///
  /// [txn] Database transaction (ensures atomicity)
  /// [tableName] Original table name
  /// [newTableDdl] CREATE TABLE statement for new table (must use tableName_new)
  /// [dataMigration] INSERT INTO statement to migrate data
  /// [indexes] List of CREATE INDEX statements (optional)
  /// [validateBefore] Optional validation before rebuild
  /// [validateAfter] Optional validation after rebuild
  static Future<void> rebuildTable(
    DatabaseExecutor txn, {
    required String tableName,
    required String newTableDdl,
    required String dataMigration,
    List<String>? indexes,
    Future<bool> Function(DatabaseExecutor)? validateBefore,
    Future<bool> Function(DatabaseExecutor)? validateAfter,
  }) async {
    final tempTableName = '${tableName}_new';

    AppLogger.info(
      'SafeTableRebuild',
      '🔄 Starting safe rebuild of table: $tableName',
    );

    try {
      // ===========================================
      // STEP 1: Pre-rebuild validation
      // ===========================================
      if (validateBefore != null) {
        AppLogger.info(
          'SafeTableRebuild',
          '  Step 1/6: Running pre-rebuild validation',
        );

        final isValid = await validateBefore(txn);
        if (!isValid) {
          throw Exception(
            'Pre-rebuild validation failed for table: $tableName',
          );
        }
      } else {
        AppLogger.info(
          'SafeTableRebuild',
          '  Step 1/6: Skipping pre-rebuild validation (not provided)',
        );
      }

      // ===========================================
      // STEP 2: Verify table exists
      // ===========================================
      AppLogger.info(
        'SafeTableRebuild',
        '  Step 2/6: Verifying source table exists',
      );

      final tableExists = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );

      if (tableExists.isEmpty) {
        throw Exception('Source table $tableName does not exist!');
      }

      // Get row count before rebuild
      final countBefore = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      final rowCountBefore = countBefore.first['count'] as int;

      AppLogger.info(
        'SafeTableRebuild',
        '  ✅ Source table has $rowCountBefore rows',
      );

      // ===========================================
      // STEP 3: Create new table
      // ===========================================
      AppLogger.info(
        'SafeTableRebuild',
        '  Step 3/6: Creating new table schema',
      );

      await txn.execute(newTableDdl);

      // Verify new table was created
      final newTableExists = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tempTableName],
      );

      if (newTableExists.isEmpty) {
        throw Exception('Failed to create new table: $tempTableName');
      }

      // ===========================================
      // STEP 4: Migrate data
      // ===========================================
      AppLogger.info(
        'SafeTableRebuild',
        '  Step 4/6: Migrating data to new table',
      );

      await txn.execute(dataMigration);

      // Verify data was migrated
      final countAfter = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM $tempTableName',
      );
      final rowCountAfter = countAfter.first['count'] as int;

      AppLogger.info(
        'SafeTableRebuild',
        '  ✅ Migrated $rowCountAfter rows (source had $rowCountBefore)',
      );

      // Sanity check: Row count shouldn't decrease (unless intentional filtering)
      if (rowCountAfter < rowCountBefore) {
        AppLogger.warning(
          'SafeTableRebuild',
          '  ⚠️ Row count decreased: $rowCountBefore → $rowCountAfter',
        );
      }

      // ===========================================
      // STEP 5: Atomic swap (DROP + RENAME)
      // ===========================================
      AppLogger.info(
        'SafeTableRebuild',
        '  Step 5/6: Atomic table swap (DROP + RENAME)',
      );

      // ✅ CRITICAL: These two operations MUST be in same transaction
      // If app crashes between them, transaction rollback will restore old table
      await txn.execute('DROP TABLE $tableName');
      await txn.execute('ALTER TABLE $tempTableName RENAME TO $tableName');

      AppLogger.info('SafeTableRebuild', '  ✅ Atomic swap complete');

      // ===========================================
      // STEP 6: Recreate indexes
      // ===========================================
      if (indexes != null && indexes.isNotEmpty) {
        AppLogger.info(
          'SafeTableRebuild',
          '  Step 6/6: Recreating ${indexes.length} indexes',
        );

        for (final indexDdl in indexes) {
          await txn.execute(indexDdl);
        }

        AppLogger.info('SafeTableRebuild', '  ✅ All indexes recreated');
      } else {
        AppLogger.info(
          'SafeTableRebuild',
          '  Step 6/6: No indexes to recreate',
        );
      }

      // ===========================================
      // Post-rebuild validation
      // ===========================================
      if (validateAfter != null) {
        AppLogger.info(
          'SafeTableRebuild',
          '  Final: Running post-rebuild validation',
        );

        final isValid = await validateAfter(txn);
        if (!isValid) {
          throw Exception(
            'Post-rebuild validation failed for table: $tableName',
          );
        }
      }

      AppLogger.info(
        'SafeTableRebuild',
        '🎉 Successfully rebuilt table: $tableName',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'SafeTableRebuild',
        '💥 Table rebuild failed for: $tableName',
        e,
        stackTrace,
      );

      AppLogger.error(
        'SafeTableRebuild',
        '🔄 Transaction will be rolled back automatically',
      );

      rethrow; // Let transaction handle rollback
    }
  }

  /// Verify table schema matches expected columns
  ///
  /// Useful for pre/post validation
  static Future<bool> verifyTableColumns(
    DatabaseExecutor db,
    String tableName,
    Set<String> expectedColumns,
  ) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final actualColumns = columns.map((col) => col['name'] as String).toSet();

      final missing = expectedColumns.difference(actualColumns);
      final extra = actualColumns.difference(expectedColumns);

      if (missing.isNotEmpty) {
        AppLogger.error(
          'SafeTableRebuild',
          'Table $tableName missing columns: ${missing.join(", ")}',
        );
        return false;
      }

      if (extra.isNotEmpty) {
        AppLogger.warning(
          'SafeTableRebuild',
          'Table $tableName has extra columns: ${extra.join(", ")}',
        );
        // Extra columns are OK (backwards compatibility)
      }

      return true;
    } catch (e) {
      AppLogger.error('SafeTableRebuild', 'Failed to verify table columns', e);
      return false;
    }
  }

  /// Verify foreign key integrity for a table
  static Future<bool> verifyForeignKeyIntegrity(
    DatabaseExecutor db,
    String tableName,
  ) async {
    try {
      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check($tableName)');

      if (fkCheck.isNotEmpty) {
        AppLogger.error(
          'SafeTableRebuild',
          'Foreign key violations in $tableName: $fkCheck',
        );
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('SafeTableRebuild', 'Failed to check foreign keys', e);
      return false;
    }
  }
}
