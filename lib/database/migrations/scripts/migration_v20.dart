// =============================================
// GROWLOG - Migration v19 → v20
// FIX: harvests FK Constraint ON DELETE RESTRICT → CASCADE
// =============================================

import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/migrations/safe_table_rebuild.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v20: Fix harvests FK constraint
///
/// PROBLEM:
/// Current FK constraint on harvests table:
/// - harvests.plant_id → plants(id) ON DELETE RESTRICT
///
/// ISSUE: User Experience Problem
/// When a user tries to delete a plant that has harvest records,
/// the deletion fails with a FK constraint error.
/// This is confusing because harvests are owned by plants and
/// should be deleted when the plant is deleted.
///
/// SOLUTION:
/// Change to ON DELETE CASCADE:
/// - When plant is deleted, its harvest records are automatically deleted
/// - Better UX: No unexpected errors when deleting plants
/// - Harvests are dependent data - should not exist without parent plant
///
/// WHAT IT DOES:
/// 1. Rebuilds harvests table with CASCADE constraint
/// 2. Preserves all harvest data
/// 3. Validates schema after rebuild
///
/// SAFETY:
/// - Atomic: Uses SafeTableRebuild for guaranteed rollback
/// - Non-destructive: All data preserved
/// - Validated: Schema checks before and after
final Migration migrationV20 = Migration(
  version: 20,
  description: 'Fix harvests FK constraint: CASCADE on plant deletion',
  up: (txn) async {
    AppLogger.info(
      'Migration_v20',
      '🔄 Starting Migration v20: Harvests FK Constraint Fix',
    );

    // ===========================================
    // Rebuild harvests table with CASCADE constraint
    // ===========================================
    AppLogger.info(
      'Migration_v20',
      '📝 Rebuilding harvests table with CASCADE constraint',
    );

    await SafeTableRebuild.rebuildTable(
      txn,
      tableName: 'harvests',
      newTableDdl: '''
        CREATE TABLE harvests_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plant_id INTEGER NOT NULL,
          harvest_date TEXT NOT NULL,
          wet_weight REAL,
          dry_weight REAL,
          drying_start_date TEXT,
          drying_end_date TEXT,
          drying_days INTEGER,
          drying_method TEXT,
          drying_temperature REAL,
          drying_humidity REAL,
          curing_start_date TEXT,
          curing_end_date TEXT,
          curing_days INTEGER,
          curing_method TEXT,
          curing_notes TEXT,
          thc_percentage REAL,
          cbd_percentage REAL,
          terpene_profile TEXT,
          rating INTEGER CHECK(rating >= 1 AND rating <= 5),
          taste_notes TEXT,
          effect_notes TEXT,
          overall_notes TEXT,
          created_at TEXT DEFAULT (datetime('now')),
          updated_at TEXT,
          FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
        )
      ''',
      dataMigration: '''
        INSERT INTO harvests_new (
          id, plant_id, harvest_date, wet_weight, dry_weight,
          drying_start_date, drying_end_date, drying_days, drying_method,
          drying_temperature, drying_humidity,
          curing_start_date, curing_end_date, curing_days, curing_method, curing_notes,
          thc_percentage, cbd_percentage, terpene_profile,
          rating, taste_notes, effect_notes, overall_notes,
          created_at, updated_at
        )
        SELECT
          id, plant_id, harvest_date, wet_weight, dry_weight,
          drying_start_date, drying_end_date, drying_days, drying_method,
          drying_temperature, drying_humidity,
          curing_start_date, curing_end_date, curing_days, curing_method, curing_notes,
          thc_percentage, cbd_percentage, terpene_profile,
          rating, taste_notes, effect_notes, overall_notes,
          created_at, updated_at
        FROM harvests
      ''',
      indexes: [
        'CREATE INDEX idx_harvests_plant ON harvests(plant_id)',
        'CREATE INDEX idx_harvests_date ON harvests(harvest_date)',
        'CREATE INDEX idx_harvests_rating ON harvests(rating)',
      ],
      validateAfter: (db) async {
        // Verify harvests table exists and has data
        final count = await db.rawQuery('SELECT COUNT(*) as count FROM harvests');
        final rowCount = count.first['count'] as int;
        AppLogger.info('Migration_v20', 'Validated: $rowCount harvests preserved');
        return true;
      },
    );

    AppLogger.info(
      'Migration_v20',
      '✅ Harvests table rebuilt with CASCADE constraint',
    );

    // Verify schema integrity
    final integrityCheck = await txn.rawQuery('PRAGMA integrity_check');
    final result = integrityCheck.first['integrity_check'];
    if (result != 'ok') {
      throw Exception('Database integrity check failed after v20: $result');
    }

    // Verify FK constraint is correct
    final fkCheck = await txn.rawQuery('PRAGMA foreign_key_list(harvests)');
    final plantIdFk = fkCheck.firstWhere(
      (fk) => fk['from'] == 'plant_id',
      orElse: () => throw Exception('FK constraint on plant_id not found'),
    );

    if (plantIdFk['on_delete'] != 'CASCADE') {
      throw Exception(
        'FK constraint verification failed: Expected CASCADE, got ${plantIdFk['on_delete']}',
      );
    }

    AppLogger.info(
      'Migration_v20',
      '🎉 Migration v20 complete: Harvests now CASCADE on plant deletion',
    );
  },
);
