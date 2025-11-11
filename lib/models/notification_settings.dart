// =============================================
// GROWLOG - Notification Settings Model
// =============================================

class NotificationSettings {
  final bool enabled;
  final bool wateringReminders;
  final bool fertilizingReminders;
  final bool photoReminders;
  final bool harvestReminders;
  final int wateringIntervalDays;
  final int fertilizingIntervalDays;
  final int photoIntervalDays;
  final String notificationTime; // Format: "HH:mm"

  NotificationSettings({
    this.enabled = false,
    this.wateringReminders = true,
    this.fertilizingReminders = true,
    this.photoReminders = true,
    this.harvestReminders = true,
    this.wateringIntervalDays = 2,
    this.fertilizingIntervalDays = 7,
    this.photoIntervalDays = 7,
    this.notificationTime = "09:00",
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? wateringReminders,
    bool? fertilizingReminders,
    bool? photoReminders,
    bool? harvestReminders,
    int? wateringIntervalDays,
    int? fertilizingIntervalDays,
    int? photoIntervalDays,
    String? notificationTime,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      wateringReminders: wateringReminders ?? this.wateringReminders,
      fertilizingReminders: fertilizingReminders ?? this.fertilizingReminders,
      photoReminders: photoReminders ?? this.photoReminders,
      harvestReminders: harvestReminders ?? this.harvestReminders,
      wateringIntervalDays: wateringIntervalDays ?? this.wateringIntervalDays,
      fertilizingIntervalDays:
          fertilizingIntervalDays ?? this.fertilizingIntervalDays,
      photoIntervalDays: photoIntervalDays ?? this.photoIntervalDays,
      notificationTime: notificationTime ?? this.notificationTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled ? 1 : 0,
      'watering_reminders': wateringReminders ? 1 : 0,
      'fertilizing_reminders': fertilizingReminders ? 1 : 0,
      'photo_reminders': photoReminders ? 1 : 0,
      'harvest_reminders': harvestReminders ? 1 : 0,
      'watering_interval_days': wateringIntervalDays,
      'fertilizing_interval_days': fertilizingIntervalDays,
      'photo_interval_days': photoIntervalDays,
      'notification_time': notificationTime,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] == 1,
      wateringReminders: map['watering_reminders'] == 1,
      fertilizingReminders: map['fertilizing_reminders'] == 1,
      photoReminders: map['photo_reminders'] == 1,
      harvestReminders: map['harvest_reminders'] == 1,
      // ✅ CRITICAL FIX: Null-safe casts with fallback defaults
      wateringIntervalDays: map['watering_interval_days'] as int? ?? 2,
      fertilizingIntervalDays: map['fertilizing_interval_days'] as int? ?? 7,
      photoIntervalDays: map['photo_interval_days'] as int? ?? 7,
      notificationTime: map['notification_time'] as String? ?? "09:00",
    );
  }
}

/// Plant-specific notification override
class PlantNotificationSettings {
  final int plantId;
  final bool overrideGlobal;
  final int? wateringIntervalDays;
  final bool? wateringEnabled;

  PlantNotificationSettings({
    required this.plantId,
    this.overrideGlobal = false,
    this.wateringIntervalDays,
    this.wateringEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'plant_id': plantId,
      'override_global': overrideGlobal ? 1 : 0,
      'watering_interval_days': wateringIntervalDays,
      'watering_enabled': wateringEnabled != null
          ? (wateringEnabled! ? 1 : 0)
          : null,
    };
  }

  factory PlantNotificationSettings.fromMap(Map<String, dynamic> map) {
    return PlantNotificationSettings(
      plantId: map['plant_id'] as int,
      overrideGlobal: map['override_global'] == 1,
      wateringIntervalDays: map['watering_interval_days'] as int?,
      wateringEnabled: map['watering_enabled'] != null
          ? map['watering_enabled'] == 1
          : null,
    );
  }
}
