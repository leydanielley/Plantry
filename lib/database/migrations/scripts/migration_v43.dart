import 'package:growlog_app/database/migrations/migration.dart';

final migrationV43 = Migration(
  version: 43,
  description: 'Recipes: Add phase column to rdwc_recipes',
  up: (db) async {
    final cols = await db.rawQuery('PRAGMA table_info(rdwc_recipes)');
    final colNames = cols.map((r) => r['name'] as String).toList();
    if (!colNames.contains('phase')) {
      await db.execute('ALTER TABLE rdwc_recipes ADD COLUMN phase TEXT');
    }
  },
  down: (db) async {},
);
