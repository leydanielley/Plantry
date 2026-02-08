// =============================================
// GROWLOG - Migration v37 Tests
// Tests for migration v36 → v37 (Add Missing Indexes)
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/database/migrations/scripts/migration_v37.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/repositories/fertilizer_repository.dart';

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration v36 → v37: Add Missing Indexes', () {
    late Database db;

    setUp(() async {
      // Create an in-memory database for testing
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create a v36 database structure (without fertilizers.name index)
          await _createV36Schema(db);
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Migration v37 succeeds on v36 database', () async {
      // Act: Run migration
      await migrationV37.up(db);

      // Assert: No exception thrown
      expect(true, true, reason: 'Migration should complete without errors');
    });

    test('fertilizers.name index is created', () async {
      // Arrange: Run migration
      await migrationV37.up(db);

      // Act: Query indexes on fertilizers table
      final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND tbl_name = 'fertilizers'
      ''');

      final indexNames = indexes.map((row) => row['name'] as String).toList();

      // Assert
      expect(indexNames, contains('idx_fertilizers_name'),
          reason: 'idx_fertilizers_name should exist');
    });

    test('fertilizers.name index has correct definition', () async {
      // Arrange: Run migration
      await migrationV37.up(db);

      // Act: Query index definition
      final indexDef = await db.rawQuery('''
        SELECT sql FROM sqlite_master
        WHERE type = 'index' AND name = 'idx_fertilizers_name'
      ''');

      // Assert
      expect(indexDef, isNotEmpty, reason: 'Index should exist');
      final sql = (indexDef.first['sql'] as String).toLowerCase();
      expect(sql, contains('fertilizers'), reason: 'Index should be on fertilizers table');
      expect(sql, contains('name'), reason: 'Index should be on name column');
    });

    test('Migration is idempotent (can run multiple times)', () async {
      // Arrange: Run migration first time
      await migrationV37.up(db);

      // Act: Run migration again
      await migrationV37.up(db);

      // Assert: No exception thrown
      expect(true, true, reason: 'Migration should be idempotent');

      // Verify index still exists
      final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND tbl_name = 'fertilizers'
      ''');

      final indexNames = indexes.map((row) => row['name'] as String).toList();
      expect(indexNames, contains('idx_fertilizers_name'));
    });

    test('Existing fertilizers data is preserved', () async {
      // Arrange: Insert test fertilizer before migration
      await db.insert('fertilizers', {
        'name': 'Test Fertilizer',
        'brand': 'Test Brand',
        'npk': '10-10-10',
        'is_liquid': 1,
      });

      // Act: Run migration
      await migrationV37.up(db);

      // Assert: Data still exists
      final fertilizers = await db.query('fertilizers', where: 'name = ?', whereArgs: ['Test Fertilizer']);
      expect(fertilizers, isNotEmpty, reason: 'Fertilizer data should be preserved');
      expect(fertilizers.first['brand'], 'Test Brand');
    });

    test('FertilizerRepository queries work after migration', () async {
      // Arrange: Set up database and run migration
      DatabaseHelper.setTestDatabase(db);
      await migrationV37.up(db);

      final repo = FertilizerRepository();

      // Insert test fertilizers
      await repo.save(Fertilizer(name: 'Zinc', brand: 'Brand A'));
      await repo.save(Fertilizer(name: 'Calcium', brand: 'Brand B'));
      await repo.save(Fertilizer(name: 'Nitrogen', brand: 'Brand C'));

      // Act: Query with ORDER BY name (uses index)
      final fertilizers = await repo.findAll();

      // Assert: Results are sorted by name
      expect(fertilizers.length, 3);
      expect(fertilizers[0].name, 'Calcium', reason: 'Should be sorted alphabetically');
      expect(fertilizers[1].name, 'Nitrogen');
      expect(fertilizers[2].name, 'Zinc');

      DatabaseHelper.setTestDatabase(null);
    });

    test('Database integrity check passes after migration', () async {
      // Arrange: Run migration
      await migrationV37.up(db);

      // Act: Run integrity check
      final result = await db.rawQuery('PRAGMA integrity_check');

      // Assert
      expect(result, isNotEmpty);
      expect(result.first['integrity_check'], 'ok',
          reason: 'Database integrity should be ok');
    });

    test('Migration works with empty fertilizers table', () async {
      // Arrange: Ensure table is empty
      await db.delete('fertilizers');

      // Act: Run migration
      await migrationV37.up(db);

      // Assert: Index created even with empty table
      final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND tbl_name = 'fertilizers'
      ''');

      final indexNames = indexes.map((row) => row['name'] as String).toList();
      expect(indexNames, contains('idx_fertilizers_name'));
    });
  });
}

/// Creates a v36 schema for testing
/// This simulates the database state before v37 migration
/// (without fertilizers.name index)
Future<void> _createV36Schema(Database db) async {
  // Fertilizers Table (WITHOUT name index - simulating v36)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT,
      npk TEXT,
      type TEXT,
      description TEXT,
      ec_value REAL,
      ppm_value REAL,
      formula TEXT,
      source TEXT,
      purity REAL,
      is_liquid INTEGER DEFAULT 1,
      density REAL,
      n_no3 REAL,
      n_nh4 REAL,
      p REAL,
      k REAL,
      mg REAL,
      ca REAL,
      s REAL,
      b REAL,
      fe REAL,
      zn REAL,
      cu REAL,
      mn REAL,
      mo REAL,
      na REAL,
      si REAL,
      cl REAL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Note: We deliberately DO NOT create the idx_fertilizers_name index here
  // This simulates the v36 state where the index is missing
}
