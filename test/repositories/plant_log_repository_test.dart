// =============================================
// GROWLOG - PlantLogRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/plant_log_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late PlantLogRepository repository;
  late int testPlantId;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    repository = PlantLogRepository();
    await TestDatabaseHelper.seedTestData(testDb);

    // Create test plant
    testPlantId = await testDb.insert('plants', {
      'name': 'Test Plant for Logs',
      'seed_type': 'REGULAR',
      'medium': 'SOIL',
      'phase': 'VEG',
    });
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('PlantLogRepository - CRUD Operations', () {
    test('save() - should create new log', () async {
      // Arrange
      final log = PlantLog(
        plantId: testPlantId,
        dayNumber: 10,
        logDate: DateTime.now(),
        actionType: ActionType.water,
        waterAmount: 2.5,
        phIn: 6.2,
        ecIn: 1.8,
      );

      // Act
      final saved = await repository.save(log);

      // Assert
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.plantId, equals(testPlantId));
      expect(found.waterAmount, equals(2.5));
      expect(found.phIn, equals(6.2));
    });

    test('save() - should update existing log', () async {
      // Arrange
      final log = PlantLog(
        plantId: testPlantId,
        dayNumber: 10,
        logDate: DateTime.now(),
        actionType: ActionType.water,
        waterAmount: 2.0,
      );
      final saved = await repository.save(log);

      // Act
      final updated = saved.copyWith(waterAmount: 3.0, note: 'Updated note');
      final result = await repository.save(updated);

      // Assert
      expect(result.id, equals(saved.id));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.waterAmount, equals(3.0));
      expect(found.note, equals('Updated note'));
    });

    test('findById() - should return log when exists', () async {
      // Arrange
      final log = PlantLog(
        plantId: testPlantId,
        dayNumber: 15,
        logDate: DateTime.now(),
        actionType: ActionType.feed,
      );
      final saved = await repository.save(log);

      // Act
      final found = await repository.findById(saved.id!);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(saved.id));
      expect(found.plantId, equals(testPlantId));
    });

    test('findById() - should return null when not exists', () async {
      // Act
      final found = await repository.findById(99999);

      // Assert
      expect(found, isNull);
    });

    test('delete() - should remove log', () async {
      // Arrange
      final log = PlantLog(
        plantId: testPlantId,
        dayNumber: 20,
        logDate: DateTime.now(),
        actionType: ActionType.note,
      );
      final saved = await repository.save(log);

      // Act
      final deleted = await repository.delete(saved.id!);

      // Assert
      expect(deleted, equals(1));

      final found = await repository.findById(saved.id!);
      expect(found, isNull);
    });

    test('delete() - should return 0 for non-existent log', () async {
      // Act
      final deleted = await repository.delete(99999);

      // Assert
      expect(deleted, equals(0));
    });
  });

  group('PlantLogRepository - Query Operations', () {
    test('findByPlant() - should return logs for a plant', () async {
      // Arrange - Create 3 logs
      for (int i = 1; i <= 3; i++) {
        final log = PlantLog(
          plantId: testPlantId,
          dayNumber: i * 5,
          logDate: DateTime.now().subtract(Duration(days: 3 - i)),
          actionType: ActionType.water,
        );
        await repository.save(log);
      }

      // Act
      final logs = await repository.findByPlant(testPlantId);

      // Assert
      expect(logs, isNotEmpty);
      expect(logs.length, greaterThanOrEqualTo(3));
      for (final log in logs) {
        expect(log.plantId, equals(testPlantId));
      }
    });

    test('findByPlant() - should order by day_number DESC', () async {
      // Arrange - Create logs with different day numbers
      await repository.save(
        PlantLog(
          plantId: testPlantId,
          dayNumber: 10,
          logDate: DateTime.now(),
          actionType: ActionType.water,
        ),
      );
      await repository.save(
        PlantLog(
          plantId: testPlantId,
          dayNumber: 20,
          logDate: DateTime.now(),
          actionType: ActionType.water,
        ),
      );
      await repository.save(
        PlantLog(
          plantId: testPlantId,
          dayNumber: 15,
          logDate: DateTime.now(),
          actionType: ActionType.water,
        ),
      );

      // Act
      final logs = await repository.findByPlant(testPlantId);

      // Assert
      expect(logs, isNotEmpty);
      expect(logs.length, greaterThanOrEqualTo(3));
      // Should be in descending order: 20, 15, 10
      expect(logs[0].dayNumber, greaterThanOrEqualTo(logs[1].dayNumber));
      expect(logs[1].dayNumber, greaterThanOrEqualTo(logs[2].dayNumber));
    });

    test('findByPlant(limit) - should respect limit', () async {
      // Arrange - Create 5 logs
      for (int i = 1; i <= 5; i++) {
        await repository.save(
          PlantLog(
            plantId: testPlantId,
            dayNumber: i,
            logDate: DateTime.now(),
            actionType: ActionType.water,
          ),
        );
      }

      // Act
      final logs = await repository.findByPlant(testPlantId, limit: 3);

      // Assert
      expect(logs.length, equals(3));
    });

    test('findByPlant(limit + offset) - should respect both', () async {
      // Arrange - Create 5 logs
      for (int i = 1; i <= 5; i++) {
        await repository.save(
          PlantLog(
            plantId: testPlantId,
            dayNumber: i,
            logDate: DateTime.now(),
            actionType: ActionType.water,
          ),
        );
      }

      // Act - Skip first 2, return next 2
      final logs = await repository.findByPlant(
        testPlantId,
        limit: 2,
        offset: 2,
      );

      // Assert
      expect(logs.length, equals(2));
    });

    test(
      'findByPlant() - should return empty list for plant without logs',
      () async {
        // Arrange - Create another plant without logs
        final emptyPlantId = await testDb.insert('plants', {
          'name': 'Empty Plant',
          'seed_type': 'REGULAR',
          'medium': 'SOIL',
          'phase': 'SEEDLING',
        });

        // Act
        final logs = await repository.findByPlant(emptyPlantId);

        // Assert
        expect(logs, isEmpty);
      },
    );
  });

  group('PlantLogRepository - Batch Operations', () {
    test('findByIds() - should return multiple logs', () async {
      // Arrange - Create 3 logs
      final log1 = await repository.save(
        PlantLog(
          plantId: testPlantId,
          dayNumber: 5,
          logDate: DateTime.now(),
          actionType: ActionType.water,
        ),
      );
      final log2 = await repository.save(
        PlantLog(
          plantId: testPlantId,
          dayNumber: 10,
          logDate: DateTime.now(),
          actionType: ActionType.feed,
        ),
      );
      final log3 = await repository.save(
        PlantLog(
          plantId: testPlantId,
          dayNumber: 15,
          logDate: DateTime.now(),
          actionType: ActionType.note,
        ),
      );

      // Act
      final logs = await repository.findByIds([log1.id!, log2.id!, log3.id!]);

      // Assert
      expect(logs, isNotEmpty);
      expect(logs.length, equals(3));
      final ids = logs.map((l) => l.id).toList();
      expect(ids, contains(log1.id));
      expect(ids, contains(log2.id));
      expect(ids, contains(log3.id));
    });

    test('findByIds() - should return empty list for empty input', () async {
      // Act
      final logs = await repository.findByIds([]);

      // Assert
      expect(logs, isEmpty);
    });

    test('findByIds() - should handle non-existent IDs gracefully', () async {
      // Arrange - Create 1 log
      final log = await repository.save(
        PlantLog(
          plantId: testPlantId,
          dayNumber: 5,
          logDate: DateTime.now(),
          actionType: ActionType.water,
        ),
      );

      // Act - Mix existing and non-existing IDs
      final logs = await repository.findByIds([log.id!, 99998, 99999]);

      // Assert - Should only return the existing one
      expect(logs, isNotEmpty);
      expect(logs.length, equals(1));
      expect(logs.first.id, equals(log.id));
    });
  });

  group('PlantLogRepository - Edge Cases', () {
    test('save() - should handle all action types', () async {
      final actionTypes = [
        ActionType.water,
        ActionType.feed,
        ActionType.note,
        ActionType.phaseChange,
        ActionType.transplant,
        ActionType.trim,
        ActionType.training,
      ];

      for (final actionType in actionTypes) {
        // Arrange
        final log = PlantLog(
          plantId: testPlantId,
          dayNumber: 10,
          logDate: DateTime.now(),
          actionType: actionType,
        );

        // Act
        final saved = await repository.save(log);

        // Assert
        final found = await repository.findById(saved.id!);
        expect(found, isNotNull);
        expect(found!.actionType, equals(actionType));
      }
    });

    test('save() - should handle full log with all fields', () async {
      // Arrange
      final log = PlantLog(
        plantId: testPlantId,
        dayNumber: 25,
        logDate: DateTime.now(),
        loggedBy: 'Test User',
        actionType: ActionType.water,
        phase: PlantPhase.veg,
        phaseDayNumber: 5,
        waterAmount: 3.5,
        phIn: 6.5,
        phOut: 6.2,
        ecIn: 1.8,
        ecOut: 1.5,
        temperature: 24.5,
        humidity: 60.0,
        runoff: true,
        cleanse: false,
        containerSize: 10.0,
        containerMediumAmount: 8.5,
        containerDrainage: true,
        containerDrainageMaterial: 'Perlite',
        systemReservoirSize: 50.0,
        systemBucketCount: 4,
        systemBucketSize: 10.0,
        note: 'Full test log',
      );

      // Act
      final saved = await repository.save(log);

      // Assert
      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.waterAmount, equals(3.5));
      expect(found.phIn, equals(6.5));
      expect(found.temperature, equals(24.5));
      expect(found.runoff, isTrue);
      expect(found.containerSize, equals(10.0));
      expect(found.note, equals('Full test log'));
    });

    test('save() - should handle minimal log', () async {
      // Arrange - Only required fields
      final log = PlantLog(
        plantId: testPlantId,
        dayNumber: 1,
        logDate: DateTime.now(),
        actionType: ActionType.note,
      );

      // Act
      final saved = await repository.save(log);

      // Assert
      expect(saved.id, isNotNull);

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.plantId, equals(testPlantId));
      expect(found.dayNumber, equals(1));
    });

    test(
      'findByPlant() - should handle multiple plants independently',
      () async {
        // Arrange - Create 2 plants with logs
        final plant1Id = testPlantId;
        final plant2Id = await testDb.insert('plants', {
          'name': 'Plant 2',
          'seed_type': 'REGULAR',
          'medium': 'SOIL',
          'phase': 'VEG',
        });

        await repository.save(
          PlantLog(
            plantId: plant1Id,
            dayNumber: 5,
            logDate: DateTime.now(),
            actionType: ActionType.water,
          ),
        );
        await repository.save(
          PlantLog(
            plantId: plant1Id,
            dayNumber: 10,
            logDate: DateTime.now(),
            actionType: ActionType.water,
          ),
        );
        await repository.save(
          PlantLog(
            plantId: plant2Id,
            dayNumber: 5,
            logDate: DateTime.now(),
            actionType: ActionType.water,
          ),
        );

        // Act
        final logs1 = await repository.findByPlant(plant1Id);
        final logs2 = await repository.findByPlant(plant2Id);

        // Assert
        expect(logs1.length, greaterThanOrEqualTo(2));
        expect(logs2.length, greaterThanOrEqualTo(1));
        for (final log in logs1) {
          expect(log.plantId, equals(plant1Id));
        }
        for (final log in logs2) {
          expect(log.plantId, equals(plant2Id));
        }
      },
    );
  });
}
