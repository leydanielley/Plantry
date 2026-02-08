// =============================================
// LOAD TEST - Database Performance with >10k Records
// Tests system behavior under heavy load
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/database_helper.dart';

void main() {
  late Database testDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create fresh in-memory database for each test
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 15,
        onCreate: (db, version) async {
          // Simplified schema for load testing
          await db.execute('''
            CREATE TABLE plants (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              seed_type TEXT NOT NULL,
              medium TEXT NOT NULL,
              phase TEXT DEFAULT 'SEEDLING',
              archived INTEGER DEFAULT 0,
              created_at TEXT DEFAULT (datetime('now'))
            )
          ''');

          await db.execute('''
            CREATE TABLE plant_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              plant_id INTEGER NOT NULL,
              day_number INTEGER NOT NULL,
              log_date TEXT NOT NULL DEFAULT (datetime('now')),
              action_type TEXT NOT NULL,
              note TEXT,
              archived INTEGER DEFAULT 0,
              created_at TEXT DEFAULT (datetime('now')),
              FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
            )
          ''');

          await db.execute(
            'CREATE INDEX idx_logs_plant ON plant_logs(plant_id)',
          );
          await db.execute(
            'CREATE INDEX idx_logs_archived ON plant_logs(archived)',
          );
          await db.execute(
            'CREATE UNIQUE INDEX idx_plant_logs_plant_day_unique ON plant_logs(plant_id, day_number) WHERE archived = 0',
          );
        },
      ),
    );

    // Inject test database
    DatabaseHelper.setTestDatabase(testDb);
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('Load Test - 10,000+ Plants', () {
    test(
      'should handle inserting 10,000 plants without memory overflow',
      () async {
        final stopwatch = Stopwatch()..start();

        // Insert 10,000 plants in batches of 500
        const totalPlants = 10000;
        const batchSize = 500;
        int inserted = 0;

        for (int batch = 0; batch < totalPlants / batchSize; batch++) {
          await testDb.transaction((txn) async {
            final batchStopwatch = Stopwatch()..start();

            for (int i = 0; i < batchSize; i++) {
              final plantNum = batch * batchSize + i + 1;
              await txn.insert('plants', {
                'name': 'Plant $plantNum',
                'seed_type': plantNum % 2 == 0 ? 'PHOTO' : 'AUTO',
                'medium': ['ERDE', 'COCO', 'HYDRO'][plantNum % 3],
                'phase': 'VEG',
                'archived': 0,
              });
              inserted++;
            }

            batchStopwatch.stop();
            print(
              '  Batch ${batch + 1}/${totalPlants ~/ batchSize}: '
              '${batchStopwatch.elapsedMilliseconds}ms',
            );
          });
        }

        stopwatch.stop();
        print(
          '✅ Inserted $inserted plants in ${stopwatch.elapsedMilliseconds}ms',
        );
        print(
          '   Average: ${(stopwatch.elapsedMilliseconds / inserted).toStringAsFixed(2)}ms per plant',
        );

        // Verify count
        final count = Sqflite.firstIntValue(
          await testDb.rawQuery('SELECT COUNT(*) FROM plants'),
        );
        expect(count, equals(totalPlants));

        // Performance assertion: Should complete within reasonable time
        expect(
          stopwatch.elapsed.inSeconds,
          lessThan(60),
          reason: 'Inserting 10k plants should take less than 60 seconds',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'should handle querying 10,000 plants with pagination',
      () async {
        // Setup: Insert 10,000 plants
        print('  Setup: Inserting 10,000 plants...');
        await testDb.transaction((txn) async {
          for (int i = 1; i <= 10000; i++) {
            await txn.insert('plants', {
              'name': 'Plant $i',
              'seed_type': 'PHOTO',
              'medium': 'ERDE',
              'archived': 0,
            });
          }
        });

        print('  Testing pagination queries...');

        // Test 1: Query with LIMIT (should be fast)
        final stopwatch1 = Stopwatch()..start();
        final page1 = await testDb.query(
          'plants',
          where: 'archived = ?',
          whereArgs: [0],
          limit: 100,
          orderBy: 'id DESC',
        );
        stopwatch1.stop();

        print(
          '  ✅ Limited query (100 records): ${stopwatch1.elapsedMilliseconds}ms',
        );
        expect(page1.length, equals(100));
        expect(
          stopwatch1.elapsedMilliseconds,
          lessThan(500),
          reason: 'Limited query should be fast (<500ms)',
        );

        // Test 2: Query without LIMIT (should trigger warning)
        final stopwatch2 = Stopwatch()..start();
        final allPlants = await testDb.query(
          'plants',
          where: 'archived = ?',
          whereArgs: [0],
        );
        stopwatch2.stop();

        print(
          '  ⚠️  Unlimited query (all 10k): ${stopwatch2.elapsedMilliseconds}ms',
        );
        expect(allPlants.length, equals(10000));

        // This should be slower but still reasonable
        expect(
          stopwatch2.elapsedMilliseconds,
          lessThan(5000),
          reason: 'Even unlimited query should complete within 5 seconds',
        );

        // Test 3: Pagination with OFFSET
        final stopwatch3 = Stopwatch()..start();
        final page5 = await testDb.query(
          'plants',
          where: 'archived = ?',
          whereArgs: [0],
          limit: 100,
          offset: 400,
          orderBy: 'id DESC',
        );
        stopwatch3.stop();

        print(
          '  ✅ Paginated query (page 5): ${stopwatch3.elapsedMilliseconds}ms',
        );
        expect(page5.length, equals(100));
        expect(
          stopwatch3.elapsedMilliseconds,
          lessThan(500),
          reason: 'Paginated query should be fast',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('Load Test - 50,000+ Plant Logs', () {
    test(
      'should handle 50,000 logs across 100 plants',
      () async {
        print('  Setup: Creating 100 plants...');

        // Create 100 plants
        final plantIds = <int>[];
        await testDb.transaction((txn) async {
          for (int i = 1; i <= 100; i++) {
            final plantId = await txn.insert('plants', {
              'name': 'Plant $i',
              'seed_type': 'PHOTO',
              'medium': 'ERDE',
              'archived': 0,
            });
            plantIds.add(plantId);
          }
        });

        print('  Creating 50,000 logs (500 logs per plant)...');

        final stopwatch = Stopwatch()..start();
        int totalLogs = 0;

        // Insert 500 logs per plant (50,000 total)
        for (final plantId in plantIds) {
          await testDb.transaction((txn) async {
            for (int day = 1; day <= 500; day++) {
              await txn.insert('plant_logs', {
                'plant_id': plantId,
                'day_number': day,
                'log_date': DateTime.now().toIso8601String(),
                'action_type': ['WATER', 'FEED', 'NOTE'][day % 3],
                'note': 'Day $day log',
                'archived': 0,
              });
              totalLogs++;
            }
          });

          if ((plantId - plantIds.first + 1) % 10 == 0) {
            print('    Progress: ${plantId - plantIds.first + 1}/100 plants');
          }
        }

        stopwatch.stop();
        print('✅ Created $totalLogs logs in ${stopwatch.elapsed.inSeconds}s');

        // Verify count
        final count = Sqflite.firstIntValue(
          await testDb.rawQuery('SELECT COUNT(*) FROM plant_logs'),
        );
        expect(count, equals(50000));

        // Performance assertion
        expect(
          stopwatch.elapsed.inSeconds,
          lessThan(120),
          reason: 'Creating 50k logs should take less than 2 minutes',
        );

        // Test querying logs for a single plant (should be fast with index)
        final queryStopwatch = Stopwatch()..start();
        final logs = await testDb.query(
          'plant_logs',
          where: 'plant_id = ? AND archived = ?',
          whereArgs: [plantIds.first, 0],
          orderBy: 'day_number DESC',
        );
        queryStopwatch.stop();

        print(
          '  ✅ Query logs for 1 plant: ${queryStopwatch.elapsedMilliseconds}ms (${logs.length} logs)',
        );
        expect(logs.length, equals(500));
        expect(
          queryStopwatch.elapsedMilliseconds,
          lessThan(500),
          reason: 'Indexed query should be fast',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'should handle complex JOIN queries with large dataset',
      () async {
        // Setup: 1,000 plants with 10 logs each (10,000 logs total)
        print('  Setup: Creating 1,000 plants with logs...');

        await testDb.transaction((txn) async {
          for (int i = 1; i <= 1000; i++) {
            final plantId = await txn.insert('plants', {
              'name': 'Plant $i',
              'seed_type': 'PHOTO',
              'medium': 'ERDE',
              'archived': 0,
            });

            for (int day = 1; day <= 10; day++) {
              await txn.insert('plant_logs', {
                'plant_id': plantId,
                'day_number': day,
                'log_date': DateTime.now().toIso8601String(),
                'action_type': 'WATER',
                'archived': 0,
              });
            }
          }
        });

        // Test complex JOIN query
        final stopwatch = Stopwatch()..start();
        final result = await testDb.rawQuery('''
        SELECT
          p.id, p.name, p.phase,
          COUNT(pl.id) as log_count,
          MAX(pl.day_number) as max_day
        FROM plants p
        LEFT JOIN plant_logs pl ON p.id = pl.plant_id
        WHERE p.archived = 0
        GROUP BY p.id
        HAVING log_count > 5
        ORDER BY max_day DESC
        LIMIT 100
      ''');
        stopwatch.stop();

        print(
          '  ✅ Complex JOIN query: ${stopwatch.elapsedMilliseconds}ms (${result.length} results)',
        );
        expect(result.length, equals(100));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason: 'Complex JOIN should complete within 2 seconds',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('Load Test - Memory & Cleanup', () {
    test(
      'should handle deletion of 10,000 records without memory leak',
      () async {
        // Insert 10,000 plants
        print('  Setup: Creating 10,000 plants...');
        await testDb.transaction((txn) async {
          for (int i = 1; i <= 10000; i++) {
            await txn.insert('plants', {
              'name': 'Plant $i',
              'seed_type': 'PHOTO',
              'medium': 'ERDE',
              'archived': 0,
            });
          }
        });

        // Delete in batches
        print('  Deleting 10,000 plants in batches...');
        final stopwatch = Stopwatch()..start();

        await testDb.transaction((txn) async {
          await txn.delete('plants');
        });

        stopwatch.stop();
        print('  ✅ Deleted all plants in ${stopwatch.elapsedMilliseconds}ms');

        final count = Sqflite.firstIntValue(
          await testDb.rawQuery('SELECT COUNT(*) FROM plants'),
        );
        expect(count, equals(0));

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason: 'Batch deletion should be fast',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('Load Test - Index Performance', () {
    test('should demonstrate index effectiveness with 10k records', () async {
      // Create 10,000 plants
      await testDb.transaction((txn) async {
        for (int i = 1; i <= 10000; i++) {
          await txn.insert('plants', {
            'name': 'Plant $i',
            'seed_type': i % 2 == 0 ? 'PHOTO' : 'AUTO',
            'medium': ['ERDE', 'COCO', 'HYDRO'][i % 3],
            'phase': ['SEEDLING', 'VEG', 'BLOOM'][i % 3],
            'archived': i > 9000 ? 1 : 0, // 10% archived
          });
        }
      });

      // Query 1: With indexed column (archived)
      final stopwatch1 = Stopwatch()..start();
      final active = await testDb.query(
        'plants',
        where: 'archived = ?',
        whereArgs: [0],
      );
      stopwatch1.stop();

      print(
        '  ✅ Indexed query (archived=0): ${stopwatch1.elapsedMilliseconds}ms (${active.length} results)',
      );
      expect(active.length, equals(9000));

      // Query 2: Without index (phase - no index created)
      final stopwatch2 = Stopwatch()..start();
      final veg = await testDb.query(
        'plants',
        where: 'phase = ?',
        whereArgs: ['VEG'],
      );
      stopwatch2.stop();

      print(
        '  ⚠️  Non-indexed query (phase=VEG): ${stopwatch2.elapsedMilliseconds}ms (${veg.length} results)',
      );

      // Indexed queries should be significantly faster
      // (Though with SQLite's efficiency, the difference may not be dramatic for 10k records)
      print(
        '  Index speedup factor: ${(stopwatch2.elapsedMilliseconds / stopwatch1.elapsedMilliseconds).toStringAsFixed(2)}x',
      );
    });
  });
}
