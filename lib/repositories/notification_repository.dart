// =============================================
// GROWLOG - Notification Repository
// =============================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:growlog_app/models/notification_settings.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/repositories/interfaces/i_notification_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';

// ✅ AUDIT FIX: Error handling standardized with RepositoryErrorHandler mixin
class NotificationRepository
    with RepositoryErrorHandler
    implements INotificationRepository {
  @override
  String get repositoryName => 'NotificationRepository';

  static const String _keyEnabled = 'notifications_enabled';
  static const String _keyWateringReminders = 'notifications_watering';
  static const String _keyFertilizingReminders = 'notifications_fertilizing';
  static const String _keyPhotoReminders = 'notifications_photo';
  static const String _keyHarvestReminders = 'notifications_harvest';
  static const String _keyWateringInterval = 'notifications_watering_interval';
  static const String _keyFertilizingInterval =
      'notifications_fertilizing_interval';
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
      await prefs.setBool(
        _keyFertilizingReminders,
        settings.fertilizingReminders,
      );
      await prefs.setBool(_keyPhotoReminders, settings.photoReminders);
      await prefs.setBool(_keyHarvestReminders, settings.harvestReminders);
      await prefs.setInt(_keyWateringInterval, settings.wateringIntervalDays);
      await prefs.setInt(
        _keyFertilizingInterval,
        settings.fertilizingIntervalDays,
      );
      await prefs.setInt(_keyPhotoInterval, settings.photoIntervalDays);
      await prefs.setString(_keyNotificationTime, settings.notificationTime);

      AppLogger.info('NotificationRepository', 'Settings saved successfully');
    } catch (e) {
      AppLogger.error('NotificationRepository', 'Failed to save settings', e);
      rethrow;
    }
  }

  /// Update specific setting
  /// ✅ CRITICAL FIX: Atomic operations to prevent race conditions
  /// Previous implementation had read-modify-write race condition where concurrent
  /// calls could overwrite each other's changes. Now each setter directly updates
  /// only its specific field atomically via SharedPreferences.
  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, enabled);
      AppLogger.debug('NotificationRepository', 'Enabled updated', enabled);
    } catch (e) {
      AppLogger.error('NotificationRepository', 'Failed to set enabled', e);
      rethrow;
    }
  }

  @override
  Future<void> setWateringReminders(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWateringReminders, enabled);
      AppLogger.debug(
        'NotificationRepository',
        'Watering reminders updated',
        enabled,
      );
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set watering reminders',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> setFertilizingReminders(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFertilizingReminders, enabled);
      AppLogger.debug(
        'NotificationRepository',
        'Fertilizing reminders updated',
        enabled,
      );
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set fertilizing reminders',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> setPhotoReminders(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPhotoReminders, enabled);
      AppLogger.debug(
        'NotificationRepository',
        'Photo reminders updated',
        enabled,
      );
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set photo reminders',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> setHarvestReminders(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHarvestReminders, enabled);
      AppLogger.debug(
        'NotificationRepository',
        'Harvest reminders updated',
        enabled,
      );
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set harvest reminders',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> setWateringInterval(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWateringInterval, days);
      AppLogger.debug(
        'NotificationRepository',
        'Watering interval updated',
        days,
      );
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set watering interval',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> setFertilizingInterval(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyFertilizingInterval, days);
      AppLogger.debug(
        'NotificationRepository',
        'Fertilizing interval updated',
        days,
      );
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set fertilizing interval',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> setPhotoInterval(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPhotoInterval, days);
      AppLogger.debug('NotificationRepository', 'Photo interval updated', days);
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set photo interval',
        e,
      );
      rethrow;
    }
  }

  @override
  Future<void> setNotificationTime(String time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNotificationTime, time);
      AppLogger.debug(
        'NotificationRepository',
        'Notification time updated',
        time,
      );
    } catch (e) {
      AppLogger.error(
        'NotificationRepository',
        'Failed to set notification time',
        e,
      );
      rethrow;
    }
  }
}
