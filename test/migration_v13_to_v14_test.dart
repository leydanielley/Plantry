// =============================================
// MIGRATION V13 → V14 SAFETY TEST
// Ensures no data loss during migration
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/migrations/scripts/migration_v14.dart';

void main() {
  late Database testDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create a v13 database with test data
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 13,
        onCreate: (db, version) async {
          await _createV13Schema(db);
          await _seedV13TestData(db);
        },
      ),
    );
    await testDb.execute('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await testDb.close();
  });

  group('Migration v13 → v14 Safety Tests', () {
    test('should preserve all plant_logs data during migration', () async {
      // Arrange: Get initial data count
      final beforeCount = Sqflite.firstIntValue(
        await testDb.rawQuery('SELECT COUNT(*) FROM plant_logs'),
      );

      expect(beforeCount, greaterThan(0), reason: 'Should have test data');

      // Get sample log to verify data integrity
      final sampleLogBefore = await testDb.query('plant_logs', limit: 1);
      expect(sampleLogBefore, isNotEmpty);

      final sampleId = sampleLogBefore.first['id'] as int;
      final sampleNote = sampleLogBefore.first['note'] as String?;

      // Act: Run migration v14
      await migrationV14.up(testDb);

      // Assert: Verify data preserved
      final afterCount = Sqflite.firstIntValue(
        await testDb.rawQuery('SELECT COUNT(*) FROM plant_logs'),
      );
      expect(afterCount, equals(beforeCount), reason: 'All logs preserved');

      // Verify specific log data integrity
      final sampleLogAfter = await testDb.query(
        'plant_logs',
        where: 'id = ?',
        whereArgs: [sampleId],
      );
      expect(sampleLogAfter, isNotEmpty);
      expect(sampleLogAfter.first['note'], equals(sampleNote));
    });

    test('should add archived column to plant_logs', () async {
      // Act
      await migrationV14.up(testDb);

      // Assert: Check if archived column exists
      final tableInfo = await testDb.rawQuery('PRAGMA table_info(plant_logs)');
      final hasArchived = tableInfo.any((col) => col['name'] == 'archived');

      expect(hasArchived, isTrue, reason: 'archived column should exist');

      // Verify default value is 0
      final logs = await testDb.query('plant_logs');
      for (final log in logs) {
        expect(log['archived'], equals(0), reason: 'Default archived = 0');
      }
    });

    test('should add archived column to rdwc_logs', () async {
      // Act
      await migrationV14.up(testDb);

      // Assert
      final tableInfo = await testDb.rawQuery('PRAGMA table_info(rdwc_logs)');
      final hasArchived = tableInfo.any((col) => col['name'] == 'archived');

      expect(hasArchived, isTrue);
    });

    test('should add archived column to rooms', () async {
      // Act
      await migrationV14.up(testDb);

      // Assert
      final tableInfo = await testDb.rawQuery('PRAGMA table_info(rooms)');
      final hasArchived = tableInfo.any((col) => col['name'] == 'archived');

      expect(hasArchived, isTrue);
    });

    test('should change plant_logs FK from CASCADE to RESTRICT', () async {
      // Act
      await migrationV14.up(testDb);

      // Assert: Try to delete a plant with logs - should fail with RESTRICT
      final plantId = await testDb.insert('plants', {
        'name': 'Test Plant',
        'seed_type': 'REGULAR',
        'medium': 'SOIL',
        'phase': 'VEG',
      });

      await testDb.insert('plant_logs', {
        'plant_id': plantId,
        'log_date': DateTime.now().toIso8601String(),
        'action_type': 'NOTE',
        'day_number': 1,
        'archived': 0,
      });

      // Should throw due to RESTRICT
      expect(
        () => testDb.delete('plants', where: 'id = ?', whereArgs: [plantId]),
        throwsA(isA<DatabaseException>()),
        reason: 'RESTRICT should prevent deletion',
      );
    });

    test('should preserve all rdwc_logs data', () async {
      // Arrange
      final beforeCount = Sqflite.firstIntValue(
        await testDb.rawQuery('SELECT COUNT(*) FROM rdwc_logs'),
      );

      // Act
      await migrationV14.up(testDb);

      // Assert
      final afterCount = Sqflite.firstIntValue(
        await testDb.rawQuery('SELECT COUNT(*) FROM rdwc_logs'),
      );
      expect(afterCount, equals(beforeCount));
    });

    test('should preserve all rooms data', () async {
      // Arrange
      final beforeCount = Sqflite.firstIntValue(
        await testDb.rawQuery('SELECT COUNT(*) FROM rooms'),
      );

      // Act
      await migrationV14.up(testDb);

      // Assert
      final afterCount = Sqflite.firstIntValue(
        await testDb.rawQuery('SELECT COUNT(*) FROM rooms'),
      );
      expect(afterCount, equals(beforeCount));
    });
  });
}

/// Creates v13 database schema
Future<void> _createV13Schema(Database db) async {
  // Rooms table (v13 - no archived column)
  await db.execute('''
    CREATE TABLE rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      grow_type TEXT,
      watering_system TEXT,
      rdwc_system_id INTEGER,
      width REAL DEFAULT 0.0,
      depth REAL DEFAULT 0.0,
      height REAL DEFAULT 0.0,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Plants table
  await db.execute('''
    CREATE TABLE plants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      breeder TEXT,
      strain TEXT,
      feminized INTEGER DEFAULT 1,
      seed_type TEXT NOT NULL,
      medium TEXT NOT NULL,
      phase TEXT DEFAULT 'SEEDLING',
      room_id INTEGER,
      grow_id INTEGER,
      rdwc_system_id INTEGER,
      bucket_number INTEGER,
      seed_date TEXT,
      phase_start_date TEXT,
      veg_date TEXT,
      bloom_date TEXT,
      harvest_date TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      created_by TEXT,
      log_profile_name TEXT DEFAULT 'standard',
      archived INTEGER DEFAULT 0,
      current_container_size REAL,
      current_system_size REAL,
      FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE SET NULL,
      FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems (id) ON DELETE SET NULL
    )
  ''');

  // Plant logs table (v13 - no archived, CASCADE DELETE)
  await db.execute('''
    CREATE TABLE plant_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plant_id INTEGER NOT NULL,
      log_date TEXT NOT NULL DEFAULT (datetime('now')),
      action_type TEXT NOT NULL,
      day_number INTEGER NOT NULL,
      phase TEXT,
      phase_day_number INTEGER,
      watering_ml REAL,
      nutrient_ppm REAL,
      nutrient_ec REAL,
      ph REAL,
      temperature REAL,
      humidity REAL,
      light_hours REAL,
      note TEXT,
      training TEXT,
      defoliation INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
    )
  ''');

  // RDWC Systems table
  await db.execute('''
    CREATE TABLE rdwc_systems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      room_id INTEGER,
      grow_id INTEGER,
      max_capacity REAL NOT NULL,
      current_level REAL NOT NULL,
      bucket_count INTEGER NOT NULL,
      description TEXT,
      archived INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE SET NULL
    )
  ''');

  // RDWC Logs table (v13 - no archived, CASCADE DELETE)
  await db.execute('''
    CREATE TABLE rdwc_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      system_id INTEGER NOT NULL,
      log_date TEXT DEFAULT (datetime('now')),
      log_type TEXT NOT NULL,
      level_before REAL,
      water_added REAL,
      level_after REAL,
      water_consumed REAL,
      ph_before REAL,
      ph_after REAL,
      ec_before REAL,
      ec_after REAL,
      note TEXT,
      logged_by TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (system_id) REFERENCES rdwc_systems(id) ON DELETE CASCADE
    )
  ''');

  // Photos table (CASCADE DELETE)
  await db.execute('''
    CREATE TABLE photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id INTEGER,
      image_path TEXT NOT NULL,
      description TEXT,
      taken_at TEXT DEFAULT (datetime('now')),
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE
    )
  ''');

  // Harvests table (CASCADE DELETE)
  await db.execute('''
    CREATE TABLE harvests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plant_id INTEGER NOT NULL,
      harvest_date TEXT NOT NULL,
      wet_weight REAL,
      dry_weight REAL,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
    )
  ''');

  // Hardware table (CASCADE DELETE)
  await db.execute('''
    CREATE TABLE hardware (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      brand TEXT,
      model TEXT,
      wattage REAL,
      purchase_date TEXT,
      active INTEGER DEFAULT 1,
      notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )
  ''');

  // Fertilizers table
  await db.execute('''
    CREATE TABLE fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT,
      type TEXT,
      npk TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Log fertilizers junction
  await db.execute('''
    CREATE TABLE log_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      unit TEXT DEFAULT 'ml',
      FOREIGN KEY (log_id) REFERENCES plant_logs (id) ON DELETE CASCADE,
      FOREIGN KEY (fertilizer_id) REFERENCES fertilizers (id) ON DELETE CASCADE
    )
  ''');

  // RDWC log fertilizers junction (CASCADE DELETE)
  await db.execute('''
    CREATE TABLE rdwc_log_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rdwc_log_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      amount_type TEXT NOT NULL,
      FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs(id) ON DELETE CASCADE,
      FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE CASCADE
    )
  ''');
}

/// Seeds v13 test data
Future<void> _seedV13TestData(Database db) async {
  // Insert test room
  final roomId = await db.insert('rooms', {
    'name': 'Test Room v13',
    'grow_type': 'INDOOR',
    'width': 2.0,
    'depth': 1.0,
    'height': 2.0,
    'updated_at': DateTime.now().toIso8601String(),
  });

  // Insert test plant
  final plantId = await db.insert('plants', {
    'name': 'Test Plant v13',
    'seed_type': 'REGULAR',
    'medium': 'SOIL',
    'phase': 'VEG',
    'room_id': roomId,
    'archived': 0,
  });

  // Insert test logs (with phase_day_number!)
  await db.insert('plant_logs', {
    'plant_id': plantId,
    'log_date': DateTime.now().toIso8601String(),
    'action_type': 'WATER',
    'day_number': 1,
    'phase': 'SEEDLING',
    'phase_day_number': 1,
    'note': 'First log',
  });

  await db.insert('plant_logs', {
    'plant_id': plantId,
    'log_date': DateTime.now().toIso8601String(),
    'action_type': 'NOTE',
    'day_number': 2,
    'phase': 'SEEDLING',
    'phase_day_number': 2,
    'note': 'Second log - THIS DATA MUST NOT BE LOST!',
  });

  // Insert RDWC system
  final systemId = await db.insert('rdwc_systems', {
    'name': 'Test RDWC System',
    'max_capacity': 100.0,
    'current_level': 80.0,
    'bucket_count': 4,
    'archived': 0,
  });

  // Insert RDWC logs
  await db.insert('rdwc_logs', {
    'system_id': systemId,
    'log_date': DateTime.now().toIso8601String(),
    'log_type': 'measurement',
    'ph_before': 6.0,
    'ec_before': 1.5,
    'note': 'RDWC test log - must be preserved',
  });
}
