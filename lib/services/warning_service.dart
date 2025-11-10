// =============================================
// GROWLOG - Warning Service
// =============================================

import '../models/plant.dart';
import '../repositories/interfaces/i_plant_log_repository.dart';
import '../repositories/interfaces/i_photo_repository.dart';
import '../utils/app_logger.dart';
import 'interfaces/i_warning_service.dart';

enum WarningLevel {
  info,
  warning,
  critical,
}

class PlantWarning {
  final String message;
  final WarningLevel level;
  final String? recommendation;
  final DateTime detectedAt;

  PlantWarning({
    required this.message,
    required this.level,
    this.recommendation,
    required this.detectedAt,
  });

  String getIcon() {
    switch (level) {
      case WarningLevel.info:
        return 'ℹ️';
      case WarningLevel.warning:
        return '⚠️';
      case WarningLevel.critical:
        return '🚨';
    }
  }
}

class WarningService implements IWarningService {
  final IPlantLogRepository _logRepo;
  final IPhotoRepository _photoRepo;

  WarningService(this._logRepo, this._photoRepo);

  /// Check for all warnings for a plant
  @override
  Future<List<PlantWarning>> checkWarnings(Plant plant) async {
    if (plant.id == null) return [];

    final warnings = <PlantWarning>[];

    try {
      // Check watering
      warnings.addAll(await _checkWateringWarnings(plant.id!));

      // Check pH/EC
      warnings.addAll(await _checkNutrientWarnings(plant.id!));

      // Check activity
      warnings.addAll(await _checkActivityWarnings(plant.id!));

      // Check photos
      warnings.addAll(await _checkPhotoWarnings(plant.id!));

      return warnings;
    } catch (e) {
      AppLogger.error('WarningService', 'Failed to check warnings', e);
      return warnings;
    }
  }

  // ============================================================
  // WARNING CHECKS
  // ============================================================

  Future<List<PlantWarning>> _checkWateringWarnings(int plantId) async {
    final warnings = <PlantWarning>[];

    try {
      final logs = await _logRepo.findByPlant(plantId);
      final waterLogs = logs.where((l) => l.waterAmount != null && l.waterAmount! > 0).toList();

      if (waterLogs.isEmpty) {
        return warnings;
      }

      waterLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final daysSinceWatering = DateTime.now().difference(waterLogs.first.logDate).inDays;

      if (daysSinceWatering >= 7) {
        warnings.add(PlantWarning(
          message: 'Lange nicht gegossen ($daysSinceWatering Tage)',
          level: WarningLevel.critical,
          recommendation: 'Prüfe Pflanze und gieße falls nötig',
          detectedAt: DateTime.now(),
        ));
      } else if (daysSinceWatering >= 4) {
        warnings.add(PlantWarning(
          message: 'Bewässerung könnte bald nötig sein',
          level: WarningLevel.warning,
          recommendation: 'Prüfe Medium-Feuchtigkeit',
          detectedAt: DateTime.now(),
        ));
      }

      // Check for extreme water amounts
      if (waterLogs.length >= 3) {
        // ✅ FIX: Store recentWaterLogs to avoid multiple evaluations and prevent division by zero
        final recentWaterLogs = waterLogs.take(10).toList();
        if (recentWaterLogs.isNotEmpty) {
          final waterAmounts = recentWaterLogs.map((l) => l.waterAmount!).toList();
          final avgWater = waterAmounts.reduce((a, b) => a + b) / waterAmounts.length;
          final lastWater = waterLogs.first.waterAmount!;

          if (lastWater > avgWater * 2) {
            warnings.add(PlantWarning(
              message: 'Letztes Gießen ungewöhnlich hoch (${lastWater.toStringAsFixed(1)}L)',
              level: WarningLevel.info,
              recommendation: 'Normale Menge: ~${avgWater.toStringAsFixed(1)}L',
              detectedAt: DateTime.now(),
            ));
          }
        }
      }
    } catch (e) {
      // Ignore
    }

    return warnings;
  }

  Future<List<PlantWarning>> _checkNutrientWarnings(int plantId) async {
    final warnings = <PlantWarning>[];

    try {
      final logs = await _logRepo.findByPlant(plantId);

      // pH warnings
      final phLogs = logs.where((l) => l.phIn != null).toList();
      if (phLogs.isNotEmpty) {
        phLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
        final latestPh = phLogs.first.phIn!;

        if (latestPh < 4.5 || latestPh > 8.0) {
          warnings.add(PlantWarning(
            message: 'pH kritisch: ${latestPh.toStringAsFixed(1)}',
            level: WarningLevel.critical,
            recommendation: 'pH sofort auf 5.8-6.5 korrigieren',
            detectedAt: DateTime.now(),
          ));
        } else if (latestPh < 5.3 || latestPh > 7.2) {
          warnings.add(PlantWarning(
            message: 'pH außerhalb optimal: ${latestPh.toStringAsFixed(1)}',
            level: WarningLevel.warning,
            recommendation: 'pH auf 5.8-6.5 anpassen',
            detectedAt: DateTime.now(),
          ));
        }

        // Check pH fluctuation
        if (phLogs.length >= 5) {
          final recentPh = phLogs.take(5).map((l) => l.phIn!).toList();
          final minPh = recentPh.reduce((a, b) => a < b ? a : b);
          final maxPh = recentPh.reduce((a, b) => a > b ? a : b);

          if ((maxPh - minPh) > 2.0) {
            warnings.add(PlantWarning(
              message: 'pH schwankt stark (${minPh.toStringAsFixed(1)} - ${maxPh.toStringAsFixed(1)})',
              level: WarningLevel.warning,
              recommendation: 'pH stabilisieren durch regelmäßige Prüfung',
              detectedAt: DateTime.now(),
            ));
          }
        }
      }

      // EC warnings
      final ecLogs = logs.where((l) => l.ecIn != null).toList();
      if (ecLogs.isNotEmpty) {
        ecLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
        final latestEc = ecLogs.first.ecIn!;

        if (latestEc > 3.5) {
          warnings.add(PlantWarning(
            message: 'EC sehr hoch: ${latestEc.toStringAsFixed(2)}',
            level: WarningLevel.critical,
            recommendation: 'Nährstoffverbrennung möglich - EC reduzieren',
            detectedAt: DateTime.now(),
          ));
        } else if (latestEc > 2.8) {
          warnings.add(PlantWarning(
            message: 'EC hoch: ${latestEc.toStringAsFixed(2)}',
            level: WarningLevel.warning,
            recommendation: 'EC überwachen, evtl. reduzieren',
            detectedAt: DateTime.now(),
          ));
        } else if (latestEc < 0.3) {
          warnings.add(PlantWarning(
            message: 'EC sehr niedrig: ${latestEc.toStringAsFixed(2)}',
            level: WarningLevel.warning,
            recommendation: 'Nährstoffgabe erhöhen',
            detectedAt: DateTime.now(),
          ));
        }

        // Check EC trend
        if (ecLogs.length >= 5) {
          final recentEc = ecLogs.take(5).map((l) => l.ecIn!).toList();
          final isIncreasing = recentEc.first > recentEc.last;
          final change = (recentEc.first - recentEc.last).abs();

          if (change > 0.5 && isIncreasing) {
            warnings.add(PlantWarning(
              message: 'EC steigt kontinuierlich',
              level: WarningLevel.warning,
              recommendation: 'Salzaufbau möglich - Flush in Betracht ziehen',
              detectedAt: DateTime.now(),
            ));
          }
        }
      }
    } catch (e) {
      // Ignore
    }

    return warnings;
  }

  Future<List<PlantWarning>> _checkActivityWarnings(int plantId) async {
    final warnings = <PlantWarning>[];

    try {
      final logs = await _logRepo.findByPlant(plantId);

      if (logs.isEmpty) {
        warnings.add(PlantWarning(
          message: 'Keine Log-Einträge vorhanden',
          level: WarningLevel.info,
          recommendation: 'Beginne mit regelmäßigem Logging',
          detectedAt: DateTime.now(),
        ));
        return warnings;
      }

      logs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final daysSinceLog = DateTime.now().difference(logs.first.logDate).inDays;

      if (daysSinceLog >= 10) {
        warnings.add(PlantWarning(
          message: 'Lange kein Log-Eintrag ($daysSinceLog Tage)',
          level: WarningLevel.warning,
          recommendation: 'Regelmäßiges Logging hilft beim Tracking',
          detectedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      // Ignore
    }

    return warnings;
  }

  Future<List<PlantWarning>> _checkPhotoWarnings(int plantId) async {
    final warnings = <PlantWarning>[];

    try {
      final photos = await _photoRepo.getPhotosByPlantId(plantId);

      if (photos.isEmpty) {
        warnings.add(PlantWarning(
          message: 'Keine Fotos vorhanden',
          level: WarningLevel.info,
          recommendation: 'Wöchentliche Fotos helfen beim Wachstums-Tracking',
          detectedAt: DateTime.now(),
        ));
        return warnings;
      }

      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final daysSincePhoto = DateTime.now().difference(photos.first.createdAt).inDays;

      if (daysSincePhoto >= 14) {
        warnings.add(PlantWarning(
          message: 'Lange kein Foto gemacht ($daysSincePhoto Tage)',
          level: WarningLevel.info,
          recommendation: 'Aktuelles Foto für Wachstums-Vergleich aufnehmen',
          detectedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      // Ignore
    }

    return warnings;
  }
}
