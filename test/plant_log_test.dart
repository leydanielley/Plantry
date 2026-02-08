// =============================================
// PLANT LOG TESTS - Based on QA Analysis
// TC-017 to TC-024: Plant Log functionality
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

  group('TC-017: Water Log', () {
    test('should create water log with correct day_number', () async {
      // Arrange
      final seedDate = DateTime.now().subtract(const Duration(days: 10));
      final plant = await plantRepo.save(
        Plant(
          name: 'Water Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: seedDate,
        ),
      );

      // Act
      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 11, // 10 days + 1 (1-indexed)
          actionType: ActionType.water,
          waterAmount: 2.0,
        ),
      );

      // Assert
      expect(log.id, isNotNull);
      expect(log.actionType, ActionType.water);
      expect(log.waterAmount, 2.0);
      expect(log.dayNumber, 11);
    });

    test('should handle zero water_amount', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      // Act
      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.water,
          waterAmount: 0.0,
        ),
      );

      // Assert
      expect(log.waterAmount, 0.0);
    });

    test('should clamp negative water_amount', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      // Act
      final log = PlantLog(
        plantId: plant.id!,
        logDate: DateTime.now(),
        dayNumber: 1,
        actionType: ActionType.water,
        waterAmount: -5.0, // Invalid
      );

      // Assert - waterAmount should be clamped to 0
      expect(log.waterAmount, greaterThanOrEqualTo(0));
    });
  });

  group('TC-018: Feed Log with Fertilizers', () {
    test('should create feed log and link fertilizers', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Feed Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      final fertilizer1 = await fertilizerRepo.save(
        Fertilizer(name: 'Fertilizer A', type: 'Base'),
      );

      final fertilizer2 = await fertilizerRepo.save(
        Fertilizer(name: 'Fertilizer B', type: 'Boost'),
      );

      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.feed,
        ),
      );

      // Act - Link fertilizers to log
      await testDb.insert('log_fertilizers', {
        'log_id': log.id,
        'fertilizer_id': fertilizer1.id,
        'amount': 5.0,
        'unit': 'ml',
      });

      await testDb.insert('log_fertilizers', {
        'log_id': log.id,
        'fertilizer_id': fertilizer2.id,
        'amount': 10.0,
        'unit': 'ml',
      });

      // Assert
      final results = await testDb.query(
        'log_fertilizers',
        where: 'log_id = ?',
        whereArgs: [log.id],
      );

      expect(results.length, 2);
      expect(results[0]['amount'], 5.0);
      expect(results[1]['amount'], 10.0);
    });
  });

  group('TC-019: Runoff Measurements for Soil', () {
    test('should store runoff values for soil medium', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Soil Plant',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      // Act
      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.water,
          phIn: 6.0,
          phOut: 5.5,
          ecIn: 1.2,
          ecOut: 1.5,
        ),
      );

      // Assert
      expect(log.phIn, 6.0);
      expect(log.phOut, 5.5);
      expect(log.ecIn, 1.2);
      expect(log.ecOut, 1.5);
    });

    test('should allow phOut without phIn', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: DateTime.now(),
        ),
      );

      // Act
      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.water,
          phOut: 6.2, // Only runoff value
        ),
      );

      // Assert
      expect(log.phIn, isNull);
      expect(log.phOut, 6.2);
    });
  });

  group('TC-020: Runoff Not Needed for RDWC', () {
    test('RDWC plant should not require runoff measurements', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'RDWC Plant',
          seedType: SeedType.photo,
          medium: Medium.rdwc,
          seedDate: DateTime.now(),
        ),
      );

      // Act
      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 1,
          actionType: ActionType.water,
          // No phOut/ecOut needed for RDWC
        ),
      );

      // Assert
      expect(log.phOut, isNull);
      expect(log.ecOut, isNull);
      expect(plant.medium, Medium.rdwc);
    });
  });

  group('TC-022: Log Deletion with RESTRICT (v14)', () {
    test('soft delete archives log even when photos exist', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Photo Test',
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

      // Create photos linked to log
      await testDb.insert('photos', {
        'log_id': log.id,
        'file_path': '/test/photo1.jpg',
        'created_at': DateTime.now().toIso8601String(),
      });

      await testDb.insert('photos', {
        'log_id': log.id,
        'file_path': '/test/photo2.jpg',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Act - With soft delete, this doesn't throw, it archives
      final deleted = await logRepo.delete(log.id!);

      // Assert - Log is archived, photos remain linked
      expect(deleted, equals(1));

      final archivedLog = await logRepo.findById(log.id!);
      expect(archivedLog, isNotNull);
      expect(archivedLog!.archived, isTrue);

      // Verify photos still exist
      final photos = await testDb.query(
        'photos',
        where: 'log_id = ?',
        whereArgs: [log.id],
      );

      expect(photos.length, 2);
    });

    test('soft delete archives log even after photos are deleted', () async {
      // Arrange
      final plant = await plantRepo.save(
        Plant(
          name: 'Photo Test 2',
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

      // Create photo linked to log
      final photoId = await testDb.insert('photos', {
        'log_id': log.id,
        'file_path': '/test/photo1.jpg',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Act - Delete photo first, then archive log
      await testDb.delete('photos', where: 'id = ?', whereArgs: [photoId]);
      await logRepo.delete(log.id!);

      // Assert - Log is archived (not permanently deleted)
      final deletedLog = await logRepo.findById(log.id!);
      expect(deletedLog, isNotNull);
      expect(deletedLog!.archived, isTrue);
    });
  });

  group('TC-023: day_number Consistency', () {
    test('should track day_number based on seedDate', () async {
      // Arrange
      final seedDate = DateTime.now().subtract(const Duration(days: 30));
      final plant = await plantRepo.save(
        Plant(
          name: 'Day Number Test',
          seedType: SeedType.photo,
          medium: Medium.erde,
          seedDate: seedDate,
        ),
      );

      // Act
      final log = await logRepo.save(
        PlantLog(
          plantId: plant.id!,
          logDate: DateTime.now(),
          dayNumber: 31, // Expected: 30 days + 1 (1-indexed)
          actionType: ActionType.water,
        ),
      );

      // Assert
      final retrievedLog = await logRepo.findById(log.id!);
      expect(retrievedLog, isNotNull);
      expect(retrievedLog!.dayNumber, greaterThanOrEqualTo(30));
      expect(retrievedLog.dayNumber, lessThanOrEqualTo(32));
    });
  });
}
