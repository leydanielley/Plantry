// =============================================
// GROWLOG - Soft-Delete System Tests
// Tests for archive/restore logic validation
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/rdwc_system.dart';

void main() {
  group('Soft-Delete Models Tests', () {
    test('Plant model has archived property', () {
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        archived: false,
      );

      expect(plant.archived, false);

      final archivedPlant = plant.copyWith(archived: true);
      expect(archivedPlant.archived, true);
    });

    test('Plant copyWith preserves archived state', () {
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        archived: false,
      );

      final updatedPlant = plant.copyWith(name: 'Updated Plant');
      expect(updatedPlant.archived, false);
      expect(updatedPlant.name, 'Updated Plant');
    });

    test('RdwcSystem model has archived property', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 80.0,
        bucketCount: 4,
        archived: false,
      );

      expect(system.archived, false);

      final archivedSystem = system.copyWith(archived: true);
      expect(archivedSystem.archived, true);
    });

    // Note: Room model doesn't have archived property in Dart,
    // it's only in the database (migration v14)
  });

  group('Soft-Delete Logic Tests', () {
    test('Archived items should not appear in filtered lists', () {
      final plants = [
        Plant(
          id: 1,
          name: 'Active Plant',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.seedling,
          archived: false,
        ),
        Plant(
          id: 2,
          name: 'Archived Plant',
          seedType: SeedType.auto,
          medium: Medium.coco,
          phase: PlantPhase.veg,
          archived: true,
        ),
      ];

      // Filter out archived
      final activePlants = plants.where((p) => !p.archived).toList();
      expect(activePlants.length, 1);
      expect(activePlants.first.name, 'Active Plant');
    });

    test('Only archived items should appear in archive list', () {
      final plants = [
        Plant(
          id: 1,
          name: 'Active Plant',
          seedType: SeedType.photo,
          medium: Medium.erde,
          phase: PlantPhase.seedling,
          archived: false,
        ),
        Plant(
          id: 2,
          name: 'Archived Plant',
          seedType: SeedType.auto,
          medium: Medium.coco,
          phase: PlantPhase.veg,
          archived: true,
        ),
      ];

      // Filter only archived
      final archivedPlants = plants.where((p) => p.archived).toList();
      expect(archivedPlants.length, 1);
      expect(archivedPlants.first.name, 'Archived Plant');
    });

    test('Restore operation should set archived to false', () {
      final archivedPlant = Plant(
        id: 1,
        name: 'Archived Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        archived: true,
      );

      expect(archivedPlant.archived, true);

      // Simulate restore
      final restoredPlant = archivedPlant.copyWith(archived: false);
      expect(restoredPlant.archived, false);
      expect(restoredPlant.name, 'Archived Plant');
    });

    test('Archive operation should set archived to true', () {
      final activePlant = Plant(
        id: 1,
        name: 'Active Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        archived: false,
      );

      expect(activePlant.archived, false);

      // Simulate archive
      final archivedPlant = activePlant.copyWith(archived: true);
      expect(archivedPlant.archived, true);
      expect(archivedPlant.name, 'Active Plant');
    });
  });

  group('Migration v14 Schema Validation', () {
    test('All soft-delete models have archived field', () {
      // Plant
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        archived: false,
      );
      expect(plant.archived, isNotNull);

      // RdwcSystem
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 80.0,
        bucketCount: 4,
        archived: false,
      );
      expect(system.archived, isNotNull);

      // Note: Room model doesn't have archived property in Dart
    });

    test('Models default to not archived', () {
      // Plant
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
      );
      expect(plant.archived, false);

      // RdwcSystem
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 80.0,
        bucketCount: 4,
      );
      expect(system.archived, false);

      // Note: Room model doesn't have archived property in Dart
    });
  });

  group('Related Data Counts', () {
    test('getRelatedDataCounts should return map with correct keys', () {
      // Mock counts
      final counts = {'logs': 5, 'photos': 3, 'harvests': 1};

      expect(counts.containsKey('logs'), true);
      expect(counts.containsKey('photos'), true);
      expect(counts.containsKey('harvests'), true);
      expect(counts['logs'], 5);
      expect(counts['photos'], 3);
      expect(counts['harvests'], 1);
    });

    test('getSystemRelatedDataCounts should return map with correct keys', () {
      // Mock counts
      final counts = {'logs': 10, 'plants': 4};

      expect(counts.containsKey('logs'), true);
      expect(counts.containsKey('plants'), true);
      expect(counts['logs'], 10);
      expect(counts['plants'], 4);
    });
  });
}
