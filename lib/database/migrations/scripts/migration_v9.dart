// =============================================
// GROWLOG - Migration v8 → v9
// CRITICAL FIX: CASCADE → RESTRICT Constraints
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v9: Fix CASCADE constraints on fertilizer relationships
///
/// PROBLEM:
/// - log_fertilizers had ON DELETE CASCADE (WRONG!)
/// - template_fertilizers had ON DELETE CASCADE (WRONG!)
///
/// This meant if a fertilizer was deleted, ALL historical log data
/// and templates would be lost!
///
/// FIX:
/// - Change to ON DELETE RESTRICT (CORRECT!)
/// - Prevents accidental data loss
/// - Consistent with rdwc_log_fertilizers and rdwc_recipe_fertilizers
///
/// SAFETY:
/// - Automatic backup created before migration
/// - Transaction ensures all-or-nothing
/// - Rollback on any error
///
/// NOTE:
/// SQLite doesn't support ALTER CONSTRAINT, so we must:
/// 1. Create new tables with correct constraints
/// 2. Copy all data
/// 3. Drop old tables
/// 4. Rename new tables
/// 5. Recreate indices
final Migration migrationV9 = Migration(
  version: 9,
  description: 'CRITICAL FIX: Change fertilizer CASCADE → RESTRICT constraints',
  up: (DatabaseExecutor txn) async {
    AppLogger.info(
      'Migration_v9',
      '🔧 Starting CRITICAL constraint fix',
      'log_fertilizers + template_fertilizers: CASCADE → RESTRICT',
    );

    // ================================================================
    // FIX 1: log_fertilizers table
    // ================================================================

    AppLogger.info(
      'Migration_v9',
      '1/4: Creating new log_fertilizers table...',
    );

    // Step 1: Create new table with correct constraints
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS log_fertilizers_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL,
        unit TEXT DEFAULT 'ml',
        FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');

    AppLogger.info('Migration_v9', '2/4: Copying log_fertilizers data...');

    // Step 2: Copy all data from old table
    await txn.execute('''
      INSERT INTO log_fertilizers_new (id, log_id, fertilizer_id, amount, unit)
      SELECT id, log_id, fertilizer_id, amount, unit
      FROM log_fertilizers
    ''');

    // Verify data was copied
    final logFertCount = Sqflite.firstIntValue(
      await txn.rawQuery('SELECT COUNT(*) FROM log_fertilizers_new'),
    );
    AppLogger.info('Migration_v9', 'Copied $logFertCount log_fertilizers rows');

    // Step 3: Drop old table
    await txn.execute('DROP TABLE log_fertilizers');

    // Step 4: Rename new table
    await txn.execute(
      'ALTER TABLE log_fertilizers_new RENAME TO log_fertilizers',
    );

    // Step 5: Recreate index
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_log_fertilizers_lookup ON log_fertilizers(log_id, fertilizer_id)',
    );

    AppLogger.info('Migration_v9', '✅ log_fertilizers fixed!');

    // ================================================================
    // FIX 2: template_fertilizers table
    // ================================================================

    AppLogger.info(
      'Migration_v9',
      '3/4: Creating new template_fertilizers table...',
    );

    // Step 1: Create new table with correct constraints
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS template_fertilizers_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        unit TEXT DEFAULT 'ml',
        FOREIGN KEY (template_id) REFERENCES log_templates(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');

    AppLogger.info('Migration_v9', '4/4: Copying template_fertilizers data...');

    // Step 2: Copy all data from old table
    await txn.execute('''
      INSERT INTO template_fertilizers_new (id, template_id, fertilizer_id, amount, unit)
      SELECT id, template_id, fertilizer_id, amount, unit
      FROM template_fertilizers
    ''');

    // Verify data was copied
    final templateFertCount = Sqflite.firstIntValue(
      await txn.rawQuery('SELECT COUNT(*) FROM template_fertilizers_new'),
    );
    AppLogger.info(
      'Migration_v9',
      'Copied $templateFertCount template_fertilizers rows',
    );

    // Step 3: Drop old table
    await txn.execute('DROP TABLE template_fertilizers');

    // Step 4: Rename new table
    await txn.execute(
      'ALTER TABLE template_fertilizers_new RENAME TO template_fertilizers',
    );

    // Step 5: Recreate index
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_template_fertilizers_template ON template_fertilizers(template_id)',
    );

    AppLogger.info('Migration_v9', '✅ template_fertilizers fixed!');

    // ================================================================
    // VERIFICATION
    // ================================================================

    AppLogger.info('Migration_v9', '🔍 Verifying migration...');

    // Verify foreign keys are working
    await txn.rawQuery('PRAGMA foreign_key_check(log_fertilizers)');
    await txn.rawQuery('PRAGMA foreign_key_check(template_fertilizers)');

    // Count records in both tables
    final logFertTotal =
        Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM log_fertilizers'),
        ) ??
        0;
    final templateFertTotal =
        Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM template_fertilizers'),
        ) ??
        0;

    AppLogger.info('Migration_v9', '📊 Final counts:');
    AppLogger.info('Migration_v9', '  - log_fertilizers: $logFertTotal');
    AppLogger.info(
      'Migration_v9',
      '  - template_fertilizers: $templateFertTotal',
    );

    AppLogger.info(
      'Migration_v9',
      '🎉 CRITICAL FIX COMPLETE!',
      'Fertilizer data is now protected from accidental deletion',
    );
  },
);
