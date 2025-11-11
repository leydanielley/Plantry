// =============================================
// GROWLOG - Health Score Service
// =============================================

import 'dart:math';

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/health_score.dart';
import 'package:growlog_app/models/enums.dart';  // For PlantPhase
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_photo_repository.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/config/health_score_config.dart';  // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
import 'package:growlog_app/services/interfaces/i_health_score_service.dart';

class HealthScoreService implements IHealthScoreService {
  final IPlantLogRepository _logRepo;
  final IPhotoRepository _photoRepo;

  HealthScoreService(this._logRepo, this._photoRepo);

  /// Calculate health score for a plant
  @override
  Future<HealthScore> calculateHealthScore(Plant plant) async {
    if (plant.id == null) {
      return _getDefaultScore();
    }

    try {
      final factors = <String, double>{};
      final warnings = <String>[];
      final recommendations = <String>[];

      // Factor 1: Watering Regularity (30%) - Phase-specific
      final wateringScore = await _calculateWateringScore(plant.id!, plant.phase, warnings, recommendations);
      factors['watering'] = wateringScore;

      // Factor 2: pH Stability (25%)
      final phScore = await _calculatePhScore(plant.id!, warnings, recommendations);
      factors['ph_stability'] = phScore;

      // Factor 3: EC/Nutrient Trends (20%) - Phase-specific
      final ecScore = await _calculateEcScore(plant.id!, plant.phase, warnings, recommendations);
      factors['nutrient_health'] = ecScore;

      // Factor 4: Photo Documentation (15%)
      final photoScore = await _calculatePhotoScore(plant.id!, warnings, recommendations);
      factors['documentation'] = photoScore;

      // Factor 5: Log Activity (10%)
      final activityScore = await _calculateActivityScore(plant.id!, warnings, recommendations);
      factors['activity'] = activityScore;

      // Calculate weighted total score
      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      final totalScore = (
        (wateringScore * HealthScoreConfig.wateringWeight) +
        (phScore * HealthScoreConfig.phStabilityWeight) +
        (ecScore * HealthScoreConfig.ecWeight) +
        (photoScore * HealthScoreConfig.photoWeight) +
        (activityScore * HealthScoreConfig.activityWeight)
      ).round().clamp(HealthScoreConfig.minScore.toInt(), HealthScoreConfig.maxScore.toInt());

      final level = HealthScore.getLevelFromScore(totalScore);

      return HealthScore(
        score: totalScore,
        level: level,
        factors: factors,
        warnings: warnings,
        recommendations: recommendations,
        calculatedAt: DateTime.now(),
      );
    } catch (e) {
      AppLogger.error('HealthScoreService', 'Failed to calculate health score', e);
      return _getDefaultScore();
    }
  }

  // ============================================================
  // PHASE-SPECIFIC THRESHOLDS
  // ============================================================

  /// Get phase-specific watering interval thresholds (in days)
  /// ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
  Map<String, int> _getWateringThresholds(PlantPhase phase) {
    return HealthScoreConfig.getWateringThresholds(phase);
  }

  /// Get phase-specific EC/PPM acceptable ranges
  /// ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
  Map<String, double> _getEcThresholds(PlantPhase phase) {
    return HealthScoreConfig.getEcThresholds(phase);
  }

  // ============================================================
  // FACTOR CALCULATIONS
  // ============================================================

  /// Factor 1: Watering Regularity (30%) - Phase-specific thresholds
  Future<double> _calculateWateringScore(
    int plantId,
    PlantPhase phase,
    List<String> warnings,
    List<String> recommendations,
  ) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);
      final waterLogs = logs.where((l) => l.waterAmount != null && l.waterAmount! > 0).toList();

      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      if (waterLogs.isEmpty) {
        warnings.add('Noch keine Bewässerungseinträge');
        recommendations.add('Beginne mit regelmäßigem Gießen');
        return HealthScoreConfig.noWateringLogsScore;
      }

      if (waterLogs.length == 1) {
        return HealthScoreConfig.singleWateringLogScore; // Has at least one log
      }

      // Check regularity (intervals between watering)
      waterLogs.sort((a, b) => a.logDate.compareTo(b.logDate));
      final intervals = <int>[];

      for (int i = 1; i < waterLogs.length; i++) {
        final daysDiff = waterLogs[i].logDate.difference(waterLogs[i - 1].logDate).inDays;
        intervals.add(daysDiff);
      }

      // ✅ FIX: Prevent crash if intervals is empty
      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      if (intervals.isEmpty) return HealthScoreConfig.singleWateringLogScore;

      // Calculate standard deviation (measure of consistency)
      // Additional safety check to prevent reduce() crash
      if (intervals.length == 1) {
        // With only one interval, there's no variance to calculate
        final thresholds = _getWateringThresholds(phase);
        final warningDays = thresholds['warning']!;
        if (intervals.first <= warningDays) return 90.0;
        return HealthScoreConfig.insufficientPhDataScore;
      }

      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance = intervals.map((i) => (i - mean) * (i - mean)).reduce((a, b) => a + b) / intervals.length;
      final stdDev = variance.isNaN ? 0.0 : sqrt(variance);

      // Get phase-specific thresholds
      final thresholds = _getWateringThresholds(phase);
      final warningDays = thresholds['warning']!;
      final criticalDays = thresholds['critical']!;

      // Check last watering
      final daysSinceLastWater = DateTime.now().difference(waterLogs.last.logDate).inDays;

      if (daysSinceLastWater > warningDays) {
        warnings.add('Zuletzt vor $daysSinceLastWater Tagen gegossen (${phase.name} Phase)');
        recommendations.add('Prüfe, ob die Pflanze Wasser braucht');
      }

      // Score based on regularity and recency
      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      double score = HealthScoreConfig.baseScore;

      // Penalty for inconsistency
      if (stdDev > HealthScoreConfig.wateringInconsistencyStdDevThreshold) {
        score -= HealthScoreConfig.wateringInconsistencyPenalty;
        warnings.add('Unregelmäßiges Gießen');
        recommendations.add('Versuche es regelmäßiger');
      }

      // Phase-specific penalty for time since last watering
      if (daysSinceLastWater > criticalDays) {
        score -= HealthScoreConfig.wateringCriticalPenalty;
      } else if (daysSinceLastWater > warningDays) {
        score -= HealthScoreConfig.wateringWarningPenalty;
      } else if (daysSinceLastWater > (warningDays - 1)) {
        score -= HealthScoreConfig.wateringMinorPenalty;
      }

      return score.clamp(HealthScoreConfig.minScore, HealthScoreConfig.maxScore);
    } catch (e) {
      return HealthScoreConfig.defaultScore;
    }
  }

  /// Factor 2: pH Stability (25%)
  Future<double> _calculatePhScore(
    int plantId,
    List<String> warnings,
    List<String> recommendations,
  ) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);
      final phLogs = logs.where((l) => l.phIn != null).toList();

      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      if (phLogs.isEmpty) {
        return HealthScoreConfig.noPhLogsScore; // Neutral score if no pH data
      }

      if (phLogs.length < HealthScoreConfig.minPhLogsForTrend) {
        return HealthScoreConfig.insufficientPhDataScore; // Not enough data for trend
      }

      // Get recent pH values (last 10 logs)
      phLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final recentPh = phLogs.take(HealthScoreConfig.recentPhLogsCount).map((l) => l.phIn!).toList();

      // ✅ FIX: Additional safety check before reduce
      if (recentPh.isEmpty) return HealthScoreConfig.noPhLogsScore;

      // Calculate pH statistics
      final avgPh = recentPh.reduce((a, b) => a + b) / recentPh.length;
      final minPh = recentPh.reduce((a, b) => a < b ? a : b);
      final maxPh = recentPh.reduce((a, b) => a > b ? a : b);
      final range = maxPh - minPh;

      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      double score = HealthScoreConfig.baseScore;

      // Check if pH is in optimal range
      if (HealthScoreConfig.isPhInCriticalRange(avgPh)) {
        score -= HealthScoreConfig.phCriticalRangePenalty;
        warnings.add('pH außerhalb optimal (Ø ${avgPh.toStringAsFixed(1)})');
        recommendations.add('pH auf ${HealthScoreConfig.phOptimalMin}-${HealthScoreConfig.phOptimalMax} anpassen');
      } else if (!HealthScoreConfig.isPhInOptimalRange(avgPh)) {
        score -= HealthScoreConfig.phAcceptableRangePenalty;
        warnings.add('pH kann optimiert werden');
      }

      // Check pH stability
      if (range > HealthScoreConfig.phStabilityCriticalRange) {
        score -= HealthScoreConfig.phStabilityCriticalPenalty;
        warnings.add('pH schwankt stark (${minPh.toStringAsFixed(1)} - ${maxPh.toStringAsFixed(1)})');
        recommendations.add('pH stabilisieren');
      } else if (range > HealthScoreConfig.phStabilityWarningRange) {
        score -= HealthScoreConfig.phStabilityWarningPenalty;
        warnings.add('pH schwankt leicht');
      }

      return score.clamp(HealthScoreConfig.minScore, HealthScoreConfig.maxScore);
    } catch (e) {
      return HealthScoreConfig.noPhLogsScore;
    }
  }

  /// Factor 3: EC/Nutrient Health (20%)
  Future<double> _calculateEcScore(
    int plantId,
    PlantPhase phase,
    List<String> warnings,
    List<String> recommendations,
  ) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);
      final ecLogs = logs.where((l) => l.ecIn != null).toList();

      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      if (ecLogs.isEmpty) {
        return HealthScoreConfig.noEcLogsScore; // Neutral if no EC data
      }

      if (ecLogs.length < HealthScoreConfig.minEcLogsForTrend) {
        return HealthScoreConfig.insufficientEcDataScore;
      }

      // Get recent EC values
      ecLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final recentEc = ecLogs.take(HealthScoreConfig.recentEcLogsCount).map((l) => l.ecIn!).toList();

      // ✅ FIX: Additional safety check before reduce
      if (recentEc.isEmpty) return HealthScoreConfig.noEcLogsScore;

      final avgEc = recentEc.reduce((a, b) => a + b) / recentEc.length;

      // Get phase-specific EC thresholds
      final thresholds = _getEcThresholds(phase);
      final minEc = thresholds['min']!;
      final maxEc = thresholds['max']!;

      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      double score = HealthScoreConfig.baseScore;

      // Check for EC trends
      if (recentEc.length >= HealthScoreConfig.minEcLogsForTrendDetection) {
        final isIncreasing = recentEc[0] > recentEc[recentEc.length - 1];
        final change = (recentEc[0] - recentEc[recentEc.length - 1]).abs();

        if (change > HealthScoreConfig.ecTrendChangeThreshold && isIncreasing) {
          score -= HealthScoreConfig.ecTrendPenalty;
          warnings.add('EC steigt (Salzaufbau möglich)');
          recommendations.add('Flush mit pH-Wasser erwägen');
        }
      }

      // Phase-specific EC range checking
      if (avgEc > maxEc) {
        score -= HealthScoreConfig.ecOutOfRangeHighPenalty;
        warnings.add('EC zu hoch für ${phase.name} Phase (${avgEc.toStringAsFixed(2)} > $maxEc)');
        recommendations.add('EC reduzieren, um Nährstoffverbrennung zu vermeiden');
      } else if (avgEc < minEc) {
        score -= HealthScoreConfig.ecOutOfRangeLowPenalty;
        warnings.add('EC zu niedrig für ${phase.name} Phase (${avgEc.toStringAsFixed(2)} < $minEc)');
        recommendations.add('Mehr Nährstoffe geben');
      }

      return score.clamp(HealthScoreConfig.minScore, HealthScoreConfig.maxScore);
    } catch (e) {
      return HealthScoreConfig.noEcLogsScore;
    }
  }

  /// Factor 4: Photo Documentation (15%)
  Future<double> _calculatePhotoScore(
    int plantId,
    List<String> warnings,
    List<String> recommendations,
  ) async {
    try {
      final photos = await _photoRepo.getPhotosByPlantId(plantId);

      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      if (photos.isEmpty) {
        warnings.add('Noch keine Fotos');
        recommendations.add('Wöchentliche Fotos helfen beim Vergleich');
        return HealthScoreConfig.noPhotosScore;
      }

      // Check photo frequency
      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final daysSinceLastPhoto = DateTime.now().difference(photos.first.createdAt).inDays;

      double score = HealthScoreConfig.baseScore;

      if (daysSinceLastPhoto > HealthScoreConfig.photoCriticalDays) {
        score -= HealthScoreConfig.photoCriticalPenalty;
        warnings.add('Lange kein Foto gemacht ($daysSinceLastPhoto Tage)');
        recommendations.add('Aktuelles Foto aufnehmen');
      } else if (daysSinceLastPhoto > HealthScoreConfig.photoWarningDays) {
        score -= HealthScoreConfig.photoWarningPenalty;
        warnings.add('Letztes Foto vor $daysSinceLastPhoto Tagen');
      }

      // Bonus for regular photo documentation
      if (photos.length >= HealthScoreConfig.photoBonusMinCount) {
        score += HealthScoreConfig.photoBonus;
      }

      return score.clamp(HealthScoreConfig.minScore, HealthScoreConfig.maxScore);
    } catch (e) {
      return HealthScoreConfig.defaultScore;
    }
  }

  /// Factor 5: Log Activity (10%)
  Future<double> _calculateActivityScore(
    int plantId,
    List<String> warnings,
    List<String> recommendations,
  ) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);

      // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
      if (logs.isEmpty) {
        warnings.add('Noch keine Einträge');
        recommendations.add('Beginne mit regelmäßigen Einträgen');
        return HealthScoreConfig.noLogsScore;
      }

      logs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final daysSinceLastLog = DateTime.now().difference(logs.first.logDate).inDays;

      double score = HealthScoreConfig.baseScore;

      if (daysSinceLastLog > HealthScoreConfig.activityCriticalDays) {
        score -= HealthScoreConfig.activityCriticalPenalty;
        warnings.add('Lange kein Eintrag ($daysSinceLastLog Tage)');
        recommendations.add('Regelmäßige Einträge verbessern das Tracking');
      } else if (daysSinceLastLog > HealthScoreConfig.activityWarningDays) {
        score -= HealthScoreConfig.activityWarningPenalty;
      }

      // Bonus for consistent logging
      if (logs.length >= HealthScoreConfig.activityBonusMinCount) {
        score += HealthScoreConfig.activityBonus;
      }

      return score.clamp(HealthScoreConfig.minScore, HealthScoreConfig.maxScore);
    } catch (e) {
      return HealthScoreConfig.defaultScore;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  HealthScore _getDefaultScore() {
    // ✅ AUDIT FIX: Magic numbers extracted to HealthScoreConfig
    return HealthScore(
      score: HealthScoreConfig.defaultScore.toInt(),
      level: HealthLevel.fair,
      factors: {
        'watering': HealthScoreConfig.defaultScore,
        'ph_stability': HealthScoreConfig.defaultScore,
        'nutrient_health': HealthScoreConfig.defaultScore,
        'documentation': HealthScoreConfig.defaultScore,
        'activity': HealthScoreConfig.defaultScore,
      },
      warnings: ['Nicht genug Daten für Berechnung'],
      recommendations: ['Beginne mit regelmäßigem Logging'],
      calculatedAt: DateTime.now(),
    );
  }
}
