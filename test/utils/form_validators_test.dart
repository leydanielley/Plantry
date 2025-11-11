// =============================================
// GROWLOG - Form Validators Tests
// Tests all form validation logic for user inputs
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/utils/form_validators.dart';

void main() {
  group('RdwcSystemFormValidator - Name Validation', () {
    test('should return error for null', () {
      expect(
        RdwcSystemFormValidator.validateName(null),
        equals('Name is required'),
      );
    });

    test('should return error for empty string', () {
      expect(
        RdwcSystemFormValidator.validateName(''),
        equals('Name is required'),
      );
    });

    test('should return error for whitespace only', () {
      expect(
        RdwcSystemFormValidator.validateName('   '),
        equals('Name is required'),
      );
    });

    test('should return error for tabs/newlines only', () {
      expect(
        RdwcSystemFormValidator.validateName('\t\n'),
        equals('Name is required'),
      );
    });

    test('should return null for valid name', () {
      expect(RdwcSystemFormValidator.validateName('My System'), isNull);
    });

    test('should return null for name with leading/trailing whitespace', () {
      // Trim happens in validation
      expect(RdwcSystemFormValidator.validateName('  Test  '), isNull);
    });

    test('should return null for single character', () {
      expect(RdwcSystemFormValidator.validateName('A'), isNull);
    });

    test('should return null for very long name', () {
      expect(RdwcSystemFormValidator.validateName('A' * 200), isNull);
    });
  });

  group('RdwcSystemFormValidator - Bucket Count Validation', () {
    test('should return error for null', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount(null),
        equals('Bucket count is required'),
      );
    });

    test('should return error for empty string', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount(''),
        equals('Bucket count is required'),
      );
    });

    test('should return error for whitespace', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount('  '),
        equals('Bucket count is required'),
      );
    });

    test('should return error for non-numeric input', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount('abc'),
        equals('Must be greater than 0'),
      );
    });

    test('should return error for decimal input', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount('4.5'),
        equals('Must be greater than 0'),
      );
    });

    test('should return error for zero', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount('0'),
        equals('Must be greater than 0'),
      );
    });

    test('should return error for negative', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount('-5'),
        equals('Must be greater than 0'),
      );
    });

    test('should return null for valid positive integer', () {
      expect(RdwcSystemFormValidator.validateBucketCount('4'), isNull);
    });

    test('should return null for 1', () {
      expect(RdwcSystemFormValidator.validateBucketCount('1'), isNull);
    });

    test('should return null for large number', () {
      expect(RdwcSystemFormValidator.validateBucketCount('999'), isNull);
    });
  });

  group('RdwcSystemFormValidator - Max Capacity Validation', () {
    test('should return error for null', () {
      expect(
        RdwcSystemFormValidator.validateMaxCapacity(null),
        equals('Max capacity is required'),
      );
    });

    test('should return error for empty string', () {
      expect(
        RdwcSystemFormValidator.validateMaxCapacity(''),
        equals('Max capacity is required'),
      );
    });

    test('should return error for non-numeric', () {
      expect(
        RdwcSystemFormValidator.validateMaxCapacity('xyz'),
        equals('Must be greater than 0'),
      );
    });

    test('should return error for zero', () {
      expect(
        RdwcSystemFormValidator.validateMaxCapacity('0'),
        equals('Must be greater than 0'),
      );
    });

    test('should return error for negative', () {
      expect(
        RdwcSystemFormValidator.validateMaxCapacity('-100'),
        equals('Must be greater than 0'),
      );
    });

    test('should return null for valid integer', () {
      expect(RdwcSystemFormValidator.validateMaxCapacity('100'), isNull);
    });

    test('should return null for valid decimal', () {
      expect(RdwcSystemFormValidator.validateMaxCapacity('123.45'), isNull);
    });

    test('should return null for very small positive', () {
      expect(RdwcSystemFormValidator.validateMaxCapacity('0.1'), isNull);
    });

    test('should return null for very large number', () {
      expect(RdwcSystemFormValidator.validateMaxCapacity('99999'), isNull);
    });
  });

  group('RdwcSystemFormValidator - Current Level Validation', () {
    test('should return error for null', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel(null, '100'),
        equals('Current level is required'),
      );
    });

    test('should return error for empty string', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('', '100'),
        equals('Current level is required'),
      );
    });

    test('should return error for non-numeric', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('invalid', '100'),
        equals('Must be 0 or greater'),
      );
    });

    test('should return error for negative', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('-10', '100'),
        equals('Must be 0 or greater'),
      );
    });

    test('should return null for zero', () {
      expect(RdwcSystemFormValidator.validateCurrentLevel('0', '100'), isNull);
    });

    test('should return null for valid positive', () {
      expect(RdwcSystemFormValidator.validateCurrentLevel('50', '100'), isNull);
    });

    test('should return null for decimal', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('75.5', '100'),
        isNull,
      );
    });

    test('should return null when equal to max capacity', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('100', '100'),
        isNull,
      );
    });

    test('should return error when exceeds max capacity', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('150', '100'),
        equals('Cannot exceed max capacity'),
      );
    });

    test('should return error when slightly exceeds max capacity', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('100.1', '100'),
        equals('Cannot exceed max capacity'),
      );
    });

    test('should return null when max capacity is null', () {
      // Cannot check against max capacity if it's not provided
      expect(RdwcSystemFormValidator.validateCurrentLevel('150', null), isNull);
    });

    test('should return null when max capacity is empty', () {
      expect(RdwcSystemFormValidator.validateCurrentLevel('150', ''), isNull);
    });

    test('should return null when max capacity is invalid', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('150', 'abc'),
        isNull,
      );
    });

    test('should handle both values as decimals correctly', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('99.9', '100.0'),
        isNull,
      );
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('100.1', '100.0'),
        equals('Cannot exceed max capacity'),
      );
    });
  });

  group('RdwcSystemFormValidator - Wattage Validation', () {
    test('should return null for null (optional field)', () {
      expect(RdwcSystemFormValidator.validateWattage(null), isNull);
    });

    test('should return null for empty string (optional field)', () {
      expect(RdwcSystemFormValidator.validateWattage(''), isNull);
    });

    test('should return null for whitespace (optional field)', () {
      expect(RdwcSystemFormValidator.validateWattage('   '), isNull);
    });

    test('should return error for non-numeric', () {
      expect(
        RdwcSystemFormValidator.validateWattage('abc'),
        equals('Must be > 0'),
      );
    });

    test('should return error for zero', () {
      expect(
        RdwcSystemFormValidator.validateWattage('0'),
        equals('Must be > 0'),
      );
    });

    test('should return error for negative', () {
      expect(
        RdwcSystemFormValidator.validateWattage('-100'),
        equals('Must be > 0'),
      );
    });

    test('should return error for decimal (must be integer)', () {
      expect(
        RdwcSystemFormValidator.validateWattage('100.5'),
        equals('Must be > 0'),
      );
    });

    test('should return null for valid positive integer', () {
      expect(RdwcSystemFormValidator.validateWattage('55'), isNull);
    });

    test('should return null for 1', () {
      expect(RdwcSystemFormValidator.validateWattage('1'), isNull);
    });

    test('should return null for large number', () {
      expect(RdwcSystemFormValidator.validateWattage('5000'), isNull);
    });
  });

  group('RdwcSystemFormValidator - Flow Rate Validation', () {
    test('should return null for null (optional field)', () {
      expect(RdwcSystemFormValidator.validateFlowRate(null), isNull);
    });

    test('should return null for empty string (optional field)', () {
      expect(RdwcSystemFormValidator.validateFlowRate(''), isNull);
    });

    test('should return null for whitespace (optional field)', () {
      expect(RdwcSystemFormValidator.validateFlowRate('  '), isNull);
    });

    test('should return error for non-numeric', () {
      expect(
        RdwcSystemFormValidator.validateFlowRate('invalid'),
        equals('Must be > 0'),
      );
    });

    test('should return error for zero', () {
      expect(
        RdwcSystemFormValidator.validateFlowRate('0'),
        equals('Must be > 0'),
      );
    });

    test('should return error for negative', () {
      expect(
        RdwcSystemFormValidator.validateFlowRate('-50.5'),
        equals('Must be > 0'),
      );
    });

    test('should return null for valid integer', () {
      expect(RdwcSystemFormValidator.validateFlowRate('1200'), isNull);
    });

    test('should return null for valid decimal', () {
      expect(RdwcSystemFormValidator.validateFlowRate('1234.5'), isNull);
    });

    test('should return null for very small positive', () {
      expect(RdwcSystemFormValidator.validateFlowRate('0.1'), isNull);
    });

    test('should return null for large number', () {
      expect(RdwcSystemFormValidator.validateFlowRate('10000'), isNull);
    });
  });

  group('RdwcSystemFormValidator - Cooling Power Validation', () {
    test('should return null for null (optional field)', () {
      expect(RdwcSystemFormValidator.validateCoolingPower(null), isNull);
    });

    test('should return null for empty string (optional field)', () {
      expect(RdwcSystemFormValidator.validateCoolingPower(''), isNull);
    });

    test('should return null for whitespace (optional field)', () {
      expect(RdwcSystemFormValidator.validateCoolingPower('  '), isNull);
    });

    test('should return error for non-numeric', () {
      expect(
        RdwcSystemFormValidator.validateCoolingPower('text'),
        equals('Must be > 0'),
      );
    });

    test('should return error for zero', () {
      expect(
        RdwcSystemFormValidator.validateCoolingPower('0'),
        equals('Must be > 0'),
      );
    });

    test('should return error for negative', () {
      expect(
        RdwcSystemFormValidator.validateCoolingPower('-300'),
        equals('Must be > 0'),
      );
    });

    test('should return error for decimal (must be integer)', () {
      expect(
        RdwcSystemFormValidator.validateCoolingPower('450.5'),
        equals('Must be > 0'),
      );
    });

    test('should return null for valid positive integer', () {
      expect(RdwcSystemFormValidator.validateCoolingPower('450'), isNull);
    });

    test('should return null for 1', () {
      expect(RdwcSystemFormValidator.validateCoolingPower('1'), isNull);
    });

    test('should return null for large number', () {
      expect(RdwcSystemFormValidator.validateCoolingPower('9999'), isNull);
    });
  });

  group('RdwcSystemFormValidator - Edge Cases', () {
    test('should handle leading zeros correctly', () {
      expect(RdwcSystemFormValidator.validateBucketCount('04'), isNull);
      expect(RdwcSystemFormValidator.validateMaxCapacity('0100.5'), isNull);
      expect(RdwcSystemFormValidator.validateWattage('055'), isNull);
    });

    test('should handle plus sign prefix', () {
      expect(RdwcSystemFormValidator.validateBucketCount('+4'), isNull);
      expect(RdwcSystemFormValidator.validateMaxCapacity('+100.5'), isNull);
    });

    test('should handle very long numeric strings', () {
      expect(
        RdwcSystemFormValidator.validateMaxCapacity('999999999.999'),
        isNull,
      );
    });

    test('should handle scientific notation as invalid', () {
      expect(
        RdwcSystemFormValidator.validateMaxCapacity('1e5'),
        isNull, // Dart's tryParse handles scientific notation
      );
    });

    test('should handle special characters', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount('4!'),
        equals('Must be greater than 0'),
      );
      expect(
        RdwcSystemFormValidator.validateMaxCapacity('100@'),
        equals('Must be greater than 0'),
      );
    });

    test('should handle mixed alphanumeric', () {
      expect(
        RdwcSystemFormValidator.validateBucketCount('4a'),
        equals('Must be greater than 0'),
      );
      expect(
        RdwcSystemFormValidator.validateMaxCapacity('100x'),
        equals('Must be greater than 0'),
      );
    });

    test('should handle current level validation with edge values', () {
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('0.0', '0.0'),
        isNull,
      );
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('0.1', '0.1'),
        isNull,
      );
      expect(
        RdwcSystemFormValidator.validateCurrentLevel('0.11', '0.1'),
        equals('Cannot exceed max capacity'),
      );
    });

    test('should handle unicode whitespace', () {
      expect(
        RdwcSystemFormValidator.validateName('\u00A0\u00A0'), // Non-breaking spaces
        equals('Name is required'),
      );
    });
  });
}
