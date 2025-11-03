// =============================================
// GROWLOG - Database Helper (✅ BUG FIX #4: SeedType CHECK korrigiert)
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/app_logger.dart';
import 'migrations/migration_manager.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _isInitializing = false;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_database != null) return _database!;
    }

    _isInitializing = true;
    try {
      _database = await _initDB('growlog.db');
      return _database!;
    } finally {
      _isInitializing = false;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    AppLogger.info('DatabaseHelper', 'Opening database at: $path');

    return await openDatabase(
      path,
      version: 2,  // ✅ v2: Phase-Tracking in Logs
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
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

    // Use MigrationManager for v2+ migrations
    // Run for any upgrade beyond v2 (MigrationManager handles version detection)
    if (newVersion > 2) {
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
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_grows_archived ON grows(archived)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_grows_room ON grows(room_id)');

    // Plants Table - ✅ BUG FIX #4: SeedType CHECK korrigiert (ohne 'REGULAR')
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
        seed_date TEXT,
        phase_start_date TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        created_by TEXT,
        log_profile_name TEXT DEFAULT 'standard',
        archived INTEGER DEFAULT 0,
        current_container_size REAL,
        current_system_size REAL,
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL,
        FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_room ON plants(room_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_grow ON plants(grow_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_phase ON plants(phase)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plants_archived ON plants(archived)');

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
        unit TEXT DEFAULT 'ml',
        FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE,
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE CASCADE
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
        FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE CASCADE
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

    AppLogger.info('DatabaseHelper', 'Schema v$version created successfully! ✅');
  }

  Future<void> analyze() async {
    final db = await database;
    AppLogger.info('DatabaseHelper', '🔍 Running ANALYZE for query optimization...');
    await db.execute('ANALYZE');
    AppLogger.info('DatabaseHelper', '✅ Database analyzed!');
  }
}
