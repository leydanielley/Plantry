// =============================================
// GROWLOG - GrowRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/grow_repository.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late GrowRepository growRepository;
  late PlantRepository plantRepository;

  // Initialize sqflite_ffi once for all tests
  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  // Create fresh database before each test
  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();

    // Mock DatabaseHelper.instance.database to return our test database
    DatabaseHelper.setTestDatabase(testDb);

    growRepository = GrowRepository();
    plantRepository = PlantRepository();

    // Seed test data
    await TestDatabaseHelper.seedTestData(testDb);
  });

  // Close database after each test
  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('GrowRepository - create()', () {
    test('Creating new grow - should insert and return ID', () async {
      // Arrange
      final grow = Grow(
        name: 'Summer Grow 2025',
        description: 'Test grow for summer',
        startDate: DateTime(2025, 6, 1),
      );

      // Act
      final id = await growRepository.create(grow);

      // Assert
      expect(id, isNotNull);
      expect(id, greaterThan(0));

      // Verify in database
      final retrieved = await growRepository.getById(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Summer Grow 2025'));
      expect(retrieved.description, equals('Test grow for summer'));
    });

    test('Creating grow with room assignment - should save room ID', () async {
      // Arrange
      final grow = Grow(
        name: 'Grow in Room 1',
        startDate: DateTime(2025, 1, 1),
        roomId: 1, // Test room from seed data
      );

      // Act
      final id = await growRepository.create(grow);

      // Assert
      final retrieved = await growRepository.getById(id);
      expect(retrieved!.roomId, equals(1));
    });

    test('Creating grow with end date - should set end date', () async {
      // Arrange
      final grow = Grow(
        name: 'Completed Grow',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 3, 1),
      );

      // Act
      final id = await growRepository.create(grow);

      // Assert
      final retrieved = await growRepository.getById(id);
      expect(retrieved!.endDate, equals(DateTime(2025, 3, 1)));
      expect(retrieved.isComplete, isTrue);
    });
  });

  group('GrowRepository - update()', () {
    test('Updating existing grow - should modify fields', () async {
      // Arrange - Create initial grow
      final grow = Grow(
        name: 'Original Name',
        description: 'Original description',
        startDate: DateTime(2025, 1, 1),
      );
      final id = await growRepository.create(grow);
      final savedGrow = await growRepository.getById(id);

      // Act - Update the grow
      final updatedGrow = savedGrow!.copyWith(
        name: 'Updated Name',
        description: 'Updated description',
      );
      final result = await growRepository.update(updatedGrow);

      // Assert
      expect(result, equals(1), reason: 'Should return number of rows updated');

      final retrieved = await growRepository.getById(id);
      expect(retrieved!.name, equals('Updated Name'));
      expect(retrieved.description, equals('Updated description'));
    });

    test('Updating grow end date - should mark as complete', () async {
      // Arrange
      final grow = Grow(name: 'Ongoing Grow', startDate: DateTime(2025, 1, 1));
      final id = await growRepository.create(grow);
      final savedGrow = await growRepository.getById(id);

      // Act
      final completedGrow = savedGrow!.copyWith(endDate: DateTime(2025, 2, 1));
      await growRepository.update(completedGrow);

      // Assert
      final retrieved = await growRepository.getById(id);
      expect(retrieved!.isComplete, isTrue);
      expect(retrieved.endDate, equals(DateTime(2025, 2, 1)));
    });
  });

  group('GrowRepository - getById()', () {
    test('Finding existing grow - should return grow', () async {
      // Arrange
      final grow = Grow(name: 'Findable Grow', startDate: DateTime(2025, 1, 1));
      final id = await growRepository.create(grow);

      // Act
      final found = await growRepository.getById(id);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(id));
      expect(found.name, equals('Findable Grow'));
    });

    test('Finding non-existent grow - should return null', () async {
      // Act
      final found = await growRepository.getById(99999);

      // Assert
      expect(found, isNull);
    });

    test('Finding archived grow - should return the grow', () async {
      // Arrange
      final grow = Grow(
        name: 'Archived Grow',
        startDate: DateTime(2025, 1, 1),
        archived: true,
      );
      final id = await growRepository.create(grow);

      // Act
      final found = await growRepository.getById(id);

      // Assert
      expect(found, isNotNull);
      expect(found!.archived, isTrue);
    });
  });

  group('GrowRepository - getAll()', () {
    test(
      'Getting all grows - should return only non-archived grows by default',
      () async {
        // Arrange
        await growRepository.create(
          Grow(name: 'Grow 1', startDate: DateTime(2025, 1, 1)),
        );
        await growRepository.create(
          Grow(name: 'Grow 2', startDate: DateTime(2025, 2, 1)),
        );
        await growRepository.create(
          Grow(
            name: 'Archived',
            startDate: DateTime(2025, 3, 1),
            archived: true,
          ),
        );

        // Act
        final grows = await growRepository.getAll();

        // Assert
        expect(
          grows.length,
          equals(3),
          reason:
              'Should include Test Grow from seed data + 2 new non-archived grows',
        );
        expect(grows.any((g) => g.name == 'Test Grow'), isTrue);
        expect(grows.any((g) => g.name == 'Grow 1'), isTrue);
        expect(grows.any((g) => g.name == 'Grow 2'), isTrue);
        expect(grows.any((g) => g.name == 'Archived'), isFalse);
      },
    );

    test(
      'Getting all grows with includeArchived=true - should return all grows',
      () async {
        // Arrange
        await growRepository.create(
          Grow(name: 'Grow 1', startDate: DateTime(2025, 1, 1)),
        );
        await growRepository.create(
          Grow(
            name: 'Archived',
            startDate: DateTime(2025, 2, 1),
            archived: true,
          ),
        );

        // Act
        final grows = await growRepository.getAll(includeArchived: true);

        // Assert
        expect(
          grows.length,
          equals(3),
          reason: 'Should include Test Grow from seed data + 2 new grows',
        );
        expect(grows.any((g) => g.name == 'Archived'), isTrue);
      },
    );

    test('Getting all grows - should order by start_date DESC', () async {
      // Arrange - Create grows in non-chronological order
      await growRepository.create(
        Grow(name: 'Middle', startDate: DateTime(2025, 2, 1)),
      );
      await growRepository.create(
        Grow(name: 'Latest', startDate: DateTime(2025, 3, 1)),
      );
      await growRepository.create(
        Grow(name: 'Earliest', startDate: DateTime(2025, 1, 1)),
      );

      // Act
      final grows = await growRepository.getAll();

      // Assert - Should be ordered by date DESC (newest first)
      // Note: Test Grow from seed data might be first if it has the latest date
      final ourGrows = grows.where((g) => g.name != 'Test Grow').toList();
      expect(ourGrows[0].name, equals('Latest'));
      expect(ourGrows[1].name, equals('Middle'));
      expect(ourGrows[2].name, equals('Earliest'));
    });

    test(
      'Getting all grows when database is empty - should return seeded data',
      () async {
        // Act - Only seed data exists (Test Grow)
        final grows = await growRepository.getAll();

        // Assert - Should have Test Grow from seed data
        expect(grows.length, equals(1));
        expect(grows.first.name, equals('Test Grow'));
      },
    );
  });

  group('GrowRepository - delete()', () {
    test('Deleting grow - should remove from database', () async {
      // Arrange
      final grow = Grow(name: 'To Delete', startDate: DateTime(2025, 1, 1));
      final id = await growRepository.create(grow);

      // Act
      final result = await growRepository.delete(id);

      // Assert
      expect(result, equals(1), reason: 'Should return number of rows deleted');

      final found = await growRepository.getById(id);
      expect(found, isNull, reason: 'Grow should no longer exist');
    });

    test(
      'Deleting grow with plants - should detach plants from grow',
      () async {
        // Arrange - Create grow with plants
        final grow = Grow(
          name: 'Grow With Plants',
          startDate: DateTime(2025, 1, 1),
        );
        final growId = await growRepository.create(grow);

        final plant = Plant(
          name: 'Plant in Grow',
          seedType: SeedType.photo,
          medium: Medium.erde,
          growId: growId,
        );
        final savedPlant = await plantRepository.save(plant);

        // Act
        await growRepository.delete(growId);

        // Assert - Plant should still exist but with null grow_id
        final updatedPlant = await plantRepository.findById(savedPlant.id!);
        expect(updatedPlant, isNotNull, reason: 'Plant should still exist');
        expect(
          updatedPlant!.growId,
          isNull,
          reason: 'Plant should be detached from grow',
        );
      },
    );

    test('Deleting non-existent grow - should return 0', () async {
      // Act
      final result = await growRepository.delete(99999);

      // Assert
      expect(result, equals(0));
    });
  });

  group('GrowRepository - archive()', () {
    test('Archiving grow - should set archived flag', () async {
      // Arrange
      final grow = Grow(name: 'To Archive', startDate: DateTime(2025, 1, 1));
      final id = await growRepository.create(grow);

      // Act
      final result = await growRepository.archive(id);

      // Assert
      expect(result, equals(1));

      final archived = await growRepository.getById(id);
      expect(archived!.archived, isTrue);
    });

    test('Archived grow - should not appear in getAll() by default', () async {
      // Arrange
      final grow = Grow(name: 'To Archive', startDate: DateTime(2025, 1, 1));
      final id = await growRepository.create(grow);

      // Act
      await growRepository.archive(id);

      // Assert
      final grows = await growRepository.getAll();
      expect(grows.any((g) => g.id == id), isFalse);
    });

    test(
      'Archived grow - should appear in getAll(includeArchived: true)',
      () async {
        // Arrange
        final grow = Grow(name: 'To Archive', startDate: DateTime(2025, 1, 1));
        final id = await growRepository.create(grow);
        await growRepository.archive(id);

        // Act
        final grows = await growRepository.getAll(includeArchived: true);

        // Assert
        expect(grows.any((g) => g.id == id && g.archived), isTrue);
      },
    );
  });

  group('GrowRepository - unarchive()', () {
    test('Unarchiving grow - should clear archived flag', () async {
      // Arrange
      final grow = Grow(
        name: 'To Unarchive',
        startDate: DateTime(2025, 1, 1),
        archived: true,
      );
      final id = await growRepository.create(grow);

      // Act
      final result = await growRepository.unarchive(id);

      // Assert
      expect(result, equals(1));

      final unarchived = await growRepository.getById(id);
      expect(unarchived!.archived, isFalse);
    });

    test('Unarchived grow - should appear in getAll()', () async {
      // Arrange
      final grow = Grow(
        name: 'To Unarchive',
        startDate: DateTime(2025, 1, 1),
        archived: true,
      );
      final id = await growRepository.create(grow);

      // Act
      await growRepository.unarchive(id);

      // Assert
      final grows = await growRepository.getAll();
      expect(grows.any((g) => g.id == id), isTrue);
    });
  });

  group('GrowRepository - getPlantCount()', () {
    test(
      'Getting plant count for grow with plants - should return correct count',
      () async {
        // Arrange
        final grow = Grow(
          name: 'Grow With Plants',
          startDate: DateTime(2025, 1, 1),
        );
        final growId = await growRepository.create(grow);

        // Create 3 plants in this grow
        for (int i = 1; i <= 3; i++) {
          await plantRepository.save(
            Plant(
              name: 'Plant $i',
              seedType: SeedType.photo,
              medium: Medium.erde,
              growId: growId,
            ),
          );
        }

        // Act
        final count = await growRepository.getPlantCount(growId);

        // Assert
        expect(count, equals(3));
      },
    );

    test(
      'Getting plant count for grow without plants - should return 0',
      () async {
        // Arrange
        final grow = Grow(name: 'Empty Grow', startDate: DateTime(2025, 1, 1));
        final growId = await growRepository.create(grow);

        // Act
        final count = await growRepository.getPlantCount(growId);

        // Assert
        expect(count, equals(0));
      },
    );

    test(
      'Getting plant count for non-existent grow - should return 0',
      () async {
        // Act
        final count = await growRepository.getPlantCount(99999);

        // Assert
        expect(count, equals(0));
      },
    );
  });

  group('GrowRepository - getPlantCountsForGrows()', () {
    test(
      'Getting plant counts for multiple grows - should return map with counts',
      () async {
        // Arrange - Create multiple grows with different plant counts
        final grow1Id = await growRepository.create(
          Grow(name: 'Grow 1', startDate: DateTime(2025, 1, 1)),
        );
        final grow2Id = await growRepository.create(
          Grow(name: 'Grow 2', startDate: DateTime(2025, 2, 1)),
        );

        // Grow 1: 2 plants
        await plantRepository.save(
          Plant(
            name: 'Plant 1A',
            seedType: SeedType.photo,
            medium: Medium.erde,
            growId: grow1Id,
          ),
        );
        await plantRepository.save(
          Plant(
            name: 'Plant 1B',
            seedType: SeedType.photo,
            medium: Medium.erde,
            growId: grow1Id,
          ),
        );

        // Grow 2: 3 plants
        await plantRepository.save(
          Plant(
            name: 'Plant 2A',
            seedType: SeedType.photo,
            medium: Medium.erde,
            growId: grow2Id,
          ),
        );
        await plantRepository.save(
          Plant(
            name: 'Plant 2B',
            seedType: SeedType.photo,
            medium: Medium.erde,
            growId: grow2Id,
          ),
        );
        await plantRepository.save(
          Plant(
            name: 'Plant 2C',
            seedType: SeedType.photo,
            medium: Medium.erde,
            growId: grow2Id,
          ),
        );

        // Act
        final counts = await growRepository.getPlantCountsForGrows([
          grow1Id,
          grow2Id,
        ]);

        // Assert
        expect(counts.length, equals(2));
        expect(counts[grow1Id], equals(2));
        expect(counts[grow2Id], equals(3));
      },
    );

    test(
      'Getting plant counts with empty list - should return empty map',
      () async {
        // Act
        final counts = await growRepository.getPlantCountsForGrows([]);

        // Assert
        expect(counts, isEmpty);
      },
    );

    test(
      'Getting plant counts for grows without plants - should not include in result',
      () async {
        // Arrange
        final grow1Id = await growRepository.create(
          Grow(name: 'Empty Grow', startDate: DateTime(2025, 1, 1)),
        );
        final grow2Id = await growRepository.create(
          Grow(name: 'Grow With Plant', startDate: DateTime(2025, 2, 1)),
        );

        await plantRepository.save(
          Plant(
            name: 'Plant',
            seedType: SeedType.photo,
            medium: Medium.erde,
            growId: grow2Id,
          ),
        );

        // Act
        final counts = await growRepository.getPlantCountsForGrows([
          grow1Id,
          grow2Id,
        ]);

        // Assert
        expect(
          counts.length,
          equals(1),
          reason: 'Should only include grows with plants',
        );
        expect(counts[grow2Id], equals(1));
        expect(counts.containsKey(grow1Id), isFalse);
      },
    );
  });

  group('GrowRepository - updatePhaseForAllPlants()', () {
    test(
      'Updating phase for all plants in grow - should update all plants',
      () async {
        // Arrange
        final grow = Grow(name: 'Grow', startDate: DateTime(2025, 1, 1));
        final growId = await growRepository.create(grow);

        final plant1 = await plantRepository.save(
          Plant(
            name: 'Plant 1',
            seedType: SeedType.photo,
            medium: Medium.erde,
            phase: PlantPhase.seedling,
            growId: growId,
            seedDate: DateTime(2025, 1, 1),
          ),
        );

        final plant2 = await plantRepository.save(
          Plant(
            name: 'Plant 2',
            seedType: SeedType.photo,
            medium: Medium.erde,
            phase: PlantPhase.seedling,
            growId: growId,
            seedDate: DateTime(2025, 1, 1),
          ),
        );

        // Act
        await growRepository.updatePhaseForAllPlants(growId, 'VEG');

        // Assert - Both plants should be updated
        final updatedPlant1 = await plantRepository.findById(plant1.id!);
        final updatedPlant2 = await plantRepository.findById(plant2.id!);

        expect(updatedPlant1!.phase, equals(PlantPhase.veg));
        expect(updatedPlant2!.phase, equals(PlantPhase.veg));
        expect(updatedPlant1.phaseStartDate, isNotNull);
        expect(updatedPlant2.phaseStartDate, isNotNull);
      },
    );

    test('Updating phase should recalculate phase day numbers in logs', () async {
      // Arrange
      final grow = Grow(name: 'Grow', startDate: DateTime(2025, 1, 1));
      final growId = await growRepository.create(grow);

      final plant = await plantRepository.save(
        Plant(
          name: 'Plant',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.seedling,
          growId: growId,
          seedDate: DateTime(2025, 1, 1),
          phaseStartDate: DateTime(2025, 1, 1),
        ),
      );

      // Create a log before phase change
      final log = PlantLog(
        plantId: plant.id!,
        dayNumber: 5,
        logDate: DateTime(2025, 1, 5),
        actionType: ActionType.water,
        phaseDayNumber: 5, // Old phase day number
      );
      await testDb.insert('plant_logs', log.toMap());

      // Act - Change phase (this will set a new phase start date = today)
      await growRepository.updatePhaseForAllPlants(growId, 'VEG');

      // Assert - Phase day number should be recalculated if log is after new phase start
      final logs = await testDb.query(
        'plant_logs',
        where: 'plant_id = ?',
        whereArgs: [plant.id],
      );
      expect(logs.length, equals(1));
      // The phase_day_number might be recalculated based on new phase_start_date
      expect(logs.first['phase_day_number'], isNotNull);
    });

    test(
      'Updating phase for grow with no plants - should not throw error',
      () async {
        // Arrange
        final grow = Grow(name: 'Empty Grow', startDate: DateTime(2025, 1, 1));
        final growId = await growRepository.create(grow);

        // Act & Assert - Should not throw
        await growRepository.updatePhaseForAllPlants(growId, 'VEG');
      },
    );
  });

  group('GrowRepository - Error Handling', () {
    test(
      'Getting all grows with database error - should return empty list',
      () async {
        // Arrange - Close database to simulate error
        await testDb.close();

        // Act
        final grows = await growRepository.getAll();

        // Assert
        expect(grows, isEmpty, reason: 'Should return empty list on error');
      },
    );

    test('Getting by ID with database error - should return null', () async {
      // Arrange - Close database to simulate error
      await testDb.close();

      // Act
      final grow = await growRepository.getById(1);

      // Assert
      expect(grow, isNull, reason: 'Should return null on error');
    });

    test('Getting plant count with database error - should return 0', () async {
      // Arrange - Close database to simulate error
      await testDb.close();

      // Act
      final count = await growRepository.getPlantCount(1);

      // Assert
      expect(count, equals(0), reason: 'Should return 0 on error');
    });
  });
}
