// =============================================
// GROWLOG - SettingsRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growlog_app/repositories/settings_repository.dart';
import 'package:growlog_app/models/app_settings.dart';

void main() {
  late SettingsRepository repository;

  setUp(() {
    // Initialize SharedPreferences with empty values
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepository();
  });

  group('SettingsRepository - Get/Set Operations', () {
    test('getSettings() - should return default settings initially', () async {
      // Act
      final settings = await repository.getSettings();

      // Assert - Default values
      expect(settings.language, equals('de'));
      expect(settings.isDarkMode, isFalse);
      expect(settings.isExpertMode, isFalse);
      expect(settings.nutrientUnit, equals(NutrientUnit.ec));
      expect(settings.ppmScale, equals(PpmScale.scale700));
      expect(settings.temperatureUnit, equals(TemperatureUnit.celsius));
      expect(settings.lengthUnit, equals(LengthUnit.cm));
      expect(settings.volumeUnit, equals(VolumeUnit.liter));
    });

    test('setLanguage() - should save and retrieve language', () async {
      // Act
      await repository.setLanguage('en');
      final settings = await repository.getSettings();

      // Assert
      expect(settings.language, equals('en'));
    });

    test('setDarkMode() - should save and retrieve dark mode', () async {
      // Act
      await repository.setDarkMode(true);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.isDarkMode, isTrue);
    });

    test('setExpertMode() - should save and retrieve expert mode', () async {
      // Act
      await repository.setExpertMode(true);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.isExpertMode, isTrue);
    });

    test(
      'setNutrientUnit() - should save and retrieve nutrient unit',
      () async {
        // Act
        await repository.setNutrientUnit(NutrientUnit.ppm);
        final settings = await repository.getSettings();

        // Assert
        expect(settings.nutrientUnit, equals(NutrientUnit.ppm));
      },
    );

    test('setPpmScale() - should save and retrieve PPM scale', () async {
      // Act
      await repository.setPpmScale(PpmScale.scale500);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.ppmScale, equals(PpmScale.scale500));
    });

    test(
      'setTemperatureUnit() - should save and retrieve temperature unit',
      () async {
        // Act
        await repository.setTemperatureUnit(TemperatureUnit.fahrenheit);
        final settings = await repository.getSettings();

        // Assert
        expect(settings.temperatureUnit, equals(TemperatureUnit.fahrenheit));
      },
    );

    test('setLengthUnit() - should save and retrieve length unit', () async {
      // Act
      await repository.setLengthUnit(LengthUnit.inch);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.lengthUnit, equals(LengthUnit.inch));
    });

    test('setVolumeUnit() - should save and retrieve volume unit', () async {
      // Act
      await repository.setVolumeUnit(VolumeUnit.gallon);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.volumeUnit, equals(VolumeUnit.gallon));
    });
  });

  group('SettingsRepository - Bulk Operations', () {
    test('saveSettings() - should save all settings at once', () async {
      // Arrange
      final settings = AppSettings(
        language: 'en',
        isDarkMode: true,
        isExpertMode: true,
        nutrientUnit: NutrientUnit.ppm,
        ppmScale: PpmScale.scale640,
        temperatureUnit: TemperatureUnit.fahrenheit,
        lengthUnit: LengthUnit.inch,
        volumeUnit: VolumeUnit.gallon,
      );

      // Act
      await repository.saveSettings(settings);
      final retrieved = await repository.getSettings();

      // Assert
      expect(retrieved.language, equals('en'));
      expect(retrieved.isDarkMode, isTrue);
      expect(retrieved.isExpertMode, isTrue);
      expect(retrieved.nutrientUnit, equals(NutrientUnit.ppm));
      expect(retrieved.ppmScale, equals(PpmScale.scale640));
      expect(retrieved.temperatureUnit, equals(TemperatureUnit.fahrenheit));
      expect(retrieved.lengthUnit, equals(LengthUnit.inch));
      expect(retrieved.volumeUnit, equals(VolumeUnit.gallon));
    });

    test('saveSettings() - should overwrite existing settings', () async {
      // Arrange - Save initial settings
      final initial = AppSettings(
        language: 'en',
        isDarkMode: true,
        isExpertMode: false,
        nutrientUnit: NutrientUnit.ppm,
        ppmScale: PpmScale.scale500,
        temperatureUnit: TemperatureUnit.fahrenheit,
        lengthUnit: LengthUnit.inch,
        volumeUnit: VolumeUnit.gallon,
      );
      await repository.saveSettings(initial);

      // Act - Update with new settings
      final updated = AppSettings(
        language: 'de',
        isDarkMode: false,
        isExpertMode: true,
        nutrientUnit: NutrientUnit.ec,
        ppmScale: PpmScale.scale700,
        temperatureUnit: TemperatureUnit.celsius,
        lengthUnit: LengthUnit.cm,
        volumeUnit: VolumeUnit.liter,
      );
      await repository.saveSettings(updated);
      final retrieved = await repository.getSettings();

      // Assert - Should have new values
      expect(retrieved.language, equals('de'));
      expect(retrieved.isDarkMode, isFalse);
      expect(retrieved.isExpertMode, isTrue);
      expect(retrieved.nutrientUnit, equals(NutrientUnit.ec));
      expect(retrieved.ppmScale, equals(PpmScale.scale700));
      expect(retrieved.temperatureUnit, equals(TemperatureUnit.celsius));
      expect(retrieved.lengthUnit, equals(LengthUnit.cm));
      expect(retrieved.volumeUnit, equals(VolumeUnit.liter));
    });
  });

  group('SettingsRepository - Edge Cases', () {
    test('getSettings() - should handle all nutrient unit values', () async {
      // Test all nutrient unit values
      for (final unit in NutrientUnit.values) {
        await repository.setNutrientUnit(unit);
        final settings = await repository.getSettings();
        expect(settings.nutrientUnit, equals(unit));
      }
    });

    test('getSettings() - should handle all PPM scale values', () async {
      // Test all PPM scale values
      for (final scale in PpmScale.values) {
        await repository.setPpmScale(scale);
        final settings = await repository.getSettings();
        expect(settings.ppmScale, equals(scale));
      }
    });

    test('getSettings() - should handle all temperature unit values', () async {
      // Test all temperature unit values
      for (final unit in TemperatureUnit.values) {
        await repository.setTemperatureUnit(unit);
        final settings = await repository.getSettings();
        expect(settings.temperatureUnit, equals(unit));
      }
    });

    test('getSettings() - should handle all length unit values', () async {
      // Test all length unit values
      for (final unit in LengthUnit.values) {
        await repository.setLengthUnit(unit);
        final settings = await repository.getSettings();
        expect(settings.lengthUnit, equals(unit));
      }
    });

    test('getSettings() - should handle all volume unit values', () async {
      // Test all volume unit values
      for (final unit in VolumeUnit.values) {
        await repository.setVolumeUnit(unit);
        final settings = await repository.getSettings();
        expect(settings.volumeUnit, equals(unit));
      }
    });

    test(
      'getSettings() - should handle multiple updates to same setting',
      () async {
        // Act - Multiple updates
        await repository.setLanguage('en');
        await repository.setLanguage('de');
        await repository.setLanguage('fr');
        final settings = await repository.getSettings();

        // Assert - Should have latest value
        expect(settings.language, equals('fr'));
      },
    );

    test(
      'getSettings() - should persist across repository instances',
      () async {
        // Arrange - Save with first instance
        await repository.setLanguage('en');
        await repository.setDarkMode(true);

        // Act - Create new instance and retrieve
        final newRepository = SettingsRepository();
        final settings = await newRepository.getSettings();

        // Assert - Should have persisted values
        expect(settings.language, equals('en'));
        expect(settings.isDarkMode, isTrue);
      },
    );
  });

  group('SettingsRepository - Partial Updates', () {
    test('should allow updating individual settings independently', () async {
      // Arrange - Set initial complete settings
      final initial = AppSettings(
        language: 'de',
        isDarkMode: false,
        isExpertMode: false,
        nutrientUnit: NutrientUnit.ec,
        ppmScale: PpmScale.scale700,
        temperatureUnit: TemperatureUnit.celsius,
        lengthUnit: LengthUnit.cm,
        volumeUnit: VolumeUnit.liter,
      );
      await repository.saveSettings(initial);

      // Act - Update only language
      await repository.setLanguage('en');
      var settings = await repository.getSettings();

      // Assert - Language changed, others unchanged
      expect(settings.language, equals('en'));
      expect(settings.isDarkMode, isFalse);
      expect(settings.nutrientUnit, equals(NutrientUnit.ec));

      // Act - Update only dark mode
      await repository.setDarkMode(true);
      settings = await repository.getSettings();

      // Assert - Dark mode changed, others unchanged
      expect(settings.language, equals('en')); // Still 'en' from before
      expect(settings.isDarkMode, isTrue);
      expect(settings.nutrientUnit, equals(NutrientUnit.ec));
    });
  });
}
