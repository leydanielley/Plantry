// =============================================
// GROWLOG - Notification Service Configuration
// ✅ AUDIT FIX: Centralized magic numbers from notification_service.dart
// =============================================

import 'package:flutter/material.dart';

/// Configuration constants for notification service
///
/// Centralizes all notification settings, IDs, colors, and other
/// constants to prevent magic numbers.
class NotificationConfig {
  // ═══════════════════════════════════════════
  // TIMEZONE SETTINGS
  // ═══════════════════════════════════════════

  /// Default timezone location
  static const String defaultTimezone = 'Europe/Berlin';

  /// Default notification time (HH:MM format)
  static const String defaultNotificationTime = '09:00';

  // ═══════════════════════════════════════════
  // NOTIFICATION IDS
  // ═══════════════════════════════════════════

  /// Test notification ID
  static const int testNotificationId = 999;

  /// Watering notification ID offset multiplier
  static const int wateringIdMultiplier = 10;

  /// Watering notification ID offset
  static const int wateringIdOffset = 1;

  /// Fertilizing notification ID offset
  static const int fertilizingIdOffset = 2;

  /// Photo notification ID offset
  static const int photoIdOffset = 3;

  /// Harvest notification ID offset
  static const int harvestIdOffset = 4;

  // ═══════════════════════════════════════════
  // HARVEST REMINDER SETTINGS
  // ═══════════════════════════════════════════

  /// Days before harvest to send reminder
  static const int harvestReminderDaysBefore = 3;

  // ═══════════════════════════════════════════
  // CHANNEL SETTINGS
  // ═══════════════════════════════════════════

  /// Notification channel ID
  static const String channelId = 'plantry_reminders';

  /// Notification channel name (hardcoded as it's used in native Android code)
  static const String channelName = 'Pflanz-Erinnerungen';

  /// Notification channel description (hardcoded as it's used in native Android code)
  static const String channelDescription =
      'Erinnerungen für Gießen, Düngen und Pflege';

  /// Notification icon
  static const String notificationIcon = '@mipmap/ic_launcher';

  /// Notification color (green)
  static const Color notificationColor = Color(0xFF004225);

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Calculate watering notification ID for a plant
  static int getWateringNotificationId(int plantId) =>
      plantId * wateringIdMultiplier + wateringIdOffset;

  /// Calculate fertilizing notification ID for a plant
  static int getFertilizingNotificationId(int plantId) =>
      plantId * wateringIdMultiplier + fertilizingIdOffset;

  /// Calculate photo notification ID for a plant
  static int getPhotoNotificationId(int plantId) =>
      plantId * wateringIdMultiplier + photoIdOffset;

  /// Calculate harvest notification ID for a plant
  static int getHarvestNotificationId(int plantId) =>
      plantId * wateringIdMultiplier + harvestIdOffset;
}
