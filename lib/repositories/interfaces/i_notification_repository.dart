// =============================================
// GROWLOG - NotificationRepository Interface
// =============================================

import 'package:growlog_app/models/notification_settings.dart';

abstract class INotificationRepository {
  Future<NotificationSettings> getSettings();
  Future<void> saveSettings(NotificationSettings settings);
  Future<void> setEnabled(bool enabled);
  Future<void> setWateringReminders(bool enabled);
  Future<void> setFertilizingReminders(bool enabled);
  Future<void> setPhotoReminders(bool enabled);
  Future<void> setHarvestReminders(bool enabled);
  Future<void> setWateringInterval(int days);
  Future<void> setFertilizingInterval(int days);
  Future<void> setPhotoInterval(int days);
  Future<void> setNotificationTime(String time);
}
