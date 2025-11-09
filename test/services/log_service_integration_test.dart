// =============================================
// GROWLOG - LogService Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/services/interfaces/i_log_service.dart';
import 'package:growlog_app/services/log_service.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late ILogService logService;
  late IPlantRepository plantRepository;

  // Initialize sqflite_ffi once for all tests
  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  // Create fresh database before each test
  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();

    // Mock DatabaseHelper.instance.database to return our test database
    DatabaseHelper.setTestDatabase(testDb);

    // Initialize dependencies for LogService
    plantRepository = PlantRepository();
    logService = LogService(DatabaseHelper.instance, plantRepository);

    // Seed test data (rooms, grows, fertilizers)
    await TestDatabaseHelper.seedTestData(testDb);
  });

  // Close database after each test
  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('LogService - saveSingleLog()', () {
    test('Creating new log with fertilizers - should save log and associations', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
        phaseStartDate: DateTime(2025, 1, 10),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 15,
        logDate: DateTime(2025, 1, 15),
        actionType: ActionType.water,
        waterAmount: 2.0,
        phIn: 6.0,
        ecIn: 1.5,
      );

      final fertilizers = <int, double>{
        1: 10.0, // Test Fertilizer A - 10ml
        2: 5.0,  // Test Fertilizer B - 5ml
      };

      // Act
      final savedLog = await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: fertilizers,
        photoPaths: [],
      );

      // Assert
      expect(savedLog.id, isNotNull);
      expect(savedLog.plantId, equals(savedPlant.id));
      expect(savedLog.dayNumber, equals(15));
      expect(savedLog.waterAmount, equals(2.0));

      // Verify fertilizers were saved
      final logFerts = await testDb.query('log_fertilizers', where: 'log_id = ?', whereArgs: [savedLog.id]);
      expect(logFerts.length, equals(2));
      expect(logFerts.any((f) => f['fertilizer_id'] == 1 && f['amount'] == 10.0), isTrue);
      expect(logFerts.any((f) => f['fertilizer_id'] == 2 && f['amount'] == 5.0), isTrue);
    });

    test('Creating log - should auto-calculate day number from seed date', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 999, // Wrong value - should be corrected
        logDate: DateTime(2025, 1, 10),
        actionType: ActionType.water,
      );

      // Act
      final savedLog = await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {},
        photoPaths: [],
      );

      // Assert
      expect(savedLog.dayNumber, equals(10), reason: 'Day number should be auto-calculated');
    });

    test('Creating log - should calculate phase day number', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
        phaseStartDate: DateTime(2025, 1, 10),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 15,
        logDate: DateTime(2025, 1, 15),
        actionType: ActionType.water,
      );

      // Act
      final savedLog = await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {},
        photoPaths: [],
      );

      // Assert
      expect(savedLog.phaseDayNumber, equals(6), reason: 'Phase day number should be calculated');
      expect(savedLog.phase, equals(PlantPhase.veg), reason: 'Phase should be set from plant');
    });

    test('Creating log for archived plant - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Archived Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.archived,
        archived: true,
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime.now(),
        actionType: ActionType.water,
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(plant: savedPlant, log: log, fertilizers: {}, photoPaths: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Creating log with invalid pH - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
        phIn: 15.0, // Invalid pH > 14
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(plant: savedPlant, log: log, fertilizers: {}, photoPaths: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Creating log with invalid EC - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
        ecIn: 15.0, // Invalid EC > 10
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(plant: savedPlant, log: log, fertilizers: {}, photoPaths: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Creating log with transplant action - should update plant container size', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
        currentContainerSize: 5.0,
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 10,
        logDate: DateTime(2025, 1, 10),
        actionType: ActionType.transplant,
        containerSize: 10.0, // New container size
      );

      // Act
      await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {},
        photoPaths: [],
      );

      // Assert - Plant should be updated
      final updatedPlant = await plantRepository.findById(savedPlant.id!);
      expect(updatedPlant!.currentContainerSize, equals(10.0));
    });

    test('Creating log with phase change - should update plant phase', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 10,
        logDate: DateTime(2025, 1, 10),
        actionType: ActionType.phaseChange,
      );

      // Act
      await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {},
        photoPaths: [],
        newPhase: PlantPhase.veg,
      );

      // Assert - Plant should be updated
      final updatedPlant = await plantRepository.findById(savedPlant.id!);
      expect(updatedPlant!.phase, equals(PlantPhase.veg));
      expect(updatedPlant.phaseStartDate, equals(DateTime(2025, 1, 10)));
    });

    test('Updating existing log - should update fertilizers', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 5,
        logDate: DateTime(2025, 1, 5),
        actionType: ActionType.water,
      );

      // Create initial log with fertilizers
      final savedLog = await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {1: 10.0},
        photoPaths: [],
      );

      // Act - Update with different fertilizers
      final updatedLog = savedLog.copyWith(note: 'Updated');
      await logService.saveSingleLog(
        plant: savedPlant,
        log: updatedLog,
        fertilizers: {2: 15.0}, // Different fertilizer
        photoPaths: [],
      );

      // Assert - Old fertilizers should be replaced
      final logFerts = await testDb.query('log_fertilizers', where: 'log_id = ?', whereArgs: [savedLog.id]);
      expect(logFerts.length, equals(1));
      expect(logFerts.first['fertilizer_id'], equals(2));
      expect(logFerts.first['amount'], equals(15.0));
    });
  });

  group('LogService - saveBulkLog()', () {
    test('Creating bulk logs for multiple plants - should create individual logs', () async {
      // Arrange - Create multiple plants
      final plant1 = await plantRepository.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      ));
      final plant2 = await plantRepository.save(Plant(
        name: 'Plant 2',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      ));

      // Act
      final logIds = await logService.saveBulkLog(
        plantIds: [plant1.id!, plant2.id!],
        logDate: DateTime(2025, 1, 10),
        actionType: ActionType.water,
        waterAmount: 2.0,
        phIn: 6.0,
        ecIn: 1.5,
        fertilizers: {1: 10.0},
        photoPaths: [],
      );

      // Assert
      expect(logIds.length, equals(2));

      // Verify logs were created
      final logs1 = await testDb.query('plant_logs', where: 'plant_id = ?', whereArgs: [plant1.id]);
      final logs2 = await testDb.query('plant_logs', where: 'plant_id = ?', whereArgs: [plant2.id]);
      expect(logs1.length, equals(1));
      expect(logs2.length, equals(1));

      // Verify fertilizers were added to both logs
      for (final logId in logIds) {
        final ferts = await testDb.query('log_fertilizers', where: 'log_id = ?', whereArgs: [logId]);
        expect(ferts.length, equals(1));
        expect(ferts.first['fertilizer_id'], equals(1));
      }
    });

    test('Bulk logs should calculate day numbers individually per plant', () async {
      // Arrange - Create plants with different seed dates
      final plant1 = await plantRepository.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1), // Day 10
      ));
      final plant2 = await plantRepository.save(Plant(
        name: 'Plant 2',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 5), // Day 6
      ));

      // Act - Same log date for both
      await logService.saveBulkLog(
        plantIds: [plant1.id!, plant2.id!],
        logDate: DateTime(2025, 1, 10),
        actionType: ActionType.water,
        fertilizers: {},
        photoPaths: [],
      );

      // Assert - Different day numbers based on individual seed dates
      final logs1 = await testDb.query('plant_logs', where: 'plant_id = ?', whereArgs: [plant1.id]);
      final logs2 = await testDb.query('plant_logs', where: 'plant_id = ?', whereArgs: [plant2.id]);

      expect(logs1.first['day_number'], equals(10));
      expect(logs2.first['day_number'], equals(6));
    });

    test('Bulk logs with archived plant - should throw ArgumentError', () async {
      // Arrange
      final plant1 = await plantRepository.save(Plant(
        name: 'Active Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      ));
      final plant2 = await plantRepository.save(Plant(
        name: 'Archived Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.archived,
        seedDate: DateTime(2025, 1, 1),
        archived: true,
      ));

      // Act & Assert
      expect(
        () => logService.saveBulkLog(
          plantIds: [plant1.id!, plant2.id!],
          logDate: DateTime(2025, 1, 10),
          actionType: ActionType.water,
          fertilizers: {},
          photoPaths: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Bulk logs with phase change - should update all plants', () async {
      // Arrange
      final plant1 = await plantRepository.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        seedDate: DateTime(2025, 1, 1),
      ));
      final plant2 = await plantRepository.save(Plant(
        name: 'Plant 2',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        seedDate: DateTime(2025, 1, 1),
      ));

      // Act
      await logService.saveBulkLog(
        plantIds: [plant1.id!, plant2.id!],
        logDate: DateTime(2025, 1, 10),
        actionType: ActionType.phaseChange,
        fertilizers: {},
        photoPaths: [],
        newPhase: PlantPhase.veg,
      );

      // Assert - Both plants should be updated
      final updatedPlant1 = await plantRepository.findById(plant1.id!);
      final updatedPlant2 = await plantRepository.findById(plant2.id!);

      expect(updatedPlant1!.phase, equals(PlantPhase.veg));
      expect(updatedPlant2!.phase, equals(PlantPhase.veg));
    });

    test('Bulk logs with empty plant list - should throw ArgumentError', () async {
      // Act & Assert
      expect(
        () => logService.saveBulkLog(
          plantIds: [],
          logDate: DateTime.now(),
          actionType: ActionType.water,
          fertilizers: {},
          photoPaths: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('LogService - getLogWithDetails()', () {
    test('Getting log with fertilizers - should return complete data', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 5,
        logDate: DateTime(2025, 1, 5),
        actionType: ActionType.water,
      );

      final savedLog = await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {1: 10.0, 2: 5.0},
        photoPaths: [],
      );

      // Act
      final details = await logService.getLogWithDetails(savedLog.id!);

      // Assert
      expect(details, isNotNull);
      expect(details!['log'], isA<PlantLog>());
      expect(details['fertilizers'], isA<List>());
      expect((details['fertilizers'] as List).length, equals(2));
      expect(details['photos'], isA<List>());
    });

    test('Getting non-existent log - should return null', () async {
      // Act
      final details = await logService.getLogWithDetails(99999);

      // Assert
      expect(details, isNull);
    });
  });

  group('LogService - copyLog()', () {
    test('Copying log to same plant - should create duplicate with new date', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 5,
        logDate: DateTime(2025, 1, 5),
        actionType: ActionType.water,
        waterAmount: 2.0,
        phIn: 6.0,
      );

      final savedLog = await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {1: 10.0},
        photoPaths: [],
      );

      // Act - Copy to new date
      final copiedLog = await logService.copyLog(
        sourceLogId: savedLog.id!,
        targetPlantId: savedPlant.id!,
        newDate: DateTime(2025, 1, 10),
      );

      // Assert
      expect(copiedLog, isNotNull);
      expect(copiedLog!.id, isNot(equals(savedLog.id)));
      expect(copiedLog.logDate, equals(DateTime(2025, 1, 10)));
      expect(copiedLog.dayNumber, equals(10), reason: 'Day number should be recalculated');
      expect(copiedLog.waterAmount, equals(2.0));
      expect(copiedLog.phIn, equals(6.0));

      // Verify fertilizers were copied
      final ferts = await testDb.query('log_fertilizers', where: 'log_id = ?', whereArgs: [copiedLog.id]);
      expect(ferts.length, equals(1));
      expect(ferts.first['fertilizer_id'], equals(1));
    });

    test('Copying non-existent log - should return null', () async {
      // Act
      final copiedLog = await logService.copyLog(
        sourceLogId: 99999,
        targetPlantId: 1,
        newDate: DateTime.now(),
      );

      // Assert
      expect(copiedLog, isNull);
    });
  });

  group('LogService - deleteLog()', () {
    test('Deleting log - should remove log and fertilizers', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 5,
        logDate: DateTime(2025, 1, 5),
        actionType: ActionType.water,
      );

      final savedLog = await logService.saveSingleLog(
        plant: savedPlant,
        log: log,
        fertilizers: {1: 10.0},
        photoPaths: [],
      );

      // Act
      await logService.deleteLog(savedLog.id!);

      // Assert - Log should be deleted
      final logs = await testDb.query('plant_logs', where: 'id = ?', whereArgs: [savedLog.id]);
      expect(logs, isEmpty);

      // Fertilizers should be cascade deleted
      final ferts = await testDb.query('log_fertilizers', where: 'log_id = ?', whereArgs: [savedLog.id]);
      expect(ferts, isEmpty);
    });
  });

  group('LogService - deleteLogs()', () {
    test('Deleting multiple logs - should remove all logs', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log1 = await logService.saveSingleLog(
        plant: savedPlant,
        log: PlantLog(plantId: savedPlant.id!, dayNumber: 1, logDate: DateTime(2025, 1, 1), actionType: ActionType.water),
        fertilizers: {},
        photoPaths: [],
      );

      final log2 = await logService.saveSingleLog(
        plant: savedPlant,
        log: PlantLog(plantId: savedPlant.id!, dayNumber: 2, logDate: DateTime(2025, 1, 2), actionType: ActionType.water),
        fertilizers: {},
        photoPaths: [],
      );

      // Act
      await logService.deleteLogs([log1.id!, log2.id!]);

      // Assert
      final logs = await testDb.query('plant_logs', where: 'plant_id = ?', whereArgs: [savedPlant.id]);
      expect(logs, isEmpty);
    });

    test('Deleting with empty list - should do nothing', () async {
      // Act & Assert - Should not throw
      await logService.deleteLogs([]);
    });
  });

  group('LogService - Validation', () {
    test('Invalid plant ID - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
      );

      final log = PlantLog(
        plantId: -1, // Invalid
        dayNumber: 1,
        logDate: DateTime.now(),
        actionType: ActionType.water,
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(plant: plant, log: log, fertilizers: {}, photoPaths: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Invalid day number - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 0, // Invalid
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(plant: savedPlant, log: log, fertilizers: {}, photoPaths: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Invalid fertilizer amount - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(
          plant: savedPlant,
          log: log,
          fertilizers: {1: -10.0}, // Negative amount
          photoPaths: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Excessive fertilizer amount - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(
          plant: savedPlant,
          log: log,
          fertilizers: {1: 20000.0}, // Too much > 10000ml
          photoPaths: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Invalid temperature - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
        temperature: 150.0, // Invalid > 100
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(plant: savedPlant, log: log, fertilizers: {}, photoPaths: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Invalid humidity - should throw ArgumentError', () async {
      // Arrange
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
      );
      final savedPlant = await plantRepository.save(plant);

      final log = PlantLog(
        plantId: savedPlant.id!,
        dayNumber: 1,
        logDate: DateTime(2025, 1, 1),
        actionType: ActionType.water,
        humidity: 150.0, // Invalid > 100
      );

      // Act & Assert
      expect(
        () => logService.saveSingleLog(plant: savedPlant, log: log, fertilizers: {}, photoPaths: []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
