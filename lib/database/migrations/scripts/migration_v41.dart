import 'package:growlog_app/database/migrations/migration.dart';

final migrationV41 = Migration(
  version: 41,
  description: 'Add light_watts to rooms table for g/W yield calculation',
  up: (db) async {
    final columns = await db.rawQuery('PRAGMA table_info(rooms)');
    final colNames = columns.map((r) => r['name'] as String).toList();
    if (!colNames.contains('light_watts')) {
      await db.execute('ALTER TABLE rooms ADD COLUMN light_watts INTEGER');
    }
  },
  down: (db) async {
    // SQLite doesn't support DROP COLUMN easily — left intentionally empty
  },
);
