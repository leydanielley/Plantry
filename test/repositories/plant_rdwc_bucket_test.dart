// =============================================
// GROWLOG - RDWC Bucket Uniqueness Tests
// Tests for Fix #5: Prevent duplicate bucket assignments
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/rdwc_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database db;
  late PlantRepository plantRepo;
  late RdwcRepository rdwcRepo;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    db = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(db);

    // Initialize repositories
    plantRepo = PlantRepository();
    rdwcRepo = RdwcRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('Fix #5: RDWC Bucket Uniqueness', () {
    test('isBucketOccupied() returns false for unoccupied bucket', () async {
      // Arrange: Create RDWC system (no plants)
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      // Act
      final occupied = await plantRepo.isBucketOccupied(systemId, 1);

      // Assert
      expect(occupied, false, reason: 'Empty bucket should be unoccupied');
    });

    test('isBucketOccupied() returns true for occupied bucket', () async {
      // Arrange: Create RDWC system with plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
      ));

      // Act
      final occupied = await plantRepo.isBucketOccupied(systemId, 1);

      // Assert
      expect(occupied, true, reason: 'Bucket 1 should be occupied');
    });

    test('isBucketOccupied() ignores archived plants', () async {
      // Arrange: Create RDWC system with archived plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      await plantRepo.save(Plant(
        name: 'Archived Plant',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
        phase: PlantPhase.archived,
        archived: true, // Must explicitly set archived flag
      ));

      // Act
      final occupied = await plantRepo.isBucketOccupied(systemId, 1);

      // Assert
      expect(occupied, false,
          reason: 'Archived plants should not block bucket assignment');
    });

    test('isBucketOccupied() excludes specific plant ID', () async {
      // Arrange: Create RDWC system with plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      final plant = await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
      ));

      // Act: Check if bucket 1 is occupied, excluding the plant that occupies it
      final occupied = await plantRepo.isBucketOccupied(
        systemId,
        1,
        excludePlantId: plant.id,
      );

      // Assert
      expect(occupied, false,
          reason: 'Should exclude self when checking (for UPDATE validation)');
    });

    test('save() throws conflict exception for duplicate bucket', () async {
      // Arrange: Create RDWC system with plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
      ));

      // Act & Assert: Try to save another plant in bucket 1
      expect(
        () => plantRepo.save(Plant(
          name: 'Plant 2',
          seedType: SeedType.auto,
          medium: Medium.rdwc,
          rdwcSystemId: systemId,
          bucketNumber: 1, // SAME bucket!
        )),
        throwsA(isA<RepositoryException>().having(
          (e) => e.type,
          'type',
          RepositoryErrorType.conflict,
        )),
        reason: 'Should throw conflict exception for duplicate bucket',
      );
    });

    test('save() error message is in German', () async {
      // Arrange: Create RDWC system with plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
      ));

      // Act & Assert: Verify German error message
      try {
        await plantRepo.save(Plant(
          name: 'Plant 2',
          seedType: SeedType.auto,
          medium: Medium.rdwc,
          rdwcSystemId: systemId,
          bucketNumber: 1,
        ));
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<RepositoryException>());
        final exception = e as RepositoryException;
        expect(exception.message, contains('Bucket 1'),
            reason: 'Error should mention bucket number');
        expect(exception.message, contains('bereits belegt'),
            reason: 'Error should be in German');
      }
    });

    test('save() allows updating plant without changing bucket', () async {
      // Arrange: Create RDWC system with plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      final plant = await plantRepo.save(Plant(
        name: 'Original Name',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
      ));

      // Act: Update plant keeping same bucket
      final updated = await plantRepo.save(Plant(
        id: plant.id, // SAME ID = UPDATE
        name: 'Updated Name',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1, // Same bucket is OK for UPDATE
      ));

      // Assert
      expect(updated.id, plant.id, reason: 'Should be same plant');
      expect(updated.name, 'Updated Name', reason: 'Name should be updated');
      expect(updated.bucketNumber, 1, reason: 'Bucket should remain 1');
    });

    test('save() allows same bucket_number in different systems', () async {
      // Arrange: Create two RDWC systems
      final system1Id = await rdwcRepo.createSystem(RdwcSystem(
        name: 'System 1',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      final system2Id = await rdwcRepo.createSystem(RdwcSystem(
        name: 'System 2',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      // Act: Save plants with same bucket_number in different systems
      final plant1 = await plantRepo.save(Plant(
        name: 'Plant in System 1',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: system1Id,
        bucketNumber: 1,
      ));

      final plant2 = await plantRepo.save(Plant(
        name: 'Plant in System 2',
        seedType: SeedType.auto,
        medium: Medium.rdwc,
        rdwcSystemId: system2Id, // DIFFERENT system
        bucketNumber: 1, // SAME bucket number is OK
      ));

      // Assert
      expect(plant1.id, isNot(plant2.id), reason: 'Should be different plants');
      expect(plant1.rdwcSystemId, system1Id);
      expect(plant2.rdwcSystemId, system2Id);
      expect(plant1.bucketNumber, 1);
      expect(plant2.bucketNumber, 1);
    });

    test('save() allows null bucket_number', () async {
      // Arrange: Create RDWC system
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      // Act: Save plant without bucket assignment
      final plant = await plantRepo.save(Plant(
        name: 'Plant without bucket',
        seedType: SeedType.photo,
        medium: Medium.erde, // Not RDWC medium
        rdwcSystemId: systemId,
        bucketNumber: null, // No bucket
      ));

      // Assert
      expect(plant.bucketNumber, isNull,
          reason: 'Null bucket should be allowed');
    });

    test('save() allows duplicate bucket if original is archived', () async {
      // Arrange: Create RDWC system with archived plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      await plantRepo.save(Plant(
        name: 'Archived Plant',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
        phase: PlantPhase.archived,
        archived: true, // Must explicitly set archived flag
      ));

      // Act: Save new plant with same bucket_number
      final newPlant = await plantRepo.save(Plant(
        name: 'New Plant',
        seedType: SeedType.auto,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1, // Same bucket is OK (original archived)
      ));

      // Assert
      expect(newPlant.bucketNumber, 1, reason: 'Should use bucket 1');
    });

    test('save() validates bucket only for RDWC plants', () async {
      // Arrange: Create RDWC system with plant in bucket 1
      final systemId = await rdwcRepo.createSystem(RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        bucketCount: 4,
      ));

      await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        rdwcSystemId: systemId,
        bucketNumber: 1,
      ));

      // Act: Save non-RDWC plant (should not validate buckets)
      final soilPlant = await plantRepo.save(Plant(
        name: 'Soil Plant',
        seedType: SeedType.auto,
        medium: Medium.erde, // Not RDWC!
        bucketNumber: null, // No bucket for soil plants
      ));

      // Assert
      expect(soilPlant.medium, Medium.erde);
      expect(soilPlant.bucketNumber, isNull);
    });
  });
}
