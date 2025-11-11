// =============================================
// GROWLOG - HarvestConfig Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/config/harvest_config.dart';

void main() {
  group('HarvestConfig - Weight Validation', () {
    test('validateWeight() - should return null for null', () {
      expect(HarvestConfig.validateWeight(null), isNull);
    });

    test('validateWeight() - should clamp to minimum (0.1)', () {
      expect(HarvestConfig.validateWeight(-10.0), equals(0.1));
      expect(HarvestConfig.validateWeight(0.0), equals(0.1));
      expect(HarvestConfig.validateWeight(0.05), equals(0.1));
    });

    test('validateWeight() - should clamp to maximum (10000)', () {
      expect(HarvestConfig.validateWeight(15000.0), equals(10000.0));
      expect(HarvestConfig.validateWeight(99999.0), equals(10000.0));
    });

    test('validateWeight() - should allow valid values', () {
      expect(HarvestConfig.validateWeight(0.1), equals(0.1));
      expect(HarvestConfig.validateWeight(100.0), equals(100.0));
      expect(HarvestConfig.validateWeight(10000.0), equals(10000.0));
    });
  });

  group('HarvestConfig - Temperature Validation', () {
    test('validateDryingTemperature() - should return null for null', () {
      expect(HarvestConfig.validateDryingTemperature(null), isNull);
    });

    test('validateDryingTemperature() - should clamp to minimum (10)', () {
      expect(HarvestConfig.validateDryingTemperature(5.0), equals(10.0));
      expect(HarvestConfig.validateDryingTemperature(-10.0), equals(10.0));
    });

    test('validateDryingTemperature() - should clamp to maximum (35)', () {
      expect(HarvestConfig.validateDryingTemperature(40.0), equals(35.0));
      expect(HarvestConfig.validateDryingTemperature(100.0), equals(35.0));
    });

    test('validateDryingTemperature() - should allow valid values', () {
      expect(HarvestConfig.validateDryingTemperature(10.0), equals(10.0));
      expect(HarvestConfig.validateDryingTemperature(20.0), equals(20.0));
      expect(HarvestConfig.validateDryingTemperature(35.0), equals(35.0));
    });
  });

  group('HarvestConfig - Humidity Validation', () {
    test('validateHumidity() - should return null for null', () {
      expect(HarvestConfig.validateHumidity(null), isNull);
    });

    test('validateHumidity() - should clamp to minimum (0)', () {
      expect(HarvestConfig.validateHumidity(-10.0), equals(0.0));
      expect(HarvestConfig.validateHumidity(-1.0), equals(0.0));
    });

    test('validateHumidity() - should clamp to maximum (100)', () {
      expect(HarvestConfig.validateHumidity(150.0), equals(100.0));
      expect(HarvestConfig.validateHumidity(999.0), equals(100.0));
    });

    test('validateHumidity() - should allow valid values', () {
      expect(HarvestConfig.validateHumidity(0.0), equals(0.0));
      expect(HarvestConfig.validateHumidity(50.0), equals(50.0));
      expect(HarvestConfig.validateHumidity(100.0), equals(100.0));
    });
  });

  group('HarvestConfig - Percentage Validation', () {
    test('validatePercentage() - should return null for null', () {
      expect(HarvestConfig.validatePercentage(null), isNull);
    });

    test('validatePercentage() - should clamp to minimum (0)', () {
      expect(HarvestConfig.validatePercentage(-10.0), equals(0.0));
      expect(HarvestConfig.validatePercentage(-1.0), equals(0.0));
    });

    test('validatePercentage() - should clamp to maximum (100)', () {
      expect(HarvestConfig.validatePercentage(150.0), equals(100.0));
      expect(HarvestConfig.validatePercentage(999.0), equals(100.0));
    });

    test('validatePercentage() - should allow valid values', () {
      expect(HarvestConfig.validatePercentage(0.0), equals(0.0));
      expect(HarvestConfig.validatePercentage(25.5), equals(25.5));
      expect(HarvestConfig.validatePercentage(100.0), equals(100.0));
    });
  });

  group('HarvestConfig - Rating Validation', () {
    test('validateRating() - should return null for null', () {
      expect(HarvestConfig.validateRating(null), isNull);
    });

    test('validateRating() - should clamp to minimum (1)', () {
      expect(HarvestConfig.validateRating(0), equals(1));
      expect(HarvestConfig.validateRating(-5), equals(1));
    });

    test('validateRating() - should clamp to maximum (5)', () {
      expect(HarvestConfig.validateRating(6), equals(5));
      expect(HarvestConfig.validateRating(10), equals(5));
    });

    test('validateRating() - should allow valid values', () {
      expect(HarvestConfig.validateRating(1), equals(1));
      expect(HarvestConfig.validateRating(3), equals(3));
      expect(HarvestConfig.validateRating(5), equals(5));
    });
  });

  group('HarvestConfig - Days Validation', () {
    test('validateDryingDays() - should return null for null', () {
      expect(HarvestConfig.validateDryingDays(null), isNull);
    });

    test('validateDryingDays() - should clamp to minimum (0)', () {
      expect(HarvestConfig.validateDryingDays(-5), equals(0));
      expect(HarvestConfig.validateDryingDays(-1), equals(0));
    });

    test('validateDryingDays() - should clamp to maximum (60)', () {
      expect(HarvestConfig.validateDryingDays(100), equals(60));
      expect(HarvestConfig.validateDryingDays(999), equals(60));
    });

    test('validateCuringDays() - should clamp to maximum (365)', () {
      expect(HarvestConfig.validateCuringDays(500), equals(365));
      expect(HarvestConfig.validateCuringDays(999), equals(365));
    });
  });

  group('HarvestConfig - Strict Validation', () {
    test('validateWeightStrict() - should throw for too small', () {
      expect(
        () => HarvestConfig.validateWeightStrict(0.05, 'Weight'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateWeightStrict() - should throw for too large', () {
      expect(
        () => HarvestConfig.validateWeightStrict(15000.0, 'Weight'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateWeightLogic() - should throw when dry > wet', () {
      expect(
        () => HarvestConfig.validateWeightLogic(100.0, 150.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateWeightLogic() - should pass when dry <= wet', () {
      expect(
        () => HarvestConfig.validateWeightLogic(100.0, 80.0),
        returnsNormally,
      );
    });

    test('validateRatingStrict() - should throw for invalid', () {
      expect(
        () => HarvestConfig.validateRatingStrict(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => HarvestConfig.validateRatingStrict(6),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('HarvestConfig - Date Chronology', () {
    test('validateHarvestChronology() - should pass for correct order', () {
      final harvest = DateTime(2025, 1, 1);
      final dryStart = DateTime(2025, 1, 2);
      final dryEnd = DateTime(2025, 1, 10);
      final cureStart = DateTime(2025, 1, 11);
      final cureEnd = DateTime(2025, 2, 1);

      expect(
        () => HarvestConfig.validateHarvestChronology(
          harvestDate: harvest,
          dryingStartDate: dryStart,
          dryingEndDate: dryEnd,
          curingStartDate: cureStart,
          curingEndDate: cureEnd,
        ),
        returnsNormally,
      );
    });

    test(
      'validateHarvestChronology() - should throw when dry start before harvest',
      () {
        final harvest = DateTime(2025, 1, 10);
        final dryStart = DateTime(2025, 1, 5);

        expect(
          () => HarvestConfig.validateHarvestChronology(
            harvestDate: harvest,
            dryingStartDate: dryStart,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'validateHarvestChronology() - should throw when dry end before dry start',
      () {
        final dryStart = DateTime(2025, 1, 10);
        final dryEnd = DateTime(2025, 1, 5);

        expect(
          () => HarvestConfig.validateHarvestChronology(
            dryingStartDate: dryStart,
            dryingEndDate: dryEnd,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'validateHarvestChronology() - should throw when cure start before dry end',
      () {
        final dryEnd = DateTime(2025, 1, 20);
        final cureStart = DateTime(2025, 1, 15);

        expect(
          () => HarvestConfig.validateHarvestChronology(
            dryingEndDate: dryEnd,
            curingStartDate: cureStart,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });
}
