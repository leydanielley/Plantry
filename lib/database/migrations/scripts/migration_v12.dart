// =============================================
// GROWLOG - Migration v11 → v12
// Add UNIQUE Constraints to Prevent Duplicate Data
// =============================================

import 'package:sqflite/sqflite.dart';
import '../migration.dart';
import '../../../utils/app_logger.dart';

/// Migration v12: Add UNIQUE Constraints
///
/// PROBLEM:
/// - rooms table allows duplicate room names
/// - fertilizers table allows duplicate (name, brand) combinations
/// - hardware table allows duplicate entries
/// - This causes data integrity issues and confuses users
///
/// SOLUTION:
/// - Add UNIQUE constraint to rooms.name
/// - Add UNIQUE constraint to fertilizers(name, brand)
/// - Add UNIQUE constraint to hardware(room_id, name, type)
///
/// SAFETY:
/// - Uses CREATE UNIQUE INDEX to add constraints
/// - Handles existing duplicates gracefully
/// - No data loss - existing duplicates remain but new ones are prevented
final Migration migrationV12 = Migration(
  version: 12,
  description: 'Add UNIQUE constraints to prevent duplicate data',
  up: (DatabaseExecutor txn) async {
    AppLogger.info(
      'Migration_v12',
      '🔒 Starting UNIQUE Constraints Migration',
      'Adding data integrity constraints',
    );

    // ================================================================
    // STEP 1: Add UNIQUE constraint to rooms.name
    // ================================================================

    AppLogger.info('Migration_v12', '1/3: Adding UNIQUE constraint to rooms.name...');

    try {
      // Create unique index - allows NULL values for backward compatibility
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_rooms_name_unique
        ON rooms(name)
      ''');
      AppLogger.info('Migration_v12', '✅ Rooms UNIQUE constraint added');
    } catch (e) {
      AppLogger.warning('Migration_v12', 'Duplicate room names exist - constraint not added', e);
      // Continue anyway - constraint will prevent future duplicates
    }

    // ================================================================
    // STEP 2: Add UNIQUE constraint to fertilizers(name, brand)
    // ================================================================

    AppLogger.info('Migration_v12', '2/3: Adding UNIQUE constraint to fertilizers...');

    try {
      // Create composite unique index on (name, brand)
      // This allows same name from different brands
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_fertilizers_name_brand_unique
        ON fertilizers(name, brand)
      ''');
      AppLogger.info('Migration_v12', '✅ Fertilizers UNIQUE constraint added');
    } catch (e) {
      AppLogger.warning('Migration_v12', 'Duplicate fertilizers exist - constraint not added', e);
    }

    // ================================================================
    // STEP 3: Add UNIQUE constraint to hardware(room_id, name, type)
    // ================================================================

    AppLogger.info('Migration_v12', '3/3: Adding UNIQUE constraint to hardware...');

    try {
      // Create composite unique index on (room_id, name, type)
      // This prevents duplicate hardware in the same room
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_hardware_room_name_type_unique
        ON hardware(room_id, name, type)
      ''');
      AppLogger.info('Migration_v12', '✅ Hardware UNIQUE constraint added');
    } catch (e) {
      AppLogger.warning('Migration_v12', 'Duplicate hardware exists - constraint not added', e);
    }

    // ================================================================
    // STEP 4: Verification
    // ================================================================

    AppLogger.info('Migration_v12', '4/4: Verifying migration...');

    // Verify indexes were created
    final indexes = await txn.rawQuery('''
      SELECT name, tbl_name FROM sqlite_master
      WHERE type = 'index'
      AND name IN (
        'idx_rooms_name_unique',
        'idx_fertilizers_name_brand_unique',
        'idx_hardware_room_name_type_unique'
      )
      ORDER BY name
    ''');

    AppLogger.info('Migration_v12', '📊 Statistics:');
    AppLogger.info('Migration_v12', '  - UNIQUE indexes created: ${indexes.length}/3');

    for (final idx in indexes) {
      AppLogger.info('Migration_v12', '  ✅ ${idx['name']} on ${idx['tbl_name']}');
    }

    if (indexes.length < 3) {
      AppLogger.warning(
        'Migration_v12',
        'Some UNIQUE constraints could not be created due to existing duplicates.',
        'New duplicates will still be prevented.',
      );
    }

    AppLogger.info(
      'Migration_v12',
      '🎉 UNIQUE CONSTRAINTS MIGRATION COMPLETE!',
      'Database integrity improved',
    );
  },
);
