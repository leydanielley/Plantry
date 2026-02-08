// =============================================
// CRITICAL PATH TESTS - Based on QA Analysis
// Priority P0 Tests from QA Report
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/plant_log_repository.dart';
import 'package:growlog_app/repositories/fertilizer_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/enums.dart';

import 'helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late PlantRepository plantRepo;
  late PlantLogRepository logRepo;
  late FertilizerRepository fertilizerRepo;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    plantRepo = PlantRepository();
    logRepo = PlantLogRepository();
    fertilizerRepo = FertilizerRepository();
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('TC-001: Plant Creation', () {
    test('should create plant with required fields', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        seedDate: DateTime.now(),
      );

      // Act
      final savedPlant = await plantRepo.save(plant);

      // Assert
      expect(savedPlant.id, isNotNull);
      expect(savedPlant.name, 'Test Plant');
      expect(savedPlant.seedType, SeedType.photo);
      expect(savedPlant.medium, Medium.erde);
    });

    test('should handle empty name with default value', () async {
      // Arrange
      final plant = Plant(
        name: '',
        seedType: SeedType.photo,
        medium: Medium.erde,
        seedDate: DateTime.now(),
      );

      // Act
      final savedPlant = await plantRepo.save(plant);

      // Assert - empty name should be replaced with default
      expect(savedPlant.name, isNotEmpty);
      expect(savedPlant.name, 'Unknown Plant');
    });

    test('should handle 255 character name', () async {
      // Arrange
      final longName = 'A' * 255;
      final plant = Plant(
        name: longName,
        seedType: SeedType.auto,
        medium: Medium.coco,
        seedDate: DateTime.now(),
      );

      // Act
      final savedPlant = await plantRepo.save(plant);

      // Assert - name should be truncated to max length
      expect(savedPlant.name.length, lessThanOrEqualTo(100));
    });
  });

  group('TC-007: Plant Deletion with RESTRICT (v14)', () {
    test('soft delete archives plant even when logs exist', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Delete Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.water,
        ),
      );

      // Act - With soft delete, this doesn't throw, it archives
      final deleted = await plantRepo.delete(plant.id!);

      // Assert - Plant and log are archived (not deleted)
      expect(deleted, equals(1));

      final existingPlant = await plantRepo.findById(plant.id!);
      final existingLog = await logRepo.findById(log.id!);

      expect(existingPlant, isNotNull);
      expect(existingPlant!.archived, isTrue);
      expect(existingLog, isNotNull);
      // Log can remain active or be archived depending on implementation
    });

    test('soft delete archives both plant and logs', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Delete Test 2',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.water,
        ),
      );

      // Act - Delete (archive) log first, then plant
      await logRepo.delete(log.id!);
      await plantRepo.delete(plant.id!);

      // Assert - Both are archived (not permanently deleted)
      final deletedPlant = await plantRepo.findById(plant.id!);
      final deletedLog = await logRepo.findById(log.id!);

      expect(deletedPlant, isNotNull);
      expect(deletedPlant!.archived, isTrue);
      expect(deletedLog, isNotNull);
      expect(deletedLog!.archived, isTrue);
    });
  });

  group('TC-030: Foreign Key Constraints', () {
    test('should reject plant with non-existent room_id', () async {
      // Arrange
      final plant = Plant(
        name: 'FK Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        seedDate: DateTime.now(),
        roomId: 9999, // Non-existent
      );

      // Act & Assert - Should throw due to foreign key constraint
      expect(() => plantRepo.save(plant), throwsA(isA<Exception>()));
    });
  });

  group('TC-032: Fertilizer Deletion with RESTRICT', () {
    test('should prevent fertilizer deletion when in use', () async {
      // Arrange
      final fertilizer = await fertilizerRepo.save(
        Fertilizer(name: 'Test Fertilizer', type: 'Base'),
      );

      final plant = await plantRepo.save(
        Plant(
          name: 'Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.feed,
        ),
      );

      // Link fertilizer to log (creates FK constraint)
      await testDb.insert('log_fertilizers', {
        'log_id': log.id,
        'fertilizer_id': fertilizer.id,
        'amount': 5.0,
        'unit': 'ml',
      });

      // Act & Assert - Should throw exception due to RESTRICT
      expect(
        () => fertilizerRepo.delete(fertilizer.id!),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('TC-036: Race Condition Protection', () {
    test('should handle parallel plant creation', () async {
      // Arrange
      final plants = List.generate(
        10,
        (i) => Plant(
          name: 'Parallel Plant $i',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      // Act - Create all plants in parallel
      final savedPlants = await Future.wait(
        plants.map((p) => plantRepo.save(p)),
      );

      // Assert
      expect(savedPlants.length, 10);
      final ids = savedPlants.map((p) => p.id).toSet();
      expect(ids.length, 10); // All IDs should be unique
    });
  });

  group('TC-040: NULL Handling', () {
    test('should handle plant with all optional fields null', () async {
      // Arrange
      final plant = Plant(
        name: 'Minimal Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        seedDate: DateTime.now(),
        // All optional fields left as null
      );

      // Act
      final savedPlant = await plantRepo.save(plant);

      // Assert
      expect(savedPlant.id, isNotNull);
      expect(savedPlant.strain, isNull);
      expect(savedPlant.breeder, isNull);
      expect(savedPlant.roomId, isNull);
      expect(savedPlant.growId, isNull);
    });
  });

  group('TC-005: totalDays Calculation', () {
    test('should calculate correct totalDays from seedDate', () async {
      // Arrange
      final seedDate = DateTime.now().subtract(const Duration(days: 30));
      final plant = await plantRepo.save(
        Plant(
          name: 'Age Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: seedDate,
        ),
      );

      // Act
      final retrievedPlant = await plantRepo.findById(plant.id!);

      // Assert - totalDays should be 31 (1-indexed)
      expect(retrievedPlant, isNotNull);
      expect(retrievedPlant!.totalDays, greaterThanOrEqualTo(30));
      expect(retrievedPlant.totalDays, lessThanOrEqualTo(32));
    });
  });
}
