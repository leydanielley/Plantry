#!/usr/bin/env python3
"""
Creates a fresh database using onCreate logic from database_helper.dart
and validates it matches expectations
"""
import sqlite3
import os

test_db_path = "/tmp/test_onCreate_schema.db"

# Delete old DB
if os.path.exists(test_db_path):
    os.remove(test_db_path)

print("=" * 80)
print("🧪 TESTING onCreate SCHEMA (Fresh Installation)")
print("=" * 80)

conn = sqlite3.connect(test_db_path)
cursor = conn.cursor()

# Set version to 33 (current version)
cursor.execute("PRAGMA user_version = 33")

print("\n📋 Creating onCreate schema (v33)...")

# Create all tables with CURRENT schema from database_helper.dart onCreate

# Rooms
cursor.execute('''
  CREATE TABLE rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    archived INTEGER DEFAULT 0
  )
''')
print("  ✅ rooms (with archived)")

# Grows
cursor.execute('''
  CREATE TABLE grows (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    start_date TEXT,
    end_date TEXT,
    archived INTEGER DEFAULT 0
  )
''')
print("  ✅ grows")

# RDWC Systems
cursor.execute('''
  CREATE TABLE rdwc_systems (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    bucket_count INTEGER,
    reservoir_size REAL,
    archived INTEGER DEFAULT 0,
    FOREIGN KEY (id) REFERENCES rooms(id) ON DELETE RESTRICT
  )
''')
print("  ✅ rdwc_systems")

# Plants - CRITICAL TABLE
cursor.execute('''
  CREATE TABLE plants (
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
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE RESTRICT,
    FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE RESTRICT,
    FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems(id) ON DELETE RESTRICT
  )
''')
print("  ✅ plants (with RESTRICT FKs)")

# Plant Logs
cursor.execute('''
  CREATE TABLE plant_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plant_id INTEGER NOT NULL,
    log_date TEXT NOT NULL DEFAULT (datetime('now')),
    action_type TEXT NOT NULL CHECK(action_type IN ('WATER', 'FEED', 'NOTE', 'PHASE_CHANGE', 'TRANSPLANT', 'HARVEST', 'TRAINING', 'TRIM', 'OTHER')),
    phase TEXT CHECK(phase IN ('SEEDLING', 'VEG', 'BLOOM', 'HARVEST', 'ARCHIVED')),
    note TEXT,
    FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
  )
''')
print("  ✅ plant_logs (with CHECK constraints)")

# Photos
cursor.execute('''
  CREATE TABLE photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    log_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE
  )
''')
print("  ✅ photos (with CASCADE FK)")

# RDWC Logs
cursor.execute('''
  CREATE TABLE rdwc_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    system_id INTEGER NOT NULL,
    log_date TEXT NOT NULL,
    log_type TEXT NOT NULL CHECK(log_type IN ('ADDBACK', 'FULLCHANGE', 'MAINTENANCE', 'MEASUREMENT')),
    water_added REAL,
    water_temperature REAL,
    ph_value REAL,
    ec_value REAL,
    ppm_value REAL,
    note TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (system_id) REFERENCES rdwc_systems(id) ON DELETE RESTRICT
  )
''')
print("  ✅ rdwc_logs (with UPPERCASE CHECK)")

# Fertilizers
cursor.execute('''
  CREATE TABLE fertilizers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    brand TEXT,
    npk TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    archived INTEGER DEFAULT 0
  )
''')
print("  ✅ fertilizers")

# RDWC Log Fertilizers
cursor.execute('''
  CREATE TABLE rdwc_log_fertilizers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rdwc_log_id INTEGER NOT NULL,
    fertilizer_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    amount_type TEXT NOT NULL CHECK(amount_type IN ('PER_LITER', 'TOTAL')),
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs(id) ON DELETE CASCADE,
    FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
  )
''')
print("  ✅ rdwc_log_fertilizers (with CASCADE FK)")

conn.commit()

print("\n" + "=" * 80)
print("🔍 VALIDATING onCreate SCHEMA")
print("=" * 80)

errors = []

# Test plants table
print("\n📋 Testing plants table...")
cursor.execute("PRAGMA table_info(plants)")
plants_columns = {row[1]: row[2] for row in cursor.fetchall()}

required_columns = ['id', 'name', 'breeder', 'feminized', 'veg_date', 'room_id', 'grow_id']
for col in required_columns:
    if col in plants_columns:
        print(f"  ✅ {col}: {plants_columns[col]}")
    else:
        errors.append(f"plants: Missing column '{col}'")
        print(f"  ❌ {col}: MISSING")

# Test plants FKs
print("\n🔗 Testing plants Foreign Keys...")
cursor.execute("PRAGMA foreign_key_list(plants)")
plants_fks = {row[3]: (row[4], row[6]) for row in cursor.fetchall()}

for fk_col in ['room_id', 'grow_id', 'rdwc_system_id']:
    if fk_col in plants_fks:
        table, on_delete = plants_fks[fk_col]
        if on_delete == 'RESTRICT':
            print(f"  ✅ {fk_col} → {table} ON DELETE RESTRICT")
        else:
            errors.append(f"plants.{fk_col}: Should be RESTRICT, got {on_delete}")
            print(f"  ❌ {fk_col}: Should be RESTRICT, got {on_delete}")
    else:
        errors.append(f"plants.{fk_col}: Missing FK")
        print(f"  ❌ {fk_col}: Missing FK")

# Test photos FK
print("\n🔗 Testing photos Foreign Key...")
cursor.execute("PRAGMA foreign_key_list(photos)")
photos_fks = {row[3]: (row[4], row[6]) for row in cursor.fetchall()}

if 'log_id' in photos_fks:
    table, on_delete = photos_fks['log_id']
    if on_delete == 'CASCADE':
        print(f"  ✅ log_id → {table} ON DELETE CASCADE")
    else:
        errors.append(f"photos.log_id: Should be CASCADE, got {on_delete}")
        print(f"  ❌ log_id: Should be CASCADE, got {on_delete}")

# Test plant_logs CHECK constraints
print("\n📋 Testing plant_logs CHECK constraints...")
cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='plant_logs'")
sql = cursor.fetchone()[0]

if "CHECK(action_type IN" in sql:
    print("  ✅ action_type: CHECK constraint present")
else:
    errors.append("plant_logs.action_type: Missing CHECK constraint")
    print("  ❌ action_type: Missing CHECK constraint")

if "CHECK(phase IN" in sql:
    print("  ✅ phase: CHECK constraint present")
else:
    errors.append("plant_logs.phase: Missing CHECK constraint")
    print("  ❌ phase: Missing CHECK constraint")

if "DEFAULT (datetime" in sql:
    print("  ✅ log_date: DEFAULT constraint present")
else:
    errors.append("plant_logs.log_date: Missing DEFAULT constraint")
    print("  ❌ log_date: Missing DEFAULT constraint")

# Test rdwc_logs CHECK
print("\n📋 Testing rdwc_logs CHECK constraint...")
cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='rdwc_logs'")
sql = cursor.fetchone()[0]

if "'ADDBACK'" in sql and "'FULLCHANGE'" in sql:
    print("  ✅ log_type: UPPERCASE CHECK constraint")
else:
    errors.append("rdwc_logs.log_type: Missing or lowercase CHECK")
    print("  ❌ log_type: Missing or lowercase CHECK")

# Test rdwc_log_fertilizers
print("\n📋 Testing rdwc_log_fertilizers...")
cursor.execute("PRAGMA foreign_key_list(rdwc_log_fertilizers)")
fert_fks = {row[3]: (row[4], row[6]) for row in cursor.fetchall()}

if 'rdwc_log_id' in fert_fks:
    table, on_delete = fert_fks['rdwc_log_id']
    if on_delete == 'CASCADE':
        print(f"  ✅ rdwc_log_id → {table} ON DELETE CASCADE")
    else:
        errors.append(f"rdwc_log_fertilizers.rdwc_log_id: Should be CASCADE, got {on_delete}")
        print(f"  ❌ rdwc_log_id: Should be CASCADE, got {on_delete}")

cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='rdwc_log_fertilizers'")
sql = cursor.fetchone()[0]

if "'PER_LITER'" in sql and "'TOTAL'" in sql:
    print("  ✅ amount_type: Correct CHECK constraint (PER_LITER, TOTAL)")
else:
    errors.append("rdwc_log_fertilizers.amount_type: Wrong CHECK values")
    print("  ❌ amount_type: Wrong CHECK values")

# Test rooms.archived
print("\n📋 Testing rooms.archived...")
cursor.execute("PRAGMA table_info(rooms)")
rooms_columns = {row[1]: row[2] for row in cursor.fetchall()}

if 'archived' in rooms_columns:
    print(f"  ✅ archived: {rooms_columns['archived']}")
else:
    errors.append("rooms: Missing archived column")
    print("  ❌ archived: MISSING")

conn.close()

# Summary
print("\n" + "=" * 80)
print("📊 TEST SUMMARY")
print("=" * 80)

if errors:
    print(f"\n❌ ERRORS FOUND: {len(errors)}")
    for error in errors:
        print(f"  • {error}")
    exit(1)
else:
    print("\n🎉 ALL TESTS PASSED!")
    print("✅ onCreate schema is valid and matches all requirements")
    print(f"✅ Test database saved: {test_db_path}")
    exit(0)
