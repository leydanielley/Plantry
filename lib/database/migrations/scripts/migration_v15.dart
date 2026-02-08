// =============================================
// GROWLOG - Migration v14 → v15
// DATA INTEGRITY IMPROVEMENTS: NOT NULL Constraints & Schema Fixes
// =============================================

import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v15: Data Integrity & Schema Consistency Fixes
///
/// PROBLEMS FIXED:
/// 1. Missing NOT NULL constraints in plant_logs (log_date, action_type)
/// 2. Missing UNIQUE constraint on plant_logs(plant_id, day_number)
/// 3. CHECK constraint inconsistency (lowercase vs UPPERCASE in rdwc_logs.log_type)
/// 4. Missing NOT NULL constraint for rdwc_logs.archived
///
/// IMPACT:
/// - Prevents NULL values in critical fields
/// - Prevents duplicate day_numbers for same plant
/// - Consistent CHECK constraints across schema
/// - Better data integrity
///
/// SAFETY:
/// - Cleans existing NULL values before adding constraints
/// - Transaction-wrapped for rollback on error
/// - Validates data before schema changes
final Migration migrationV15 = Migration(
  version: 15,
  description: 'Data integrity improvements: NOT NULL constraints & fixes',
  up: (db) async {
    AppLogger.info(
      'Migration_v15',
      '🔄 Starting Migration v15: Data Integrity Improvements',
    );

    // ===========================================
    // STEP 0: Pre-Migration Data Validation & Cleanup
    // ===========================================
    AppLogger.info(
      'Migration_v15',
      '🔍 Step 0/4: Validating and cleaning data',
    );

    // Check for NULL values in critical fields
    final nullLogDates = await db.rawQuery(
      'SELECT COUNT(*) as count FROM plant_logs WHERE log_date IS NULL',
    );
    final nullLogDatesCount = nullLogDates.first['count'] as int;

    final nullActionTypes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM plant_logs WHERE action_type IS NULL',
    );
    final nullActionTypesCount = nullActionTypes.first['count'] as int;

    AppLogger.info(
      'Migration_v15',
      '  Found $nullLogDatesCount NULL log_dates, $nullActionTypesCount NULL action_types',
    );

    // Cleanup NULL values with sensible defaults
    if (nullLogDatesCount > 0) {
      AppLogger.warning(
        'Migration_v15',
        '  Cleaning $nullLogDatesCount NULL log_dates...',
      );
      await db.execute('''
        UPDATE plant_logs
        SET log_date = datetime('now')
        WHERE log_date IS NULL
      ''');
    }

    if (nullActionTypesCount > 0) {
      AppLogger.warning(
        'Migration_v15',
        '  Cleaning $nullActionTypesCount NULL action_types...',
      );
      await db.execute('''
        UPDATE plant_logs
        SET action_type = 'NOTE'
        WHERE action_type IS NULL
      ''');
    }

    // Check for duplicate day_numbers
    final duplicateDays = await db.rawQuery('''
      SELECT plant_id, day_number, COUNT(*) as count
      FROM plant_logs
      WHERE archived = 0
      GROUP BY plant_id, day_number
      HAVING COUNT(*) > 1
    ''');

    if (duplicateDays.isNotEmpty) {
      AppLogger.warning(
        'Migration_v15',
        '  Found ${duplicateDays.length} duplicate day_numbers, fixing...',
      );

      // Fix duplicates by renumbering
      for (final dup in duplicateDays) {
        final plantId = dup['plant_id'] as int;
        AppLogger.debug(
          'Migration_v15',
          '  Recalculating day_numbers for plant $plantId',
        );

        // Get all logs for this plant in chronological order
        final logs = await db.query(
          'plant_logs',
          where: 'plant_id = ? AND archived = 0',
          whereArgs: [plantId],
          orderBy: 'log_date ASC, id ASC',
        );

        // Renumber sequentially
        int dayNumber = 1;
        for (final log in logs) {
          final logId = log['id'] as int;
          await db.update(
            'plant_logs',
            {'day_number': dayNumber},
            where: 'id = ?',
            whereArgs: [logId],
          );
          dayNumber++;
        }
      }

      AppLogger.info('Migration_v15', '  ✅ Duplicate day_numbers fixed');
    }

    AppLogger.info('Migration_v15', '  ✅ Data validation and cleanup complete');

    // ===========================================
    // STEP 1: Rebuild plant_logs with NOT NULL Constraints
    // ===========================================
    AppLogger.info(
      'Migration_v15',
      '📝 Step 1/4: Rebuilding plant_logs with NOT NULL constraints',
    );

    await db.execute('''
      CREATE TABLE plant_logs_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        log_date TEXT NOT NULL DEFAULT (datetime('now')),
        logged_by TEXT,
        action_type TEXT NOT NULL CHECK(action_type IN ('WATER', 'FEED', 'NOTE', 'PHASE_CHANGE', 'TRANSPLANT', 'HARVEST', 'TRAINING', 'TRIM', 'OTHER')),
        phase TEXT CHECK(phase IN ('SEEDLING', 'VEG', 'BLOOM', 'HARVEST', 'ARCHIVED')),
        phase_day_number INTEGER,
        water_amount REAL,
        ph_in REAL,
        ph_out REAL,
        ec_in REAL,
        ec_out REAL,
        temperature REAL,
        humidity REAL,
        runoff INTEGER DEFAULT 0,
        cleanse INTEGER DEFAULT 0,
        container_size REAL,
        container_medium_amount REAL,
        container_drainage INTEGER DEFAULT 0,
        container_drainage_material TEXT,
        system_reservoir_size REAL,
        system_bucket_count INTEGER,
        system_bucket_size REAL,
        note TEXT,
        archived INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
      )
    ''');

    // Copy all data (cleaned data ensures no NULLs violate constraints)
    await db.execute('''
      INSERT INTO plant_logs_new
      SELECT * FROM plant_logs
    ''');

    await db.execute('DROP TABLE plant_logs');
    await db.execute('ALTER TABLE plant_logs_new RENAME TO plant_logs');

    AppLogger.info('Migration_v15', '  ✅ plant_logs rebuilt with NOT NULL');

    // ===========================================
    // STEP 2: Create UNIQUE Index on plant_id + day_number
    // ===========================================
    AppLogger.info(
      'Migration_v15',
      '📝 Step 2/4: Creating UNIQUE index on (plant_id, day_number)',
    );

    // Partial unique index: Only for non-archived logs
    await db.execute('''
      CREATE UNIQUE INDEX idx_plant_logs_plant_day_unique
      ON plant_logs(plant_id, day_number)
      WHERE archived = 0
    ''');

    AppLogger.info('Migration_v15', '  ✅ UNIQUE index created');

    // ===========================================
    // STEP 3: Normalize CHECK Constraints (lowercase → UPPERCASE)
    // ===========================================
    AppLogger.info(
      'Migration_v15',
      '📝 Step 3/4: Normalizing CHECK constraints to UPPERCASE',
    );

    // Update rdwc_logs.log_type values to UPPERCASE
    await db.execute('''
      UPDATE rdwc_logs
      SET log_type = UPPER(log_type)
      WHERE log_type != UPPER(log_type)
    ''');

    // Rebuild rdwc_logs with correct CHECK constraint
    await db.execute('''
      CREATE TABLE rdwc_logs_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        log_date TEXT DEFAULT (datetime('now')),
        log_type TEXT NOT NULL CHECK(log_type IN ('ADDBACK', 'FULLCHANGE', 'MAINTENANCE', 'MEASUREMENT')),
        level_before REAL,
        water_added REAL,
        level_after REAL,
        water_consumed REAL,
        ph_before REAL,
        ph_after REAL,
        ec_before REAL,
        ec_after REAL,
        note TEXT,
        logged_by TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (system_id) REFERENCES rdwc_systems(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('INSERT INTO rdwc_logs_new SELECT * FROM rdwc_logs');
    await db.execute('DROP TABLE rdwc_logs');
    await db.execute('ALTER TABLE rdwc_logs_new RENAME TO rdwc_logs');

    AppLogger.info('Migration_v15', '  ✅ CHECK constraints normalized');

    // ===========================================
    // STEP 4: Re-create Indexes
    // ===========================================
    AppLogger.info('Migration_v15', '📝 Step 4/4: Re-creating indexes');

    // plant_logs indexes
    await db.execute('CREATE INDEX idx_logs_plant ON plant_logs(plant_id)');
    await db.execute('CREATE INDEX idx_logs_date ON plant_logs(log_date DESC)');
    await db.execute('CREATE INDEX idx_logs_action ON plant_logs(action_type)');
    await db.execute(
      'CREATE INDEX idx_plant_logs_lookup ON plant_logs(plant_id, log_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_plant_logs_action_date ON plant_logs(action_type, log_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_plant_logs_plant_archived ON plant_logs(plant_id, archived)',
    );
    await db.execute(
      'CREATE INDEX idx_plant_logs_archived_date ON plant_logs(archived, log_date DESC)',
    );

    // rdwc_logs indexes
    await db.execute(
      'CREATE INDEX idx_rdwc_logs_system_date ON rdwc_logs(system_id, log_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_rdwc_logs_system_type_date ON rdwc_logs(system_id, log_type, log_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_rdwc_logs_system_archived ON rdwc_logs(system_id, archived)',
    );
    await db.execute(
      'CREATE INDEX idx_rdwc_logs_archived_date ON rdwc_logs(archived, log_date DESC)',
    );

    AppLogger.info('Migration_v15', '  ✅ 11 indexes re-created');

    // ===========================================
    // COMPLETION
    // ===========================================
    AppLogger.info('Migration_v15', '🎉 DATA INTEGRITY IMPROVEMENTS COMPLETE!');
    AppLogger.info('Migration_v15', 'Changes:');
    AppLogger.info(
      'Migration_v15',
      '  ✅ NOT NULL constraints added (2 fields)',
    );
    AppLogger.info(
      'Migration_v15',
      '  ✅ UNIQUE constraint on plant_logs(plant_id, day_number)',
    );
    AppLogger.info(
      'Migration_v15',
      '  ✅ CHECK constraints normalized to UPPERCASE',
    );
    AppLogger.info('Migration_v15', '  ✅ 11 indexes optimized');
    AppLogger.info(
      'Migration_v15',
      '  🔒 Data integrity significantly improved',
    );
  },
  down: (db) async {
    // Rollback would require dropping NOT NULL constraints (complex in SQLite)
    AppLogger.warning(
      'Migration_v15',
      '⚠️ Rollback not implemented (constraints remain)',
    );
  },
);
