// =============================================
// GROWLOG - RdwcSystemConfig Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/config/rdwc_system_config.dart';

void main() {
  group('RdwcSystemConfig - Soft Validation (Clamping)', () {
    test('validateCapacity() - should clamp to minimum', () {
      expect(RdwcSystemConfig.validateCapacity(-10), equals(100.0));
      expect(RdwcSystemConfig.validateCapacity(0), equals(100.0));
      expect(RdwcSystemConfig.validateCapacity(0.5), equals(100.0));
    });

    test('validateCapacity() - should clamp to maximum', () {
      expect(RdwcSystemConfig.validateCapacity(20000), equals(10000.0));
    });

    test('validateCapacity() - should allow valid values', () {
      expect(RdwcSystemConfig.validateCapacity(50), equals(50.0));
      expect(RdwcSystemConfig.validateCapacity(100), equals(100.0));
      expect(RdwcSystemConfig.validateCapacity(5000), equals(5000.0));
    });

    test('validateLevel() - should clamp to minimum (0)', () {
      expect(RdwcSystemConfig.validateLevel(-10, 100), equals(0.0));
      expect(RdwcSystemConfig.validateLevel(-1, 100), equals(0.0));
    });

    test('validateLevel() - should clamp to maxCapacity', () {
      expect(RdwcSystemConfig.validateLevel(150, 100), equals(100.0));
      expect(RdwcSystemConfig.validateLevel(200, 100), equals(100.0));
    });

    test('validateLevel() - should allow valid values', () {
      expect(RdwcSystemConfig.validateLevel(0, 100), equals(0.0));
      expect(RdwcSystemConfig.validateLevel(50, 100), equals(50.0));
      expect(RdwcSystemConfig.validateLevel(100, 100), equals(100.0));
    });

    test('validateBucketCount() - should clamp to minimum (1)', () {
      expect(RdwcSystemConfig.validateBucketCount(-5), equals(4));
      expect(RdwcSystemConfig.validateBucketCount(0), equals(4));
    });

    test('validateBucketCount() - should clamp to maximum (50)', () {
      expect(RdwcSystemConfig.validateBucketCount(100), equals(50));
      expect(RdwcSystemConfig.validateBucketCount(999), equals(50));
    });

    test('validateBucketCount() - should allow valid values', () {
      expect(RdwcSystemConfig.validateBucketCount(1), equals(1));
      expect(RdwcSystemConfig.validateBucketCount(4), equals(4));
      expect(RdwcSystemConfig.validateBucketCount(12), equals(12));
      expect(RdwcSystemConfig.validateBucketCount(50), equals(50));
    });

    test('validateName() - should return default for empty strings', () {
      expect(RdwcSystemConfig.validateName(''), equals('Unnamed System'));
      expect(RdwcSystemConfig.validateName('   '), equals('Unnamed System'));
    });

    test('validateName() - should trim whitespace', () {
      expect(RdwcSystemConfig.validateName('  Test  '), equals('Test'));
      expect(RdwcSystemConfig.validateName('\tTest\n'), equals('Test'));
    });

    test('validateName() - should keep valid names', () {
      expect(RdwcSystemConfig.validateName('My System'), equals('My System'));
      expect(RdwcSystemConfig.validateName('RDWC-1'), equals('RDWC-1'));
    });

    test('validateWattage() - should return null for null input', () {
      expect(RdwcSystemConfig.validateWattage(null), isNull);
    });

    test('validateWattage() - should clamp negative to 0', () {
      expect(RdwcSystemConfig.validateWattage(-100), equals(0));
      expect(RdwcSystemConfig.validateWattage(-1), equals(0));
    });

    test('validateWattage() - should clamp to maximum (5000)', () {
      expect(RdwcSystemConfig.validateWattage(10000), equals(5000));
      expect(RdwcSystemConfig.validateWattage(99999), equals(5000));
    });

    test('validateWattage() - should allow valid values', () {
      expect(RdwcSystemConfig.validateWattage(0), equals(0));
      expect(RdwcSystemConfig.validateWattage(100), equals(100));
      expect(RdwcSystemConfig.validateWattage(2500), equals(2500));
      expect(RdwcSystemConfig.validateWattage(5000), equals(5000));
    });

    test('validateFlowRate() - should return null for null input', () {
      expect(RdwcSystemConfig.validateFlowRate(null), isNull);
    });

    test('validateFlowRate() - should clamp negative to 0', () {
      expect(RdwcSystemConfig.validateFlowRate(-100.0), equals(0.0));
      expect(RdwcSystemConfig.validateFlowRate(-1.5), equals(0.0));
    });

    test('validateFlowRate() - should clamp to maximum (10000)', () {
      expect(RdwcSystemConfig.validateFlowRate(20000.0), equals(10000.0));
      expect(RdwcSystemConfig.validateFlowRate(99999.9), equals(10000.0));
    });

    test('validateFlowRate() - should allow valid values', () {
      expect(RdwcSystemConfig.validateFlowRate(0.0), equals(0.0));
      expect(RdwcSystemConfig.validateFlowRate(500.5), equals(500.5));
      expect(RdwcSystemConfig.validateFlowRate(5000.0), equals(5000.0));
      expect(RdwcSystemConfig.validateFlowRate(10000.0), equals(10000.0));
    });
  });

  group('RdwcSystemConfig - Strict Validation (Throws Errors)', () {
    test('validateCapacityStrict() - should throw for too small', () {
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(-10),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(0.5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateCapacityStrict() - should throw for too large', () {
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(15000),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(99999),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateCapacityStrict() - should pass for valid values', () {
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(1.0),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(100.0),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(10000.0),
        returnsNormally,
      );
    });

    test('validateBucketCountStrict() - should throw for invalid', () {
      expect(
        () => RdwcSystemConfig.validateBucketCountStrict(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateBucketCountStrict(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateBucketCountStrict(100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateBucketCountStrict() - should pass for valid values', () {
      expect(
        () => RdwcSystemConfig.validateBucketCountStrict(1),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateBucketCountStrict(4),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateBucketCountStrict(50),
        returnsNormally,
      );
    });

    test('validateLevelStrict() - should throw for negative', () {
      expect(
        () => RdwcSystemConfig.validateLevelStrict(-10, 100),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateLevelStrict(-0.1, 100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateLevelStrict() - should throw for exceeding capacity', () {
      expect(
        () => RdwcSystemConfig.validateLevelStrict(150, 100),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateLevelStrict(100.1, 100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateLevelStrict() - should pass for valid values', () {
      expect(
        () => RdwcSystemConfig.validateLevelStrict(0, 100),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateLevelStrict(50, 100),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateLevelStrict(100, 100),
        returnsNormally,
      );
    });

    test('validateNameStrict() - should throw for empty', () {
      expect(
        () => RdwcSystemConfig.validateNameStrict(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateNameStrict('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateNameStrict() - should throw for too short', () {
      expect(
        () => RdwcSystemConfig.validateNameStrict('A'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateNameStrict() - should throw for too long', () {
      final longName = 'A' * 101;
      expect(
        () => RdwcSystemConfig.validateNameStrict(longName),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateNameStrict() - should pass for valid names', () {
      expect(() => RdwcSystemConfig.validateNameStrict('AB'), returnsNormally);
      expect(
        () => RdwcSystemConfig.validateNameStrict('My System'),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateNameStrict('RDWC-1'),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateNameStrict('A' * 100),
        returnsNormally,
      );
    });

    test('validateWattageStrict() - should pass for null', () {
      expect(
        () => RdwcSystemConfig.validateWattageStrict(null),
        returnsNormally,
      );
    });

    test('validateWattageStrict() - should throw for negative', () {
      expect(
        () => RdwcSystemConfig.validateWattageStrict(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateWattageStrict(-100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateWattageStrict() - should throw for too large', () {
      expect(
        () => RdwcSystemConfig.validateWattageStrict(10000),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateWattageStrict() - should pass for valid values', () {
      expect(() => RdwcSystemConfig.validateWattageStrict(0), returnsNormally);
      expect(
        () => RdwcSystemConfig.validateWattageStrict(100),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateWattageStrict(5000),
        returnsNormally,
      );
    });

    test('validateFlowRateStrict() - should pass for null', () {
      expect(
        () => RdwcSystemConfig.validateFlowRateStrict(null),
        returnsNormally,
      );
    });

    test('validateFlowRateStrict() - should throw for negative', () {
      expect(
        () => RdwcSystemConfig.validateFlowRateStrict(-1.0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RdwcSystemConfig.validateFlowRateStrict(-100.5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateFlowRateStrict() - should throw for too large', () {
      expect(
        () => RdwcSystemConfig.validateFlowRateStrict(20000.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateFlowRateStrict() - should pass for valid values', () {
      expect(
        () => RdwcSystemConfig.validateFlowRateStrict(0.0),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateFlowRateStrict(500.5),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateFlowRateStrict(10000.0),
        returnsNormally,
      );
    });
  });

  group('RdwcSystemConfig - Water Level Checks', () {
    test('isLowWater() - should detect low water correctly', () {
      expect(RdwcSystemConfig.isLowWater(29.9), isTrue);
      expect(RdwcSystemConfig.isLowWater(25.0), isTrue);
      expect(RdwcSystemConfig.isLowWater(0.0), isTrue);
      expect(RdwcSystemConfig.isLowWater(30.0), isFalse);
      expect(RdwcSystemConfig.isLowWater(50.0), isFalse);
    });

    test('isCriticallyLow() - should detect critically low correctly', () {
      expect(RdwcSystemConfig.isCriticallyLow(14.9), isTrue);
      expect(RdwcSystemConfig.isCriticallyLow(10.0), isTrue);
      expect(RdwcSystemConfig.isCriticallyLow(0.0), isTrue);
      expect(RdwcSystemConfig.isCriticallyLow(15.0), isFalse);
      expect(RdwcSystemConfig.isCriticallyLow(30.0), isFalse);
    });

    test('isFull() - should detect full reservoir correctly', () {
      expect(RdwcSystemConfig.isFull(95.0), isTrue);
      expect(RdwcSystemConfig.isFull(96.0), isTrue);
      expect(RdwcSystemConfig.isFull(100.0), isTrue);
      expect(RdwcSystemConfig.isFull(94.9), isFalse);
      expect(RdwcSystemConfig.isFull(50.0), isFalse);
    });
  });

  group('RdwcSystemConfig - Edge Cases', () {
    test('should handle boundary values for capacity', () {
      // Exactly at boundaries
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(1.0),
        returnsNormally,
      );
      expect(
        () => RdwcSystemConfig.validateCapacityStrict(10000.0),
        returnsNormally,
      );
    });

    test('should handle decimal precision correctly', () {
      expect(RdwcSystemConfig.validateCapacity(99.999), equals(99.999));
      expect(RdwcSystemConfig.validateLevel(49.5, 100), equals(49.5));
      expect(RdwcSystemConfig.validateFlowRate(1234.567), equals(1234.567));
    });

    test('should handle very large invalid values', () {
      expect(RdwcSystemConfig.validateCapacity(1000000), equals(10000.0));
      expect(RdwcSystemConfig.validateWattage(999999), equals(5000));
    });

    test('should handle very small invalid values', () {
      expect(RdwcSystemConfig.validateCapacity(-999), equals(100.0));
      expect(RdwcSystemConfig.validateLevel(-999, 100), equals(0.0));
      expect(RdwcSystemConfig.validateWattage(-999), equals(0));
    });
  });
}
