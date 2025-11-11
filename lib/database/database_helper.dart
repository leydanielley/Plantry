// =============================================
// GROWLOG - Database Helper (✅ BUG FIX: Race Condition Fixed)
// =============================================
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/app_logger.dart';
import 'migrations/migration_manager.dart';
import 'database_recovery.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static final _lock = Lock();  // ✅ CRITICAL FIX: Mutex prevents race condition

  DatabaseHelper._init();

  /// Allows test database injection (only for testing!)
  /// This method should only be called from test code
  @visibleForTesting
  static void setTestDatabase(Database? db) {
    _database = db;
  }

  // ✅ CRITICAL FIX: Thread-safe database initialization with mutex lock
  // Prevents multiple threads from initializing database simultaneously
  Future<Database> get database async {
    // Fast path: If already initialized, return immediately
    if (_database != null) return _database!;

    // Slow path: Use lock to ensure only one thread initializes
    return await _lock.synchronized(() async {
      // Double-check pattern: Another thread may have initialized while we waited
      if (_database != null) return _database!;

      try {
        AppLogger.info('DatabaseHelper', 'Initializing database with mutex lock...');
        _database = await _initDB('growlog.db');
        AppLogger.info('DatabaseHelper', '✅ Database initialized successfully');
        return _database!;
      } catch (e, stackTrace) {
        AppLogger.error('DatabaseHelper', 'Database initialization failed', e, stackTrace);
        _database = null;  // Reset on failure to allow retry
        rethrow;
      }
    });
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    AppLogger.info('DatabaseHelper', 'Opening database at: $path');

    try {
      return await openDatabase(
        path,
        version: 13,  // ✅ v13: Database integrity & performance (FK constraints, composite indexes)
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      AppLogger.error('DatabaseHelper', 'Database open failed, attempting recovery...', e);

      // Attempt database recovery
      final recoveryResult = await DatabaseRecovery.performRecovery(path);

      if (recoveryResult.isSuccess || recoveryResult.wasRecreated) {
        AppLogger.info('DatabaseHelper', 'Recovery successful, reopening database...');

        // Try opening again
        return await openDatabase(
          path,
          version: 13,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onConfigure: _onConfigure,
        );
      } else {
        AppLogger.error('DatabaseHelper', 'Database recovery failed completely');
        rethrow;
      }
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      'DatabaseHelper',
      'Upgrading database',
      'from v$oldVersion to v$newVersion',
    );

    // Handle legacy migration v1 → v2 (already released)
    if (oldVersion < 2) {
      // v1 → v2: Phase-Tracking in plant_logs
      AppLogger.info(
        'DatabaseHelper',
        'Migration 1→2: Adding phase & phase_day_number to plant_logs...',
      );

      await db.execute('''
        ALTER TABLE plant_logs ADD COLUMN phase TEXT
      ''');

      await db.execute('''
        ALTER TABLE plant_logs ADD COLUMN phase_day_number INTEGER
      ''');

      AppLogger.info('DatabaseHelper', '✅ Migration 1→2 complete!');
    }

    // v2 → v3: RDWC System Management
    if (oldVersion < 3 && newVersion >= 3) {
      AppLogger.info(
        'DatabaseHelper',
        'Migration 2→3: Adding RDWC System tables...',
      );

      // RDWC Systems Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rdwc_systems (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          room_id INTEGER,
          grow_id INTEGER,
          max_capacity REAL NOT NULL,
          current_level REAL DEFAULT 0,
          description TEXT,
          created_at TEXT DEFAULT (datetime('now')),
          archived INTEGER DEFAULT 0,
          FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL,
          FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_systems_room ON rdwc_systems(room_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_systems_grow ON rdwc_systems(grow_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_systems_archived ON rdwc_systems(archived)');

      // RDWC Logs Table (Water Addback Tracking)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rdwc_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          system_id INTEGER NOT NULL,
          log_date TEXT DEFAULT (datetime('now')),
          log_type TEXT NOT NULL CHECK(log_type IN ('ADDBACK', 'FULLCHANGE', 'MAINTENANCE', 'MEASUREMENT')),
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_logs_system ON rdwc_logs(system_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_logs_date ON rdwc_logs(log_date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_logs_type ON rdwc_logs(log_type)');

      AppLogger.info('DatabaseHelper', '✅ Migration 2→3 complete!');
    }

    // v3 → v4: RDWC bucket tracking & plant linking
    if (oldVersion < 4 && newVersion >= 4) {
      AppLogger.info(
        'DatabaseHelper',
        'Migration 3→4: Adding bucket tracking and plant-to-RDWC linking...',
      );

      // Add bucket_count to rdwc_systems
      await db.execute('''
        ALTER TABLE rdwc_systems ADD COLUMN bucket_count INTEGER DEFAULT 4
      ''');

      // Add rdwc_system_id and bucket_number to plants
      await db.execute('''
        ALTER TABLE plants ADD COLUMN rdwc_system_id INTEGER
      ''');
      await db.execute('''
        ALTER TABLE plants ADD COLUMN bucket_number INTEGER
      ''');

      // Create index for plant-to-system lookup
      await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_rdwc_system ON plants(rdwc_system_id)');

      AppLogger.info('DatabaseHelper', '✅ Migration 3→4 complete!');
    }

    // v4 → v5: Room-RDWC system linking
    if (oldVersion < 5 && newVersion >= 5) {
      AppLogger.info(
        'DatabaseHelper',
        'Migration 4→5: Adding Room-RDWC system linking...',
      );

      // Add rdwc_system_id to rooms
      await db.execute('''
        ALTER TABLE rooms ADD COLUMN rdwc_system_id INTEGER
      ''');

      // Create index for room-to-system lookup
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rooms_rdwc_system ON rooms(rdwc_system_id)');

      AppLogger.info('DatabaseHelper', '✅ Migration 4→5 complete!');
    }

    // v5 → v6: RDWC System hardware specifications
    if (oldVersion < 6 && newVersion >= 6) {
      AppLogger.info(
        'DatabaseHelper',
        'Migration 5→6: Adding RDWC System hardware specs...',
      );

      // Add hardware columns to rdwc_systems
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN pump_brand TEXT');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN pump_model TEXT');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN pump_wattage INTEGER');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN pump_flow_rate REAL');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN accessories TEXT');

      AppLogger.info('DatabaseHelper', '✅ Migration 5→6 complete!');
    }

    // v6 → v7: RDWC System Air Pump & Chiller specifications
    if (oldVersion < 7 && newVersion >= 7) {
      AppLogger.info(
        'DatabaseHelper',
        'Migration 6→7: Adding RDWC System Air Pump & Chiller specs...',
      );

      // Add Air Pump columns to rdwc_systems
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN air_pump_brand TEXT');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN air_pump_model TEXT');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN air_pump_wattage INTEGER');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN air_pump_flow_rate REAL');

      // Add Chiller columns to rdwc_systems
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN chiller_brand TEXT');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN chiller_model TEXT');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN chiller_wattage INTEGER');
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN chiller_cooling_power INTEGER');

      AppLogger.info('DatabaseHelper', '✅ Migration 6→7 complete!');
    }

    // Use MigrationManager for v7+ migrations
    // Run for any upgrade beyond v7 (MigrationManager handles version detection)
    if (newVersion > 7) {
      final migrationManager = MigrationManager();
      await migrationManager.migrate(db, oldVersion, newVersion);

      // Verify database integrity after migration
      final isValid = await migrationManager.verifyDatabase(db);
      if (!isValid) {
        throw Exception('Database integrity check failed after migration');
      }
    }

    AppLogger.info(
      'DatabaseHelper',
      '✅ Database upgrade completed successfully',
      'v$newVersion',
    );
  }

  Future<void> _createDB(Database db, int version) async {
    AppLogger.info('DatabaseHelper', 'Creating database schema v$version...');

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
        updated_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rooms_rdwc_system ON rooms(rdwc_system_id)');

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
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_grows_archived ON grows(archived)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_grows_room ON grows(room_id)');

    // Plants Table - ✅ BUG FIX #4: SeedType CHECK korrigiert (ohne 'REGULAR')
    // ✅ v10: Phase History (veg_date, bloom_date, harvest_date)
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
        current_system_size REAL,
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL,
        FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE SET NULL,
        FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_room ON plants(room_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_grow ON plants(grow_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_rdwc_system ON plants(rdwc_system_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_phase ON plants(phase)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_archived ON plants(archived)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_veg_date ON plants(veg_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_bloom_date ON plants(bloom_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_harvest_date ON plants(harvest_date)');

    // Plant Logs Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plant_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        log_date TEXT DEFAULT (datetime('now')),
        logged_by TEXT,
        action_type TEXT CHECK(action_type IN ('WATER', 'FEED', 'NOTE', 'PHASE_CHANGE', 'TRANSPLANT', 'HARVEST', 'TRAINING', 'TRIM', 'OTHER')),
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
        container_size REAL,
        container_medium_amount REAL,
        container_drainage INTEGER DEFAULT 0,
        container_drainage_material TEXT,
        system_reservoir_size REAL,
        system_bucket_count INTEGER,
        system_bucket_size REAL,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_plant ON plant_logs(plant_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_date ON plant_logs(log_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_action ON plant_logs(action_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plant_logs_lookup ON plant_logs(plant_id, log_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plant_logs_action_date ON plant_logs(action_type, log_date DESC)');

    // Fertilizers Table (v8: added ec_value, ppm_value for RDWC calculations)
    // ✅ FIX: Added v11 migration fields to prevent schema mismatch on fresh installs
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

    // Log Fertilizers Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL,
        unit TEXT DEFAULT 'ml',
        FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_log_fertilizers_lookup ON log_fertilizers(log_id, fertilizer_id)');

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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hardware_room ON hardware(room_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hardware_type ON hardware(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hardware_active ON hardware(active)');

    // Photos Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_photos_log ON photos(log_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_photos_log_lookup ON photos(log_id, created_at DESC)');

    // Log Templates Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        action_type TEXT NOT NULL CHECK(action_type IN ('WATER', 'FEED', 'NOTE', 'PHASE_CHANGE', 'TRANSPLANT', 'HARVEST', 'TRAINING', 'TRIM', 'OTHER')),
        water_amount REAL,
        ph_in REAL,
        ec_in REAL,
        temperature REAL,
        humidity REAL,
        runoff INTEGER DEFAULT 0,
        cleanse INTEGER DEFAULT 0,
        note TEXT,
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
        unit TEXT DEFAULT 'ml',
        FOREIGN KEY (template_id) REFERENCES log_templates(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_template_fertilizers_template ON template_fertilizers(template_id)');

    // Harvests Table
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_harvests_plant ON harvests(plant_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_harvests_date ON harvests(harvest_date)');

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
        created_at TEXT DEFAULT (datetime('now')),
        archived INTEGER DEFAULT 0,
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL,
        FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_systems_room ON rdwc_systems(room_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_systems_grow ON rdwc_systems(grow_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_systems_archived ON rdwc_systems(archived)');

    // RDWC Logs Table (Water Addback Tracking)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rdwc_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        log_date TEXT DEFAULT (datetime('now')),
        log_type TEXT NOT NULL CHECK(log_type IN ('ADDBACK', 'FULLCHANGE', 'MAINTENANCE', 'MEASUREMENT')),
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_logs_system ON rdwc_logs(system_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_logs_date ON rdwc_logs(log_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_logs_type ON rdwc_logs(log_type)');

    // RDWC Log Fertilizers Table (v8: Expert Mode nutrient tracking)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rdwc_log_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rdwc_log_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        amount_type TEXT NOT NULL CHECK(amount_type IN ('PER_LITER', 'TOTAL')),
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_log_fertilizers_log ON rdwc_log_fertilizers(rdwc_log_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_log_fertilizers_fertilizer ON rdwc_log_fertilizers(fertilizer_id)');

    // RDWC Recipes Table (v8: Reusable fertilizer combinations)
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_recipes_name ON rdwc_recipes(name)');

    // RDWC Recipe Fertilizers Table (v8: Recipe → Fertilizer mapping)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rdwc_recipe_fertilizers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        fertilizer_id INTEGER NOT NULL,
        ml_per_liter REAL NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES rdwc_recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_recipe_fertilizers_recipe ON rdwc_recipe_fertilizers(recipe_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rdwc_recipe_fertilizers_fertilizer ON rdwc_recipe_fertilizers(fertilizer_id)');

    AppLogger.info('DatabaseHelper', 'Schema v$version created successfully! ✅');
  }

  Future<void> analyze() async {
    final db = await database;
    AppLogger.info('DatabaseHelper', '🔍 Running ANALYZE for query optimization...');
    await db.execute('ANALYZE');
    AppLogger.info('DatabaseHelper', '✅ Database analyzed!');
  }
}
