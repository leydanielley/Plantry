// =============================================
// GROWLOG - PlantRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late PlantRepository repository;

  // Initialize sqflite_ffi once for all tests
  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  // Create fresh database before each test
  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();

    // Mock DatabaseHelper.instance.database to return our test database
    // This is a workaround since PlantRepository uses DatabaseHelper.instance
    DatabaseHelper.setTestDatabase(testDb);

    repository = PlantRepository();
  });

  // Close database after each test
  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('PlantRepository - save()', () {
    test(
      'Creating new plant - should insert and return plant with ID',
      () async {
        // Arrange
        final plant = Plant(
          name: 'Test Plant',
          strain: 'Test Strain',
          breeder: 'Test Breeder',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.seedling,
          seedDate: DateTime(2025, 1, 1),
          feminized: true,
        );

        // Act
        final savedPlant = await repository.save(plant);

        // Assert
        expect(
          savedPlant.id,
          isNotNull,
          reason: 'Saved plant should have an ID',
        );
        expect(savedPlant.id, greaterThan(0), reason: 'ID should be positive');
        expect(savedPlant.name, equals('Test Plant'));
        expect(savedPlant.strain, equals('Test Strain'));
        expect(savedPlant.seedType, equals(SeedType.photo));
        expect(savedPlant.medium, equals(Medium.erde));
      },
    );

    test(
      'Updating existing plant - should update and return modified plant',
      () async {
        // Arrange - Create initial plant
        final plant = Plant(
          name: 'Original Name',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.seedling,
          seedDate: DateTime(2025, 1, 1),
        );
        final savedPlant = await repository.save(plant);

        // Act - Update the plant
        final updatedPlant = savedPlant.copyWith(
          name: 'Updated Name',
          phase: PlantPhase.veg,
        );
        final result = await repository.save(updatedPlant);

        // Assert
        expect(
          result.id,
          equals(savedPlant.id),
          reason: 'ID should remain the same',
        );
        expect(result.name, equals('Updated Name'));
        expect(result.phase, equals(PlantPhase.veg));

        // Verify in database
        final retrieved = await repository.findById(savedPlant.id!);
        expect(retrieved!.name, equals('Updated Name'));
        expect(retrieved.phase, equals(PlantPhase.veg));
      },
    );

    test(
      'Updating plant seed date - should recalculate log day numbers',
      () async {
        // Arrange - Create plant with seed date and a log
        final plant = Plant(
          name: 'Plant With Logs',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.seedling,
          seedDate: DateTime(2025, 1, 1),
        );
        final savedPlant = await repository.save(plant);

        // Create a log for day 5
        final log = PlantLog(
          plantId: savedPlant.id!,
          dayNumber: 5,
          logDate: DateTime(2025, 1, 5),
          actionType: ActionType.water,
        );
        await testDb.insert('plant_logs', log.toMap());

        // Act - Change seed date to later date
        final updatedPlant = savedPlant.copyWith(
          seedDate: DateTime(2025, 1, 3), // 2 days later
        );
        await repository.save(updatedPlant);

        // Assert - Log day number should be recalculated
        final logs = await testDb.query(
          'plant_logs',
          where: 'plant_id = ?',
          whereArgs: [savedPlant.id],
        );
        expect(logs.length, equals(1));
        expect(
          logs.first['day_number'],
          equals(3),
          reason: 'Day number should be recalculated from new seed date',
        );
      },
    );

    test(
      'Updating plant seed date to after log date - should delete invalid logs',
      () async {
        // Arrange - Create plant with seed date and a log
        final plant = Plant(
          name: 'Plant With Logs',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.seedling,
          seedDate: DateTime(2025, 1, 1),
        );
        final savedPlant = await repository.save(plant);

        // Create a log before new seed date
        final log = PlantLog(
          plantId: savedPlant.id!,
          dayNumber: 2,
          logDate: DateTime(2025, 1, 2),
          actionType: ActionType.water,
        );
        await testDb.insert('plant_logs', log.toMap());

        // Act - Change seed date to after log date
        final updatedPlant = savedPlant.copyWith(
          seedDate: DateTime(2025, 1, 5), // After the log
        );
        await repository.save(updatedPlant);

        // Assert - Log should be deleted
        final logs = await testDb.query(
          'plant_logs',
          where: 'plant_id = ?',
          whereArgs: [savedPlant.id],
        );
        expect(
          logs.length,
          equals(0),
          reason: 'Logs before seed date should be deleted',
        );
      },
    );

    test(
      'Updating plant phase dates - should recalculate phase day numbers',
      () async {
        // Arrange - Create plant with phase dates and logs
        final plant = Plant(
          name: 'Plant With Phase',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.veg,
          seedDate: DateTime(2025, 1, 1),
          vegDate: DateTime(2025, 1, 10),
        );
        final savedPlant = await repository.save(plant);

        // Create a log in veg phase
        final log = PlantLog(
          plantId: savedPlant.id!,
          dayNumber: 15,
          logDate: DateTime(2025, 1, 15),
          actionType: ActionType.water,
          phase: PlantPhase.veg,
          phaseDayNumber: 6, // Wrong value
        );
        await testDb.insert('plant_logs', log.toMap());

        // Act - Update veg date
        final updatedPlant = savedPlant.copyWith(
          vegDate: DateTime(2025, 1, 12), // Later veg date
        );
        await repository.save(updatedPlant);

        // Assert - Phase day number should be recalculated
        final logs = await testDb.query(
          'plant_logs',
          where: 'plant_id = ?',
          whereArgs: [savedPlant.id],
        );
        expect(logs.length, equals(1));
        expect(
          logs.first['phase_day_number'],
          equals(4),
          reason: 'Phase day number should be recalculated',
        );
      },
    );
  });

  group('PlantRepository - findById()', () {
    test('Finding existing plant - should return plant', () async {
      // Arrange
      final plant = Plant(
        name: 'Findable Plant',
        seedType: SeedType.auto,
        medium: Medium.coco,
        phase: PlantPhase.bloom,
      );
      final savedPlant = await repository.save(plant);

      // Act
      final found = await repository.findById(savedPlant.id!);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(savedPlant.id));
      expect(found.name, equals('Findable Plant'));
      expect(found.seedType, equals(SeedType.auto));
      expect(found.medium, equals(Medium.coco));
      expect(found.phase, equals(PlantPhase.bloom));
    });

    test('Finding non-existent plant - should return null', () async {
      // Act
      final found = await repository.findById(99999);

      // Assert
      expect(found, isNull);
    });

    test('Finding archived plant - should return the plant', () async {
      // Arrange
      final plant = Plant(
        name: 'Archived Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.archived,
        archived: true,
      );
      final savedPlant = await repository.save(plant);

      // Act
      final found = await repository.findById(savedPlant.id!);

      // Assert
      expect(found, isNotNull);
      expect(found!.archived, isTrue);
    });
  });

  group('PlantRepository - findAll()', () {
    test(
      'Finding all plants - should return only non-archived plants',
      () async {
        // Arrange - Create multiple plants
        await repository.save(
          Plant(name: 'Plant 1', seedType: SeedType.photo, medium: Medium.erde),
        );
        await repository.save(
          Plant(name: 'Plant 2', seedType: SeedType.auto, medium: Medium.coco),
        );
        await repository.save(
          Plant(
            name: 'Archived Plant',
            seedType: SeedType.photo,
            medium: Medium.erde,
            archived: true,
          ),
        );

        // Act
        final plants = await repository.findAll();

        // Assert
        expect(
          plants.length,
          equals(2),
          reason: 'Should only return non-archived plants',
        );
        expect(plants.any((p) => p.name == 'Plant 1'), isTrue);
        expect(plants.any((p) => p.name == 'Plant 2'), isTrue);
        expect(plants.any((p) => p.name == 'Archived Plant'), isFalse);
      },
    );

    test(
      'Finding all plants with pagination - should respect limit and offset',
      () async {
        // Arrange - Create 5 plants
        for (int i = 1; i <= 5; i++) {
          await repository.save(
            Plant(
              name: 'Plant $i',
              seedType: SeedType.photo,
              medium: Medium.erde,
            ),
          );
        }

        // Act - Get page 2 with limit 2
        final plants = await repository.findAll(limit: 2, offset: 2);

        // Assert
        expect(plants.length, equals(2));
      },
    );

    test(
      'Finding all plants when database is empty - should return empty list',
      () async {
        // Act
        final plants = await repository.findAll();

        // Assert
        expect(plants, isEmpty);
      },
    );

    test('Finding all plants should order by ID DESC', () async {
      // Arrange - Create plants in sequence
      final plant1 = await repository.save(
        Plant(name: 'First', seedType: SeedType.photo, medium: Medium.erde),
      );
      final plant2 = await repository.save(
        Plant(name: 'Second', seedType: SeedType.photo, medium: Medium.erde),
      );
      final plant3 = await repository.save(
        Plant(name: 'Third', seedType: SeedType.photo, medium: Medium.erde),
      );

      // Act
      final plants = await repository.findAll();

      // Assert - Should be in reverse order (newest first)
      expect(plants.length, equals(3));
      expect(plants[0].id, equals(plant3.id));
      expect(plants[1].id, equals(plant2.id));
      expect(plants[2].id, equals(plant1.id));
    });
  });

  group('PlantRepository - findByRoom()', () {
    test(
      'Finding plants by room - should return only plants in that room',
      () async {
        // Arrange - Seed test data with room
        await TestDatabaseHelper.seedTestData(testDb);

        await repository.save(
          Plant(
            name: 'Plant in Room 1',
            seedType: SeedType.photo,
            medium: Medium.erde,
            roomId: 1,
          ),
        );
        await repository.save(
          Plant(
            name: 'Plant in Room 1 #2',
            seedType: SeedType.photo,
            medium: Medium.erde,
            roomId: 1,
          ),
        );
        await repository.save(
          Plant(
            name: 'Plant without room',
            seedType: SeedType.photo,
            medium: Medium.erde,
          ),
        );

        // Act
        final plants = await repository.findByRoom(1);

        // Assert
        expect(plants.length, equals(2));
        expect(plants.every((p) => p.roomId == 1), isTrue);
      },
    );

    test(
      'Finding plants by non-existent room - should return empty list',
      () async {
        // Act
        final plants = await repository.findByRoom(99999);

        // Assert
        expect(plants, isEmpty);
      },
    );

    test('Finding plants by room - should exclude archived plants', () async {
      // Arrange
      await TestDatabaseHelper.seedTestData(testDb);

      await repository.save(
        Plant(
          name: 'Active in Room',
          seedType: SeedType.photo,
          medium: Medium.erde,
          roomId: 1,
        ),
      );
      await repository.save(
        Plant(
          name: 'Archived in Room',
          seedType: SeedType.photo,
          medium: Medium.erde,
          roomId: 1,
          archived: true,
        ),
      );

      // Act
      final plants = await repository.findByRoom(1);

      // Assert
      expect(plants.length, equals(1));
      expect(plants.first.name, equals('Active in Room'));
    });
  });

  group('PlantRepository - findByRdwcSystem()', () {
    test(
      'Finding plants by RDWC system - should return plants ordered by bucket number',
      () async {
        // Arrange - Create RDWC system
        await testDb.insert('rdwc_systems', {
          'id': 1,
          'name': 'Test RDWC System',
          'total_volume': 100.0,
          'current_volume': 90.0,
        });

        await repository.save(
          Plant(
            name: 'Bucket 3',
            seedType: SeedType.photo,
            medium: Medium.rdwc,
            rdwcSystemId: 1,
            bucketNumber: 3,
          ),
        );
        await repository.save(
          Plant(
            name: 'Bucket 1',
            seedType: SeedType.photo,
            medium: Medium.rdwc,
            rdwcSystemId: 1,
            bucketNumber: 1,
          ),
        );
        await repository.save(
          Plant(
            name: 'Bucket 2',
            seedType: SeedType.photo,
            medium: Medium.rdwc,
            rdwcSystemId: 1,
            bucketNumber: 2,
          ),
        );

        // Act
        final plants = await repository.findByRdwcSystem(1);

        // Assert
        expect(plants.length, equals(3));
        expect(plants[0].bucketNumber, equals(1));
        expect(plants[1].bucketNumber, equals(2));
        expect(plants[2].bucketNumber, equals(3));
      },
    );

    test(
      'Finding plants by RDWC system - should exclude archived plants',
      () async {
        // Arrange
        await testDb.insert('rdwc_systems', {
          'id': 1,
          'name': 'Test RDWC System',
          'total_volume': 100.0,
          'current_volume': 90.0,
        });

        await repository.save(
          Plant(
            name: 'Active',
            seedType: SeedType.photo,
            medium: Medium.rdwc,
            rdwcSystemId: 1,
            bucketNumber: 1,
          ),
        );
        await repository.save(
          Plant(
            name: 'Archived',
            seedType: SeedType.photo,
            medium: Medium.rdwc,
            rdwcSystemId: 1,
            bucketNumber: 2,
            archived: true,
          ),
        );

        // Act
        final plants = await repository.findByRdwcSystem(1);

        // Assert
        expect(plants.length, equals(1));
        expect(plants.first.name, equals('Active'));
      },
    );
  });

  group('PlantRepository - delete()', () {
    test('Deleting existing plant - should remove from database', () async {
      // Arrange
      final plant = Plant(
        name: 'To Delete',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );
      final savedPlant = await repository.save(plant);

      // Act
      final result = await repository.delete(savedPlant.id!);

      // Assert
      expect(result, equals(1), reason: 'Should return number of rows deleted');

      final found = await repository.findById(savedPlant.id!);
      expect(found, isNull, reason: 'Plant should no longer exist');
    });

    test('Deleting plant with logs - should cascade delete logs', () async {
      // Arrange
      final plant = Plant(
        name: 'With Logs',
        seedType: SeedType.photo,
        medium: Medium.erde,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await repository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
      );
      await testDb.insert('plant_logs', log.toMap());

      // Act
      await repository.delete(savedPlant.id!);

      // Assert - Logs should be deleted due to CASCADE
      final logs = await testDb.query(
        'plant_logs',
        where: 'plant_id = ?',
        whereArgs: [savedPlant.id],
      );
      expect(logs, isEmpty, reason: 'Logs should be cascade deleted');
    });

    test('Deleting non-existent plant - should return 0', () async {
      // Act
      final result = await repository.delete(99999);

      // Assert
      expect(result, equals(0));
    });
  });

  group('PlantRepository - archive()', () {
    test('Archiving plant - should set archived flag to 1', () async {
      // Arrange
      final plant = Plant(
        name: 'To Archive',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );
      final savedPlant = await repository.save(plant);

      // Act
      final result = await repository.archive(savedPlant.id!);

      // Assert
      expect(result, equals(1));

      final archived = await testDb.query(
        'plants',
        where: 'id = ?',
        whereArgs: [savedPlant.id],
      );
      expect(archived.first['archived'], equals(1));
    });

    test('Archived plant - should not appear in findAll()', () async {
      // Arrange
      final plant = Plant(
        name: 'To Archive',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );
      final savedPlant = await repository.save(plant);

      // Act
      await repository.archive(savedPlant.id!);

      // Assert
      final plants = await repository.findAll();
      expect(plants.any((p) => p.id == savedPlant.id), isFalse);
    });
  });

  group('PlantRepository - count()', () {
    test(
      'Counting plants - should return correct count of non-archived plants',
      () async {
        // Arrange
        await repository.save(
          Plant(name: 'Plant 1', seedType: SeedType.photo, medium: Medium.erde),
        );
        await repository.save(
          Plant(name: 'Plant 2', seedType: SeedType.photo, medium: Medium.erde),
        );
        await repository.save(
          Plant(
            name: 'Archived',
            seedType: SeedType.photo,
            medium: Medium.erde,
            archived: true,
          ),
        );

        // Act
        final count = await repository.count();

        // Assert
        expect(
          count,
          equals(2),
          reason: 'Should only count non-archived plants',
        );
      },
    );

    test('Counting when database is empty - should return 0', () async {
      // Act
      final count = await repository.count();

      // Assert
      expect(count, equals(0));
    });
  });

  group('PlantRepository - getLogCount()', () {
    test(
      'Getting log count for plant with logs - should return correct count',
      () async {
        // Arrange
        final plant = Plant(
          name: 'Plant With Logs',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime(2025, 1, 1),
        );
        final savedPlant = await repository.save(plant);

        for (int i = 1; i <= 3; i++) {
          final log = PlantLog(
            plantId: savedPlant.id!,
            dayNumber: i,
            logDate: DateTime(2025, 1, i),
            actionType: ActionType.water,
          );
          await testDb.insert('plant_logs', log.toMap());
        }

        // Act
        final count = await repository.getLogCount(savedPlant.id!);

        // Assert
        expect(count, equals(3));
      },
    );

    test(
      'Getting log count for plant without logs - should return 0',
      () async {
        // Arrange
        final plant = Plant(
          name: 'Plant Without Logs',
          seedType: SeedType.photo,
          medium: Medium.erde,
        );
        final savedPlant = await repository.save(plant);

        // Act
        final count = await repository.getLogCount(savedPlant.id!);

        // Assert
        expect(count, equals(0));
      },
    );
  });

  group('PlantRepository - Error Handling', () {
    test(
      'Finding all plants with database error - should return empty list',
      () async {
        // Arrange - Close database to simulate error
        await testDb.close();

        // Act
        final plants = await repository.findAll();

        // Assert
        expect(plants, isEmpty, reason: 'Should return empty list on error');
      },
    );

    test('Finding by ID with database error - should return null', () async {
      // Arrange - Close database to simulate error
      await testDb.close();

      // Act
      final plant = await repository.findById(1);

      // Assert
      expect(plant, isNull, reason: 'Should return null on error');
    });
  });
}
