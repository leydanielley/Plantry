// =============================================
// GROWLOG - HarvestRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/harvest_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/harvest.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late HarvestRepository repository;
  late int testPlantId;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    repository = HarvestRepository();
    await TestDatabaseHelper.seedTestData(testDb);

    // Create a test plant for harvest tests
    testPlantId = await testDb.insert('plants', {
      'name': 'Test Plant for Harvest',
      'seed_type': 'REGULAR',
      'medium': 'SOIL',
      'phase': 'HARVEST',
      'seed_date': DateTime.now()
          .subtract(const Duration(days: 90))
          .toIso8601String(),
    });
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('HarvestRepository - CRUD Operations', () {
    test('createHarvest() - should create new harvest', () async {
      // Arrange
      final harvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now(),
        wetWeight: 500.0,
      );

      // Act
      final id = await repository.createHarvest(harvest);

      // Assert
      expect(id, greaterThan(0));

      final found = await repository.getHarvestById(id);
      expect(found, isNotNull);
      expect(found!.plantId, equals(testPlantId));
      expect(found.wetWeight, equals(500.0));
    });

    test('createHarvest() - should create harvest with all fields', () async {
      // Arrange
      final harvestDate = DateTime.now();
      final harvest = Harvest(
        plantId: testPlantId,
        harvestDate: harvestDate,
        wetWeight: 500.0,
        dryWeight: 100.0,
        rating: 5,
        tasteNotes: 'Fruity',
        effectNotes: 'Relaxing',
        overallNotes: 'Great harvest',
        thcPercentage: 22.5,
        cbdPercentage: 0.5,
        terpeneProfile: 'Myrcene, Limonene',
      );

      // Act
      final id = await repository.createHarvest(harvest);

      // Assert
      final found = await repository.getHarvestById(id);
      expect(found, isNotNull);
      expect(found!.wetWeight, equals(500.0));
      expect(found.dryWeight, equals(100.0));
      expect(found.rating, equals(5));
      expect(found.tasteNotes, equals('Fruity'));
      expect(found.effectNotes, equals('Relaxing'));
      expect(found.overallNotes, equals('Great harvest'));
      expect(found.thcPercentage, equals(22.5));
      expect(found.cbdPercentage, equals(0.5));
      expect(found.terpeneProfile, equals('Myrcene, Limonene'));
    });

    test('updateHarvest() - should update existing harvest', () async {
      // Arrange
      final harvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now(),
        wetWeight: 500.0,
      );
      final id = await repository.createHarvest(harvest);
      final created = await repository.getHarvestById(id);

      // Act
      final updated = created!.copyWith(dryWeight: 100.0, rating: 4);
      final updateCount = await repository.updateHarvest(updated);

      // Assert
      expect(updateCount, equals(1));

      final found = await repository.getHarvestById(id);
      expect(found, isNotNull);
      expect(found!.dryWeight, equals(100.0));
      expect(found.rating, equals(4));
    });

    test(
      'deleteHarvest() - should delete harvest and reset plant phase',
      () async {
        // Arrange
        final harvest = Harvest(
          plantId: testPlantId,
          harvestDate: DateTime.now(),
          wetWeight: 500.0,
        );
        final id = await repository.createHarvest(harvest);

        // Act
        final deleteCount = await repository.deleteHarvest(id);

        // Assert
        expect(deleteCount, equals(1));

        final found = await repository.getHarvestById(id);
        expect(found, isNull);

        // Verify plant was reset to BLOOM phase
        final plantMaps = await testDb.query(
          'plants',
          where: 'id = ?',
          whereArgs: [testPlantId],
        );
        expect(plantMaps.first['phase'], equals('BLOOM'));
      },
    );

    test('getHarvestById() - should return harvest when exists', () async {
      // Arrange
      final harvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now(),
        wetWeight: 500.0,
      );
      final id = await repository.createHarvest(harvest);

      // Act
      final found = await repository.getHarvestById(id);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(id));
      expect(found.plantId, equals(testPlantId));
    });

    test('getHarvestById() - should return null when not exists', () async {
      // Act
      final found = await repository.getHarvestById(99999);

      // Assert
      expect(found, isNull);
    });

    test('getHarvestByPlantId() - should return harvest for plant', () async {
      // Arrange
      final harvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now(),
        wetWeight: 500.0,
      );
      await repository.createHarvest(harvest);

      // Act
      final found = await repository.getHarvestByPlantId(testPlantId);

      // Assert
      expect(found, isNotNull);
      expect(found!.plantId, equals(testPlantId));
    });

    test(
      'getHarvestByPlantId() - should return null for plant without harvest',
      () async {
        // Act
        final found = await repository.getHarvestByPlantId(99999);

        // Assert
        expect(found, isNull);
      },
    );

    test('getAllHarvests() - should return all harvests', () async {
      // Arrange
      await repository.createHarvest(
        Harvest(
          plantId: testPlantId,
          harvestDate: DateTime.now(),
          wetWeight: 500.0,
        ),
      );

      // Act
      final harvests = await repository.getAllHarvests();

      // Assert
      expect(harvests, isNotEmpty);
    });

    test('getAllHarvests(limit) - should respect limit', () async {
      // Arrange - Create multiple harvests
      for (int i = 1; i <= 5; i++) {
        final plantId = await testDb.insert('plants', {
          'name': 'Plant $i',
          'seed_type': 'REGULAR',
          'medium': 'SOIL',
          'phase': 'HARVEST',
        });
        await repository.createHarvest(
          Harvest(
            plantId: plantId,
            harvestDate: DateTime.now().subtract(Duration(days: i)),
            wetWeight: i * 100.0,
          ),
        );
      }

      // Act
      final harvests = await repository.getAllHarvests(limit: 3);

      // Assert
      expect(harvests.length, equals(3));
    });
  });

  group('HarvestRepository - Status Tracking', () {
    test('getDryingHarvests() - should return harvests in drying', () async {
      // Arrange - Harvest in drying
      final dryingHarvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now().subtract(const Duration(days: 7)),
        wetWeight: 500.0,
        dryingStartDate: DateTime.now().subtract(const Duration(days: 5)),
        // No dryingEndDate - still drying
      );
      await repository.createHarvest(dryingHarvest);

      // Act
      final drying = await repository.getDryingHarvests();

      // Assert
      expect(drying, isNotEmpty);
      for (final h in drying) {
        expect(h.dryingStartDate, isNotNull);
        expect(h.dryingEndDate, isNull);
      }
    });

    test('getCuringHarvests() - should return harvests in curing', () async {
      // Arrange - Harvest in curing
      final curingHarvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now().subtract(const Duration(days: 14)),
        wetWeight: 500.0,
        dryWeight: 100.0,
        dryingStartDate: DateTime.now().subtract(const Duration(days: 12)),
        dryingEndDate: DateTime.now().subtract(const Duration(days: 5)),
        curingStartDate: DateTime.now().subtract(const Duration(days: 3)),
        // No curingEndDate - still curing
      );
      await repository.createHarvest(curingHarvest);

      // Act
      final curing = await repository.getCuringHarvests();

      // Assert
      expect(curing, isNotEmpty);
      for (final h in curing) {
        expect(h.curingStartDate, isNotNull);
        expect(h.curingEndDate, isNull);
      }
    });

    test('getCompletedHarvests() - should return completed harvests', () async {
      // Arrange - Completed harvest
      final completedHarvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now().subtract(const Duration(days: 30)),
        wetWeight: 500.0,
        dryWeight: 100.0,
        dryingStartDate: DateTime.now().subtract(const Duration(days: 28)),
        dryingEndDate: DateTime.now().subtract(const Duration(days: 21)),
        curingStartDate: DateTime.now().subtract(const Duration(days: 20)),
        curingEndDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      await repository.createHarvest(completedHarvest);

      // Act
      final completed = await repository.getCompletedHarvests();

      // Assert
      expect(completed, isNotEmpty);
      for (final h in completed) {
        expect(h.dryWeight, isNotNull);
        expect(h.dryingEndDate, isNotNull);
        expect(h.curingEndDate, isNotNull);
      }
    });
  });

  group('HarvestRepository - Statistics', () {
    test('getTotalYield() - should calculate total dry weight', () async {
      // Arrange
      await repository.createHarvest(
        Harvest(
          plantId: testPlantId,
          harvestDate: DateTime.now(),
          wetWeight: 500.0,
          dryWeight: 100.0,
        ),
      );

      final plant2Id = await testDb.insert('plants', {
        'name': 'Plant 2',
        'seed_type': 'REGULAR',
        'medium': 'SOIL',
        'phase': 'HARVEST',
      });
      await repository.createHarvest(
        Harvest(
          plantId: plant2Id,
          harvestDate: DateTime.now(),
          wetWeight: 600.0,
          dryWeight: 120.0,
        ),
      );

      // Act
      final totalYield = await repository.getTotalYield();

      // Assert
      expect(totalYield, equals(220.0)); // 100 + 120
    });

    test('getTotalYield() - should return 0 when no harvests', () async {
      // Act
      final totalYield = await repository.getTotalYield();

      // Assert
      expect(totalYield, equals(0.0));
    });

    test('getAverageYield() - should calculate average dry weight', () async {
      // Arrange
      await repository.createHarvest(
        Harvest(
          plantId: testPlantId,
          harvestDate: DateTime.now(),
          wetWeight: 500.0,
          dryWeight: 100.0,
        ),
      );

      final plant2Id = await testDb.insert('plants', {
        'name': 'Plant 2',
        'seed_type': 'REGULAR',
        'medium': 'SOIL',
        'phase': 'HARVEST',
      });
      await repository.createHarvest(
        Harvest(
          plantId: plant2Id,
          harvestDate: DateTime.now(),
          wetWeight: 600.0,
          dryWeight: 120.0,
        ),
      );

      // Act
      final averageYield = await repository.getAverageYield();

      // Assert
      expect(averageYield, equals(110.0)); // (100 + 120) / 2
    });

    test('getAverageYield() - should return 0 when no harvests', () async {
      // Act
      final averageYield = await repository.getAverageYield();

      // Assert
      expect(averageYield, equals(0.0));
    });

    test('getHarvestCount() - should return correct count', () async {
      // Arrange - Get initial count
      final initialCount = await repository.getHarvestCount();

      // Create 2 harvests
      await repository.createHarvest(
        Harvest(
          plantId: testPlantId,
          harvestDate: DateTime.now(),
          wetWeight: 500.0,
        ),
      );

      final plant2Id = await testDb.insert('plants', {
        'name': 'Plant 2',
        'seed_type': 'REGULAR',
        'medium': 'SOIL',
        'phase': 'HARVEST',
      });
      await repository.createHarvest(
        Harvest(
          plantId: plant2Id,
          harvestDate: DateTime.now(),
          wetWeight: 600.0,
        ),
      );

      // Act
      final finalCount = await repository.getHarvestCount();

      // Assert
      expect(finalCount, equals(initialCount + 2));
    });
  });

  group('HarvestRepository - Join Queries', () {
    test(
      'getHarvestWithPlant() - should return harvest with plant data',
      () async {
        // Arrange
        final harvest = Harvest(
          plantId: testPlantId,
          harvestDate: DateTime.now(),
          wetWeight: 500.0,
        );
        final id = await repository.createHarvest(harvest);

        // Act
        final result = await repository.getHarvestWithPlant(id);

        // Assert
        expect(result, isNotNull);
        expect(result!['id'], equals(id));
        expect(result['plant_id'], equals(testPlantId));
        expect(result['plant_name'], equals('Test Plant for Harvest'));
      },
    );

    test(
      'getHarvestWithPlant() - should return null when not exists',
      () async {
        // Act
        final result = await repository.getHarvestWithPlant(99999);

        // Assert
        expect(result, isNull);
      },
    );

    test(
      'getAllHarvestsWithPlants() - should return harvests with plant data',
      () async {
        // Arrange
        await repository.createHarvest(
          Harvest(
            plantId: testPlantId,
            harvestDate: DateTime.now(),
            wetWeight: 500.0,
          ),
        );

        // Act
        final results = await repository.getAllHarvestsWithPlants();

        // Assert
        expect(results, isNotEmpty);
        for (final result in results) {
          expect(result['plant_id'], isNotNull);
          expect(result['plant_name'], isNotNull);
        }
      },
    );
  });

  group('HarvestRepository - Edge Cases', () {
    test('createHarvest() - should handle minimal harvest data', () async {
      // Arrange - Only required fields
      final harvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now(),
      );

      // Act
      final id = await repository.createHarvest(harvest);

      // Assert
      expect(id, greaterThan(0));

      final found = await repository.getHarvestById(id);
      expect(found, isNotNull);
      expect(found!.plantId, equals(testPlantId));
      expect(found.wetWeight, isNull);
      expect(found.dryWeight, isNull);
    });

    test('updateHarvest() - should handle progressive updates', () async {
      // Arrange - Create minimal harvest
      final harvest = Harvest(
        plantId: testPlantId,
        harvestDate: DateTime.now(),
        wetWeight: 500.0,
      );
      final id = await repository.createHarvest(harvest);
      var current = await repository.getHarvestById(id);

      // Act & Assert - Update 1: Start drying
      current = current!.copyWith(
        dryingStartDate: DateTime.now(),
        dryingMethod: 'Hanging',
      );
      await repository.updateHarvest(current);

      var found = await repository.getHarvestById(id);
      expect(found!.dryingStartDate, isNotNull);
      expect(found.dryingMethod, equals('Hanging'));

      // Act & Assert - Update 2: End drying, add dry weight
      current = found.copyWith(dryingEndDate: DateTime.now(), dryWeight: 100.0);
      await repository.updateHarvest(current);

      found = await repository.getHarvestById(id);
      expect(found!.dryingEndDate, isNotNull);
      expect(found.dryWeight, equals(100.0));

      // Act & Assert - Update 3: Start curing
      current = found.copyWith(
        curingStartDate: DateTime.now(),
        curingMethod: 'Glass Jars',
      );
      await repository.updateHarvest(current);

      found = await repository.getHarvestById(id);
      expect(found!.curingStartDate, isNotNull);
      expect(found.curingMethod, equals('Glass Jars'));
    });

    test('getHarvestsByGrowId() - should return harvests for a grow', () async {
      // Arrange - Create grow and plant
      final growId = await testDb.insert('grows', {
        'name': 'Test Grow',
        'start_date': DateTime.now()
            .subtract(const Duration(days: 100))
            .toIso8601String(),
      });

      final plantId = await testDb.insert('plants', {
        'name': 'Grow Plant',
        'seed_type': 'REGULAR',
        'medium': 'SOIL',
        'phase': 'HARVEST',
        'grow_id': growId,
      });

      await repository.createHarvest(
        Harvest(
          plantId: plantId,
          harvestDate: DateTime.now(),
          wetWeight: 500.0,
        ),
      );

      // Act
      final harvests = await repository.getHarvestsByGrowId(growId);

      // Assert
      expect(harvests, isNotEmpty);
    });

    test(
      'getHarvestsByGrowId() - should return empty for grow without harvests',
      () async {
        // Act
        final harvests = await repository.getHarvestsByGrowId(99999);

        // Assert
        expect(harvests, isEmpty);
      },
    );
  });
}
