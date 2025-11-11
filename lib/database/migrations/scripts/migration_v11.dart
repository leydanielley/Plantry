// =============================================
// GROWLOG - Migration v10 → v11
// Fertilizer Model Extension for HydroBuddy Import
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v11: Fertilizer Model Extension
///
/// PROBLEM:
/// - Fertilizer model only has basic NPK string ("13-0-38")
/// - No detailed nutrient composition (micronutrients, separated N forms)
/// - Cannot import HydroBuddy database with full nutrient profiles
///
/// LÖSUNG:
/// - Add detailed nutrient composition fields:
///   • formula, source, purity, isLiquid, density
///   • Separated nitrogen forms: nNO3, nNH4
///   • Individual macronutrients: p, k, mg, ca, s
///   • Micronutrients: b, fe, zn, cu, mn, mo, na, si, cl
///
/// SICHERHEIT:
/// - All new fields are nullable (backward compatible)
/// - Existing fertilizers remain unchanged
/// - No data migration needed
/// - Automatic backup by MigrationManager
final Migration migrationV11 = Migration(
  version: 11,
  description: 'Fertilizer Model Extension for HydroBuddy Import',
  up: (DatabaseExecutor txn) async {
    AppLogger.info(
      'Migration_v11',
      '🧪 Starting Fertilizer Extension Migration',
      'Adding detailed nutrient composition fields',
    );

    // ================================================================
    // STEP 1: Add metadata fields
    // ================================================================

    AppLogger.info('Migration_v11', '1/4: Adding metadata fields...');

    await txn.execute('ALTER TABLE fertilizers ADD COLUMN formula TEXT');
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN source TEXT');
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN purity REAL');
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN is_liquid INTEGER');
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN density REAL');

    AppLogger.info('Migration_v11', '✅ Metadata fields added');

    // ================================================================
    // STEP 2: Add macronutrient fields
    // ================================================================

    AppLogger.info('Migration_v11', '2/4: Adding macronutrient fields...');

    // Separated nitrogen forms
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN n_no3 REAL');  // N as Nitrate
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN n_nh4 REAL');  // N as Ammonium

    // Other macronutrients
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN p REAL');      // Phosphorus
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN k REAL');      // Potassium
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN mg REAL');     // Magnesium
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN ca REAL');     // Calcium
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN s REAL');      // Sulfur

    AppLogger.info('Migration_v11', '✅ Macronutrient fields added');

    // ================================================================
    // STEP 3: Add micronutrient fields
    // ================================================================

    AppLogger.info('Migration_v11', '3/4: Adding micronutrient fields...');

    await txn.execute('ALTER TABLE fertilizers ADD COLUMN b REAL');      // Boron
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN fe REAL');     // Iron
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN zn REAL');     // Zinc
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN cu REAL');     // Copper
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN mn REAL');     // Manganese
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN mo REAL');     // Molybdenum
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN na REAL');     // Sodium
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN si REAL');     // Silicon
    await txn.execute('ALTER TABLE fertilizers ADD COLUMN cl REAL');     // Chlorine

    AppLogger.info('Migration_v11', '✅ Micronutrient fields added');

    // ================================================================
    // STEP 4: Verification
    // ================================================================

    AppLogger.info('Migration_v11', '4/4: Verifying migration...');

    // Count existing fertilizers
    final fertCount = Sqflite.firstIntValue(
      await txn.rawQuery('SELECT COUNT(*) FROM fertilizers'),
    ) ?? 0;

    AppLogger.info('Migration_v11', '📊 Statistics:');
    AppLogger.info('Migration_v11', '  - Existing fertilizers: $fertCount');
    AppLogger.info('Migration_v11', '  - New fields added: 22 (5 metadata + 7 macro + 9 micro + 1 flag)');

    // Verify schema
    final tableInfo = await txn.rawQuery('PRAGMA table_info(fertilizers)');
    final columnNames = tableInfo.map((col) => col['name'] as String).toList();

    AppLogger.info('Migration_v11', '🔍 Verifying new columns exist:');

    final expectedColumns = [
      'formula', 'source', 'purity', 'is_liquid', 'density',
      'n_no3', 'n_nh4', 'p', 'k', 'mg', 'ca', 's',
      'b', 'fe', 'zn', 'cu', 'mn', 'mo', 'na', 'si', 'cl',
    ];

    for (final col in expectedColumns) {
      if (columnNames.contains(col)) {
        AppLogger.debug('Migration_v11', '  ✅ $col');
      } else {
        throw Exception('Migration failed: Column $col not found!');
      }
    }

    AppLogger.info(
      'Migration_v11',
      '🎉 FERTILIZER EXTENSION COMPLETE!',
      'Ready for HydroBuddy database import',
    );
  },
);
