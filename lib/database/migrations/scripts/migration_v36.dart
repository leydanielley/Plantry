// =============================================
// GROWLOG - Migration v35 → v36
// Standardize Foreign Key CASCADE Rules
// =============================================

import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/migrations/safe_table_rebuild.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v36: Standardize Foreign Key CASCADE Rules
///
/// PROBLEM:
/// Current database has inconsistent foreign key CASCADE rules:
/// - harvests.plant_id → CASCADE (deletes harvests when plant deleted)
/// - hardware.room_id → CASCADE (deletes equipment when room deleted)
/// - plant_logs.plant_id → RESTRICT (blocks plant deletion if logs exist)
///
/// This inconsistency is confusing and risky:
/// - Users can accidentally lose valuable harvest data by deleting plants
/// - Equipment tracking disappears when rooms are deleted
/// - But they CAN'T delete plants that have logs (blocked by RESTRICT)
///
/// ROOT CAUSE:
/// Historical flip-flopping between CASCADE and RESTRICT in migrations:
/// - v14: Changed some tables to RESTRICT (soft-delete pattern)
/// - v20: Changed harvests back to CASCADE (created inconsistency)
///
/// SOLUTION:
/// Establish consistent FK constraint policy across entire schema:
///
/// **Entity FKs → RESTRICT** (prevent accidental data loss)
/// - harvests.plant_id: CASCADE → RESTRICT
/// - hardware.room_id: CASCADE → RESTRICT
///
/// **Child Data FKs → CASCADE** (delete with parent)
/// - photos.log_id: CASCADE (already correct)
/// - log_fertilizers.log_id: CASCADE (already correct)
/// - template_fertilizers.template_id: CASCADE (already correct)
///
/// **Reference Data FKs → RESTRICT** (protect reference data)
/// - All fertilizer_id FKs: RESTRICT (already correct)
///
/// **Nullable Relationships → SET NULL** (allow optional associations)
/// - rooms.rdwc_system_id: SET NULL (already correct)
/// - grows.room_id: SET NULL (already correct)
///
/// IMPACT:
/// - Prevents accidental data loss from cascade deletes
/// - Aligns with existing soft-delete pattern (archived flags)
/// - Forces users to explicitly handle dependencies before deletion
/// - Consistent behavior across all entity relationships
///
/// SAFETY:
/// - Uses SafeTableRebuild for atomic table operations
/// - Transaction-wrapped (automatic rollback on error)
/// - Validates data integrity before and after
/// - Preserves all data (100% data preservation)
/// - Verifies row counts match before/after
/// - Automatic backup by MigrationManager
final Migration migrationV36 = Migration(
  version: 36,
  description: 'Standardize FK CASCADE rules for data integrity',
  up: (txn) async {
    AppLogger.info(
      'Migration_v36',
      '🔄 Starting Migration v36: Standardize FK CASCADE Rules',
    );
    AppLogger.info(
      'Migration_v36',
      '🎯 Goal: Change harvests & hardware from CASCADE → RESTRICT',
    );

    // ===========================================
    // STEP 1: Rebuild harvests table
    // ===========================================
    AppLogger.info(
      'Migration_v36',
      '📝 Step 1/2: Rebuilding harvests table (CASCADE → RESTRICT)',
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
          FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
        )
      ''',
      dataMigration: '''
        INSERT INTO harvests_new (
          id, plant_id, harvest_date, wet_weight, dry_weight,
          drying_start_date, drying_end_date, drying_days, drying_method,
          drying_temperature, drying_humidity, curing_start_date,
          curing_end_date, curing_days, curing_method, curing_notes,
          thc_percentage, cbd_percentage, terpene_profile, rating,
          taste_notes, effect_notes, overall_notes, created_at, updated_at
        )
        SELECT
          id, plant_id, harvest_date, wet_weight, dry_weight,
          drying_start_date, drying_end_date, drying_days, drying_method,
          drying_temperature, drying_humidity, curing_start_date,
          curing_end_date, curing_days, curing_method, curing_notes,
          thc_percentage, cbd_percentage, terpene_profile, rating,
          taste_notes, effect_notes, overall_notes, created_at, updated_at
        FROM harvests
      ''',
      indexes: [
        'CREATE INDEX idx_harvests_plant ON harvests(plant_id)',
        'CREATE INDEX idx_harvests_date ON harvests(harvest_date)',
      ],
      validateAfter: (db) async {
        // Verify FK constraint changed to RESTRICT
        final fkCheck = await db.rawQuery('PRAGMA foreign_key_list(harvests)');
        final plantIdFk = fkCheck.firstWhere(
          (fk) => fk['from'] == 'plant_id',
          orElse: () => throw Exception('FK constraint on plant_id not found'),
        );

        if (plantIdFk['on_delete'] != 'RESTRICT') {
          AppLogger.error(
            'Migration_v36',
            'FK constraint validation failed: '
            'expected RESTRICT, got ${plantIdFk['on_delete']}',
          );
          return false;
        }

        AppLogger.info(
          'Migration_v36',
          '  ✅ harvests.plant_id FK changed to RESTRICT',
        );

        // Verify foreign key integrity
        return await SafeTableRebuild.verifyForeignKeyIntegrity(db, 'harvests');
      },
    );

    AppLogger.info('Migration_v36', '  ✅ harvests table rebuilt successfully');

    // ===========================================
    // STEP 2: Rebuild hardware table
    // ===========================================
    AppLogger.info(
      'Migration_v36',
      '📝 Step 2/2: Rebuilding hardware table (CASCADE → RESTRICT)',
    );

    await SafeTableRebuild.rebuildTable(
      txn,
      tableName: 'hardware',
      newTableDdl: '''
        CREATE TABLE hardware_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          brand TEXT,
          model TEXT,
          wattage INTEGER,
          quantity INTEGER DEFAULT 1,
          airflow INTEGER,
          spectrum TEXT,
          color_temperature TEXT,
          dimmable INTEGER,
          flange_size TEXT,
          controllable INTEGER,
          oscillating INTEGER,
          diameter INTEGER,
          cooling_power INTEGER,
          heating_power INTEGER,
          coverage REAL,
          has_thermostat INTEGER,
          humidification_rate INTEGER,
          pump_rate INTEGER,
          is_digital INTEGER,
          program_count INTEGER,
          dripper_count INTEGER,
          capacity INTEGER,
          material TEXT,
          has_chiller INTEGER,
          has_air_pump INTEGER,
          filter_diameter TEXT,
          filter_length INTEGER,
          controller_type TEXT,
          output_count INTEGER,
          controller_functions TEXT,
          specifications TEXT,
          purchase_date TEXT,
          purchase_price REAL,
          notes TEXT,
          active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT (datetime('now')),
          FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE RESTRICT
        )
      ''',
      dataMigration: '''
        INSERT INTO hardware_new (
          id, room_id, name, type, brand, model, wattage, quantity,
          airflow, spectrum, color_temperature, dimmable, flange_size,
          controllable, oscillating, diameter, cooling_power, heating_power,
          coverage, has_thermostat, humidification_rate, pump_rate,
          is_digital, program_count, dripper_count, capacity, material,
          has_chiller, has_air_pump, filter_diameter, filter_length,
          controller_type, output_count, controller_functions, specifications,
          purchase_date, purchase_price, notes, active, created_at
        )
        SELECT
          id, room_id, name, type, brand, model, wattage, quantity,
          airflow, spectrum, color_temperature, dimmable, flange_size,
          controllable, oscillating, diameter, cooling_power, heating_power,
          coverage, has_thermostat, humidification_rate, pump_rate,
          is_digital, program_count, dripper_count, capacity, material,
          has_chiller, has_air_pump, filter_diameter, filter_length,
          controller_type, output_count, controller_functions, specifications,
          purchase_date, purchase_price, notes, active, created_at
        FROM hardware
      ''',
      indexes: [
        'CREATE INDEX idx_hardware_room ON hardware(room_id)',
        'CREATE INDEX idx_hardware_type ON hardware(type)',
        'CREATE INDEX idx_hardware_active ON hardware(active)',
      ],
      validateAfter: (db) async {
        // Verify FK constraint changed to RESTRICT
        final fkCheck = await db.rawQuery('PRAGMA foreign_key_list(hardware)');
        final roomIdFk = fkCheck.firstWhere(
          (fk) => fk['from'] == 'room_id',
          orElse: () => throw Exception('FK constraint on room_id not found'),
        );

        if (roomIdFk['on_delete'] != 'RESTRICT') {
          AppLogger.error(
            'Migration_v36',
            'FK constraint validation failed: '
            'expected RESTRICT, got ${roomIdFk['on_delete']}',
          );
          return false;
        }

        AppLogger.info(
          'Migration_v36',
          '  ✅ hardware.room_id FK changed to RESTRICT',
        );

        // Verify foreign key integrity
        return await SafeTableRebuild.verifyForeignKeyIntegrity(db, 'hardware');
      },
    );

    AppLogger.info('Migration_v36', '  ✅ hardware table rebuilt successfully');

    // ===========================================
    // STEP 3: Final Validation
    // ===========================================
    AppLogger.info('Migration_v36', '🔍 Step 3/3: Final validation');

    // Check database integrity
    final integrityCheck = await txn.rawQuery('PRAGMA integrity_check');
    final result = integrityCheck.first['integrity_check'];
    if (result != 'ok') {
      throw Exception('Database integrity check failed after v36: $result');
    }

    AppLogger.info('Migration_v36', '  ✅ Database integrity check passed');

    // Get data counts to confirm no data loss
    final harvestsCount = await txn.rawQuery('SELECT COUNT(*) as count FROM harvests');
    final hardwareCount = await txn.rawQuery('SELECT COUNT(*) as count FROM hardware');

    AppLogger.info(
      'Migration_v36',
      '  ✅ Data preserved: '
          '${harvestsCount.first['count']} harvests, '
          '${hardwareCount.first['count']} hardware items',
    );

    // Verify FK constraints on both tables
    final harvestsFkCheck = await txn.rawQuery('PRAGMA foreign_key_check(harvests)');
    final hardwareFkCheck = await txn.rawQuery('PRAGMA foreign_key_check(hardware)');

    if (harvestsFkCheck.isNotEmpty) {
      throw Exception('Foreign key violations in harvests: $harvestsFkCheck');
    }

    if (hardwareFkCheck.isNotEmpty) {
      throw Exception('Foreign key violations in hardware: $hardwareFkCheck');
    }

    AppLogger.info('Migration_v36', '  ✅ Foreign key constraints validated');

    AppLogger.info(
      'Migration_v36',
      '✅✅✅ Migration v36 complete: FK CASCADE rules standardized',
    );
    AppLogger.info(
      'Migration_v36',
      '🎊 Database policy: Entity FKs use RESTRICT (prevent data loss)',
    );
  },
);
