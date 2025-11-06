// =============================================
// GROWLOG - Migration v8: RDWC Expert Mode Logging
// =============================================

import '../../../utils/app_logger.dart';
import '../migration.dart';

/// Migration v8: RDWC Expert Mode Logging
///
/// This migration adds advanced nutrient tracking for RDWC systems in Expert Mode:
/// - Fertilizer logging per RDWC log (which nutrients were added)
/// - EC/PPM values for fertilizers (for automatic calculations)
/// - Recipe system for storing fertilizer combinations
///
/// Changes:
/// 1. Create rdwc_log_fertilizers table (link fertilizers to RDWC logs)
/// 2. Extend fertilizers table (add ec_value, ppm_value columns)
/// 3. Create rdwc_recipes table (save fertilizer recipes)
/// 4. Create rdwc_recipe_fertilizers table (recipes → fertilizers mapping)
final migrationV8 = Migration(
  version: 8,
  description: 'RDWC Expert Mode: Advanced nutrient tracking & recipes',
  up: (db) async {
    AppLogger.info('Migration v8', 'Starting RDWC Expert Mode migration...');

    // 1. Create rdwc_log_fertilizers table
    // Links fertilizers to RDWC logs with amount and type (per liter / total)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rdwc_log_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rdwc_log_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        amount_type TEXT NOT NULL CHECK(amount_type IN ('PER_LITER', 'TOTAL')),
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rdwc_log_fertilizers_log ON rdwc_log_fertilizers(rdwc_log_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rdwc_log_fertilizers_fertilizer ON rdwc_log_fertilizers(fertilizer_id)',
    );

    AppLogger.info('Migration v8', '✓ Created rdwc_log_fertilizers table');

    // 2. Extend fertilizers table with EC/PPM values
    // These values enable automatic EC/PPM calculation in RDWC
    await db.execute('ALTER TABLE fertilizers ADD COLUMN ec_value REAL');
    await db.execute('ALTER TABLE fertilizers ADD COLUMN ppm_value REAL');

    AppLogger.info('Migration v8', '✓ Extended fertilizers table with EC/PPM values');

    // 3. Create rdwc_recipes table
    // Recipes store fertilizer combinations for reuse (e.g., "Bloom Week 3")
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rdwc_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        target_ec REAL,
        target_ph REAL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rdwc_recipes_name ON rdwc_recipes(name)',
    );

    AppLogger.info('Migration v8', '✓ Created rdwc_recipes table');

    // 4. Create rdwc_recipe_fertilizers table
    // Maps recipes to their fertilizers with dosage per liter
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rdwc_recipe_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        ml_per_liter REAL NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES rdwc_recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rdwc_recipe_fertilizers_recipe ON rdwc_recipe_fertilizers(recipe_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rdwc_recipe_fertilizers_fertilizer ON rdwc_recipe_fertilizers(fertilizer_id)',
    );

    AppLogger.info('Migration v8', '✓ Created rdwc_recipe_fertilizers table');

    AppLogger.info('Migration v8', '✅ RDWC Expert Mode migration completed successfully!');
  },

  // Optional: Rollback logic (if migration fails)
  down: (db) async {
    AppLogger.info('Migration v8', 'Rolling back RDWC Expert Mode migration...');

    // Remove new tables
    await db.execute('DROP TABLE IF EXISTS rdwc_recipe_fertilizers');
    await db.execute('DROP TABLE IF EXISTS rdwc_recipes');
    await db.execute('DROP TABLE IF EXISTS rdwc_log_fertilizers');

    // Note: Cannot remove columns in SQLite without recreating table
    // So we leave ec_value and ppm_value columns (they're optional anyway)
    AppLogger.warning(
      'Migration v8',
      'Note: Cannot remove ec_value/ppm_value columns from fertilizers (SQLite limitation)',
    );

    AppLogger.info('Migration v8', '✅ Rollback completed');
  },
);
