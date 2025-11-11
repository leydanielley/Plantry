// =============================================
// GROWLOG - SettingsRepository Interface
// =============================================

import 'package:growlog_app/models/app_settings.dart';

abstract class ISettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> setLanguage(String language);
  Future<void> setDarkMode(bool isDarkMode);
  Future<void> setExpertMode(bool isExpertMode);
  Future<void> setNutrientUnit(NutrientUnit unit);
  Future<void> setPpmScale(PpmScale scale);
  Future<void> setTemperatureUnit(TemperatureUnit unit);
  Future<void> setLengthUnit(LengthUnit unit);
  Future<void> setVolumeUnit(VolumeUnit unit);
  Future<void> saveSettings(AppSettings settings);
}
