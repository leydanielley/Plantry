// =============================================
// GROWLOG - RdwcSystem Validation Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/rdwc_system.dart';

void main() {
  group('RdwcSystem - Constructor Validation', () {
    test('should clamp negative maxCapacity to default', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: -100.0,
        currentLevel: 50.0,
        bucketCount: 4,
      );

      expect(system.maxCapacity, equals(100.0)); // Default
    });

    test('should clamp too large maxCapacity', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 99999.0,
        currentLevel: 50.0,
        bucketCount: 4,
      );

      expect(system.maxCapacity, equals(10000.0)); // Maximum
    });

    test('should clamp negative currentLevel to 0', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: -50.0,
        bucketCount: 4,
      );

      expect(system.currentLevel, equals(0.0));
    });

    test('should clamp currentLevel exceeding maxCapacity', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 150.0,
        bucketCount: 4,
      );

      expect(system.currentLevel, equals(100.0)); // Clamped to maxCapacity
    });

    test('should clamp negative bucketCount to default', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: -5,
      );

      expect(system.bucketCount, equals(4)); // Default
    });

    test('should clamp zero bucketCount to default', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 0,
      );

      expect(system.bucketCount, equals(4)); // Default
    });

    test('should clamp too large bucketCount', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 999,
      );

      expect(system.bucketCount, equals(50)); // Maximum
    });

    test('should use default name for empty string', () {
      final system = RdwcSystem(
        name: '',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
      );

      expect(system.name, equals('Unnamed System'));
    });

    test('should use default name for whitespace', () {
      final system = RdwcSystem(
        name: '   ',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
      );

      expect(system.name, equals('Unnamed System'));
    });

    test('should trim whitespace from name', () {
      final system = RdwcSystem(
        name: '  Test System  ',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
      );

      expect(system.name, equals('Test System'));
    });

    test('should clamp negative pumpWattage to 0', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        pumpWattage: -100,
      );

      expect(system.pumpWattage, equals(0));
    });

    test('should clamp too large pumpWattage', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        pumpWattage: 99999,
      );

      expect(system.pumpWattage, equals(5000)); // Maximum
    });

    test('should allow null pumpWattage', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        pumpWattage: null,
      );

      expect(system.pumpWattage, isNull);
    });

    test('should clamp negative pumpFlowRate to 0', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        pumpFlowRate: -100.0,
      );

      expect(system.pumpFlowRate, equals(0.0));
    });

    test('should clamp too large pumpFlowRate', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        pumpFlowRate: 99999.0,
      );

      expect(system.pumpFlowRate, equals(10000.0)); // Maximum
    });

    test('should clamp negative airPumpWattage to 0', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        airPumpWattage: -50,
      );

      expect(system.airPumpWattage, equals(0));
    });

    test('should clamp negative chillerWattage to 0', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        chillerWattage: -200,
      );

      expect(system.chillerWattage, equals(0));
    });

    test('should clamp negative chillerCoolingPower to 0', () {
      final system = RdwcSystem(
        name: 'Test System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        chillerCoolingPower: -500,
      );

      expect(system.chillerCoolingPower, equals(0));
    });
  });

  group('RdwcSystem - Valid Values', () {
    test('should accept all valid values', () {
      final system = RdwcSystem(
        name: 'Premium System',
        roomId: 1,
        growId: 2,
        maxCapacity: 500.0,
        currentLevel: 450.0,
        bucketCount: 10,
        description: 'Test description',
        pumpBrand: 'Hailea',
        pumpModel: 'HX-6550',
        pumpWattage: 55,
        pumpFlowRate: 3500.0,
        airPumpBrand: 'Eheim',
        airPumpModel: 'Air400',
        airPumpWattage: 8,
        airPumpFlowRate: 400.0,
        chillerBrand: 'Teco',
        chillerModel: 'TK-500',
        chillerWattage: 200,
        chillerCoolingPower: 450,
        accessories: 'UV Sterilizer, pH Controller',
        archived: false,
      );

      expect(system.name, equals('Premium System'));
      expect(system.roomId, equals(1));
      expect(system.growId, equals(2));
      expect(system.maxCapacity, equals(500.0));
      expect(system.currentLevel, equals(450.0));
      expect(system.bucketCount, equals(10));
      expect(system.description, equals('Test description'));
      expect(system.pumpBrand, equals('Hailea'));
      expect(system.pumpModel, equals('HX-6550'));
      expect(system.pumpWattage, equals(55));
      expect(system.pumpFlowRate, equals(3500.0));
      expect(system.airPumpBrand, equals('Eheim'));
      expect(system.airPumpModel, equals('Air400'));
      expect(system.airPumpWattage, equals(8));
      expect(system.airPumpFlowRate, equals(400.0));
      expect(system.chillerBrand, equals('Teco'));
      expect(system.chillerModel, equals('TK-500'));
      expect(system.chillerWattage, equals(200));
      expect(system.chillerCoolingPower, equals(450));
      expect(system.accessories, equals('UV Sterilizer, pH Controller'));
      expect(system.archived, isFalse);
    });

    test('should accept minimal valid system', () {
      final system = RdwcSystem(
        name: 'AB', // Minimum 2 chars for strict validation
        maxCapacity: 10.0,
        currentLevel: 5.0,
        bucketCount: 1,
      );

      expect(system.name, equals('AB'));
      expect(system.maxCapacity, equals(10.0));
      expect(system.currentLevel, equals(5.0));
      expect(system.bucketCount, equals(1));
      expect(system.roomId, isNull);
      expect(system.growId, isNull);
      expect(system.description, isNull);
      expect(system.pumpWattage, isNull);
      expect(system.archived, isFalse);
    });

    test('should accept boundary values', () {
      final system = RdwcSystem(
        name: 'Boundary Test',
        maxCapacity: 10000.0, // Maximum
        currentLevel: 10000.0,
        bucketCount: 50, // Maximum
        pumpWattage: 5000, // Maximum
        pumpFlowRate: 10000.0, // Maximum
      );

      expect(system.maxCapacity, equals(10000.0));
      expect(system.currentLevel, equals(10000.0));
      expect(system.bucketCount, equals(50));
      expect(system.pumpWattage, equals(5000));
      expect(system.pumpFlowRate, equals(10000.0));
    });
  });

  group('RdwcSystem - Calculated Properties', () {
    test('fillPercentage - should calculate correctly', () {
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 75.0,
        bucketCount: 4,
      );

      expect(system.fillPercentage, equals(75.0));
    });

    test('remainingCapacity - should calculate correctly', () {
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 30.0,
        bucketCount: 4,
      );

      expect(system.remainingCapacity, equals(70.0));
    });

    test('isLowWater - should be true below 30%', () {
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 29.0, // 29%
        bucketCount: 4,
      );

      expect(system.isLowWater, isTrue);
    });

    test('isLowWater - should be false at 30% or above', () {
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 30.0, // 30%
        bucketCount: 4,
      );

      expect(system.isLowWater, isFalse);
    });

    test('isCriticallyLow - should be true below 15%', () {
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 14.0, // 14%
        bucketCount: 4,
      );

      expect(system.isCriticallyLow, isTrue);
    });

    test('isFull - should be true at 95% or above', () {
      final system = RdwcSystem(
        name: 'Test',
        maxCapacity: 100.0,
        currentLevel: 95.0, // 95%
        bucketCount: 4,
      );

      expect(system.isFull, isTrue);
    });
  });

  group('RdwcSystem - Edge Cases', () {
    test('should handle zero currentLevel', () {
      final system = RdwcSystem(
        name: 'Empty System',
        maxCapacity: 100.0,
        currentLevel: 0.0,
        bucketCount: 4,
      );

      expect(system.currentLevel, equals(0.0));
      expect(system.fillPercentage, equals(0.0));
      expect(system.remainingCapacity, equals(100.0));
      expect(system.isCriticallyLow, isTrue);
    });

    test('should handle full system', () {
      final system = RdwcSystem(
        name: 'Full System',
        maxCapacity: 100.0,
        currentLevel: 100.0,
        bucketCount: 4,
      );

      expect(system.currentLevel, equals(100.0));
      expect(system.fillPercentage, equals(100.0));
      expect(system.remainingCapacity, equals(0.0));
      expect(system.isFull, isTrue);
    });

    test('should handle decimal precision', () {
      final system = RdwcSystem(
        name: 'Precise System',
        maxCapacity: 123.456,
        currentLevel: 67.89,
        bucketCount: 7,
        pumpFlowRate: 3456.78,
      );

      expect(system.maxCapacity, equals(123.456));
      expect(system.currentLevel, equals(67.89));
      expect(system.pumpFlowRate, equals(3456.78));
    });

    test('should handle archived system', () {
      final system = RdwcSystem(
        name: 'Archived System',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
        archived: true,
      );

      expect(system.archived, isTrue);
    });

    test('copyWith should preserve validation', () {
      final original = RdwcSystem(
        name: 'Original',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
      );

      // Try to set invalid values via copyWith - they should be validated
      final updated = original.copyWith(
        maxCapacity: 99999.0, // Should be clamped
        currentLevel: -10.0, // Should be clamped
        bucketCount: 999, // Should be clamped
      );

      expect(updated.maxCapacity, equals(10000.0)); // Clamped to max
      expect(updated.currentLevel, equals(0.0)); // Clamped to min
      expect(updated.bucketCount, equals(50)); // Clamped to max
    });
  });
}
