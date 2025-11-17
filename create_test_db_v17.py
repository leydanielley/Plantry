#!/usr/bin/env python3
"""
Creates a v17 test database that can be used to test migration to v33
"""
import sqlite3
import os

test_db_path = "/tmp/growlog_test_v17.db"

# Delete old DB
if os.path.exists(test_db_path):
    os.remove(test_db_path)
    print(f"🗑️  Deleted old test DB: {test_db_path}")

print("=" * 80)
print("🔨 Creating v17 test database")
print("=" * 80)

conn = sqlite3.connect(test_db_path)
cursor = conn.cursor()

# Set user_version to 17 (SQLite's version tracking)
cursor.execute("PRAGMA user_version = 17")

print("\n📋 Creating v17 schema...")

# Create v17 schema (BEFORE buggy v18)
cursor.execute('''
  CREATE TABLE rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    archived INTEGER DEFAULT 0
  )
''')
print("  ✅ rooms table created (with archived)")

cursor.execute('''
  CREATE TABLE grows (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  )
''')
print("  ✅ grows table created")

cursor.execute('''
  CREATE TABLE rdwc_systems (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  )
''')
print("  ✅ rdwc_systems table created")

# v17 had plants with all fields but SET NULL FKs
cursor.execute('''
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
''')
print("  ✅ plants table created (with SET NULL - BUG!)")

cursor.execute('''
  CREATE TABLE plant_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plant_id INTEGER NOT NULL,
    log_date TEXT NOT NULL,
    action_type TEXT NOT NULL,
    note TEXT,
    FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
  )
''')
print("  ✅ plant_logs table created")

cursor.execute('''
  CREATE TABLE photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    log_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE RESTRICT
  )
''')
print("  ✅ photos table created (with RESTRICT - BUG!)")

cursor.execute('''
  CREATE TABLE rdwc_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    system_id INTEGER NOT NULL,
    log_date TEXT NOT NULL,
    log_type TEXT NOT NULL CHECK(log_type IN ('ADDBACK', 'FULLCHANGE', 'MAINTENANCE', 'MEASUREMENT')),
    FOREIGN KEY (system_id) REFERENCES rdwc_systems(id) ON DELETE RESTRICT
  )
''')
print("  ✅ rdwc_logs table created")

cursor.execute('''
  CREATE TABLE rdwc_log_fertilizers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rdwc_log_id INTEGER NOT NULL,
    fertilizer_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    amount_type TEXT NOT NULL CHECK(amount_type IN ('PER_LITER', 'TOTAL')),
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (rdwc_log_id) REFERENCES rdwc_logs(id) ON DELETE RESTRICT,
    FOREIGN KEY (fertilizer_id) REFERENCES fertilizers(id) ON DELETE RESTRICT
  )
''')
print("  ✅ rdwc_log_fertilizers table created (with RESTRICT - BUG!)")

print("\n📝 Inserting test data...")

# Insert test data
cursor.execute("INSERT INTO rooms (name, archived) VALUES ('Test Room', 0)")
cursor.execute("INSERT INTO grows (name) VALUES ('Test Grow 2024')")
cursor.execute("INSERT INTO rdwc_systems (name) VALUES ('Test RDWC System')")

cursor.execute('''
  INSERT INTO plants (name, strain, breeder, feminized, phase, germination_date, veg_date, room_id, grow_id, rdwc_system_id, archived)
  VALUES ('Test Cannabis Plant', 'Blue Dream', 'Humboldt Seeds', 1, 'VEG', '2024-01-01', '2024-01-15', 1, 1, 1, 0)
''')
print("  ✅ Inserted test plant with critical data (breeder, feminized, veg_date)")

cursor.execute('''
  INSERT INTO plant_logs (plant_id, log_date, action_type, note)
  VALUES (1, '2024-01-20 10:00:00', 'WATER', 'Test log entry - watered with 1L')
''')
print("  ✅ Inserted test log")

cursor.execute('''
  INSERT INTO photos (log_id, file_path)
  VALUES (1, '/storage/emulated/0/Pictures/Plantry/test_photo.jpg')
''')
print("  ✅ Inserted test photo")

conn.commit()

# Verify data
cursor.execute("SELECT COUNT(*) FROM plants")
plant_count = cursor.fetchone()[0]

cursor.execute("SELECT breeder, feminized, veg_date FROM plants WHERE id = 1")
plant_data = cursor.fetchone()

print("\n🔍 Verifying test database...")
print(f"  ✅ Plants count: {plant_count}")
print(f"  ✅ Test plant data:")
print(f"     - breeder: {plant_data[0]}")
print(f"     - feminized: {plant_data[1]}")
print(f"     - veg_date: {plant_data[2]}")

# Check version
cursor.execute("PRAGMA user_version")
version = cursor.fetchone()[0]
print(f"  ✅ Database version: {version}")

conn.close()

print("\n" + "=" * 80)
print(f"✅ v17 test database created successfully!")
print(f"📍 Location: {test_db_path}")
print("\n📋 NEXT STEPS:")
print("1. Copy this DB to the app's data directory")
print("2. Start the app - it should automatically migrate v17 → v33")
print("3. Verify the following fixes:")
print("   - plants.room_id: SET NULL → RESTRICT")
print("   - plants.grow_id: SET NULL → RESTRICT")
print("   - photos.log_id: RESTRICT → CASCADE")
print("   - rdwc_log_fertilizers.rdwc_log_id: RESTRICT → CASCADE")
print("   - All data preserved (breeder, feminized, veg_date)")
print("=" * 80)
