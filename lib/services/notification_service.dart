// =============================================
// GROWLOG - Notification Service (100% Offline)
// =============================================

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../utils/app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));

      // Android initialization
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;
      AppLogger.info('NotificationService', 'Initialized successfully');
    } catch (e) {
      AppLogger.error('NotificationService', 'Initialization failed', e);
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.debug('NotificationService', 'Notification tapped: ${response.payload}');
    // TODO: Navigate to relevant screen based on payload
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        AppLogger.info('NotificationService', 'Permission granted: $granted');
        return granted ?? false;
      }
      return true;
    } catch (e) {
      AppLogger.error('NotificationService', 'Permission request failed', e);
      return false;
    }
  }

  /// Schedule watering reminder for a plant
  Future<void> scheduleWateringReminder({
    required int plantId,
    required String plantName,
    required DateTime lastWatering,
    required int intervalDays,
    String notificationTime = "09:00",
  }) async {
    if (!_initialized) await initialize();

    try {
      final nextWatering = lastWatering.add(Duration(days: intervalDays));
      final timeParts = notificationTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final scheduledDate = tz.TZDateTime(
        tz.local,
        nextWatering.year,
        nextWatering.month,
        nextWatering.day,
        hour,
        minute,
      );

      // Skip if in the past
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        AppLogger.debug('NotificationService', 'Skipping past date for plant $plantId');
        return;
      }

      await _notifications.zonedSchedule(
        _getWateringNotificationId(plantId),
        '💧 Zeit zum Gießen!',
        '$plantName braucht Wasser',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'watering:$plantId',
      );

      AppLogger.info('NotificationService',
        'Scheduled watering reminder for $plantName at $scheduledDate');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to schedule watering reminder', e);
    }
  }

  /// Schedule fertilizing reminder for a plant
  Future<void> scheduleFertilizingReminder({
    required int plantId,
    required String plantName,
    required DateTime lastFertilizing,
    required int intervalDays,
    String notificationTime = "09:00",
  }) async {
    if (!_initialized) await initialize();

    try {
      final nextFertilizing = lastFertilizing.add(Duration(days: intervalDays));
      final timeParts = notificationTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final scheduledDate = tz.TZDateTime(
        tz.local,
        nextFertilizing.year,
        nextFertilizing.month,
        nextFertilizing.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }

      await _notifications.zonedSchedule(
        _getFertilizingNotificationId(plantId),
        '🌿 Zeit zum Düngen!',
        '$plantName braucht Nährstoffe',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'fertilizing:$plantId',
      );

      AppLogger.info('NotificationService',
        'Scheduled fertilizing reminder for $plantName at $scheduledDate');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to schedule fertilizing reminder', e);
    }
  }

  /// Schedule photo reminder for a plant
  Future<void> schedulePhotoReminder({
    required int plantId,
    required String plantName,
    required DateTime lastPhoto,
    required int intervalDays,
    String notificationTime = "09:00",
  }) async {
    if (!_initialized) await initialize();

    try {
      final nextPhoto = lastPhoto.add(Duration(days: intervalDays));
      final timeParts = notificationTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final scheduledDate = tz.TZDateTime(
        tz.local,
        nextPhoto.year,
        nextPhoto.month,
        nextPhoto.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }

      await _notifications.zonedSchedule(
        _getPhotoNotificationId(plantId),
        '📸 Foto-Erinnerung',
        'Wöchentliches Foto von $plantName machen',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'photo:$plantId',
      );

      AppLogger.info('NotificationService',
        'Scheduled photo reminder for $plantName at $scheduledDate');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to schedule photo reminder', e);
    }
  }

  /// Schedule harvest reminder
  Future<void> scheduleHarvestReminder({
    required int plantId,
    required String plantName,
    required DateTime estimatedHarvestDate,
    String notificationTime = "09:00",
  }) async {
    if (!_initialized) await initialize();

    try {
      final timeParts = notificationTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Remind 3 days before
      final reminderDate = estimatedHarvestDate.subtract(const Duration(days: 3));

      final scheduledDate = tz.TZDateTime(
        tz.local,
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }

      await _notifications.zonedSchedule(
        _getHarvestNotificationId(plantId),
        '🌾 Ernte bald fertig!',
        '$plantName: Ernte in ca. 3 Tagen',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'harvest:$plantId',
      );

      AppLogger.info('NotificationService',
        'Scheduled harvest reminder for $plantName at $scheduledDate');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to schedule harvest reminder', e);
    }
  }

  /// Cancel all reminders for a plant
  Future<void> cancelPlantReminders(int plantId) async {
    try {
      await _notifications.cancel(_getWateringNotificationId(plantId));
      await _notifications.cancel(_getFertilizingNotificationId(plantId));
      await _notifications.cancel(_getPhotoNotificationId(plantId));
      await _notifications.cancel(_getHarvestNotificationId(plantId));

      AppLogger.info('NotificationService', 'Cancelled all reminders for plant $plantId');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to cancel reminders', e);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      AppLogger.info('NotificationService', 'Cancelled all notifications');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to cancel all notifications', e);
    }
  }

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to get pending notifications', e);
      return [];
    }
  }

  /// Show immediate notification (for testing)
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    try {
      await _notifications.show(
        999,
        '🌱 Plantry Test',
        'Benachrichtigungen funktionieren!',
        _notificationDetails(),
        payload: 'test',
      );
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to show test notification', e);
    }
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'plantry_reminders',
        'Pflanz-Erinnerungen',
        channelDescription: 'Erinnerungen für Gießen, Düngen und Pflege',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF004225),
        enableVibration: true,
        playSound: true,
      ),
    );
  }

  int _getWateringNotificationId(int plantId) => plantId * 10 + 1;
  int _getFertilizingNotificationId(int plantId) => plantId * 10 + 2;
  int _getPhotoNotificationId(int plantId) => plantId * 10 + 3;
  int _getHarvestNotificationId(int plantId) => plantId * 10 + 4;
}
