// =============================================
// GROWLOG - NotificationRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growlog_app/repositories/notification_repository.dart';
import 'package:growlog_app/models/notification_settings.dart';

void main() {
  late NotificationRepository repository;

  setUp(() {
    // Initialize SharedPreferences with empty values
    SharedPreferences.setMockInitialValues({});
    repository = NotificationRepository();
  });

  group('NotificationRepository - Get/Set Operations', () {
    test('getSettings() - should return default settings initially', () async {
      // Act
      final settings = await repository.getSettings();

      // Assert - Default values
      expect(settings.enabled, isFalse);
      expect(settings.wateringReminders, isTrue);
      expect(settings.fertilizingReminders, isTrue);
      expect(settings.photoReminders, isTrue);
      expect(settings.harvestReminders, isTrue);
      expect(settings.wateringIntervalDays, equals(2));
      expect(settings.fertilizingIntervalDays, equals(7));
      expect(settings.photoIntervalDays, equals(7));
      expect(settings.notificationTime, equals("09:00"));
    });

    test('setEnabled() - should update enabled setting', () async {
      // Act
      await repository.setEnabled(true);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.enabled, isTrue);
    });

    test('setWateringReminders() - should update watering reminders', () async {
      // Act
      await repository.setWateringReminders(false);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.wateringReminders, isFalse);
    });

    test(
      'setFertilizingReminders() - should update fertilizing reminders',
      () async {
        // Act
        await repository.setFertilizingReminders(false);
        final settings = await repository.getSettings();

        // Assert
        expect(settings.fertilizingReminders, isFalse);
      },
    );

    test('setPhotoReminders() - should update photo reminders', () async {
      // Act
      await repository.setPhotoReminders(false);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.photoReminders, isFalse);
    });

    test('setHarvestReminders() - should update harvest reminders', () async {
      // Act
      await repository.setHarvestReminders(false);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.harvestReminders, isFalse);
    });

    test('setWateringInterval() - should update watering interval', () async {
      // Act
      await repository.setWateringInterval(3);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.wateringIntervalDays, equals(3));
    });

    test(
      'setFertilizingInterval() - should update fertilizing interval',
      () async {
        // Act
        await repository.setFertilizingInterval(14);
        final settings = await repository.getSettings();

        // Assert
        expect(settings.fertilizingIntervalDays, equals(14));
      },
    );

    test('setPhotoInterval() - should update photo interval', () async {
      // Act
      await repository.setPhotoInterval(3);
      final settings = await repository.getSettings();

      // Assert
      expect(settings.photoIntervalDays, equals(3));
    });

    test('setNotificationTime() - should update notification time', () async {
      // Act
      await repository.setNotificationTime("18:30");
      final settings = await repository.getSettings();

      // Assert
      expect(settings.notificationTime, equals("18:30"));
    });
  });

  group('NotificationRepository - Bulk Operations', () {
    test('saveSettings() - should save all settings at once', () async {
      // Arrange
      final settings = NotificationSettings(
        enabled: true,
        wateringReminders: false,
        fertilizingReminders: false,
        photoReminders: false,
        harvestReminders: false,
        wateringIntervalDays: 1,
        fertilizingIntervalDays: 14,
        photoIntervalDays: 3,
        notificationTime: "20:00",
      );

      // Act
      await repository.saveSettings(settings);
      final retrieved = await repository.getSettings();

      // Assert
      expect(retrieved.enabled, isTrue);
      expect(retrieved.wateringReminders, isFalse);
      expect(retrieved.fertilizingReminders, isFalse);
      expect(retrieved.photoReminders, isFalse);
      expect(retrieved.harvestReminders, isFalse);
      expect(retrieved.wateringIntervalDays, equals(1));
      expect(retrieved.fertilizingIntervalDays, equals(14));
      expect(retrieved.photoIntervalDays, equals(3));
      expect(retrieved.notificationTime, equals("20:00"));
    });

    test('saveSettings() - should overwrite existing settings', () async {
      // Arrange - Save initial settings
      final initial = NotificationSettings(
        enabled: true,
        wateringReminders: false,
        wateringIntervalDays: 1,
        notificationTime: "08:00",
      );
      await repository.saveSettings(initial);

      // Act - Update with new settings
      final updated = NotificationSettings(
        enabled: false,
        wateringReminders: true,
        wateringIntervalDays: 5,
        notificationTime: "22:00",
      );
      await repository.saveSettings(updated);
      final retrieved = await repository.getSettings();

      // Assert - Should have new values
      expect(retrieved.enabled, isFalse);
      expect(retrieved.wateringReminders, isTrue);
      expect(retrieved.wateringIntervalDays, equals(5));
      expect(retrieved.notificationTime, equals("22:00"));
    });
  });

  group('NotificationRepository - Edge Cases', () {
    test(
      'getSettings() - should handle multiple updates to same setting',
      () async {
        // Act - Multiple updates
        await repository.setWateringInterval(1);
        await repository.setWateringInterval(2);
        await repository.setWateringInterval(3);
        final settings = await repository.getSettings();

        // Assert - Should have latest value
        expect(settings.wateringIntervalDays, equals(3));
      },
    );

    test(
      'getSettings() - should persist across repository instances',
      () async {
        // Arrange - Save with first instance
        await repository.setEnabled(true);
        await repository.setNotificationTime("15:30");

        // Act - Create new instance and retrieve
        final newRepository = NotificationRepository();
        final settings = await newRepository.getSettings();

        // Assert - Should have persisted values
        expect(settings.enabled, isTrue);
        expect(settings.notificationTime, equals("15:30"));
      },
    );

    test('should allow updating individual settings independently', () async {
      // Arrange - Set initial complete settings
      final initial = NotificationSettings(
        enabled: true,
        wateringReminders: true,
        fertilizingReminders: true,
        wateringIntervalDays: 2,
        notificationTime: "09:00",
      );
      await repository.saveSettings(initial);

      // Act - Update only enabled
      await repository.setEnabled(false);
      var settings = await repository.getSettings();

      // Assert - Enabled changed, others unchanged
      expect(settings.enabled, isFalse);
      expect(settings.wateringReminders, isTrue);
      expect(settings.wateringIntervalDays, equals(2));

      // Act - Update only interval
      await repository.setWateringInterval(7);
      settings = await repository.getSettings();

      // Assert - Interval changed, others unchanged
      expect(settings.enabled, isFalse); // Still false from before
      expect(settings.wateringIntervalDays, equals(7));
      expect(settings.wateringReminders, isTrue);
    });

    test(
      'setWateringInterval() - should handle various interval values',
      () async {
        final intervals = [1, 2, 3, 7, 14, 30];

        for (final interval in intervals) {
          await repository.setWateringInterval(interval);
          final settings = await repository.getSettings();
          expect(settings.wateringIntervalDays, equals(interval));
        }
      },
    );

    test(
      'setFertilizingInterval() - should handle various interval values',
      () async {
        final intervals = [7, 10, 14, 21, 30];

        for (final interval in intervals) {
          await repository.setFertilizingInterval(interval);
          final settings = await repository.getSettings();
          expect(settings.fertilizingIntervalDays, equals(interval));
        }
      },
    );

    test(
      'setNotificationTime() - should handle various time formats',
      () async {
        final times = ["00:00", "06:30", "12:00", "18:45", "23:59"];

        for (final time in times) {
          await repository.setNotificationTime(time);
          final settings = await repository.getSettings();
          expect(settings.notificationTime, equals(time));
        }
      },
    );

    test('should maintain all reminder flags independently', () async {
      // Act - Toggle each reminder independently
      await repository.setWateringReminders(false);
      await repository.setFertilizingReminders(false);
      await repository.setPhotoReminders(false);
      await repository.setHarvestReminders(false);

      var settings = await repository.getSettings();

      // Assert - All should be false
      expect(settings.wateringReminders, isFalse);
      expect(settings.fertilizingReminders, isFalse);
      expect(settings.photoReminders, isFalse);
      expect(settings.harvestReminders, isFalse);

      // Act - Toggle only one back to true
      await repository.setWateringReminders(true);
      settings = await repository.getSettings();

      // Assert - Only watering changed
      expect(settings.wateringReminders, isTrue);
      expect(settings.fertilizingReminders, isFalse);
      expect(settings.photoReminders, isFalse);
      expect(settings.harvestReminders, isFalse);
    });
  });
}
