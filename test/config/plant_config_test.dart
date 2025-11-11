// =============================================
// GROWLOG - PlantConfig Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/config/plant_config.dart';

void main() {
  group('PlantConfig - Soft Validation (Clamping)', () {
    test('validateName() - should return default for empty', () {
      expect(PlantConfig.validateName(''), equals('Unknown Plant'));
      expect(PlantConfig.validateName('   '), equals('Unknown Plant'));
    });

    test('validateName() - should trim whitespace', () {
      expect(PlantConfig.validateName('  Test  '), equals('Test'));
      expect(PlantConfig.validateName('\tTest\n'), equals('Test'));
    });

    test('validateName() - should truncate long names', () {
      final longName = 'A' * 150;
      expect(PlantConfig.validateName(longName).length, equals(100));
    });

    test('validateName() - should keep valid names', () {
      expect(PlantConfig.validateName('My Plant'), equals('My Plant'));
      expect(PlantConfig.validateName('Gorilla Glue #4'), equals('Gorilla Glue #4'));
    });

    test('validateBucketNumber() - should return null for null', () {
      expect(PlantConfig.validateBucketNumber(null), isNull);
    });

    test('validateBucketNumber() - should clamp to minimum (1)', () {
      expect(PlantConfig.validateBucketNumber(-5), equals(1));
      expect(PlantConfig.validateBucketNumber(0), equals(1));
    });

    test('validateBucketNumber() - should clamp to maximum (50)', () {
      expect(PlantConfig.validateBucketNumber(100), equals(50));
      expect(PlantConfig.validateBucketNumber(999), equals(50));
    });

    test('validateBucketNumber() - should allow valid values', () {
      expect(PlantConfig.validateBucketNumber(1), equals(1));
      expect(PlantConfig.validateBucketNumber(25), equals(25));
      expect(PlantConfig.validateBucketNumber(50), equals(50));
    });

    test('validateContainerSize() - should return null for null', () {
      expect(PlantConfig.validateContainerSize(null), isNull);
    });

    test('validateContainerSize() - should clamp to minimum (0.1)', () {
      expect(PlantConfig.validateContainerSize(-10.0), equals(0.1));
      expect(PlantConfig.validateContainerSize(0.05), equals(0.1));
    });

    test('validateContainerSize() - should clamp to maximum (1000)', () {
      expect(PlantConfig.validateContainerSize(2000.0), equals(1000.0));
      expect(PlantConfig.validateContainerSize(99999.0), equals(1000.0));
    });

    test('validateContainerSize() - should allow valid values', () {
      expect(PlantConfig.validateContainerSize(0.1), equals(0.1));
      expect(PlantConfig.validateContainerSize(11.0), equals(11.0));
      expect(PlantConfig.validateContainerSize(1000.0), equals(1000.0));
    });

    test('validateSystemSize() - should return null for null', () {
      expect(PlantConfig.validateSystemSize(null), isNull);
    });

    test('validateSystemSize() - should clamp to minimum (1.0)', () {
      expect(PlantConfig.validateSystemSize(-10.0), equals(1.0));
      expect(PlantConfig.validateSystemSize(0.5), equals(1.0));
    });

    test('validateSystemSize() - should clamp to maximum (10000)', () {
      expect(PlantConfig.validateSystemSize(20000.0), equals(10000.0));
      expect(PlantConfig.validateSystemSize(99999.0), equals(10000.0));
    });

    test('validateSystemSize() - should allow valid values', () {
      expect(PlantConfig.validateSystemSize(1.0), equals(1.0));
      expect(PlantConfig.validateSystemSize(100.0), equals(100.0));
      expect(PlantConfig.validateSystemSize(10000.0), equals(10000.0));
    });

    test('validateLogProfileName() - should return default for empty', () {
      expect(PlantConfig.validateLogProfileName(''), equals('standard'));
      expect(PlantConfig.validateLogProfileName('   '), equals('standard'));
    });

    test('validateLogProfileName() - should trim whitespace', () {
      expect(PlantConfig.validateLogProfileName('  custom  '), equals('custom'));
    });

    test('validateLogProfileName() - should keep valid names', () {
      expect(PlantConfig.validateLogProfileName('custom'), equals('custom'));
      expect(PlantConfig.validateLogProfileName('standard'), equals('standard'));
    });
  });

  group('PlantConfig - Strict Validation (Throws Errors)', () {
    test('validateNameStrict() - should throw for empty', () {
      expect(
        () => PlantConfig.validateNameStrict(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PlantConfig.validateNameStrict('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateNameStrict() - should throw for too long', () {
      final longName = 'A' * 101;
      expect(
        () => PlantConfig.validateNameStrict(longName),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateNameStrict() - should pass for valid names', () {
      expect(() => PlantConfig.validateNameStrict('A'), returnsNormally);
      expect(() => PlantConfig.validateNameStrict('My Plant'), returnsNormally);
      expect(() => PlantConfig.validateNameStrict('A' * 100), returnsNormally);
    });

    test('validateBucketNumberStrict() - should pass for null', () {
      expect(() => PlantConfig.validateBucketNumberStrict(null), returnsNormally);
    });

    test('validateBucketNumberStrict() - should throw for too small', () {
      expect(
        () => PlantConfig.validateBucketNumberStrict(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PlantConfig.validateBucketNumberStrict(-5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateBucketNumberStrict() - should throw for too large', () {
      expect(
        () => PlantConfig.validateBucketNumberStrict(51),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PlantConfig.validateBucketNumberStrict(999),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateBucketNumberStrict() - should pass for valid values', () {
      expect(() => PlantConfig.validateBucketNumberStrict(1), returnsNormally);
      expect(() => PlantConfig.validateBucketNumberStrict(25), returnsNormally);
      expect(() => PlantConfig.validateBucketNumberStrict(50), returnsNormally);
    });

    test('validateContainerSizeStrict() - should pass for null', () {
      expect(() => PlantConfig.validateContainerSizeStrict(null), returnsNormally);
    });

    test('validateContainerSizeStrict() - should throw for too small', () {
      expect(
        () => PlantConfig.validateContainerSizeStrict(0.05),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PlantConfig.validateContainerSizeStrict(-10.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateContainerSizeStrict() - should throw for too large', () {
      expect(
        () => PlantConfig.validateContainerSizeStrict(1001.0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PlantConfig.validateContainerSizeStrict(99999.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateContainerSizeStrict() - should pass for valid values', () {
      expect(() => PlantConfig.validateContainerSizeStrict(0.1), returnsNormally);
      expect(() => PlantConfig.validateContainerSizeStrict(11.0), returnsNormally);
      expect(() => PlantConfig.validateContainerSizeStrict(1000.0), returnsNormally);
    });

    test('validateSystemSizeStrict() - should pass for null', () {
      expect(() => PlantConfig.validateSystemSizeStrict(null), returnsNormally);
    });

    test('validateSystemSizeStrict() - should throw for too small', () {
      expect(
        () => PlantConfig.validateSystemSizeStrict(0.5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PlantConfig.validateSystemSizeStrict(-10.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateSystemSizeStrict() - should throw for too large', () {
      expect(
        () => PlantConfig.validateSystemSizeStrict(10001.0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PlantConfig.validateSystemSizeStrict(99999.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateSystemSizeStrict() - should pass for valid values', () {
      expect(() => PlantConfig.validateSystemSizeStrict(1.0), returnsNormally);
      expect(() => PlantConfig.validateSystemSizeStrict(100.0), returnsNormally);
      expect(() => PlantConfig.validateSystemSizeStrict(10000.0), returnsNormally);
    });

    test('validateNotFuture() - should throw for future dates', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(
        () => PlantConfig.validateNotFuture(tomorrow, 'Seed date'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateNotFuture() - should pass for today', () {
      final today = DateTime.now();
      expect(
        () => PlantConfig.validateNotFuture(today, 'Seed date'),
        returnsNormally,
      );
    });

    test('validateNotFuture() - should pass for past dates', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        () => PlantConfig.validateNotFuture(yesterday, 'Seed date'),
        returnsNormally,
      );
    });

    test('validateNotFuture() - should pass for null', () {
      expect(
        () => PlantConfig.validateNotFuture(null, 'Seed date'),
        returnsNormally,
      );
    });
  });

  group('PlantConfig - Phase Date Chronology', () {
    test('validatePhaseChronology() - should pass for correct order', () {
      final seed = DateTime(2025, 1, 1);
      final veg = DateTime(2025, 1, 15);
      final bloom = DateTime(2025, 2, 1);
      final harvest = DateTime(2025, 4, 1);

      expect(
        () => PlantConfig.validatePhaseChronology(
          seedDate: seed,
          vegDate: veg,
          bloomDate: bloom,
          harvestDate: harvest,
        ),
        returnsNormally,
      );
    });

    test('validatePhaseChronology() - should throw when veg before seed', () {
      final seed = DateTime(2025, 1, 15);
      final veg = DateTime(2025, 1, 1);

      expect(
        () => PlantConfig.validatePhaseChronology(seedDate: seed, vegDate: veg),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validatePhaseChronology() - should throw when bloom before seed', () {
      final seed = DateTime(2025, 2, 1);
      final bloom = DateTime(2025, 1, 1);

      expect(
        () => PlantConfig.validatePhaseChronology(seedDate: seed, bloomDate: bloom),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validatePhaseChronology() - should throw when harvest before seed', () {
      final seed = DateTime(2025, 4, 1);
      final harvest = DateTime(2025, 1, 1);

      expect(
        () => PlantConfig.validatePhaseChronology(seedDate: seed, harvestDate: harvest),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validatePhaseChronology() - should throw when bloom before veg', () {
      final veg = DateTime(2025, 2, 1);
      final bloom = DateTime(2025, 1, 15);

      expect(
        () => PlantConfig.validatePhaseChronology(vegDate: veg, bloomDate: bloom),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validatePhaseChronology() - should throw when harvest before bloom', () {
      final bloom = DateTime(2025, 3, 1);
      final harvest = DateTime(2025, 2, 1);

      expect(
        () => PlantConfig.validatePhaseChronology(bloomDate: bloom, harvestDate: harvest),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validatePhaseChronology() - should throw when harvest before veg', () {
      final veg = DateTime(2025, 2, 1);
      final harvest = DateTime(2025, 1, 15);

      expect(
        () => PlantConfig.validatePhaseChronology(vegDate: veg, harvestDate: harvest),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validatePhaseChronology() - should allow same dates', () {
      final date = DateTime(2025, 1, 1);

      expect(
        () => PlantConfig.validatePhaseChronology(
          seedDate: date,
          vegDate: date,
          bloomDate: date,
          harvestDate: date,
        ),
        returnsNormally,
      );
    });

    test('validatePhaseChronology() - should pass with nulls', () {
      expect(
        () => PlantConfig.validatePhaseChronology(
          seedDate: null,
          vegDate: null,
          bloomDate: null,
          harvestDate: null,
        ),
        returnsNormally,
      );
    });

    test('validatePhaseChronology() - should pass with partial dates', () {
      final seed = DateTime(2025, 1, 1);
      final bloom = DateTime(2025, 2, 1);

      expect(
        () => PlantConfig.validatePhaseChronology(
          seedDate: seed,
          vegDate: null,
          bloomDate: bloom,
          harvestDate: null,
        ),
        returnsNormally,
      );
    });
  });
}
