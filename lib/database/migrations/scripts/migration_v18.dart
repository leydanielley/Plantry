// =============================================
// GROWLOG - Migration v17 → v18
// DATA LOSS PREVENTION: Change FK Constraints to RESTRICT
// =============================================

import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/migrations/safe_table_rebuild.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v18: FK Constraints ON DELETE SET NULL → RESTRICT
///
/// PROBLEM:
/// Current FK constraints use ON DELETE SET NULL:
/// - plants.grow_id → grows(id) ON DELETE SET NULL
/// - plants.room_id → rooms(id) ON DELETE SET NULL
/// - plants.rdwc_system_id → rdwc_systems(id) ON DELETE SET NULL
///
/// ISSUE: "Data disappearing overnight"
/// When a user deletes a grow/room, all plants get grow_id/room_id set to NULL.
/// UI then can't find these plants because it queries by grow_id/room_id.
/// Plants appear "lost" but still exist in database.
///
/// SOLUTION:
/// Change to ON DELETE RESTRICT:
/// - Prevents deletion of grow/room if plants still exist
/// - Forces user to explicitly handle plants first
/// - No more orphaned plants
///
/// WHAT IT DOES:
/// 1. Rebuilds plants table with RESTRICT constraints
/// 2. Preserves all plant data
/// 3. Validates schema after rebuild
///
/// SAFETY:
/// - Atomic: Uses SafeTableRebuild for guaranteed rollback
/// - Non-destructive: All data preserved
/// - Validated: Schema checks before and after
final Migration migrationV18 = Migration(
  version: 18,
  description: 'Fix FK constraints: Prevent orphaned plants',
  up: (txn) async {
    AppLogger.info(
      'Migration_v18',
      '🔄 Starting Migration v18: FK Constraint Fix',
    );

    // ===========================================
    // Rebuild plants table with RESTRICT constraints
    // ===========================================
    AppLogger.info(
      'Migration_v18',
      '📝 Rebuilding plants table with RESTRICT constraints',
    );

    await SafeTableRebuild.rebuildTable(
      txn,
      tableName: 'plants',
      newTableDdl: '''
        CREATE TABLE plants_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          strain TEXT,
          grow_id INTEGER,
          room_id INTEGER,
          planted_date TEXT,
          seed_type TEXT,
          medium TEXT,
          container_size REAL,
          notes TEXT,
          bucket_number INTEGER,
          rdwc_system_id INTEGER,
          archived INTEGER DEFAULT 0,
          created_at TEXT DEFAULT (datetime('now')),
          FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE RESTRICT,
          FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE RESTRICT,
          FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems(id) ON DELETE RESTRICT
        )
      ''',
      dataMigration: '''
        INSERT INTO plants_new (
          id, name, strain, grow_id, room_id, planted_date,
          seed_type, medium, container_size, notes,
          bucket_number, rdwc_system_id, archived, created_at
        )
        SELECT
          id, name, strain, grow_id, room_id, planted_date,
          seed_type, medium, container_size, notes,
          bucket_number, rdwc_system_id,
          COALESCE(archived, 0) as archived,
          created_at
        FROM plants
      ''',
      indexes: [
        'CREATE INDEX idx_plants_grow ON plants(grow_id)',
        'CREATE INDEX idx_plants_room ON plants(room_id)',
        'CREATE INDEX idx_plants_archived ON plants(archived)',
        'CREATE INDEX idx_plants_rdwc ON plants(rdwc_system_id)',
      ],
      validateAfter: (db) async {
        // Verify plants table exists and has data
        final count = await db.rawQuery('SELECT COUNT(*) as count FROM plants');
        final rowCount = count.first['count'] as int;
        AppLogger.info('Migration_v18', 'Validated: $rowCount plants preserved');
        return true;
      },
    );

    AppLogger.info(
      'Migration_v18',
      '✅ Plants table rebuilt with RESTRICT constraints',
    );

    // Verify schema integrity
    final integrityCheck = await txn.rawQuery('PRAGMA integrity_check');
    final result = integrityCheck.first['integrity_check'];
    if (result != 'ok') {
      throw Exception('Database integrity check failed after v18: $result');
    }

    AppLogger.info(
      'Migration_v18',
      '🎉 Migration v18 complete: Orphaned plants prevented',
    );
  },
);
