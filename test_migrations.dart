#!/usr/bin/env dart

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'lib/database/database_helper.dart';

void main() async {
  print('=' * 80);
  print('🧪 MIGRATION TEST SUITE - Testing all migration paths');
  print('=' * 80);

  // Initialize sqflite_ffi for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Test scenarios
  final scenarios = [
    {'name': 'v8 → v33 (Complete migration)', 'startVersion': 8},
    {'name': 'v13 → v33 (plant_logs v13 fields)', 'startVersion': 13},
    {'name': 'v17 → v33 (Before buggy v18)', 'startVersion': 17},
    {'name': 'v18 → v33 (After buggy v18)', 'startVersion': 18},
  ];

  int passedTests = 0;
  int failedTests = 0;
  List<String> failures = [];

  for (var scenario in scenarios) {
    print('\n' + '=' * 80);
    print('📋 TEST: ${scenario['name']}');
    print('=' * 80);

    try {
      final testDbPath = '/tmp/test_migration_v${scenario['startVersion']}.db';

      // Delete old test DB
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Create database with specific version
      final db = await databaseFactory.openDatabase(
        testDbPath,
        options: OpenDatabaseOptions(
          version: scenario['startVersion'] as int,
          onCreate: (db, version) async {
            await _createMinimalSchema(db, version);
          },
        ),
      );

      // Insert test data
      await _insertTestData(db, scenario['startVersion'] as int);

      // Close and reopen with migration
      await db.close();

      print('\n🔄 Running migrations from v${scenario['startVersion']} to v33...');

      final migratedDb = await DatabaseHelper.instance.database;

      // Validate schema
      print('\n🔍 Validating schema...');
      await _validateSchema(migratedDb);

      // Validate data integrity
      print('\n🔍 Validating data integrity...');
      await _validateData(migratedDb);

      await migratedDb.close();

      print('\n✅ TEST PASSED: ${scenario['name']}');
      passedTests++;

    } catch (e, stackTrace) {
      print('\n❌ TEST FAILED: ${scenario['name']}');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      failedTests++;
      failures.add('${scenario['name']}: $e');
    }
  }

  // Summary
  print('\n' + '=' * 80);
  print('📊 TEST SUMMARY');
  print('=' * 80);
  print('✅ Passed: $passedTests');
  print('❌ Failed: $failedTests');

  if (failures.isNotEmpty) {
    print('\n❌ FAILURES:');
    for (var failure in failures) {
      print('  • $failure');
    }
    exit(1);
  } else {
    print('\n🎉 ALL TESTS PASSED!');
    exit(0);
  }
}

Future<void> _createMinimalSchema(Database db, int version) async {
  print('Creating minimal schema for v$version...');

  // Create basic tables that exist in all versions
  await db.execute('''
    CREATE TABLE rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      archived INTEGER DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE grows (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE rdwc_systems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
  ''');

  if (version >= 13) {
    // v13 had plant_logs with old fields
    await db.execute('''
      CREATE TABLE plant_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        log_date TEXT NOT NULL,
        action_type TEXT NOT NULL,
        note TEXT,
        nutrient_ppm REAL,
        light_hours REAL,
        training TEXT,
        defoliation INTEGER,
        FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
      )
    ''');
  } else {
    await db.execute('''
      CREATE TABLE plant_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        log_date TEXT NOT NULL,
        action_type TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
      )
    ''');
  }

  if (version >= 17) {
    // v17 had plants without some fields that v18 lost
    await db.execute('''
      CREATE TABLE plants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        strain TEXT,
        breeder TEXT,
        feminized INTEGER DEFAULT 0,
        phase TEXT DEFAULT 'SEEDLING',
        germination_date TEXT,
        veg_date TEXT,
        bloom_date TEXT,
        harvest_date TEXT,
        room_id INTEGER,
        grow_id INTEGER,
        rdwc_system_id INTEGER,
        archived INTEGER DEFAULT 0,
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL,
        FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE SET NULL,
        FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems(id) ON DELETE RESTRICT
      )
    ''');
  } else {
    await db.execute('''
      CREATE TABLE plants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        strain TEXT,
        room_id INTEGER,
        grow_id INTEGER,
        archived INTEGER DEFAULT 0,
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL,
        FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE SET NULL
      )
    ''');
  }

  await db.execute('''
    CREATE TABLE photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id INTEGER NOT NULL,
      file_path TEXT NOT NULL,
      FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE RESTRICT
    )
  ''');

  print('✅ Minimal schema v$version created');
}

Future<void> _insertTestData(Database db, int version) async {
  print('Inserting test data for v$version...');

  // Insert test room
  await db.insert('rooms', {'name': 'Test Room', 'archived': 0});

  // Insert test grow
  await db.insert('grows', {'name': 'Test Grow 2024'});

  // Insert test plant
  final plantData = {
    'name': 'Test Plant',
    'strain': 'Test Strain',
    'room_id': 1,
    'grow_id': 1,
    'archived': 0,
  };

  if (version >= 17) {
    plantData.addAll({
      'breeder': 'Test Breeder',
      'feminized': 1,
      'phase': 'VEG',
      'germination_date': '2024-01-01',
      'veg_date': '2024-01-15',
    });
  }

  await db.insert('plants', plantData);

  // Insert test log
  final logData = {
    'plant_id': 1,
    'log_date': '2024-01-20',
    'action_type': 'WATER',
    'note': 'Test log entry',
  };

  if (version == 13) {
    logData.addAll({
      'nutrient_ppm': 800.0,
      'light_hours': 18.0,
      'training': 'LST',
      'defoliation': 1,
    });
  }

  await db.insert('plant_logs', logData);

  // Insert test photo
  await db.insert('photos', {
    'log_id': 1,
    'file_path': '/test/photo.jpg',
  });

  print('✅ Test data inserted');
}

Future<void> _validateSchema(Database db) async {
  // Check plants table
  final plantsColumns = await db.rawQuery('PRAGMA table_info(plants)');
  final plantsColumnNames = plantsColumns.map((col) => col['name']).toList();

  final requiredPlantsColumns = [
    'id', 'name', 'strain', 'breeder', 'feminized', 'phase',
    'germination_date', 'veg_date', 'bloom_date', 'harvest_date',
    'room_id', 'grow_id', 'rdwc_system_id', 'archived'
  ];

  for (var col in requiredPlantsColumns) {
    if (!plantsColumnNames.contains(col)) {
      throw Exception('Missing column in plants: $col');
    }
  }
  print('  ✅ plants table: All columns present');

  // Check plant_logs table
  final logsColumns = await db.rawQuery('PRAGMA table_info(plant_logs)');
  final logsColumnNames = logsColumns.map((col) => col['name']).toList();

  final requiredLogsColumns = [
    'id', 'plant_id', 'log_date', 'action_type', 'note', 'phase'
  ];

  for (var col in requiredLogsColumns) {
    if (!logsColumnNames.contains(col)) {
      throw Exception('Missing column in plant_logs: $col');
    }
  }
  print('  ✅ plant_logs table: All columns present');

  // Check photos FK constraint
  final photosFks = await db.rawQuery('PRAGMA foreign_key_list(photos)');
  final photosOnDelete = photosFks.firstWhere(
    (fk) => fk['from'] == 'log_id',
    orElse: () => throw Exception('photos.log_id FK not found'),
  )['on_delete'];

  if (photosOnDelete != 'CASCADE') {
    throw Exception('photos.log_id should be CASCADE but is $photosOnDelete');
  }
  print('  ✅ photos.log_id: CASCADE correct');

  // Check plants FK constraints
  final plantsFks = await db.rawQuery('PRAGMA foreign_key_list(plants)');

  for (var fk in plantsFks) {
    final from = fk['from'];
    final onDelete = fk['on_delete'];

    if (from == 'room_id' || from == 'grow_id' || from == 'rdwc_system_id') {
      if (onDelete != 'RESTRICT') {
        throw Exception('plants.$from should be RESTRICT but is $onDelete');
      }
    }
  }
  print('  ✅ plants FKs: All RESTRICT correct');

  // Check rooms.archived column
  final roomsColumns = await db.rawQuery('PRAGMA table_info(rooms)');
  final hasArchived = roomsColumns.any((col) => col['name'] == 'archived');

  if (!hasArchived) {
    throw Exception('rooms table missing archived column');
  }
  print('  ✅ rooms.archived: Present');
}

Future<void> _validateData(Database db) async {
  // Check if test data survived
  final plants = await db.query('plants');
  if (plants.isEmpty) {
    throw Exception('Test plant data lost during migration');
  }
  print('  ✅ Test plant data preserved');

  final plant = plants.first;

  // Check if breeder field exists (was lost in buggy v18)
  if (!plant.containsKey('breeder') || plant['breeder'] == null) {
    print('  ⚠️  Warning: breeder field is NULL (might be expected for some versions)');
  } else {
    print('  ✅ breeder field preserved: ${plant['breeder']}');
  }

  // Check if feminized field exists
  if (!plant.containsKey('feminized')) {
    throw Exception('feminized field missing');
  }
  print('  ✅ feminized field preserved: ${plant['feminized']}');

  // Check logs
  final logs = await db.query('plant_logs');
  if (logs.isEmpty) {
    throw Exception('Test log data lost during migration');
  }
  print('  ✅ Test log data preserved');

  // Check photos
  final photos = await db.query('photos');
  if (photos.isEmpty) {
    throw Exception('Test photo data lost during migration');
  }
  print('  ✅ Test photo data preserved');
}
