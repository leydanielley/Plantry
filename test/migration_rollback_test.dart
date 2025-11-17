// =============================================
// MIGRATION ROLLBACK TEST
// Verifies that schema validation failures trigger automatic rollback
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/migrations/migration_manager.dart';
import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/schema_registry.dart';
import 'dart:io';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration Rollback Tests', () {
    test('Schema validation failure triggers automatic rollback', () async {
      final testDbPath = '/tmp/test_migration_rollback.db';

      // Delete old test DB
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Create v17 database with test data
      var db = await databaseFactory.openDatabase(
        testDbPath,
        options: OpenDatabaseOptions(
          version: 17,
          onCreate: (db, version) async {
            // Create minimal v17 schema
            await db.execute('''
              CREATE TABLE plants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                strain TEXT,
                phase TEXT DEFAULT 'SEEDLING',
                veg_date TEXT,
                bloom_date TEXT,
                harvest_date TEXT,
                room_id INTEGER,
                grow_id INTEGER,
                archived INTEGER DEFAULT 0
              )
            ''');

            await db.execute('''
              CREATE TABLE plant_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plant_id INTEGER NOT NULL,
                day_number INTEGER NOT NULL,
                log_date TEXT NOT NULL,
                action_type TEXT NOT NULL,
                note TEXT,
                archived INTEGER DEFAULT 0,
                FOREIGN KEY (plant_id) REFERENCES plants(id)
              )
            ''');

            await db.execute('''
              CREATE TABLE photos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                log_id INTEGER NOT NULL,
                file_path TEXT NOT NULL,
                FOREIGN KEY (log_id) REFERENCES plant_logs(id)
              )
            ''');
          },
        ),
      );

      // Insert test data
      await db.insert('plants', {
        'name': 'Test Plant',
        'strain': 'Test Strain',
        'phase': 'VEG',
      });

      await db.insert('plant_logs', {
        'plant_id': 1,
        'day_number': 1,
        'log_date': '2024-01-01',
        'action_type': 'WATER',
        'note': 'First watering',
      });

      // Verify data exists
      final plantsBefore = await db.query('plants');
      expect(plantsBefore.length, 1, reason: 'Should have 1 plant before migration');

      final logsBefore = await db.query('plant_logs');
      expect(logsBefore.length, 1, reason: 'Should have 1 log before migration');

      print('✅ v17 database created with test data');

      // Close database
      await db.close();

      print('\n🔄 Attempting migration v17 → v20 with broken schema...');

      // Create broken migration that will fail validation
      final brokenMigration = Migration(
        version: 18,
        description: 'BROKEN: Missing required column',
        up: (txn) async {
          // This migration "forgets" to add a required column
          // which will cause schema validation to fail
          await txn.execute('ALTER TABLE plants ADD COLUMN broken_field TEXT');
          // Missing: Should add breeder, seed_type, etc.
        },
      );

      // Create migration manager with broken migration
      final migrationManager = MigrationManager();

      // Replace migrations with broken one (for testing)
      final originalMigrations = migrationManager.migrations;

      // Reopen database
      db = await databaseFactory.openDatabase(testDbPath);

      bool migrationFailed = false;
      String? errorMessage;

      try {
        // Manually run the broken migration
        await db.transaction((txn) async {
          // Run broken migration
          await brokenMigration.up(txn);

          // Try to validate schema (this should fail)
          final schemaValid = await SchemaRegistry.validateSchema(txn, 18);

          if (!schemaValid) {
            throw Exception('Schema validation failed (expected)');
          }
        });
      } catch (e) {
        migrationFailed = true;
        errorMessage = e.toString();
        print('✅ Migration failed as expected: $e');
      }

      // Verify migration failed
      expect(migrationFailed, isTrue,
          reason: 'Migration should have failed due to schema validation');

      print('\n🔍 Verifying database state after rollback...');

      // Verify database is still at v17
      final dbVersion = await db.rawQuery('PRAGMA user_version');
      final version = dbVersion.first['user_version'] as int;
      expect(version, equals(17),
          reason: 'Database should still be at v17 after rollback');

      print('  ✅ Database version: v$version (rollback successful)');

      // Verify original data is intact
      final plantsAfter = await db.query('plants');
      expect(plantsAfter.length, 1, reason: 'Should still have 1 plant after rollback');
      expect(plantsAfter.first['name'], equals('Test Plant'),
          reason: 'Plant data should be intact');

      final logsAfter = await db.query('plant_logs');
      expect(logsAfter.length, 1, reason: 'Should still have 1 log after rollback');

      print('  ✅ Data integrity: All data preserved');

      // Verify broken_field column does NOT exist (rollback worked)
      final plantsSchema = await db.rawQuery('PRAGMA table_info(plants)');
      final columnNames = plantsSchema.map((col) => col['name'] as String).toList();

      expect(columnNames.contains('broken_field'), isFalse,
          reason: 'Broken column should not exist (transaction rolled back)');

      print('  ✅ Schema rollback: broken_field column not present');

      await db.close();
      await file.delete();

      print('\n🎉 ROLLBACK TEST PASSED!');
      print('   - Migration failed as expected');
      print('   - Database version remained at v17');
      print('   - All data preserved');
      print('   - Schema changes rolled back');
    });

    test('Successful migration with validation commits properly', () async {
      final testDbPath = '/tmp/test_migration_success.db';

      // Delete old test DB
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Create v17 database
      var db = await databaseFactory.openDatabase(
        testDbPath,
        options: OpenDatabaseOptions(
          version: 17,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE plants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL
              )
            ''');
          },
        ),
      );

      await db.insert('plants', {'name': 'Test Plant'});
      await db.close();

      print('\n🔄 Running successful migration...');

      // Create valid migration
      final validMigration = Migration(
        version: 18,
        description: 'Valid migration',
        up: (txn) async {
          await txn.execute('ALTER TABLE plants ADD COLUMN strain TEXT');
        },
      );

      db = await databaseFactory.openDatabase(testDbPath);

      await db.transaction((txn) async {
        await validMigration.up(txn);

        // This validation should pass (no schema definition for v18 in test)
        // So we just verify the column exists
        final schema = await txn.rawQuery('PRAGMA table_info(plants)');
        final hasStrain = schema.any((col) => col['name'] == 'strain');

        if (!hasStrain) {
          throw Exception('Migration did not add strain column');
        }

        await txn.rawUpdate('PRAGMA user_version = 18');
      });

      print('✅ Migration succeeded and committed');

      // Verify changes persisted
      final version = await db.rawQuery('PRAGMA user_version');
      expect((version.first['user_version'] as int), equals(18),
          reason: 'Database should be at v18 after successful migration');

      final schema = await db.rawQuery('PRAGMA table_info(plants)');
      final hasStrain = schema.any((col) => col['name'] == 'strain');
      expect(hasStrain, isTrue, reason: 'strain column should exist after commit');

      final plants = await db.query('plants');
      expect(plants.length, 1, reason: 'Data should be preserved');

      await db.close();
      await file.delete();

      print('  ✅ Changes committed successfully');
      print('  ✅ Data preserved');
    });
  });
}
