// =============================================
// GROWLOG - Plant Log Duplicate Prevention Tests
// Tests for Fix #4: Prevent duplicate logs (same plant, same day)
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/plant_log_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database db;
  late PlantRepository plantRepo;
  late PlantLogRepository logRepo;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    db = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(db);

    // Initialize repositories
    plantRepo = PlantRepository();
    logRepo = PlantLogRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('Fix #4: Duplicate Log Prevention', () {
    test('findByPlantAndDayNumber() returns existing log', () async {
      // Arrange: Create plant and log
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      final log = await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
        note: 'Original log',
      ));

      // Act
      final foundLog = await logRepo.findByPlantAndDayNumber(plant.id!, 10);

      // Assert
      expect(foundLog, isNotNull, reason: 'Should find existing log');
      expect(foundLog!.id, log.id);
      expect(foundLog.note, 'Original log');
    });

    test('findByPlantAndDayNumber() returns null when no log exists', () async {
      // Arrange: Create plant (no logs)
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      // Act
      final foundLog = await logRepo.findByPlantAndDayNumber(plant.id!, 10);

      // Assert
      expect(foundLog, isNull, reason: 'Should return null when no log exists');
    });

    test('findByPlantAndDayNumber() ignores archived logs', () async {
      // Arrange: Create plant and archived log
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
        archived: true, // Archived log
      ));

      // Act
      final foundLog = await logRepo.findByPlantAndDayNumber(plant.id!, 10);

      // Assert
      expect(foundLog, isNull,
          reason: 'Should ignore archived logs (due to UNIQUE constraint WHERE archived = 0)');
    });

    test('findByPlantAndDayNumber() excludes specific log ID', () async {
      // Arrange: Create plant and log
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      final log = await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
      ));

      // Act: Exclude the log we just created
      final foundLog = await logRepo.findByPlantAndDayNumber(
        plant.id!,
        10,
        excludeLogId: log.id,
      );

      // Assert
      expect(foundLog, isNull,
          reason: 'Should exclude log with matching ID (used for UPDATE validation)');
    });

    test('save() throws conflict exception for duplicate log', () async {
      // Arrange: Create plant and first log
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
        note: 'First log',
      ));

      // Act & Assert: Try to save duplicate log
      expect(
        () => logRepo.save(PlantLog(
          plantId: plant.id!,
          logDate: DateTime(2025, 1, 15),
          dayNumber: 10, // SAME day number!
          phaseDayNumber: 5,
          phase: PlantPhase.veg,
          actionType: ActionType.note,
          note: 'Duplicate log',
        )),
        throwsA(isA<RepositoryException>().having(
          (e) => e.type,
          'type',
          RepositoryErrorType.conflict,
        )),
        reason: 'Should throw conflict exception for duplicate',
      );
    });

    test('save() error message is in German', () async {
      // Arrange: Create plant and first log
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
      ));

      // Act & Assert: Verify German error message
      try {
        await logRepo.save(PlantLog(
          plantId: plant.id!,
          logDate: DateTime(2025, 1, 15),
          dayNumber: 10,
          phaseDayNumber: 5,
          phase: PlantPhase.veg,
          actionType: ActionType.note,
        ));
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<RepositoryException>());
        final exception = e as RepositoryException;
        expect(exception.message, contains('Tag 10'),
            reason: 'Error should mention day number');
        expect(exception.message, contains('existiert bereits'),
            reason: 'Error should be in German');
      }
    });

    test('save() allows updating existing log (same plant, same day)', () async {
      // Arrange: Create plant and log
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      final originalLog = await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
        note: 'Original notes',
      ));

      // Act: Update the same log
      final updatedLog = await logRepo.save(PlantLog(
        id: originalLog.id, // SAME ID = UPDATE
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10, // Same day number is OK for UPDATE
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
        note: 'Updated notes',
      ));

      // Assert
      expect(updatedLog.id, originalLog.id, reason: 'Should be same log');
      expect(updatedLog.note, 'Updated notes', reason: 'Notes should be updated');

      // Verify only one log exists
      final logs = await logRepo.findByPlant(plant.id!);
      expect(logs.length, 1, reason: 'Should still have only one log');
    });

    test('save() allows same day_number for different plants', () async {
      // Arrange: Create two plants
      final plant1 = await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      final plant2 = await plantRepo.save(Plant(
        name: 'Plant 2',
        seedType: SeedType.auto,
        medium: Medium.coco,
      ));

      // Act: Save logs with same day_number for different plants
      final log1 = await logRepo.save(PlantLog(
        plantId: plant1.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
      ));

      final log2 = await logRepo.save(PlantLog(
        plantId: plant2.id!, // DIFFERENT plant
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10, // SAME day number is OK
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
      ));

      // Assert
      expect(log1.id, isNot(log2.id), reason: 'Should be different logs');
      expect(log1.plantId, plant1.id);
      expect(log2.plantId, plant2.id);
    });

    test('save() allows duplicate day_number if original is archived', () async {
      // Arrange: Create plant and archived log
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
      ));

      await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10,
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
        archived: true, // Archived log
        note: 'Archived',
      ));

      // Act: Save new log with same day_number
      final newLog = await logRepo.save(PlantLog(
        plantId: plant.id!,
        logDate: DateTime(2025, 1, 15),
        dayNumber: 10, // Same day_number is OK (original is archived)
        phaseDayNumber: 5,
        phase: PlantPhase.veg,
        actionType: ActionType.note,
        note: 'New log',
      ));

      // Assert
      expect(newLog.note, 'New log', reason: 'Should create new log');

      // Verify we have 2 logs total (1 archived, 1 active)
      final activeLogs = await logRepo.findByPlant(plant.id!);
      expect(activeLogs.length, 1, reason: 'Should have 1 active log');
      expect(activeLogs.first.note, 'New log');
    });
  });
}
