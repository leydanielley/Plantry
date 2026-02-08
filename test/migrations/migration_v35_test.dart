// =============================================
// GROWLOG - Migration v35 Test
// Tests v34→v35 healing migration
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/migrations/scripts/migration_v35.dart';

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration v35 - Healing Migration Tests', () {
    late Database db;

    setUp(() async {
      // Create an in-memory database for testing
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create a minimal v34 database structure
          // (simulating what users with v34 might have)
          await _createV34Schema(db);
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Migration v35 should succeed on v34 database', () async {
      // Run the migration
      await migrationV35.up(db);

      // Verify database version (would be set by openDatabase, not by migration)
      // But we can verify the migration completed without errors
      expect(db.isOpen, true);
    });

    test('Migration v35 should validate all critical tables exist', () async {
      // Run the migration
      await migrationV35.up(db);

      // Check that all critical tables exist
      final criticalTables = [
        'rooms',
        'grows',
        'plants',
        'plant_logs',
        'photos',
        'harvests',
        'fertilizers',
        'log_fertilizers',
        'rdwc_systems',
        'rdwc_logs',
        'rdwc_log_fertilizers',
        'rdwc_recipes',
        'rdwc_recipe_fertilizers',
        'hardware',
        'log_templates',
        'template_fertilizers',
        'app_settings',
      ];

      for (final table in criticalTables) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        expect(
          result.isNotEmpty,
          true,
          reason: 'Table $table should exist after migration',
        );
      }
    });

    test('Migration v35 should preserve existing data', () async {
      // Insert test data before migration
      await db.insert('plants', {
        'name': 'Test Plant',
        'strain': 'Test Strain',
        'seed_type': 'PHOTO',
        'medium': 'ERDE',
        'phase': 'VEG',
      });

      await db.insert('rooms', {
        'name': 'Test Room',
        'grow_type': 'INDOOR',
      });

      // Run the migration
      await migrationV35.up(db);

      // Verify data is still there
      final plants = await db.query('plants');
      expect(plants.length, 1);
      expect(plants.first['name'], 'Test Plant');

      final rooms = await db.query('rooms');
      expect(rooms.length, 1);
      expect(rooms.first['name'], 'Test Room');
    });

    test('Migration v35 should add missing archived columns', () async {
      // Run the migration
      await migrationV35.up(db);

      // Check that archived column exists in rooms
      final roomsColumns = await db.rawQuery('PRAGMA table_info(rooms)');
      final roomsColNames = roomsColumns
          .map((col) => col['name'] as String)
          .toSet();
      expect(roomsColNames.contains('archived'), true);

      // Check that archived column exists in rdwc_logs
      final rdwcLogsColumns = await db.rawQuery('PRAGMA table_info(rdwc_logs)');
      final rdwcLogsColNames = rdwcLogsColumns
          .map((col) => col['name'] as String)
          .toSet();
      expect(rdwcLogsColNames.contains('archived'), true);
    });

    test('Migration v35 should clean up orphaned photos', () async {
      // Insert a valid plant_log
      final logId = await db.insert('plant_logs', {
        'plant_id': 1,
        'day_number': 1,
        'log_date': '2024-01-01',
        'action_type': 'WATER',
      });

      // Insert a photo for the valid log
      await db.insert('photos', {
        'log_id': logId,
        'file_path': '/path/to/valid/photo.jpg',
      });

      // Insert an orphaned photo (references non-existent log_id)
      await db.insert('photos', {
        'log_id': 99999,
        'file_path': '/path/to/orphaned/photo.jpg',
      });

      // Verify we have 2 photos before migration
      final photosBefore = await db.query('photos');
      expect(photosBefore.length, 2);

      // Run the migration
      await migrationV35.up(db);

      // Verify orphaned photo was removed
      final photosAfter = await db.query('photos');
      expect(photosAfter.length, 1);
      expect(photosAfter.first['log_id'], logId);
    });

    test('Migration v35 should pass integrity check', () async {
      // Run the migration
      await migrationV35.up(db);

      // Run integrity check
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first['integrity_check'], 'ok');
    });

    test('Migration v35 should be idempotent (can run multiple times)', () async {
      // Run the migration twice
      await migrationV35.up(db);
      await migrationV35.up(db);

      // Should not throw errors and database should still be valid
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first['integrity_check'], 'ok');
    });

    test('Migration v35 should work with empty database', () async {
      // Close and recreate empty database
      await db.close();
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create only table structure, no data
          await _createV34Schema(db);
        },
      );

      // Run the migration
      await migrationV35.up(db);

      // Verify it succeeded
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first['integrity_check'], 'ok');
    });
  });
}

/// Creates a minimal v34 schema for testing
/// This simulates what users with v34 might have
Future<void> _createV34Schema(Database db) async {
  // Rooms Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      grow_type TEXT CHECK(grow_type IN ('INDOOR', 'OUTDOOR', 'GREENHOUSE')),
      watering_system TEXT CHECK(watering_system IN ('MANUAL', 'DRIP', 'AUTOPOT', 'RDWC', 'FLOOD_DRAIN')),
      rdwc_system_id INTEGER,
      width REAL DEFAULT 0,
      depth REAL DEFAULT 0,
      height REAL DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Grows Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS grows (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      start_date TEXT NOT NULL,
      end_date TEXT,
      room_id INTEGER,
      archived INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Plants Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS plants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      breeder TEXT,
      strain TEXT,
      feminized INTEGER DEFAULT 0,
      seed_type TEXT NOT NULL CHECK(seed_type IN ('PHOTO', 'AUTO')),
      medium TEXT NOT NULL CHECK(medium IN ('ERDE', 'COCO', 'HYDRO', 'AERO', 'DWC', 'RDWC')),
      phase TEXT DEFAULT 'SEEDLING' CHECK(phase IN ('SEEDLING', 'VEG', 'BLOOM', 'HARVEST', 'ARCHIVED')),
      room_id INTEGER,
      grow_id INTEGER,
      rdwc_system_id INTEGER,
      bucket_number INTEGER,
      seed_date TEXT,
      phase_start_date TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      created_by TEXT,
      log_profile_name TEXT DEFAULT 'standard',
      archived INTEGER DEFAULT 0
    )
  ''');

  // Plant Logs Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS plant_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plant_id INTEGER NOT NULL,
      day_number INTEGER NOT NULL,
      log_date TEXT NOT NULL DEFAULT (datetime('now')),
      logged_by TEXT,
      action_type TEXT NOT NULL CHECK(action_type IN ('WATER', 'FEED', 'NOTE', 'PHASE_CHANGE', 'TRANSPLANT', 'HARVEST', 'TRAINING', 'TRIM', 'OTHER')),
      phase TEXT CHECK(phase IN ('SEEDLING', 'VEG', 'BLOOM', 'HARVEST', 'ARCHIVED')),
      phase_day_number INTEGER,
      water_amount REAL,
      ph_in REAL,
      ec_in REAL,
      ph_out REAL,
      ec_out REAL,
      temperature REAL,
      humidity REAL,
      runoff INTEGER DEFAULT 0,
      cleanse INTEGER DEFAULT 0,
      note TEXT,
      archived INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Photos Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id INTEGER NOT NULL,
      file_path TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Harvests Table (minimal - missing optional fields)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS harvests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plant_id INTEGER NOT NULL,
      harvest_date TEXT NOT NULL,
      wet_weight REAL,
      dry_weight REAL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Fertilizers Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT,
      npk TEXT,
      type TEXT,
      description TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Log Fertilizers Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS log_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL,
      unit TEXT DEFAULT 'ml'
    )
  ''');

  // App Settings Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT,
      updated_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Hardware Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS hardware (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      brand TEXT,
      model TEXT,
      wattage INTEGER,
      quantity INTEGER DEFAULT 1,
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Log Templates Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS log_templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      action_type TEXT NOT NULL CHECK(action_type IN ('WATER', 'FEED', 'NOTE', 'PHASE_CHANGE', 'TRANSPLANT', 'HARVEST', 'TRAINING', 'TRIM', 'OTHER')),
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Template Fertilizers Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS template_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      template_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      unit TEXT DEFAULT 'ml'
    )
  ''');

  // RDWC Systems Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS rdwc_systems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      room_id INTEGER,
      grow_id INTEGER,
      max_capacity REAL NOT NULL,
      current_level REAL DEFAULT 0,
      bucket_count INTEGER DEFAULT 4,
      description TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      archived INTEGER DEFAULT 0
    )
  ''');

  // RDWC Logs Table (missing archived column)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS rdwc_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      system_id INTEGER NOT NULL,
      log_date TEXT DEFAULT (datetime('now')),
      log_type TEXT NOT NULL CHECK(log_type IN ('ADDBACK', 'FULLCHANGE', 'MAINTENANCE', 'MEASUREMENT')),
      level_before REAL,
      water_added REAL,
      level_after REAL,
      note TEXT,
      logged_by TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // RDWC Log Fertilizers Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS rdwc_log_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rdwc_log_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      amount_type TEXT NOT NULL CHECK(amount_type IN ('PER_LITER', 'TOTAL')),
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // RDWC Recipes Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS rdwc_recipes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      target_ec REAL,
      target_ph REAL,
      created_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // RDWC Recipe Fertilizers Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS rdwc_recipe_fertilizers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recipe_id INTEGER NOT NULL,
      fertilizer_id INTEGER NOT NULL,
      ml_per_liter REAL NOT NULL
    )
  ''');
}
