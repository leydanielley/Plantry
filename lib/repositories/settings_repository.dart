// =============================================
// GROWLOG - Settings Repository
// =============================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class SettingsRepository
    with RepositoryErrorHandler
    implements ISettingsRepository {
  @override
  String get repositoryName => 'SettingsRepository';

  static const String _keyLanguage = 'language';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyExpertMode = 'expert_mode';
  static const String _keyNutrientUnit = 'nutrient_unit';
  static const String _keyPpmScale = 'ppm_scale';
  static const String _keyTemperatureUnit = 'temperature_unit';
  static const String _keyLengthUnit = 'length_unit';
  static const String _keyVolumeUnit = 'volume_unit';

  /// Einstellungen laden (mit Fehlerbehandlung für korrupte Daten)
  @override
  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Safe enum parsing mit Fallback auf Defaults
    NutrientUnit nutrientUnit = NutrientUnit.ec;
    try {
      final value = prefs.getString(_keyNutrientUnit);
      if (value != null) {
        nutrientUnit = NutrientUnit.values.firstWhere(
          (e) => e.name == value,
          orElse: () => NutrientUnit.ec,
        );
      }
    } catch (e) {
      // Fallback zu Default bei Fehler
    }

    PpmScale ppmScale = PpmScale.scale700;
    try {
      final value = prefs.getString(_keyPpmScale);
      if (value != null) {
        ppmScale = PpmScale.values.firstWhere(
          (e) => e.name == value,
          orElse: () => PpmScale.scale700,
        );
      }
    } catch (e) {
      // Fallback zu Default bei Fehler
    }

    TemperatureUnit temperatureUnit = TemperatureUnit.celsius;
    try {
      final value = prefs.getString(_keyTemperatureUnit);
      if (value != null) {
        temperatureUnit = TemperatureUnit.values.firstWhere(
          (e) => e.name == value,
          orElse: () => TemperatureUnit.celsius,
        );
      }
    } catch (e) {
      // Fallback zu Default bei Fehler
    }

    LengthUnit lengthUnit = LengthUnit.cm;
    try {
      final value = prefs.getString(_keyLengthUnit);
      if (value != null) {
        lengthUnit = LengthUnit.values.firstWhere(
          (e) => e.name == value,
          orElse: () => LengthUnit.cm,
        );
      }
    } catch (e) {
      // Fallback zu Default bei Fehler
    }

    VolumeUnit volumeUnit = VolumeUnit.liter;
    try {
      final value = prefs.getString(_keyVolumeUnit);
      if (value != null) {
        volumeUnit = VolumeUnit.values.firstWhere(
          (e) => e.name == value,
          orElse: () => VolumeUnit.liter,
        );
      }
    } catch (e) {
      // Fallback zu Default bei Fehler
    }

    return AppSettings(
      language: prefs.getString(_keyLanguage) ?? 'de',
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
      isExpertMode: prefs.getBool(_keyExpertMode) ?? false,
      nutrientUnit: nutrientUnit,
      ppmScale: ppmScale,
      temperatureUnit: temperatureUnit,
      lengthUnit: lengthUnit,
      volumeUnit: volumeUnit,
    );
  }

  /// Sprache speichern
  @override
  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }

  /// Dark Mode speichern
  @override
  Future<void> setDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDarkMode);
  }

  /// Expert Mode speichern
  @override
  Future<void> setExpertMode(bool isExpertMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyExpertMode, isExpertMode);
  }

  /// Nutrient Unit speichern
  @override
  Future<void> setNutrientUnit(NutrientUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNutrientUnit, unit.name);
  }

  /// PPM Scale speichern
  @override
  Future<void> setPpmScale(PpmScale scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPpmScale, scale.name);
  }

  /// Temperature Unit speichern
  @override
  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTemperatureUnit, unit.name);
  }

  /// Length Unit speichern
  @override
  Future<void> setLengthUnit(LengthUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLengthUnit, unit.name);
  }

  /// Volume Unit speichern
  @override
  Future<void> setVolumeUnit(VolumeUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVolumeUnit, unit.name);
  }

  /// Alle Einstellungen speichern
  @override
  Future<void> saveSettings(AppSettings settings) async {
    await setLanguage(settings.language);
    await setDarkMode(settings.isDarkMode);
    await setExpertMode(settings.isExpertMode);
    await setNutrientUnit(settings.nutrientUnit);
    await setPpmScale(settings.ppmScale);
    await setTemperatureUnit(settings.temperatureUnit);
    await setLengthUnit(settings.lengthUnit);
    await setVolumeUnit(settings.volumeUnit);
  }
}
