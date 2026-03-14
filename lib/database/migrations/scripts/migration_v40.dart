import 'package:growlog_app/database/migrations/migration.dart';

final migrationV40 = Migration(
  version: 40,
  description: 'Add fertilizer_sets and fertilizer_set_items tables',
  up: (db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fertilizer_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fertilizer_set_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        set_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (set_id) REFERENCES fertilizer_sets(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE CASCADE
      )
    ''');
  },
  down: (db) async {
    await db.execute('DROP TABLE IF EXISTS fertilizer_set_items');
    await db.execute('DROP TABLE IF EXISTS fertilizer_sets');
  },
);
