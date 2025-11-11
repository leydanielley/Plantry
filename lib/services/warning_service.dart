// =============================================
// GROWLOG - Warning Service
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_photo_repository.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/config/warning_config.dart'; // ✅ AUDIT FIX: Magic numbers extracted to WarningConfig
import 'package:growlog_app/services/interfaces/i_warning_service.dart';

enum WarningLevel { info, warning, critical }

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
      final waterLogs = logs
          .where((l) => l.waterAmount != null && l.waterAmount! > 0)
          .toList();

      if (waterLogs.isEmpty) {
        return warnings;
      }

      waterLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final daysSinceWatering = DateTime.now()
          .difference(waterLogs.first.logDate)
          .inDays;

      // ✅ AUDIT FIX: Magic numbers extracted to WarningConfig
      if (daysSinceWatering >= WarningConfig.wateringCriticalDays) {
        warnings.add(
          PlantWarning(
            message: 'Lange nicht gegossen ($daysSinceWatering Tage)',
            level: WarningLevel.critical,
            recommendation: 'Prüfe Pflanze und gieße falls nötig',
            detectedAt: DateTime.now(),
          ),
        );
      } else if (daysSinceWatering >= WarningConfig.wateringWarningDays) {
        warnings.add(
          PlantWarning(
            message: 'Bewässerung könnte bald nötig sein',
            level: WarningLevel.warning,
            recommendation: 'Prüfe Medium-Feuchtigkeit',
            detectedAt: DateTime.now(),
          ),
        );
      }

      // Check for extreme water amounts
      if (waterLogs.length >= WarningConfig.minWaterLogsForTrend) {
        // ✅ FIX: Store recentWaterLogs to avoid multiple evaluations and prevent division by zero
        final recentWaterLogs = waterLogs
            .take(WarningConfig.recentWaterLogsCount)
            .toList();
        if (recentWaterLogs.isNotEmpty) {
          // ✅ FIX: Filter out null waterAmount values
          final waterAmounts = recentWaterLogs
              .where((l) => l.waterAmount != null)
              .map((l) => l.waterAmount!)
              .toList();

          if (waterAmounts.isEmpty)
            return warnings; // ✅ FIX: No data to analyze

          final avgWater =
              waterAmounts.reduce((a, b) => a + b) / waterAmounts.length;
          final lastWater = waterLogs.first.waterAmount;

          // ✅ FIX: Check if lastWater is not null before comparison
          if (lastWater != null &&
              lastWater >
                  avgWater * WarningConfig.waterAmountAbnormalityMultiplier) {
            warnings.add(
              PlantWarning(
                message:
                    'Letztes Gießen ungewöhnlich hoch (${lastWater.toStringAsFixed(1)}L)',
                level: WarningLevel.info,
                recommendation:
                    'Normale Menge: ~${avgWater.toStringAsFixed(1)}L',
                detectedAt: DateTime.now(),
              ),
            );
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
      // ✅ AUDIT FIX: Magic numbers extracted to WarningConfig
      final phLogs = logs.where((l) => l.phIn != null).toList();
      if (phLogs.isNotEmpty) {
        phLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
        final latestPh = phLogs.first.phIn;

        // ✅ FIX: Check if pH is not null before using
        if (latestPh == null) return warnings;

        if (WarningConfig.isPhCritical(latestPh)) {
          warnings.add(
            PlantWarning(
              message: 'pH kritisch: ${latestPh.toStringAsFixed(1)}',
              level: WarningLevel.critical,
              recommendation:
                  'pH sofort auf ${WarningConfig.phOptimalMin}-${WarningConfig.phOptimalMax} korrigieren',
              detectedAt: DateTime.now(),
            ),
          );
        } else if (WarningConfig.isPhWarning(latestPh)) {
          warnings.add(
            PlantWarning(
              message: 'pH außerhalb optimal: ${latestPh.toStringAsFixed(1)}',
              level: WarningLevel.warning,
              recommendation:
                  'pH auf ${WarningConfig.phOptimalMin}-${WarningConfig.phOptimalMax} anpassen',
              detectedAt: DateTime.now(),
            ),
          );
        }

        // Check pH fluctuation
        if (phLogs.length >= WarningConfig.minPhLogsForFluctuation) {
          // ✅ FIX: Filter out null pH values before mapping to prevent crash
          final recentPh = phLogs
              .take(WarningConfig.recentPhLogsCount)
              .where((l) => l.phIn != null)
              .map((l) => l.phIn!)
              .toList();

          // ✅ FIX: Check if we have data after filtering
          if (recentPh.isEmpty) {
            return warnings;
          }

          final minPh = recentPh.reduce((a, b) => a < b ? a : b);
          final maxPh = recentPh.reduce((a, b) => a > b ? a : b);
          final range = maxPh - minPh;

          if (WarningConfig.isPhFluctuationConcerning(range)) {
            warnings.add(
              PlantWarning(
                message:
                    'pH schwankt stark (${minPh.toStringAsFixed(1)} - ${maxPh.toStringAsFixed(1)})',
                level: WarningLevel.warning,
                recommendation: 'pH stabilisieren durch regelmäßige Prüfung',
                detectedAt: DateTime.now(),
              ),
            );
          }
        }
      }

      // EC warnings
      // ✅ AUDIT FIX: Magic numbers extracted to WarningConfig
      final ecLogs = logs.where((l) => l.ecIn != null).toList();
      if (ecLogs.isNotEmpty) {
        ecLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
        final latestEc = ecLogs.first.ecIn;

        // ✅ FIX: Check if EC is not null before using
        if (latestEc == null) return warnings;

        if (WarningConfig.isEcCritical(latestEc)) {
          warnings.add(
            PlantWarning(
              message: 'EC sehr hoch: ${latestEc.toStringAsFixed(2)}',
              level: WarningLevel.critical,
              recommendation: 'Nährstoffverbrennung möglich - EC reduzieren',
              detectedAt: DateTime.now(),
            ),
          );
        } else if (WarningConfig.isEcWarning(latestEc)) {
          if (latestEc > WarningConfig.ecWarningMax) {
            warnings.add(
              PlantWarning(
                message: 'EC hoch: ${latestEc.toStringAsFixed(2)}',
                level: WarningLevel.warning,
                recommendation: 'EC überwachen, evtl. reduzieren',
                detectedAt: DateTime.now(),
              ),
            );
          } else {
            warnings.add(
              PlantWarning(
                message: 'EC sehr niedrig: ${latestEc.toStringAsFixed(2)}',
                level: WarningLevel.warning,
                recommendation: 'Nährstoffgabe erhöhen',
                detectedAt: DateTime.now(),
              ),
            );
          }
        }

        // Check EC trend
        if (ecLogs.length >= WarningConfig.minEcLogsForTrend) {
          // ✅ FIX: Filter out null EC values before mapping to prevent crash
          final recentEc = ecLogs
              .take(WarningConfig.recentEcLogsCount)
              .where((l) => l.ecIn != null)
              .map((l) => l.ecIn!)
              .toList();

          // ✅ FIX: Check if we have at least 2 values for trend analysis
          if (recentEc.length < 2) {
            return warnings;
          }

          final isIncreasing = recentEc.first > recentEc.last;
          final change = (recentEc.first - recentEc.last).abs();

          if (WarningConfig.isEcTrendSignificant(change) && isIncreasing) {
            warnings.add(
              PlantWarning(
                message: 'EC steigt kontinuierlich',
                level: WarningLevel.warning,
                recommendation: 'Salzaufbau möglich - Flush in Betracht ziehen',
                detectedAt: DateTime.now(),
              ),
            );
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
        warnings.add(
          PlantWarning(
            message: 'Keine Log-Einträge vorhanden',
            level: WarningLevel.info,
            recommendation: 'Beginne mit regelmäßigem Logging',
            detectedAt: DateTime.now(),
          ),
        );
        return warnings;
      }

      logs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final daysSinceLog = DateTime.now().difference(logs.first.logDate).inDays;

      // ✅ AUDIT FIX: Magic numbers extracted to WarningConfig
      if (daysSinceLog >= WarningConfig.activityWarningDays) {
        warnings.add(
          PlantWarning(
            message: 'Lange kein Log-Eintrag ($daysSinceLog Tage)',
            level: WarningLevel.warning,
            recommendation: 'Regelmäßiges Logging hilft beim Tracking',
            detectedAt: DateTime.now(),
          ),
        );
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
        warnings.add(
          PlantWarning(
            message: 'Keine Fotos vorhanden',
            level: WarningLevel.info,
            recommendation: 'Wöchentliche Fotos helfen beim Wachstums-Tracking',
            detectedAt: DateTime.now(),
          ),
        );
        return warnings;
      }

      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final daysSincePhoto = DateTime.now()
          .difference(photos.first.createdAt)
          .inDays;

      // ✅ AUDIT FIX: Magic numbers extracted to WarningConfig
      if (daysSincePhoto >= WarningConfig.photoInfoDays) {
        warnings.add(
          PlantWarning(
            message: 'Lange kein Foto gemacht ($daysSincePhoto Tage)',
            level: WarningLevel.info,
            recommendation: 'Aktuelles Foto für Wachstums-Vergleich aufnehmen',
            detectedAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // Ignore
    }

    return warnings;
  }
}
