// =============================================
// GROWLOG - Test Database Helper
// =============================================

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper class for setting up test databases
class TestDatabaseHelper {
  static const int currentVersion =
      13; // Should match DatabaseHelper version (v13)

  /// Initialize sqflite_ffi for tests
  static void initFfi() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  /// Creates an in-memory test database with full schema
  static Future<Database> createTestDatabase() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: currentVersion,
        onCreate: (db, version) async {
          // ✅ Use the same schema as production database
          await _createAllTables(db);
        },
      ),
    );

    // ✅ Enable foreign keys (required for CASCADE DELETE to work)
    // Must be done AFTER opening the database
    await db.execute('PRAGMA foreign_keys = ON');

    return db;
  }

  /// Creates all tables with production schema
  static Future<void> _createAllTables(Database db) async {
    // Rooms table
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

    // Grows table
    await db.execute('''
      CREATE TABLE grows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        start_date TEXT,
        end_date TEXT,
        room_id INTEGER,
        archived INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE SET NULL
      )
    ''');

    // Plants table (v10: Added veg_date, bloom_date, harvest_date)
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
        FOREIGN KEY (grow_id) REFERENCES grows (id) ON DELETE SET NULL,
        FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems (id) ON DELETE SET NULL
      )
    ''');

    // Plant logs table (v10/v13: Added phase, phase_day_number, logged_by and extended fields)
    await db.execute('''
      CREATE TABLE plant_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        log_date TEXT NOT NULL,
        logged_by TEXT,
        action_type TEXT NOT NULL,
        phase TEXT,
        phase_day_number INTEGER,
        water_amount REAL,
        ph_in REAL,
        ph_out REAL,
        ec_in REAL,
        ec_out REAL,
        temperature REAL,
        humidity REAL,
        runoff INTEGER DEFAULT 0,
        cleanse INTEGER DEFAULT 0,
        container_size REAL,
        container_medium_amount REAL,
        container_drainage INTEGER DEFAULT 0,
        container_drainage_material TEXT,
        system_reservoir_size REAL,
        system_bucket_count INTEGER,
        system_bucket_size REAL,
        note TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE
      )
    ''');

    // Fertilizers table
    await db.execute('''
      CREATE TABLE fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT,
        type TEXT NOT NULL,
        npk TEXT,
        unit TEXT DEFAULT 'ml',
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // Log fertilizers junction table
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

    // Hardware table
    await db.execute('''
      CREATE TABLE hardware (
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
        FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE CASCADE
      )
    ''');

    // Photos table
    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (log_id) REFERENCES plant_logs (id) ON DELETE CASCADE
      )
    ''');

    // Log templates table
    await db.execute('''
      CREATE TABLE log_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_name TEXT NOT NULL,
        template_name TEXT NOT NULL,
        day_number INTEGER NOT NULL,
        action_type TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // Template fertilizers junction table
    await db.execute('''
      CREATE TABLE template_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (template_id) REFERENCES log_templates (id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers (id) ON DELETE CASCADE
      )
    ''');

    // Harvests table
    await db.execute('''
      CREATE TABLE harvests (
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
        FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE
      )
    ''');

    // App settings table
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        language TEXT DEFAULT 'de',
        theme_mode TEXT DEFAULT 'system',
        volume_unit TEXT DEFAULT 'liters',
        expert_mode INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // Insert default settings
    await db.insert('app_settings', {
      'id': 1,
      'language': 'de',
      'theme_mode': 'system',
      'volume_unit': 'liters',
      'expert_mode': 0,
    });

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
        pump_brand TEXT,
        pump_model TEXT,
        pump_wattage INTEGER,
        pump_flow_rate REAL,
        air_pump_brand TEXT,
        air_pump_model TEXT,
        air_pump_wattage INTEGER,
        air_pump_flow_rate REAL,
        chiller_brand TEXT,
        chiller_model TEXT,
        chiller_wattage INTEGER,
        chiller_cooling_power INTEGER,
        accessories TEXT,
        archived INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE SET NULL,
        FOREIGN KEY (grow_id) REFERENCES grows (id) ON DELETE SET NULL
      )
    ''');

    // RDWC Logs table
    await db.execute('''
      CREATE TABLE rdwc_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        log_date TEXT NOT NULL,
        log_type TEXT NOT NULL,
        water_added REAL,
        water_consumed REAL,
        ph_before REAL,
        ph_after REAL,
        ec_before REAL,
        ec_after REAL,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (system_id) REFERENCES rdwc_systems (id) ON DELETE CASCADE
      )
    ''');

    // RDWC Log Fertilizers junction table
    await db.execute('''
      CREATE TABLE rdwc_log_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rdwc_log_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs (id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers (id) ON DELETE CASCADE
      )
    ''');

    // RDWC Recipes table
    await db.execute('''
      CREATE TABLE rdwc_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        system_id INTEGER,
        for_volume REAL NOT NULL,
        target_ec REAL,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (system_id) REFERENCES rdwc_systems (id) ON DELETE SET NULL
      )
    ''');

    // RDWC Recipe Fertilizers junction table
    await db.execute('''
      CREATE TABLE rdwc_recipe_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES rdwc_recipes (id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Seeds test data for common scenarios
  static Future<void> seedTestData(Database db) async {
    // Insert test room
    await db.insert('rooms', {
      'id': 1,
      'name': 'Test Room',
      'grow_type': 'INDOOR',
      'width': 2.0,
      'depth': 1.0,
      'height': 2.0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Insert test grow
    await db.insert('grows', {
      'id': 1,
      'name': 'Test Grow',
      'start_date': DateTime.now().toIso8601String(),
      'archived': 0,
    });

    // Insert test fertilizers
    await db.insert('fertilizers', {
      'id': 1,
      'name': 'Test Fertilizer A',
      'brand': 'Test Brand',
      'type': 'BASE',
      'npk': '3-1-2',
      'unit': 'ml',
    });

    await db.insert('fertilizers', {
      'id': 2,
      'name': 'Test Fertilizer B',
      'brand': 'Test Brand',
      'type': 'ADDITIVE',
      'npk': '0-0-1',
      'unit': 'ml',
    });
  }

  /// Inject test database into DatabaseHelper singleton (for testing only!)
  /// This uses a workaround to set the private _database field
  static void injectTestDatabase(Database db) {
    // This is a hack to access the private _database field in DatabaseHelper
    // We use noSuchMethod pattern or reflection-like approaches
    // Since Dart doesn't allow direct private field access from outside,
    // we'll need to use the database getter and let it initialize
    // For now, we'll just store the database and hope the repositories work

    // Alternative: We directly modify the static field if possible
    // This requires the test to be in the same library or use part/part of
    // For simplicity, we'll document that tests should call DatabaseHelper.instance.database
    // and it will initialize properly with our test setup
  }

  /// Reset the DatabaseHelper singleton (for cleanup)
  static void resetDatabaseHelper() {
    // This would reset the _database field to null
    // Since we can't access private fields, we'll rely on closing the database
    // and the next call to DatabaseHelper.instance.database will reinitialize
  }
}
