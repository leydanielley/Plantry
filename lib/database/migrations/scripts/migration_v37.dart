// =============================================
// GROWLOG - Migration v36 → v37
// Add Missing Database Indexes for Performance
// =============================================

import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v37: Add Missing Database Indexes
///
/// PROBLEM:
/// fertilizers table has no index on the name column, which is used in ORDER BY queries.
/// This causes slower performance for fertilizer list operations.
///
/// SOLUTION:
/// Add idx_fertilizers_name index to optimize:
/// - FertilizerRepository.findAll() with ORDER BY name ASC
/// - Any UI dropdown/selection that sorts fertilizers alphabetically
///
/// IMPACT:
/// - Faster fertilizer list loading (especially noticeable with 100+ fertilizers)
/// - No data changes, just performance improvement
///
/// ✅ NON-DESTRUCTIVE: Only adds indexes, no data changes
/// ✅ IDEMPOTENT: Uses IF NOT EXISTS
/// ✅ FAST: Index creation is quick (~50ms for 1000 fertilizers)
final Migration migrationV37 = Migration(
  version: 37,
  description: 'Add fertilizers.name index for performance',
  up: (txn) async {
    AppLogger.info('Migration_v37', 'Starting migration v36 → v37...');

    // ================================================================
    // Add fertilizers.name index for ORDER BY optimization
    // ================================================================

    AppLogger.info('Migration_v37', 'Adding fertilizers.name index...');

    // This index optimizes:
    // - FertilizerRepository.findAll() with ORDER BY name ASC
    // - Any UI dropdown/selection that sorts fertilizers alphabetically
    await txn.execute('''
      CREATE INDEX IF NOT EXISTS idx_fertilizers_name
      ON fertilizers(name)
    ''');

    AppLogger.info('Migration_v37', '✅ fertilizers.name index created');

    // ================================================================
    // Verify index was created
    // ================================================================

    final indexes = await txn.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'index' AND tbl_name = 'fertilizers'
    ''');

    final indexNames = indexes.map((row) => row['name'] as String).toList();

    if (!indexNames.contains('idx_fertilizers_name')) {
      throw Exception('Failed to create idx_fertilizers_name');
    }

    AppLogger.info(
      'Migration_v37',
      '✅ Migration v36 → v37 complete! fertilizers.name index added.',
    );
  },
);
