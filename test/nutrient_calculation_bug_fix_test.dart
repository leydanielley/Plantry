// Test for PPM calculation bug fix
// Bug: Small volume additions caused astronomical PPM values (70k+)
// Fix: Added minimum volume threshold and maximum PPM cap

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/nutrient_calculation.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/config/nutrient_calculation_config.dart';

void main() {
  group('Nutrient Calculation Bug Fix - 70k PPM Issue', () {
    late AppSettings settings;

    setUp(() {
      settings = AppSettings(
        language: 'en',
        isDarkMode: false,
        isExpertMode: false,
        nutrientUnit: NutrientUnit.ppm,
        ppmScale: PpmScale.scale500,
        temperatureUnit: TemperatureUnit.celsius,
        lengthUnit: LengthUnit.cm,
        volumeUnit: VolumeUnit.liter,
      );
    });

    test(
      'BUG SCENARIO: Very small volume (0.1L) should trigger volume too small error',
      () {
        // This was the bug: 0.1L addition causing 501,000 PPM calculation
        final calc = NutrientCalculation(
          currentVolume: 99.9,
          currentPPM: 1000,
          targetVolume: 100.0,
          targetPPM: 1500,
          settings: settings,
          calculatorMode: CalculatorMode.topUp,
        );

        // Volume to add is too small (with floating point tolerance)
        expect(calc.volumeToAdd, closeTo(0.1, 0.01));

        // Should detect volume is too small
        expect(calc.isVolumeTooSmall, isTrue);

        // Should be an error state
        expect(calc.warningLevel, equals(WarningLevel.error));

        // Required PPM should be capped at maximum safe value
        expect(
          calc.requiredPPM,
          lessThanOrEqualTo(NutrientCalculationConfig.maximumSafeRequiredPpm),
        );
      },
    );

    test(
      'BUG SCENARIO: Small volume (1.0L) with high PPM increase should trigger high PPM warning',
      () {
        // Another problematic scenario: 1L addition causing 51,000 PPM
        final calc = NutrientCalculation(
          currentVolume: 99.0,
          currentPPM: 1000,
          targetVolume: 100.0,
          targetPPM: 1500,
          settings: settings,
          calculatorMode: CalculatorMode.topUp,
        );

        // Volume to add is at minimum threshold
        expect(calc.volumeToAdd, equals(1.0));

        // Uncapped calculation would be: (1500*100 - 1000*99) / 1 = 51,000 PPM
        final uncappedPPM = (1500 * 100 - 1000 * 99) / 1;
        expect(uncappedPPM, equals(51000.0));

        // Should detect required PPM is too high
        expect(calc.isRequiredPpmTooHigh, isTrue);

        // Should be an error state
        expect(calc.warningLevel, equals(WarningLevel.error));

        // Required PPM should be capped at safe maximum (10,000)
        expect(
          calc.requiredPPM,
          equals(NutrientCalculationConfig.maximumSafeRequiredPpm),
        );
      },
    );

    test(
      'NORMAL SCENARIO: Reasonable volume addition with high PPM should work correctly',
      () {
        // Normal scenario: Adding 10L to go from 90L to 100L
        // Adjusted to keep required PPM below extreme threshold (5000)
        final calc = NutrientCalculation(
          currentVolume: 90.0,
          currentPPM: 1000,
          targetVolume: 100.0,
          targetPPM: 1400,
          settings: settings,
          calculatorMode: CalculatorMode.topUp,
        );

        // Volume to add is reasonable
        expect(calc.volumeToAdd, equals(10.0));

        // Should NOT trigger volume too small
        expect(calc.isVolumeTooSmall, isFalse);

        // Required PPM: (1400*100 - 1000*90) / 10 = (140000 - 90000) / 10 = 5000 PPM
        expect(calc.requiredPPM, equals(5000.0));

        // Should NOT trigger required PPM too high (5000 < 10000)
        expect(calc.isRequiredPpmTooHigh, isFalse);

        // At exactly 5000 PPM, should be a warning level (high PPM threshold)
        expect(calc.warningLevel, equals(WarningLevel.warning));
      },
    );

    test('SAFE SCENARIO: Small PPM increase with reasonable volume', () {
      // Safe scenario: Adding 10L with modest PPM increase
      final calc = NutrientCalculation(
        currentVolume: 90.0,
        currentPPM: 1000,
        targetVolume: 100.0,
        targetPPM: 1100,
        settings: settings,
        calculatorMode: CalculatorMode.topUp,
      );

      // Volume to add is reasonable
      expect(calc.volumeToAdd, equals(10.0));

      // Required PPM: (1100*100 - 1000*90) / 10 = (110000 - 90000) / 10 = 2000 PPM
      expect(calc.requiredPPM, equals(2000.0));

      // Should be safe
      expect(calc.isVolumeTooSmall, isFalse);
      expect(calc.isRequiredPpmTooHigh, isFalse);
      expect(calc.isHighPPM, isFalse);

      // Should be safe level
      expect(calc.warningLevel, equals(WarningLevel.safe));
    });

    test('Config constants are set correctly', () {
      expect(
        NutrientCalculationConfig.minimumPracticalVolumeToAdd,
        equals(1.0),
      );
      expect(NutrientCalculationConfig.maximumSafeRequiredPpm, equals(10000.0));
    });
  });
}
