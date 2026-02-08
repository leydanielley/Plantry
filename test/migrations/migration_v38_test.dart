// =============================================
// GROWLOG - Migration v38 Tests
// Tests for migration v37 → v38 (Fix Unique Constraint)
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/database/migrations/scripts/migration_v38.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/plant_log_repository.dart';

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration v37 → v38: Fix Unique Constraint', () {
    late Database db;

    setUp(() async {
      // Create an in-memory database for testing
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create a v37 database structure (with old unique constraint)
          await _createV37Schema(db);
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Migration v38 succeeds on v37 database', () async {
      // Act: Run migration
      await migrationV38.up(db);

      // Assert: No exception thrown
      expect(true, true, reason: 'Migration should complete without errors');
    });

    test('Old unique constraint is removed', () async {
      // Arrange: Run migration
      await migrationV38.up(db);

      // Act: Query indexes on plant_logs table
      final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND tbl_name = 'plant_logs'
      ''');

      final indexNames = indexes.map((row) => row['name'] as String).toList();

      // Assert: Old index should NOT exist
      expect(indexNames, isNot(contains('idx_plant_logs_plant_day_unique')),
          reason: 'Old unique constraint should be removed');
    });

    test('New unique constraint with action_type is created', () async {
      // Arrange: Run migration
      await migrationV38.up(db);

      // Act: Query indexes on plant_logs table
      final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND tbl_name = 'plant_logs'
      ''');

      final indexNames = indexes.map((row) => row['name'] as String).toList();

      // Assert: New index should exist
      expect(indexNames, contains('idx_plant_logs_unique_per_action'),
          reason: 'New unique constraint should exist');
    });

    test('New unique constraint has correct definition', () async {
      // Arrange: Run migration
      await migrationV38.up(db);

      // Act: Query index definition
      final indexDef = await db.rawQuery('''
        SELECT sql FROM sqlite_master
        WHERE type = 'index' AND name = 'idx_plant_logs_unique_per_action'
      ''');

      // Assert
      expect(indexDef, isNotEmpty, reason: 'Index should exist');
      final sql = (indexDef.first['sql'] as String).toLowerCase();
      expect(sql, contains('plant_logs'),
          reason: 'Index should be on plant_logs table');
      expect(sql, contains('plant_id'),
          reason: 'Index should include plant_id');
      expect(sql, contains('day_number'),
          reason: 'Index should include day_number');
      expect(sql, contains('action_type'),
          reason: 'Index should include action_type');
      expect(sql, contains('archived'),
          reason: 'Index should have WHERE archived = 0');
    });

    test('Migration is idempotent (can run multiple times)', () async {
      // Arrange: Run migration first time
      await migrationV38.up(db);

      // Act: Run migration again
      await migrationV38.up(db);

      // Assert: No exception thrown
      expect(true, true, reason: 'Migration should be idempotent');

      // Verify indexes are correct
      final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND tbl_name = 'plant_logs'
      ''');

      final indexNames = indexes.map((row) => row['name'] as String).toList();
      expect(indexNames, contains('idx_plant_logs_unique_per_action'));
      expect(indexNames, isNot(contains('idx_plant_logs_plant_day_unique')));
    });

    test('Existing plant_logs data is preserved', () async {
      // Arrange: Insert test log before migration
      await db.insert('plants', {
        'name': 'Test Plant',
        'seed_date': DateTime.now().toIso8601String(),
        'phase': 'VEG',
      });

      final plantId = await db.rawQuery('SELECT last_insert_rowid() as id');
      final testPlantId = plantId.first['id'] as int;

      await db.insert('plant_logs', {
        'plant_id': testPlantId,
        'day_number': 26,
        'log_date': DateTime.now().toIso8601String(),
        'action_type': 'WATER',
        'archived': 0,
      });

      // Act: Run migration
      await migrationV38.up(db);

      // Assert: Data still exists
      final logs = await db.query(
        'plant_logs',
        where: 'plant_id = ? AND day_number = ?',
        whereArgs: [testPlantId, 26],
      );
      expect(logs, isNotEmpty, reason: 'Log data should be preserved');
      expect(logs.first['action_type'], 'WATER');
    });

    test('Can insert multiple logs with different actions on same day after migration',
        () async {
      // Arrange: Set up database and run migration
      DatabaseHelper.setTestDatabase(db);
      await migrationV38.up(db);

      final repo = PlantLogRepository();

      // Insert test plant
      final plantId = await db.insert('plants', {
        'name': 'Test Plant',
        'seed_date': DateTime.now().toIso8601String(),
        'phase': 'VEG',
      });

      final now = DateTime.now();

      // Act: Insert multiple logs with different actions on same day
      final waterLog = await repo.save(PlantLog(
        plantId: plantId,
        dayNumber: 26,
        logDate: now,
        actionType: ActionType.water,
      ));

      final trainingLog = await repo.save(PlantLog(
        plantId: plantId,
        dayNumber: 26,
        logDate: now,
        actionType: ActionType.training,
      ));

      final noteLog = await repo.save(PlantLog(
        plantId: plantId,
        dayNumber: 26,
        logDate: now,
        actionType: ActionType.note,
      ));

      // Assert: All logs should be saved successfully
      expect(waterLog.id, isNotNull);
      expect(trainingLog.id, isNotNull);
      expect(noteLog.id, isNotNull);

      // Verify all logs exist in database
      final logs = await repo.findByPlant(plantId);
      expect(logs.length, 3, reason: 'Should have 3 logs for same day');
      expect(logs.map((l) => l.actionType).toSet(), {
        ActionType.water,
        ActionType.training,
        ActionType.note,
      });

      DatabaseHelper.setTestDatabase(null);
    });

    test('Cannot insert duplicate logs with same action on same day after migration',
        () async {
      // Arrange: Set up database and run migration
      DatabaseHelper.setTestDatabase(db);
      await migrationV38.up(db);

      final repo = PlantLogRepository();

      // Insert test plant
      final plantId = await db.insert('plants', {
        'name': 'Test Plant',
        'seed_date': DateTime.now().toIso8601String(),
        'phase': 'VEG',
      });

      final now = DateTime.now();

      // Act: Insert first WATER log
      await repo.save(PlantLog(
        plantId: plantId,
        dayNumber: 26,
        logDate: now,
        actionType: ActionType.water,
      ));

      // Assert: Second WATER log on same day should fail
      expect(
        () => repo.save(PlantLog(
          plantId: plantId,
          dayNumber: 26,
          logDate: now,
          actionType: ActionType.water,
        )),
        throwsA(isA<Exception>()),
        reason: 'Duplicate WATER log on same day should be prevented',
      );

      DatabaseHelper.setTestDatabase(null);
    });

    test('Can insert same action type on different days after migration',
        () async {
      // Arrange: Set up database and run migration
      DatabaseHelper.setTestDatabase(db);
      await migrationV38.up(db);

      final repo = PlantLogRepository();

      // Insert test plant
      final plantId = await db.insert('plants', {
        'name': 'Test Plant',
        'seed_date': DateTime.now().toIso8601String(),
        'phase': 'VEG',
      });

      final now = DateTime.now();

      // Act: Insert WATER logs on different days
      final day26Log = await repo.save(PlantLog(
        plantId: plantId,
        dayNumber: 26,
        logDate: now,
        actionType: ActionType.water,
      ));

      final day27Log = await repo.save(PlantLog(
        plantId: plantId,
        dayNumber: 27,
        logDate: now.add(Duration(days: 1)),
        actionType: ActionType.water,
      ));

      // Assert: Both logs should be saved successfully
      expect(day26Log.id, isNotNull);
      expect(day27Log.id, isNotNull);

      // Verify both logs exist
      final logs = await repo.findByPlant(plantId);
      expect(logs.length, 2, reason: 'Should have 2 WATER logs on different days');

      DatabaseHelper.setTestDatabase(null);
    });

    test('Database integrity check passes after migration', () async {
      // Arrange: Run migration
      await migrationV38.up(db);

      // Act: Run integrity check
      final result = await db.rawQuery('PRAGMA integrity_check');

      // Assert
      expect(result, isNotEmpty);
      expect(result.first['integrity_check'], 'ok',
          reason: 'Database integrity should be ok');
    });

    test('Migration preserves existing logs with different days', () async {
      // Arrange: Insert plant and logs on DIFFERENT days (allowed by v37 constraint)
      final plantId = await db.insert('plants', {
        'name': 'Test Plant',
        'seed_date': DateTime.now().toIso8601String(),
        'phase': 'VEG',
      });

      final now = DateTime.now();

      // Insert WATER log on day 26
      await db.insert('plant_logs', {
        'plant_id': plantId,
        'day_number': 26,
        'log_date': now.toIso8601String(),
        'action_type': 'WATER',
        'archived': 0,
      });

      // Insert WATER log on day 27 (different day, so allowed by v37)
      await db.insert('plant_logs', {
        'plant_id': plantId,
        'day_number': 27,
        'log_date': now.add(Duration(days: 1)).toIso8601String(),
        'action_type': 'WATER',
        'archived': 0,
      });

      // Act: Run migration
      await migrationV38.up(db);

      // Assert: Both logs should still exist
      final logs = await db.query(
        'plant_logs',
        where: 'plant_id = ?',
        whereArgs: [plantId],
        orderBy: 'day_number',
      );

      expect(logs.length, 2, reason: 'Both logs should be preserved');
      expect(logs[0]['day_number'], 26);
      expect(logs[1]['day_number'], 27);
    });

    test('Test all action types can coexist on same day', () async {
      // Arrange: Set up database and run migration
      DatabaseHelper.setTestDatabase(db);
      await migrationV38.up(db);

      final repo = PlantLogRepository();

      // Insert test plant
      final plantId = await db.insert('plants', {
        'name': 'Test Plant',
        'seed_date': DateTime.now().toIso8601String(),
        'phase': 'VEG',
      });

      final now = DateTime.now();

      // Act: Insert logs for ALL action types on same day
      final actionTypes = [
        ActionType.water,
        ActionType.feed,
        ActionType.training,
        ActionType.trim,
        ActionType.transplant,
        ActionType.note,
        ActionType.phaseChange,
        ActionType.other,
      ];

      for (final actionType in actionTypes) {
        await repo.save(PlantLog(
          plantId: plantId,
          dayNumber: 26,
          logDate: now,
          actionType: actionType,
        ));
      }

      // Assert: All logs should be saved
      final logs = await repo.findByPlant(plantId);
      expect(logs.length, actionTypes.length,
          reason: 'Should have ${actionTypes.length} different action types on same day');

      DatabaseHelper.setTestDatabase(null);
    });
  });
}

/// Creates a v37 schema for testing
/// This simulates the database state before v38 migration
/// (with old unique constraint on plant_id, day_number only)
Future<void> _createV37Schema(Database db) async {
  // Plants Table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS plants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      seed_date TEXT,
      phase TEXT,
      archived INTEGER DEFAULT 0
    )
  ''');

  // Plant Logs Table with OLD unique constraint (v37)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS plant_logs (
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
      archived INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
    )
  ''');

  // OLD UNIQUE CONSTRAINT: Only on plant_id and day_number
  // This is the constraint we're fixing in v38
  await db.execute('''
    CREATE UNIQUE INDEX idx_plant_logs_plant_day_unique
    ON plant_logs(plant_id, day_number)
    WHERE archived = 0
  ''');
}
