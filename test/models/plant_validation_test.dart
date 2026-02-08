// =============================================
// GROWLOG - Plant Model Validation Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/enums.dart';

void main() {
  group('Plant - Constructor Validation', () {
    test('should use default name for empty string', () {
      final plant = Plant(
        name: '',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );

      expect(plant.name, equals('Unknown Plant'));
    });

    test('should use default name for whitespace', () {
      final plant = Plant(
        name: '   ',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );

      expect(plant.name, equals('Unknown Plant'));
    });

    test('should trim whitespace from name', () {
      final plant = Plant(
        name: '  Test Plant  ',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );

      expect(plant.name, equals('Test Plant'));
    });

    test('should truncate long names to 100 characters', () {
      final longName = 'A' * 150;
      final plant = Plant(
        name: longName,
        seedType: SeedType.photo,
        medium: Medium.erde,
      );

      expect(plant.name.length, equals(100));
    });

    test('should clamp negative bucket number to 1', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        bucketNumber: -5,
      );

      expect(plant.bucketNumber, equals(1));
    });

    test('should clamp zero bucket number to 1', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        bucketNumber: 0,
      );

      expect(plant.bucketNumber, equals(1));
    });

    test('should clamp large bucket number to 50', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        bucketNumber: 999,
      );

      expect(plant.bucketNumber, equals(50));
    });

    test('should allow null bucket number', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        bucketNumber: null,
      );

      expect(plant.bucketNumber, isNull);
    });

    test('should allow valid bucket numbers', () {
      final plant1 = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        bucketNumber: 1,
      );
      expect(plant1.bucketNumber, equals(1));

      final plant2 = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        bucketNumber: 25,
      );
      expect(plant2.bucketNumber, equals(25));

      final plant3 = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        bucketNumber: 50,
      );
      expect(plant3.bucketNumber, equals(50));
    });

    test('should clamp negative container size to 0.1', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        currentContainerSize: -10.0,
      );

      expect(plant.currentContainerSize, equals(0.1));
    });

    test('should clamp small container size to 0.1', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        currentContainerSize: 0.05,
      );

      expect(plant.currentContainerSize, equals(0.1));
    });

    test('should clamp large container size to 1000', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        currentContainerSize: 9999.0,
      );

      expect(plant.currentContainerSize, equals(1000.0));
    });

    test('should allow null container size', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        currentContainerSize: null,
      );

      expect(plant.currentContainerSize, isNull);
    });

    test('should allow valid container sizes', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        currentContainerSize: 11.0,
      );

      expect(plant.currentContainerSize, equals(11.0));
    });

    test('should clamp negative system size to 1.0', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        currentSystemSize: -10.0,
      );

      expect(plant.currentSystemSize, equals(1.0));
    });

    test('should clamp small system size to 1.0', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        currentSystemSize: 0.5,
      );

      expect(plant.currentSystemSize, equals(1.0));
    });

    test('should clamp large system size to 10000', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        currentSystemSize: 99999.0,
      );

      expect(plant.currentSystemSize, equals(10000.0));
    });

    test('should allow null system size', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        currentSystemSize: null,
      );

      expect(plant.currentSystemSize, isNull);
    });

    test('should allow valid system sizes', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        currentSystemSize: 100.0,
      );

      expect(plant.currentSystemSize, equals(100.0));
    });

    test('should use default log profile for empty string', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        logProfileName: '',
      );

      expect(plant.logProfileName, equals('standard'));
    });

    test('should use default log profile for whitespace', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        logProfileName: '   ',
      );

      expect(plant.logProfileName, equals('standard'));
    });

    test('should trim whitespace from log profile name', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        logProfileName: '  custom  ',
      );

      expect(plant.logProfileName, equals('custom'));
    });
  });

  group('Plant - Valid Values', () {
    test('should accept all valid values', () {
      final plant = Plant(
        name: 'Gorilla Glue #4',
        breeder: 'GG Strains',
        strain: 'Indica Dominant',
        feminized: true,
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        phase: PlantPhase.bloom,
        growId: 1,
        roomId: 2,
        rdwcSystemId: 3,
        bucketNumber: 4,
        seedDate: DateTime(2025, 1, 1),
        vegDate: DateTime(2025, 1, 15),
        bloomDate: DateTime(2025, 2, 1),
        currentContainerSize: 11.0,
        currentSystemSize: 100.0,
        logProfileName: 'custom',
        archived: false,
      );

      expect(plant.name, equals('Gorilla Glue #4'));
      expect(plant.breeder, equals('GG Strains'));
      expect(plant.strain, equals('Indica Dominant'));
      expect(plant.feminized, isTrue);
      expect(plant.seedType, equals(SeedType.photo));
      expect(plant.medium, equals(Medium.rdwc));
      expect(plant.phase, equals(PlantPhase.bloom));
      expect(plant.growId, equals(1));
      expect(plant.roomId, equals(2));
      expect(plant.rdwcSystemId, equals(3));
      expect(plant.bucketNumber, equals(4));
      expect(plant.seedDate, equals(DateTime(2025, 1, 1)));
      expect(plant.vegDate, equals(DateTime(2025, 1, 15)));
      expect(plant.bloomDate, equals(DateTime(2025, 2, 1)));
      expect(plant.currentContainerSize, equals(11.0));
      expect(plant.currentSystemSize, equals(100.0));
      expect(plant.logProfileName, equals('custom'));
      expect(plant.archived, isFalse);
    });

    test('should accept minimal valid plant', () {
      final plant = Plant(
        name: 'A',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );

      expect(plant.name, equals('A'));
      expect(plant.seedType, equals(SeedType.photo));
      expect(plant.medium, equals(Medium.erde));
      expect(plant.feminized, isTrue); // Default
      expect(plant.phase, equals(PlantPhase.seedling)); // Default
      expect(plant.logProfileName, equals('standard')); // Default
      expect(plant.archived, isFalse); // Default
    });

    test('should accept boundary values', () {
      final plant = Plant(
        name: 'A' * 100, // Maximum name length
        seedType: SeedType.auto,
        medium: Medium.rdwc,
        bucketNumber: 50, // Maximum
        currentContainerSize: 1000.0, // Maximum
        currentSystemSize: 10000.0, // Maximum
      );

      expect(plant.name.length, equals(100));
      expect(plant.bucketNumber, equals(50));
      expect(plant.currentContainerSize, equals(1000.0));
      expect(plant.currentSystemSize, equals(10000.0));
    });
  });

  group('Plant - Edge Cases', () {
    test('should handle all nulls for optional fields', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        breeder: null,
        strain: null,
        growId: null,
        roomId: null,
        rdwcSystemId: null,
        bucketNumber: null,
        seedDate: null,
        phaseStartDate: null,
        vegDate: null,
        bloomDate: null,
        harvestDate: null,
        createdBy: null,
        currentContainerSize: null,
        currentSystemSize: null,
      );

      expect(plant.breeder, isNull);
      expect(plant.strain, isNull);
      expect(plant.growId, isNull);
      expect(plant.roomId, isNull);
      expect(plant.rdwcSystemId, isNull);
      expect(plant.bucketNumber, isNull);
      expect(plant.seedDate, isNull);
      expect(plant.phaseStartDate, isNull);
      expect(plant.vegDate, isNull);
      expect(plant.bloomDate, isNull);
      expect(plant.harvestDate, isNull);
      expect(plant.createdBy, isNull);
      expect(plant.currentContainerSize, isNull);
      expect(plant.currentSystemSize, isNull);
    });

    test('should handle decimal precision for sizes', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        currentContainerSize: 11.5,
        currentSystemSize: 123.456,
      );

      expect(plant.currentContainerSize, equals(11.5));
      expect(plant.currentSystemSize, equals(123.456));
    });

    test('copyWith should preserve validation', () {
      final original = Plant(
        name: 'Original',
        seedType: SeedType.photo,
        medium: Medium.erde,
      );

      // Try to set invalid values via copyWith
      final updated = original.copyWith(
        name: '',
        bucketNumber: 999,
        currentContainerSize: -10.0,
        currentSystemSize: 99999.0,
        logProfileName: '',
      );

      expect(updated.name, equals('Unknown Plant')); // Validated
      expect(updated.bucketNumber, equals(50)); // Clamped
      expect(updated.currentContainerSize, equals(0.1)); // Clamped
      expect(updated.currentSystemSize, equals(10000.0)); // Clamped
      expect(updated.logProfileName, equals('standard')); // Validated
    });

    test('should handle very small bucket number boundary', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        bucketNumber: 1,
      );

      expect(plant.bucketNumber, equals(1));
    });

    test('should handle very small container size boundary', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.erde,
        currentContainerSize: 0.1,
      );

      expect(plant.currentContainerSize, equals(0.1));
    });

    test('should handle very small system size boundary', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        currentSystemSize: 1.0,
      );

      expect(plant.currentSystemSize, equals(1.0));
    });
  });
}
