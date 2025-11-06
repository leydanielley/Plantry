// =============================================
// GROWLOG - Settings Repository
// =============================================

import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  static const String _keyLanguage = 'language';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyExpertMode = 'expert_mode';
  static const String _keyNutrientUnit = 'nutrient_unit';
  static const String _keyPpmScale = 'ppm_scale';
  static const String _keyTemperatureUnit = 'temperature_unit';
  static const String _keyLengthUnit = 'length_unit';
  static const String _keyVolumeUnit = 'volume_unit';

  /// Einstellungen laden
  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSettings(
      language: prefs.getString(_keyLanguage) ?? 'de',
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
      isExpertMode: prefs.getBool(_keyExpertMode) ?? false,
      nutrientUnit: NutrientUnit.values.byName(
        prefs.getString(_keyNutrientUnit) ?? 'ec'
      ),
      ppmScale: PpmScale.values.byName(
        prefs.getString(_keyPpmScale) ?? 'scale700'
      ),
      temperatureUnit: TemperatureUnit.values.byName(
        prefs.getString(_keyTemperatureUnit) ?? 'celsius'
      ),
      lengthUnit: LengthUnit.values.byName(
        prefs.getString(_keyLengthUnit) ?? 'cm'
      ),
      volumeUnit: VolumeUnit.values.byName(
        prefs.getString(_keyVolumeUnit) ?? 'liter'
      ),
    );
  }

  /// Sprache speichern
  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }

  /// Dark Mode speichern
  Future<void> setDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDarkMode);
  }

  /// Expert Mode speichern
  Future<void> setExpertMode(bool isExpertMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyExpertMode, isExpertMode);
  }

  /// Nutrient Unit speichern
  Future<void> setNutrientUnit(NutrientUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNutrientUnit, unit.name);
  }

  /// PPM Scale speichern
  Future<void> setPpmScale(PpmScale scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPpmScale, scale.name);
  }

  /// Temperature Unit speichern
  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTemperatureUnit, unit.name);
  }

  /// Length Unit speichern
  Future<void> setLengthUnit(LengthUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLengthUnit, unit.name);
  }

  /// Volume Unit speichern
  Future<void> setVolumeUnit(VolumeUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVolumeUnit, unit.name);
  }

  /// Alle Einstellungen speichern
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
