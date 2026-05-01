// =============================================
// GROWLOG - Notification Service Configuration
// ✅ AUDIT FIX: Centralized magic numbers from notification_service.dart
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

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
  static const Color notificationColor = DT.accent;

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Maximum safe plantId for notification ID derivation.
  /// Android's NotificationManager uses signed 32-bit int IDs (max 2_147_483_647).
  /// With wateringIdMultiplier = 10, plantId must stay below ~214_000_000 to
  /// avoid overflow into negative IDs (which would cause cancel-collisions).
  /// Realistic plant counts in this app stay well below this limit.
  static const int _maxSafePlantId = 200000000;

  /// Calculate watering notification ID for a plant
  static int getWateringNotificationId(int plantId) {
    assert(
      plantId >= 0 && plantId < _maxSafePlantId,
      'plantId $plantId out of safe notification-ID range (0..$_maxSafePlantId)',
    );
    return plantId * wateringIdMultiplier + wateringIdOffset;
  }

  /// Calculate fertilizing notification ID for a plant
  static int getFertilizingNotificationId(int plantId) {
    assert(
      plantId >= 0 && plantId < _maxSafePlantId,
      'plantId $plantId out of safe notification-ID range (0..$_maxSafePlantId)',
    );
    return plantId * wateringIdMultiplier + fertilizingIdOffset;
  }

  /// Calculate photo notification ID for a plant
  static int getPhotoNotificationId(int plantId) {
    assert(
      plantId >= 0 && plantId < _maxSafePlantId,
      'plantId $plantId out of safe notification-ID range (0..$_maxSafePlantId)',
    );
    return plantId * wateringIdMultiplier + photoIdOffset;
  }

  /// Calculate harvest notification ID for a plant
  static int getHarvestNotificationId(int plantId) {
    assert(
      plantId >= 0 && plantId < _maxSafePlantId,
      'plantId $plantId out of safe notification-ID range (0..$_maxSafePlantId)',
    );
    return plantId * wateringIdMultiplier + harvestIdOffset;
  }
}
