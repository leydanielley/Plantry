#!/usr/bin/env python3
import sqlite3
import os
import sys

print("=" * 80)
print("🧪 MIGRATION SCHEMA TEST - Validating final schema")
print("=" * 80)

# Test database path (should be created by running the app once)
test_db_paths = [
    "/tmp/test_growlog.db",
    os.path.expanduser("~/.local/share/com.plantry.growlog/app_database/growlog.db"),
]

# Find existing DB or create new one
db_path = None
for path in test_db_paths:
    if os.path.exists(path):
        db_path = path
        print(f"✅ Found existing database: {path}")
        break

if not db_path:
    db_path = "/tmp/test_schema_validation.db"
    print(f"⚠️  No existing DB found, creating test DB: {db_path}")

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

errors = []
warnings = []

print("\n" + "=" * 80)
print("🔍 VALIDATING SCHEMA")
print("=" * 80)

# Test 1: Check plants table columns
print("\n📋 Testing plants table...")
cursor.execute("PRAGMA table_info(plants)")
plants_columns = {row[1]: row[2] for row in cursor.fetchall()}

required_plants_columns = {
    'id': 'INTEGER',
    'name': 'TEXT',
    'strain': 'TEXT',
    'breeder': 'TEXT',
    'feminized': 'INTEGER',
    'phase': 'TEXT',
    'germination_date': 'TEXT',
    'veg_date': 'TEXT',
    'bloom_date': 'TEXT',
    'harvest_date': 'TEXT',
    'room_id': 'INTEGER',
    'grow_id': 'INTEGER',
    'rdwc_system_id': 'INTEGER',
    'archived': 'INTEGER',
}

for col, col_type in required_plants_columns.items():
    if col not in plants_columns:
        errors.append(f"plants: Missing column '{col}'")
        print(f"  ❌ Missing column: {col}")
    elif col_type not in plants_columns[col]:
        warnings.append(f"plants.{col}: Expected type '{col_type}', got '{plants_columns[col]}'")
        print(f"  ⚠️  {col}: Type mismatch (expected {col_type}, got {plants_columns[col]})")
    else:
        print(f"  ✅ {col}: {plants_columns[col]}")

# Test 2: Check plants Foreign Keys
print("\n🔗 Testing plants Foreign Keys...")
cursor.execute("PRAGMA foreign_key_list(plants)")
plants_fks = {row[3]: (row[4], row[6]) for row in cursor.fetchall()}  # from: (table, on_delete)

expected_plants_fks = {
    'room_id': ('rooms', 'RESTRICT'),
    'grow_id': ('grows', 'RESTRICT'),
    'rdwc_system_id': ('rdwc_systems', 'RESTRICT'),
}

for col, (table, on_delete) in expected_plants_fks.items():
    if col not in plants_fks:
        errors.append(f"plants.{col}: Missing FK constraint")
        print(f"  ❌ {col}: Missing FK")
    else:
        fk_table, fk_on_delete = plants_fks[col]
        if fk_table != table:
            errors.append(f"plants.{col}: FK points to wrong table (expected {table}, got {fk_table})")
            print(f"  ❌ {col}: Wrong FK table ({fk_table})")
        elif fk_on_delete != on_delete:
            errors.append(f"plants.{col}: Wrong ON DELETE action (expected {on_delete}, got {fk_on_delete})")
            print(f"  ❌ {col} → {fk_table}: ON DELETE should be {on_delete}, got {fk_on_delete}")
        else:
            print(f"  ✅ {col} → {fk_table} ON DELETE {fk_on_delete}")

# Test 3: Check plant_logs table
print("\n📋 Testing plant_logs table...")
cursor.execute("PRAGMA table_info(plant_logs)")
logs_columns = {row[1]: row[2] for row in cursor.fetchall()}

required_logs_columns = {
    'id': 'INTEGER',
    'plant_id': 'INTEGER',
    'log_date': 'TEXT',
    'action_type': 'TEXT',
    'note': 'TEXT',
    'phase': 'TEXT',
}

for col, col_type in required_logs_columns.items():
    if col not in logs_columns:
        errors.append(f"plant_logs: Missing column '{col}'")
        print(f"  ❌ Missing column: {col}")
    else:
        print(f"  ✅ {col}: {logs_columns[col]}")

# Test 4: Check photos FK
print("\n🔗 Testing photos Foreign Keys...")
cursor.execute("PRAGMA foreign_key_list(photos)")
photos_fks = {row[3]: (row[4], row[6]) for row in cursor.fetchall()}

if 'log_id' not in photos_fks:
    errors.append("photos.log_id: Missing FK constraint")
    print("  ❌ log_id: Missing FK")
else:
    fk_table, fk_on_delete = photos_fks['log_id']
    if fk_on_delete != 'CASCADE':
        errors.append(f"photos.log_id: Should be CASCADE, got {fk_on_delete}")
        print(f"  ❌ log_id → {fk_table}: ON DELETE should be CASCADE, got {fk_on_delete}")
    else:
        print(f"  ✅ log_id → {fk_table} ON DELETE {fk_on_delete}")

# Test 5: Check rooms.archived
print("\n📋 Testing rooms table...")
cursor.execute("PRAGMA table_info(rooms)")
rooms_columns = {row[1]: row[2] for row in cursor.fetchall()}

if 'archived' not in rooms_columns:
    errors.append("rooms: Missing 'archived' column")
    print("  ❌ Missing column: archived")
else:
    print(f"  ✅ archived: {rooms_columns['archived']}")

# Test 6: Check rdwc_logs
print("\n📋 Testing rdwc_logs table...")
cursor.execute("PRAGMA table_info(rdwc_logs)")
rdwc_logs_columns = {row[1]: row[2] for row in cursor.fetchall()}

if 'log_type' not in rdwc_logs_columns:
    warnings.append("rdwc_logs: Missing 'log_type' column (might not exist yet)")
    print("  ⚠️  log_type column not found (table might not exist yet)")
else:
    # Try to get CREATE TABLE statement to check CHECK constraint
    cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='rdwc_logs'")
    result = cursor.fetchone()
    if result:
        create_sql = result[0]
        if "'ADDBACK'" in create_sql and "'FULLCHANGE'" in create_sql:
            print("  ✅ log_type: CHECK constraint present (UPPERCASE values)")
        elif "'addback'" in create_sql:
            errors.append("rdwc_logs.log_type: CHECK constraint has lowercase values (should be UPPERCASE)")
            print("  ❌ log_type: CHECK constraint has lowercase values!")
        else:
            warnings.append("rdwc_logs.log_type: Could not verify CHECK constraint")
            print("  ⚠️  log_type: Could not verify CHECK constraint")

# Test 7: Check rdwc_log_fertilizers
print("\n📋 Testing rdwc_log_fertilizers table...")
cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='rdwc_log_fertilizers'")
if cursor.fetchone():
    cursor.execute("PRAGMA foreign_key_list(rdwc_log_fertilizers)")
    fert_fks = {row[3]: (row[4], row[6]) for row in cursor.fetchall()}

    if 'rdwc_log_id' in fert_fks:
        fk_table, fk_on_delete = fert_fks['rdwc_log_id']
        if fk_on_delete != 'CASCADE':
            errors.append(f"rdwc_log_fertilizers.rdwc_log_id: Should be CASCADE, got {fk_on_delete}")
            print(f"  ❌ rdwc_log_id: ON DELETE should be CASCADE, got {fk_on_delete}")
        else:
            print(f"  ✅ rdwc_log_id → {fk_table} ON DELETE {fk_on_delete}")

    # Check amount_type CHECK constraint
    cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='rdwc_log_fertilizers'")
    result = cursor.fetchone()
    if result:
        create_sql = result[0]
        if "'PER_LITER'" in create_sql and "'TOTAL'" in create_sql:
            print("  ✅ amount_type: CHECK constraint correct (PER_LITER, TOTAL)")
        elif "'ml'" in create_sql or "'g'" in create_sql:
            errors.append("rdwc_log_fertilizers.amount_type: Wrong CHECK constraint values")
            print("  ❌ amount_type: Wrong CHECK constraint (should be PER_LITER, TOTAL)")
else:
    print("  ⚠️  Table does not exist yet (might be created in later migration)")

conn.close()

# Summary
print("\n" + "=" * 80)
print("📊 TEST SUMMARY")
print("=" * 80)

if errors:
    print(f"\n❌ ERRORS FOUND: {len(errors)}")
    for error in errors:
        print(f"  • {error}")

if warnings:
    print(f"\n⚠️  WARNINGS: {len(warnings)}")
    for warning in warnings:
        print(f"  • {warning}")

if not errors and not warnings:
    print("\n🎉 ALL TESTS PASSED! Schema is valid.")
    sys.exit(0)
elif not errors:
    print("\n✅ All critical tests passed (only warnings)")
    sys.exit(0)
else:
    print(f"\n❌ {len(errors)} critical errors found!")
    sys.exit(1)
