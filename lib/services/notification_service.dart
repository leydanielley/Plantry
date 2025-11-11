// =============================================
// GROWLOG - Notification Service (100% Offline)
// =============================================

import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../utils/app_logger.dart';
import '../config/notification_config.dart';  // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
import 'interfaces/i_notification_service.dart';

class NotificationService implements INotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification service
  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone with device's actual timezone
      // ✅ FIX: Detect device timezone instead of hardcoding Europe/Berlin
      tz.initializeTimeZones();
      try {
        final String deviceTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTimezone));
        AppLogger.info('NotificationService', 'Using device timezone: $deviceTimezone');
      } catch (e) {
        // Fallback to default if detection fails
        tz.setLocalLocation(tz.getLocation(NotificationConfig.defaultTimezone));
        AppLogger.warning('NotificationService', 'Timezone detection failed, using default: ${NotificationConfig.defaultTimezone}');
      }

      // ✅ FIX: Add iOS initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

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
    final payload = response.payload;
    AppLogger.debug('NotificationService', 'Notification tapped: $payload');

    if (payload == null || payload.isEmpty) {
      AppLogger.debug('NotificationService', 'No payload, skipping navigation');
      return;
    }

    // Parse payload format: "type:plantId"
    try {
      final parts = payload.split(':');
      if (parts.length != 2) {
        AppLogger.warning('NotificationService', 'Invalid payload format: $payload');
        return;
      }

      final type = parts[0];
      final plantId = int.tryParse(parts[1]);

      if (plantId == null && type != 'test') {
        AppLogger.warning('NotificationService', 'Invalid plant ID in payload: $payload');
        return;
      }

      AppLogger.info('NotificationService', 'Parsed notification: type=$type, plantId=$plantId');

      // Note: Navigation requires a NavigatorKey setup in the main app.
      // The app should register a callback via a future NavigationService
      // or use a GlobalKey<NavigatorState> to handle navigation.
      // For now, we log the navigation intent.

      switch (type) {
        case 'watering':
          AppLogger.info('NotificationService', 'Navigate to plant $plantId (watering reminder)');
          // Future: navigatorKey.currentState?.push(MaterialPageRoute(...))
          break;
        case 'fertilizing':
          AppLogger.info('NotificationService', 'Navigate to plant $plantId (fertilizing reminder)');
          break;
        case 'photo':
          AppLogger.info('NotificationService', 'Navigate to plant $plantId (photo reminder)');
          break;
        case 'harvest':
          AppLogger.info('NotificationService', 'Navigate to plant $plantId (harvest reminder)');
          break;
        case 'test':
          AppLogger.info('NotificationService', 'Test notification tapped');
          break;
        default:
          AppLogger.warning('NotificationService', 'Unknown notification type: $type');
      }
    } catch (e) {
      AppLogger.error('NotificationService', 'Error handling notification tap', e);
    }
  }

  /// Request notification permissions (Android 13+, iOS)
  /// ✅ FIX: Now properly requests permissions on both platforms
  @override
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          AppLogger.info('NotificationService', 'Android permission granted: $granted');
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          AppLogger.info('NotificationService', 'iOS permission granted: $granted');
          return granted ?? false;
        }
      }

      return false;  // ✅ FIX: Return false instead of true if no platform matched
    } catch (e) {
      AppLogger.error('NotificationService', 'Permission request failed', e);
      return false;
    }
  }

  /// Schedule watering reminder for a plant
  @override
  Future<void> scheduleWateringReminder({
    required int plantId,
    required String plantName,
    required DateTime lastWatering,
    required int intervalDays,
    String notificationTime = NotificationConfig.defaultNotificationTime,  // ✅ AUDIT FIX
  }) async {
    if (!_initialized) await initialize();

    try {
      final nextWatering = lastWatering.add(Duration(days: intervalDays));
      final timeParts = notificationTime.split(':');

      // ✅ FIX: Proper time validation with range checks
      if (timeParts.length < 2) {
        AppLogger.error('NotificationService', 'Invalid notification time format: $notificationTime');
        return;
      }

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);

      // ✅ FIX: Validate time ranges (0-23 hours, 0-59 minutes)
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        AppLogger.error('NotificationService', 'Invalid time values: hour=$hour, minute=$minute');
        throw ArgumentError('Invalid notification time: $notificationTime (expected HH:MM format with valid ranges)');
      }

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

      // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
      await _notifications.zonedSchedule(
        NotificationConfig.getWateringNotificationId(plantId),
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
  @override
  Future<void> scheduleFertilizingReminder({
    required int plantId,
    required String plantName,
    required DateTime lastFertilizing,
    required int intervalDays,
    String notificationTime = NotificationConfig.defaultNotificationTime,  // ✅ AUDIT FIX
  }) async {
    if (!_initialized) await initialize();

    try {
      final nextFertilizing = lastFertilizing.add(Duration(days: intervalDays));
      final timeParts = notificationTime.split(':');

      // ✅ FIX: Proper time validation with range checks
      if (timeParts.length < 2) {
        AppLogger.error('NotificationService', 'Invalid notification time format: $notificationTime');
        return;
      }

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);

      // ✅ FIX: Validate time ranges (0-23 hours, 0-59 minutes)
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        AppLogger.error('NotificationService', 'Invalid time values: hour=$hour, minute=$minute');
        throw ArgumentError('Invalid notification time: $notificationTime (expected HH:MM format with valid ranges)');
      }

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

      // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
      await _notifications.zonedSchedule(
        NotificationConfig.getFertilizingNotificationId(plantId),
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
  @override
  Future<void> schedulePhotoReminder({
    required int plantId,
    required String plantName,
    required DateTime lastPhoto,
    required int intervalDays,
    String notificationTime = NotificationConfig.defaultNotificationTime,  // ✅ AUDIT FIX
  }) async {
    if (!_initialized) await initialize();

    try {
      final nextPhoto = lastPhoto.add(Duration(days: intervalDays));
      final timeParts = notificationTime.split(':');

      // ✅ FIX: Proper time validation with range checks
      if (timeParts.length < 2) {
        AppLogger.error('NotificationService', 'Invalid notification time format: $notificationTime');
        return;
      }

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);

      // ✅ FIX: Validate time ranges (0-23 hours, 0-59 minutes)
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        AppLogger.error('NotificationService', 'Invalid time values: hour=$hour, minute=$minute');
        throw ArgumentError('Invalid notification time: $notificationTime (expected HH:MM format with valid ranges)');
      }

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

      // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
      await _notifications.zonedSchedule(
        NotificationConfig.getPhotoNotificationId(plantId),
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
  @override
  Future<void> scheduleHarvestReminder({
    required int plantId,
    required String plantName,
    required DateTime estimatedHarvestDate,
    String notificationTime = NotificationConfig.defaultNotificationTime,  // ✅ AUDIT FIX
  }) async {
    if (!_initialized) await initialize();

    try {
      final timeParts = notificationTime.split(':');

      // ✅ FIX: Proper time validation with range checks
      if (timeParts.length < 2) {
        AppLogger.error('NotificationService', 'Invalid notification time format: $notificationTime');
        return;
      }

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);

      // ✅ FIX: Validate time ranges (0-23 hours, 0-59 minutes)
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        AppLogger.error('NotificationService', 'Invalid time values: hour=$hour, minute=$minute');
        throw ArgumentError('Invalid notification time: $notificationTime (expected HH:MM format with valid ranges)');
      }

      // Remind 3 days before
      // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
      final reminderDate = estimatedHarvestDate.subtract(const Duration(days: NotificationConfig.harvestReminderDaysBefore));

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

      // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
      await _notifications.zonedSchedule(
        NotificationConfig.getHarvestNotificationId(plantId),
        '🌾 Ernte bald fertig!',
        '$plantName: Ernte in ca. ${NotificationConfig.harvestReminderDaysBefore} Tagen',
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
  @override
  Future<void> cancelPlantReminders(int plantId) async {
    try {
      // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
      await _notifications.cancel(NotificationConfig.getWateringNotificationId(plantId));
      await _notifications.cancel(NotificationConfig.getFertilizingNotificationId(plantId));
      await _notifications.cancel(NotificationConfig.getPhotoNotificationId(plantId));
      await _notifications.cancel(NotificationConfig.getHarvestNotificationId(plantId));

      AppLogger.info('NotificationService', 'Cancelled all reminders for plant $plantId');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to cancel reminders', e);
    }
  }

  /// Cancel all notifications
  @override
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      AppLogger.info('NotificationService', 'Cancelled all notifications');
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to cancel all notifications', e);
    }
  }

  /// Get pending notifications (for debugging)
  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      AppLogger.error('NotificationService', 'Failed to get pending notifications', e);
      return [];
    }
  }

  /// Show immediate notification (for testing)
  @override
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    try {
      // ✅ AUDIT FIX: Magic numbers extracted to NotificationConfig
      await _notifications.show(
        NotificationConfig.testNotificationId,
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
    // ✅ FIX: Add iOS notification details for cross-platform support
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationConfig.channelId,
        NotificationConfig.channelName,
        channelDescription: NotificationConfig.channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: NotificationConfig.notificationIcon,
        color: NotificationConfig.notificationColor,
        enableVibration: true,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
