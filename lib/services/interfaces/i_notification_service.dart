// =============================================
// GROWLOG - NotificationService Interface
// =============================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class INotificationService {
  /// Initialize notification service
  Future<void> initialize();

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions();

  /// Schedule watering reminder for a plant
  Future<void> scheduleWateringReminder({
    required int plantId,
    required String plantName,
    required DateTime lastWatering,
    required int intervalDays,
    String notificationTime = "09:00",
  });

  /// Schedule fertilizing reminder for a plant
  Future<void> scheduleFertilizingReminder({
    required int plantId,
    required String plantName,
    required DateTime lastFertilizing,
    required int intervalDays,
    String notificationTime = "09:00",
  });

  /// Schedule photo reminder for a plant
  Future<void> schedulePhotoReminder({
    required int plantId,
    required String plantName,
    required DateTime lastPhoto,
    required int intervalDays,
    String notificationTime = "09:00",
  });

  /// Schedule harvest reminder
  Future<void> scheduleHarvestReminder({
    required int plantId,
    required String plantName,
    required DateTime estimatedHarvestDate,
    String notificationTime = "09:00",
  });

  /// Cancel all reminders for a plant
  Future<void> cancelPlantReminders(int plantId);

  /// Cancel all notifications
  Future<void> cancelAllNotifications();

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications();

  /// Show immediate notification (for testing)
  Future<void> showTestNotification();
}
