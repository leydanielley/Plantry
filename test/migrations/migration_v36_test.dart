// =============================================
// GROWLOG - Migration v36 Test
// Tests v35→v36 FK CASCADE standardization
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/migrations/scripts/migration_v36.dart';

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration v36 - FK CASCADE Standardization Tests', () {
    late Database db;

    setUp(() async {
      // Create an in-memory database for testing
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create a v35 database structure with CASCADE constraints
          await _createV35Schema(db);
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Migration v36 should succeed on v35 database', () async {
      // Run the migration
      await migrationV36.up(db);

      // Verify database is still open and valid
      expect(db.isOpen, true);

      // Verify integrity check passes
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first['integrity_check'], 'ok');
    });

    test('Migration v36 should change harvests FK from CASCADE to RESTRICT', () async {
      // Verify initial FK constraint is CASCADE
      final fkBefore = await db.rawQuery('PRAGMA foreign_key_list(harvests)');
      final plantIdFkBefore = fkBefore.firstWhere(
        (fk) => fk['from'] == 'plant_id',
      );
      expect(plantIdFkBefore['on_delete'], 'CASCADE',
          reason: 'Initial FK should be CASCADE (testing v35 schema)');

      // Run the migration
      await migrationV36.up(db);

      // Verify FK constraint changed to RESTRICT
      final fkAfter = await db.rawQuery('PRAGMA foreign_key_list(harvests)');
      final plantIdFkAfter = fkAfter.firstWhere(
        (fk) => fk['from'] == 'plant_id',
      );
      expect(plantIdFkAfter['on_delete'], 'RESTRICT',
          reason: 'FK should be RESTRICT after migration');
    });

    test('Migration v36 should change hardware FK from CASCADE to RESTRICT', () async {
      // Verify initial FK constraint is CASCADE
      final fkBefore = await db.rawQuery('PRAGMA foreign_key_list(hardware)');
      final roomIdFkBefore = fkBefore.firstWhere(
        (fk) => fk['from'] == 'room_id',
      );
      expect(roomIdFkBefore['on_delete'], 'CASCADE',
          reason: 'Initial FK should be CASCADE (testing v35 schema)');

      // Run the migration
      await migrationV36.up(db);

      // Verify FK constraint changed to RESTRICT
      final fkAfter = await db.rawQuery('PRAGMA foreign_key_list(hardware)');
      final roomIdFkAfter = fkAfter.firstWhere(
        (fk) => fk['from'] == 'room_id',
      );
      expect(roomIdFkAfter['on_delete'], 'RESTRICT',
          reason: 'FK should be RESTRICT after migration');
    });

    test('Migration v36 should preserve all harvest data', () async {
      // Insert test data before migration
      await db.insert('plants', {
        'name': 'Test Plant',
        'seed_type': 'PHOTO',
        'medium': 'ERDE',
        'phase': 'HARVEST',
      });

      final harvestId1 = await db.insert('harvests', {
        'plant_id': 1,
        'harvest_date': '2025-01-01',
        'wet_weight': 100.5,
        'dry_weight': 20.3,
        'rating': 4,
        'taste_notes': 'Fruity',
      });

      final harvestId2 = await db.insert('harvests', {
        'plant_id': 1,
        'harvest_date': '2025-01-15',
        'wet_weight': 85.2,
        'thc_percentage': 22.5,
      });

      // Get row count before migration
      final countBefore = await db.rawQuery('SELECT COUNT(*) as count FROM harvests');
      expect(countBefore.first['count'], 2);

      // Run the migration
      await migrationV36.up(db);

      // Verify all data preserved
      final countAfter = await db.rawQuery('SELECT COUNT(*) as count FROM harvests');
      expect(countAfter.first['count'], 2,
          reason: 'All harvest records should be preserved');

      // Verify specific data integrity
      final harvest1 = await db.query('harvests', where: 'id = ?', whereArgs: [harvestId1]);
      expect(harvest1.first['wet_weight'], 100.5);
      expect(harvest1.first['dry_weight'], 20.3);
      expect(harvest1.first['rating'], 4);
      expect(harvest1.first['taste_notes'], 'Fruity');

      final harvest2 = await db.query('harvests', where: 'id = ?', whereArgs: [harvestId2]);
      expect(harvest2.first['wet_weight'], 85.2);
      expect(harvest2.first['thc_percentage'], 22.5);
    });

    test('Migration v36 should preserve all hardware data', () async {
      // Insert test data before migration
      await db.insert('rooms', {
        'name': 'Test Room',
        'grow_type': 'INDOOR',
      });

      final hardwareId1 = await db.insert('hardware', {
        'room_id': 1,
        'name': 'LED Panel 600W',
        'type': 'LIGHT',
        'brand': 'Mars Hydro',
        'wattage': 600,
        'quantity': 2,
      });

      final hardwareId2 = await db.insert('hardware', {
        'room_id': 1,
        'name': 'Inline Fan',
        'type': 'VENTILATION',
        'airflow': 400,
      });

      // Get row count before migration
      final countBefore = await db.rawQuery('SELECT COUNT(*) as count FROM hardware');
      expect(countBefore.first['count'], 2);

      // Run the migration
      await migrationV36.up(db);

      // Verify all data preserved
      final countAfter = await db.rawQuery('SELECT COUNT(*) as count FROM hardware');
      expect(countAfter.first['count'], 2,
          reason: 'All hardware records should be preserved');

      // Verify specific data integrity
      final hardware1 = await db.query('hardware', where: 'id = ?', whereArgs: [hardwareId1]);
      expect(hardware1.first['name'], 'LED Panel 600W');
      expect(hardware1.first['brand'], 'Mars Hydro');
      expect(hardware1.first['wattage'], 600);
      expect(hardware1.first['quantity'], 2);

      final hardware2 = await db.query('hardware', where: 'id = ?', whereArgs: [hardwareId2]);
      expect(hardware2.first['name'], 'Inline Fan');
      expect(hardware2.first['type'], 'VENTILATION');
      expect(hardware2.first['airflow'], 400);
    });

    test('Migration v36 should preserve indexes on harvests table', () async {
      // Run the migration
      await migrationV36.up(db);

      // Verify indexes exist
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='harvests'",
      );

      final indexNames = indexes.map((idx) => idx['name'] as String).toList();
      expect(indexNames.contains('idx_harvests_plant'), true,
          reason: 'idx_harvests_plant should exist');
      expect(indexNames.contains('idx_harvests_date'), true,
          reason: 'idx_harvests_date should exist');
    });

    test('Migration v36 should preserve indexes on hardware table', () async {
      // Run the migration
      await migrationV36.up(db);

      // Verify indexes exist
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='hardware'",
      );

      final indexNames = indexes.map((idx) => idx['name'] as String).toList();
      expect(indexNames.contains('idx_hardware_room'), true,
          reason: 'idx_hardware_room should exist');
      expect(indexNames.contains('idx_hardware_type'), true,
          reason: 'idx_hardware_type should exist');
      expect(indexNames.contains('idx_hardware_active'), true,
          reason: 'idx_hardware_active should exist');
    });

    test('Migration v36 should pass foreign key integrity check', () async {
      // Insert valid relational data
      await db.insert('plants', {
        'name': 'Test Plant',
        'seed_type': 'PHOTO',
        'medium': 'ERDE',
      });

      await db.insert('rooms', {
        'name': 'Test Room',
        'grow_type': 'INDOOR',
      });

      await db.insert('harvests', {
        'plant_id': 1,
        'harvest_date': '2025-01-01',
      });

      await db.insert('hardware', {
        'room_id': 1,
        'name': 'Test Light',
        'type': 'LIGHT',
      });

      // Run the migration
      await migrationV36.up(db);

      // Verify no foreign key violations
      final harvestsFkCheck = await db.rawQuery('PRAGMA foreign_key_check(harvests)');
      expect(harvestsFkCheck, isEmpty,
          reason: 'harvests should have no FK violations');

      final hardwareFkCheck = await db.rawQuery('PRAGMA foreign_key_check(hardware)');
      expect(hardwareFkCheck, isEmpty,
          reason: 'hardware should have no FK violations');
    });

    test('Migration v36 should pass database integrity check', () async {
      // Run the migration
      await migrationV36.up(db);

      // Run integrity check
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first['integrity_check'], 'ok',
          reason: 'Database should pass integrity check');
    });

    test('Migration v36 should be idempotent (can run multiple times)', () async {
      // Run the migration twice
      await migrationV36.up(db);
      await migrationV36.up(db);

      // Should not throw errors and database should still be valid
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first['integrity_check'], 'ok');

      // Verify FK constraints are still RESTRICT
      final harvestsFk = await db.rawQuery('PRAGMA foreign_key_list(harvests)');
      final plantIdFk = harvestsFk.firstWhere((fk) => fk['from'] == 'plant_id');
      expect(plantIdFk['on_delete'], 'RESTRICT');

      final hardwareFk = await db.rawQuery('PRAGMA foreign_key_list(hardware)');
      final roomIdFk = hardwareFk.firstWhere((fk) => fk['from'] == 'room_id');
      expect(roomIdFk['on_delete'], 'RESTRICT');
    });

    test('Migration v36 should work with empty tables', () async {
      // Run migration on empty database (no data)
      await migrationV36.up(db);

      // Verify tables exist and are empty
      final harvestsCount = await db.rawQuery('SELECT COUNT(*) as count FROM harvests');
      expect(harvestsCount.first['count'], 0);

      final hardwareCount = await db.rawQuery('SELECT COUNT(*) as count FROM hardware');
      expect(hardwareCount.first['count'], 0);

      // Verify FK constraints are RESTRICT
      final harvestsFk = await db.rawQuery('PRAGMA foreign_key_list(harvests)');
      final plantIdFk = harvestsFk.firstWhere((fk) => fk['from'] == 'plant_id');
      expect(plantIdFk['on_delete'], 'RESTRICT');

      final hardwareFk = await db.rawQuery('PRAGMA foreign_key_list(hardware)');
      final roomIdFk = hardwareFk.firstWhere((fk) => fk['from'] == 'room_id');
      expect(roomIdFk['on_delete'], 'RESTRICT');
    });

    test('Migration v36 should preserve all table columns', () async {
      // Run the migration
      await migrationV36.up(db);

      // Verify harvests table has all expected columns
      final harvestsColumns = await db.rawQuery('PRAGMA table_info(harvests)');
      final harvestsColNames = harvestsColumns
          .map((col) => col['name'] as String)
          .toSet();

      final expectedHarvestsCols = {
        'id', 'plant_id', 'harvest_date', 'wet_weight', 'dry_weight',
        'drying_start_date', 'drying_end_date', 'drying_days', 'drying_method',
        'drying_temperature', 'drying_humidity', 'curing_start_date',
        'curing_end_date', 'curing_days', 'curing_method', 'curing_notes',
        'thc_percentage', 'cbd_percentage', 'terpene_profile', 'rating',
        'taste_notes', 'effect_notes', 'overall_notes', 'created_at', 'updated_at',
      };

      expect(harvestsColNames.containsAll(expectedHarvestsCols), true,
          reason: 'harvests should have all expected columns');

      // Verify hardware table has all expected columns
      final hardwareColumns = await db.rawQuery('PRAGMA table_info(hardware)');
      final hardwareColNames = hardwareColumns
          .map((col) => col['name'] as String)
          .toSet();

      final expectedHardwareCols = {
        'id', 'room_id', 'name', 'type', 'brand', 'model', 'wattage',
        'quantity', 'active', 'created_at',
      };

      expect(hardwareColNames.containsAll(expectedHardwareCols), true,
          reason: 'hardware should have all expected columns');
    });
  });
}

/// Creates a v35 schema for testing
/// This simulates the database state before v36 migration
/// with CASCADE constraints on harvests and hardware
Future<void> _createV35Schema(Database db) async {
  // Plants Table (referenced by harvests)
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
      veg_date TEXT,
      bloom_date TEXT,
      harvest_date TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      created_by TEXT,
      log_profile_name TEXT DEFAULT 'standard',
      archived INTEGER DEFAULT 0,
      current_container_size REAL,
      current_system_size REAL
    )
  ''');

  // Rooms Table (referenced by hardware)
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
      archived INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    )
  ''');

  // Harvests Table (v35 schema with CASCADE)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS harvests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plant_id INTEGER NOT NULL,
      harvest_date TEXT NOT NULL,
      wet_weight REAL,
      dry_weight REAL,
      drying_start_date TEXT,
      drying_end_date TEXT,
      drying_days INTEGER,
      drying_method TEXT,
      drying_temperature REAL,
      drying_humidity REAL,
      curing_start_date TEXT,
      curing_end_date TEXT,
      curing_days INTEGER,
      curing_method TEXT,
      curing_notes TEXT,
      thc_percentage REAL,
      cbd_percentage REAL,
      terpene_profile TEXT,
      rating INTEGER CHECK(rating >= 1 AND rating <= 5),
      taste_notes TEXT,
      effect_notes TEXT,
      overall_notes TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT,
      FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
    )
  ''');

  await db.execute(
    'CREATE INDEX idx_harvests_plant ON harvests(plant_id)',
  );
  await db.execute(
    'CREATE INDEX idx_harvests_date ON harvests(harvest_date)',
  );

  // Hardware Table (v35 schema with CASCADE)
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
      airflow INTEGER,
      spectrum TEXT,
      color_temperature TEXT,
      dimmable INTEGER,
      flange_size TEXT,
      controllable INTEGER,
      oscillating INTEGER,
      diameter INTEGER,
      cooling_power INTEGER,
      heating_power INTEGER,
      coverage REAL,
      has_thermostat INTEGER,
      humidification_rate INTEGER,
      pump_rate INTEGER,
      is_digital INTEGER,
      program_count INTEGER,
      dripper_count INTEGER,
      capacity INTEGER,
      material TEXT,
      has_chiller INTEGER,
      has_air_pump INTEGER,
      filter_diameter TEXT,
      filter_length INTEGER,
      controller_type TEXT,
      output_count INTEGER,
      controller_functions TEXT,
      specifications TEXT,
      purchase_date TEXT,
      purchase_price REAL,
      notes TEXT,
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )
  ''');

  await db.execute(
    'CREATE INDEX idx_hardware_room ON hardware(room_id)',
  );
  await db.execute(
    'CREATE INDEX idx_hardware_type ON hardware(type)',
  );
  await db.execute(
    'CREATE INDEX idx_hardware_active ON hardware(active)',
  );
}
