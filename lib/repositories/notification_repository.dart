// =============================================
// GROWLOG - Notification Repository
// =============================================

import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_settings.dart';
import '../utils/app_logger.dart';
import 'interfaces/i_notification_repository.dart';
import 'repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class NotificationRepository with RepositoryErrorHandler implements INotificationRepository {
  @override
  String get repositoryName => 'NotificationRepository';

  static const String _keyEnabled = 'notifications_enabled';
  static const String _keyWateringReminders = 'notifications_watering';
  static const String _keyFertilizingReminders = 'notifications_fertilizing';
  static const String _keyPhotoReminders = 'notifications_photo';
  static const String _keyHarvestReminders = 'notifications_harvest';
  static const String _keyWateringInterval = 'notifications_watering_interval';
  static const String _keyFertilizingInterval = 'notifications_fertilizing_interval';
  static const String _keyPhotoInterval = 'notifications_photo_interval';
  static const String _keyNotificationTime = 'notifications_time';

  /// Get notification settings
  @override
  Future<NotificationSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return NotificationSettings(
        enabled: prefs.getBool(_keyEnabled) ?? false,
        wateringReminders: prefs.getBool(_keyWateringReminders) ?? true,
        fertilizingReminders: prefs.getBool(_keyFertilizingReminders) ?? true,
        photoReminders: prefs.getBool(_keyPhotoReminders) ?? true,
        harvestReminders: prefs.getBool(_keyHarvestReminders) ?? true,
        wateringIntervalDays: prefs.getInt(_keyWateringInterval) ?? 2,
        fertilizingIntervalDays: prefs.getInt(_keyFertilizingInterval) ?? 7,
        photoIntervalDays: prefs.getInt(_keyPhotoInterval) ?? 7,
        notificationTime: prefs.getString(_keyNotificationTime) ?? "09:00",
      );
    } catch (e) {
      AppLogger.error('NotificationRepository', 'Failed to get settings', e);
      return NotificationSettings();
    }
  }

  /// Save notification settings
  @override
  Future<void> saveSettings(NotificationSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyEnabled, settings.enabled);
      await prefs.setBool(_keyWateringReminders, settings.wateringReminders);
      await prefs.setBool(_keyFertilizingReminders, settings.fertilizingReminders);
      await prefs.setBool(_keyPhotoReminders, settings.photoReminders);
      await prefs.setBool(_keyHarvestReminders, settings.harvestReminders);
      await prefs.setInt(_keyWateringInterval, settings.wateringIntervalDays);
      await prefs.setInt(_keyFertilizingInterval, settings.fertilizingIntervalDays);
      await prefs.setInt(_keyPhotoInterval, settings.photoIntervalDays);
      await prefs.setString(_keyNotificationTime, settings.notificationTime);

      AppLogger.info('NotificationRepository', 'Settings saved successfully');
    } catch (e) {
      AppLogger.error('NotificationRepository', 'Failed to save settings', e);
      rethrow;
    }
  }

  /// Update specific setting
  @override
  Future<void> setEnabled(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(enabled: enabled));
  }

  @override
  Future<void> setWateringReminders(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(wateringReminders: enabled));
  }

  @override
  Future<void> setFertilizingReminders(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(fertilizingReminders: enabled));
  }

  @override
  Future<void> setPhotoReminders(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(photoReminders: enabled));
  }

  @override
  Future<void> setHarvestReminders(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(harvestReminders: enabled));
  }

  @override
  Future<void> setWateringInterval(int days) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(wateringIntervalDays: days));
  }

  @override
  Future<void> setFertilizingInterval(int days) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(fertilizingIntervalDays: days));
  }

  @override
  Future<void> setPhotoInterval(int days) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(photoIntervalDays: days));
  }

  @override
  Future<void> setNotificationTime(String time) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(notificationTime: time));
  }
}
