// =============================================
// Manual Test Script for v34→v35 Migration
// Run this to verify the migration works correctly
// =============================================

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:growlog_app/database/migrations/scripts/migration_v35.dart';

Future<void> main() async {
  print('═══════════════════════════════════════════════════════');
  print('TESTING v34→v35 DATABASE MIGRATION');
  print('═══════════════════════════════════════════════════════\n');

  // Initialize FFI for desktop testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Create a temporary database directory
  final tempDir = Directory.systemTemp.createTempSync('growlog_v34_test_');
  final dbPath = p.join(tempDir.path, 'test_v34.db');

  print('📁 Test database location: $dbPath\n');

  try {
    // STEP 1: Create a database with v34 schema
    print('STEP 1: Creating simulated v34 database...');
    final db = await openDatabase(
      dbPath,
      version: 34,
      onCreate: (db, version) async {
        print('  Creating v34 schema...');
        await _createV34Schema(db);
        print('  ✅ v34 schema created');
      },
    );

    // STEP 2: Insert test data
    print('\nSTEP 2: Inserting test data...');
    await _insertTestData(db);
    print('  ✅ Test data inserted');

    // STEP 3: Verify data before migration
    print('\nSTEP 3: Verifying data before migration...');
    final countsBefore = await _getDataCounts(db);
    print('  📊 Data counts BEFORE migration:');
    countsBefore.forEach((table, count) {
      print('     - $table: $count records');
    });

    // Close the database
    await db.close();

    // STEP 4: Reopen database and run migration v34→v35
    print('\nSTEP 4: Reopening database and running v34→v35 migration...');
    final db2 = await openDatabase(
      dbPath,
      version: 35,
      onUpgrade: (db, oldVersion, newVersion) async {
        print('  Upgrading from v$oldVersion to v$newVersion');
        if (oldVersion == 34 && newVersion == 35) {
          await migrationV35.up(db);
        }
      },
    );

    // STEP 5: Verify data after migration
    print('\nSTEP 5: Verifying data after migration...');
    final countsAfter = await _getDataCounts(db2);
    print('  📊 Data counts AFTER migration:');
    countsAfter.forEach((table, count) {
      print('     - $table: $count records');
    });

    // STEP 6: Compare data counts
    print('\nSTEP 6: Comparing data counts...');
    bool dataLoss = false;
    for (final table in countsBefore.keys) {
      final before = countsBefore[table]!;
      final after = countsAfter[table]!;
      if (before != after) {
        print('  ❌ DATA LOSS in $table: $before → $after');
        dataLoss = true;
      } else {
        print('  ✅ $table: No data loss ($before records preserved)');
      }
    }

    // STEP 7: Verify schema
    print('\nSTEP 7: Verifying schema...');
    final integrityCheck = await db2.rawQuery('PRAGMA integrity_check');
    final result = integrityCheck.first['integrity_check'];
    if (result == 'ok') {
      print('  ✅ Database integrity check PASSED');
    } else {
      print('  ❌ Database integrity check FAILED: $result');
    }

    // STEP 8: Verify all critical tables exist
    print('\nSTEP 8: Verifying critical tables...');
    final criticalTables = [
      'rooms', 'grows', 'plants', 'plant_logs', 'photos', 'harvests',
      'fertilizers', 'log_fertilizers', 'rdwc_systems', 'rdwc_logs',
      'hardware', 'app_settings',
    ];

    bool allTablesExist = true;
    for (final table in criticalTables) {
      final result = await db2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      if (result.isEmpty) {
        print('  ❌ Table missing: $table');
        allTablesExist = false;
      }
    }

    if (allTablesExist) {
      print('  ✅ All critical tables exist');
    }

    // STEP 9: Verify added columns
    print('\nSTEP 9: Verifying added columns...');

    // Check rooms.archived
    final roomsColumns = await db2.rawQuery('PRAGMA table_info(rooms)');
    final hasRoomsArchived = roomsColumns.any((col) => col['name'] == 'archived');
    print('  ${hasRoomsArchived ? "✅" : "❌"} rooms.archived column');

    // Check rdwc_logs.archived
    final rdwcLogsColumns = await db2.rawQuery('PRAGMA table_info(rdwc_logs)');
    final hasRdwcLogsArchived = rdwcLogsColumns.any((col) => col['name'] == 'archived');
    print('  ${hasRdwcLogsArchived ? "✅" : "❌"} rdwc_logs.archived column');

    // Check plants.veg_date, bloom_date, harvest_date
    final plantsColumns = await db2.rawQuery('PRAGMA table_info(plants)');
    final plantsColNames = plantsColumns.map((col) => col['name'] as String).toSet();
    print('  ${plantsColNames.contains("veg_date") ? "✅" : "❌"} plants.veg_date column');
    print('  ${plantsColNames.contains("bloom_date") ? "✅" : "❌"} plants.bloom_date column');
    print('  ${plantsColNames.contains("harvest_date") ? "✅" : "❌"} plants.harvest_date column');

    // STEP 10: Final verdict
    print('\n═══════════════════════════════════════════════════════');
    if (!dataLoss && allTablesExist && result == 'ok') {
      print('✅✅✅ MIGRATION TEST PASSED ✅✅✅');
      print('═══════════════════════════════════════════════════════');
      print('\nThe v34→v35 migration is working correctly!');
      print('✓ No data loss');
      print('✓ All tables present');
      print('✓ Database integrity verified');
      print('\n🎉 READY FOR PRODUCTION DEPLOYMENT 🎉');
    } else {
      print('❌❌❌ MIGRATION TEST FAILED ❌❌❌');
      print('═══════════════════════════════════════════════════════');
      print('\n⚠️ DO NOT DEPLOY! Fix issues above first.');
    }

    await db2.close();
  } catch (e, stackTrace) {
    print('\n❌ ERROR during migration test:');
    print(e);
    print('\nStack trace:');
    print(stackTrace);
  } finally {
    // Cleanup
    print('\n🧹 Cleaning up test database...');
    try {
      tempDir.deleteSync(recursive: true);
      print('✅ Cleanup complete');
    } catch (e) {
      print('⚠️ Cleanup warning: $e');
    }
  }
}

/// Create a minimal v34 schema (simulating production v34 databases)
Future<void> _createV34Schema(Database db) async {
  // This is a simplified v34 schema that represents what users might have
  // It's missing some columns that v35 will add

  await db.execute('''
    CREATE TABLE rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      grow_type TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE grows (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      start_date TEXT NOT NULL,
      archived INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE plants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      strain TEXT,
      seed_type TEXT NOT NULL,
      medium TEXT NOT NULL,
      phase TEXT DEFAULT 'SEEDLING',
      room_id INTEGER,
      grow_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      archived INTEGER DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE plant_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plant_id INTEGER NOT NULL,
      day_number INTEGER NOT NULL,
      log_date TEXT NOT NULL,
      action_type TEXT NOT NULL,
      note TEXT,
      archived INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id INTEGER NOT NULL,
      file_path TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE harvests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plant_id INTEGER NOT NULL,
      harvest_date TEXT NOT NULL,
      wet_weight REAL,
      dry_weight REAL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT,
      npk TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE log_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL
    )
  ''');

  await db.execute('''
    CREATE TABLE rdwc_systems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      max_capacity REAL NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      archived INTEGER DEFAULT 0
    )
  ''');

  // Missing archived column (v35 will add it)
  await db.execute('''
    CREATE TABLE rdwc_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      system_id INTEGER NOT NULL,
      log_date TEXT DEFAULT (datetime('now')),
      log_type TEXT NOT NULL,
      note TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE rdwc_log_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rdwc_log_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      amount_type TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE rdwc_recipes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE rdwc_recipe_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recipe_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      ml_per_liter REAL NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE hardware (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE log_templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      action_type TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  await db.execute('''
    CREATE TABLE template_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      template_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT,
      updated_at TEXT DEFAULT (datetime('now'))
    )
  ''');
}

/// Insert test data to verify preservation during migration
Future<void> _insertTestData(Database db) async {
  await db.insert('rooms', {'name': 'Test Room 1', 'grow_type': 'INDOOR'});
  await db.insert('rooms', {'name': 'Test Room 2', 'grow_type': 'OUTDOOR'});

  await db.insert('grows', {'name': 'Test Grow 1', 'start_date': '2024-01-01'});

  await db.insert('plants', {
    'name': 'Test Plant 1',
    'strain': 'Test Strain',
    'seed_type': 'PHOTO',
    'medium': 'ERDE',
    'room_id': 1,
    'grow_id': 1,
  });

  await db.insert('plants', {
    'name': 'Test Plant 2',
    'strain': 'Another Strain',
    'seed_type': 'AUTO',
    'medium': 'COCO',
    'room_id': 2,
    'grow_id': 1,
  });

  await db.insert('plant_logs', {
    'plant_id': 1,
    'day_number': 1,
    'log_date': '2024-01-01',
    'action_type': 'WATER',
    'note': 'First watering',
  });

  await db.insert('photos', {
    'log_id': 1,
    'file_path': '/test/photo1.jpg',
  });

  await db.insert('harvests', {
    'plant_id': 1,
    'harvest_date': '2024-05-01',
    'wet_weight': 500.0,
  });
}

/// Get data counts for verification
Future<Map<String, int>> _getDataCounts(Database db) async {
  final counts = <String, int>{};

  final tables = ['rooms', 'grows', 'plants', 'plant_logs', 'photos', 'harvests'];

  for (final table in tables) {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    counts[table] = result.first['count'] as int;
  }

  return counts;
}
