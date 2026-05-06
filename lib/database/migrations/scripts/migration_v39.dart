import 'package:growlog_app/database/migrations/migration.dart';

final migrationV39 = Migration(
  version: 39,
  description:
      'Add is_custom and n (Total Nitrogen) columns to fertilizers table',
  up: (db) async {
    // Check if column exists first to be safe (idempotency)
    final results = await db.rawQuery('PRAGMA table_info(fertilizers)');
    final columns = results.map((row) => row['name'] as String).toList();

    if (!columns.contains('is_custom')) {
      await db.execute(
        'ALTER TABLE fertilizers ADD COLUMN is_custom INTEGER DEFAULT 0',
      );
    }
    if (!columns.contains('n')) {
      await db.execute('ALTER TABLE fertilizers ADD COLUMN n REAL');
    }
  },
  down: (db) async {
    // Lautes Fail statt silent no-op: ein leerer down() würde die DB-Version
    // zurückstellen ohne die Spalte zu entfernen → Schema-Drift. Wer wirklich
    // downgraden muss: Pre-Migration-Backup einspielen oder Tabellen-Rebuild.
    throw UnsupportedError(
      'migration_v39: downgrade not supported (ALTER TABLE DROP COLUMN nicht zuverlässig)',
    );
  },
);
