// =============================================
// GROWLOG - Settings Repository
// =============================================

import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  static const String _keyLanguage = 'language';
  static const String _keyDarkMode = 'dark_mode';

  /// Einstellungen laden
  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return AppSettings(
      language: prefs.getString(_keyLanguage) ?? 'de',
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
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

  /// Alle Einstellungen speichern
  Future<void> saveSettings(AppSettings settings) async {
    await setLanguage(settings.language);
    await setDarkMode(settings.isDarkMode);
  }
}
