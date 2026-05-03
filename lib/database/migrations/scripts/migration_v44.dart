import 'package:growlog_app/database/migrations/migration.dart';

final migrationV44 = Migration(
  version: 44,
  description: 'RDWC: Add archived_at TEXT to rdwc_systems for race-Limbo prevention',
  up: (db) async {
    final cols = await db.rawQuery('PRAGMA table_info(rdwc_systems)');
    final colNames = cols.map((r) => r['name'] as String).toList();
    if (!colNames.contains('archived_at')) {
      await db.execute(
        'ALTER TABLE rdwc_systems ADD COLUMN archived_at TEXT',
      );
    }
  },
  down: (db) async {
    throw UnsupportedError(
      'migration_v44: downgrade not supported (Pre-Migration-Backup verwenden)',
    );
  },
);
