// =============================================
// GROWLOG - Notification Helper
// =============================================

import '../models/plant.dart';
import '../models/plant_log.dart';
import '../models/enums.dart';
import '../repositories/plant_log_repository.dart';
import '../repositories/photo_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/log_fertilizer_repository.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';

class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();
  static final NotificationRepository _notificationRepo = NotificationRepository();
  static final PlantLogRepository _logRepo = PlantLogRepository();
  static final PhotoRepository _photoRepo = PhotoRepository();
  static final LogFertilizerRepository _logFertilizerRepo = LogFertilizerRepository();

  /// Schedule all reminders for a plant based on last activities
  static Future<void> scheduleRemindersForPlant(Plant plant) async {
    try {
      final settings = await _notificationRepo.getSettings();

      if (!settings.enabled || plant.id == null) {
        return;
      }

      // Schedule watering reminder
      if (settings.wateringReminders) {
        final lastWatering = await _getLastWateringDate(plant.id!);
        if (lastWatering != null) {
          await _notificationService.scheduleWateringReminder(
            plantId: plant.id!,
            plantName: plant.name,
            lastWatering: lastWatering,
            intervalDays: settings.wateringIntervalDays,
            notificationTime: settings.notificationTime,
          );
        }
      }

      // Schedule fertilizing reminder
      if (settings.fertilizingReminders) {
        final lastFertilizing = await _getLastFertilizingDate(plant.id!);
        if (lastFertilizing != null) {
          await _notificationService.scheduleFertilizingReminder(
            plantId: plant.id!,
            plantName: plant.name,
            lastFertilizing: lastFertilizing,
            intervalDays: settings.fertilizingIntervalDays,
            notificationTime: settings.notificationTime,
          );
        }
      }

      // Schedule photo reminder
      if (settings.photoReminders) {
        final lastPhoto = await _getLastPhotoDate(plant.id!);
        if (lastPhoto != null) {
          await _notificationService.schedulePhotoReminder(
            plantId: plant.id!,
            plantName: plant.name,
            lastPhoto: lastPhoto,
            intervalDays: settings.photoIntervalDays,
            notificationTime: settings.notificationTime,
          );
        }
      }

      // Schedule harvest reminder (estimated based on phase)
      if (settings.harvestReminders) {
        final estimatedHarvest = _estimateHarvestDate(plant);
        if (estimatedHarvest != null) {
          await _notificationService.scheduleHarvestReminder(
            plantId: plant.id!,
            plantName: plant.name,
            estimatedHarvestDate: estimatedHarvest,
            notificationTime: settings.notificationTime,
          );
        }
      }

      AppLogger.info('NotificationHelper',
        'Scheduled all reminders for ${plant.name}');
    } catch (e) {
      AppLogger.error('NotificationHelper',
        'Failed to schedule reminders for plant', e);
    }
  }

  /// Reschedule reminders after a log is created
  static Future<void> onLogCreated(Plant plant, PlantLog log) async {
    try {
      final settings = await _notificationRepo.getSettings();
      if (!settings.enabled) return;

      // If log contains watering, reschedule watering reminder
      if (log.waterAmount != null && log.waterAmount! > 0) {
        await _notificationService.scheduleWateringReminder(
          plantId: plant.id!,
          plantName: plant.name,
          lastWatering: log.logDate,
          intervalDays: settings.wateringIntervalDays,
          notificationTime: settings.notificationTime,
        );
      }

      // If log contains fertilizing, reschedule fertilizing reminder
      // (Check via log_fertilizers table if needed)

      AppLogger.info('NotificationHelper', 'Rescheduled reminders after log');
    } catch (e) {
      AppLogger.error('NotificationHelper', 'Failed to reschedule after log', e);
    }
  }

  /// Reschedule reminders after a photo is added
  static Future<void> onPhotoAdded(Plant plant) async {
    try {
      final settings = await _notificationRepo.getSettings();
      if (!settings.enabled || !settings.photoReminders) return;

      final now = DateTime.now();
      await _notificationService.schedulePhotoReminder(
        plantId: plant.id!,
        plantName: plant.name,
        lastPhoto: now,
        intervalDays: settings.photoIntervalDays,
        notificationTime: settings.notificationTime,
      );

      AppLogger.info('NotificationHelper', 'Rescheduled photo reminder');
    } catch (e) {
      AppLogger.error('NotificationHelper', 'Failed to reschedule photo reminder', e);
    }
  }

  /// Cancel all reminders when plant is deleted/archived
  static Future<void> onPlantDeleted(int plantId) async {
    try {
      await _notificationService.cancelPlantReminders(plantId);
      AppLogger.info('NotificationHelper', 'Cancelled reminders for deleted plant');
    } catch (e) {
      AppLogger.error('NotificationHelper', 'Failed to cancel reminders', e);
    }
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  static Future<DateTime?> _getLastWateringDate(int plantId) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);
      final wateredLogs = logs.where((l) => l.waterAmount != null && l.waterAmount! > 0);
      if (wateredLogs.isEmpty) return null;

      wateredLogs.toList().sort((a, b) => b.logDate.compareTo(a.logDate));
      return wateredLogs.first.logDate;
    } catch (e) {
      return null;
    }
  }

  static Future<DateTime?> _getLastFertilizingDate(int plantId) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);
      if (logs.isEmpty) return null;

      // Check log_fertilizers table for actual fertilizing
      // Use batch query to avoid N+1 problem
      final logIds = logs.where((l) => l.id != null).map((l) => l.id!).toList();
      if (logIds.isEmpty) return null;

      final fertilizersMap = await _logFertilizerRepo.findByLogs(logIds);

      // Find the most recent log that has fertilizers
      logs.sort((a, b) => b.logDate.compareTo(a.logDate));

      for (final log in logs) {
        if (log.id == null) continue;

        final fertilizers = fertilizersMap[log.id];
        if (fertilizers != null && fertilizers.isNotEmpty) {
          return log.logDate;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('NotificationHelper', 'Error getting last fertilizing date', e);
      return null;
    }
  }

  static Future<DateTime?> _getLastPhotoDate(int plantId) async {
    try {
      final photos = await _photoRepo.getPhotosByPlantId(plantId);
      if (photos.isEmpty) return null;

      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return photos.first.createdAt;
    } catch (e) {
      return null;
    }
  }

  static DateTime? _estimateHarvestDate(Plant plant) {
    // Rough estimation based on phase and seed date
    if (plant.seedDate == null) return null;

    switch (plant.phase) {
      case PlantPhase.seedling:
        // ~10 weeks from now (2 weeks seedling + 8 weeks total)
        return DateTime.now().add(const Duration(days: 70));
      case PlantPhase.veg:
        // ~6-8 weeks from now
        return DateTime.now().add(const Duration(days: 50));
      case PlantPhase.bloom:
        // ~6-8 weeks from now
        return DateTime.now().add(const Duration(days: 50));
      case PlantPhase.harvest:
        // Already in harvest phase
        return DateTime.now().add(const Duration(days: 7));
      case PlantPhase.archived:
        return null;
    }
  }
}
