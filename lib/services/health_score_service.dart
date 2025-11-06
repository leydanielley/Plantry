// =============================================
// GROWLOG - Health Score Service
// =============================================

import '../models/plant.dart';
import '../models/health_score.dart';
import '../repositories/plant_log_repository.dart';
import '../repositories/photo_repository.dart';
import '../utils/app_logger.dart';

class HealthScoreService {
  final PlantLogRepository _logRepo = PlantLogRepository();
  final PhotoRepository _photoRepo = PhotoRepository();

  /// Calculate health score for a plant
  Future<HealthScore> calculateHealthScore(Plant plant) async {
    if (plant.id == null) {
      return _getDefaultScore();
    }

    try {
      final factors = <String, double>{};
      final warnings = <String>[];
      final recommendations = <String>[];

      // Factor 1: Watering Regularity (30%)
      final wateringScore = await _calculateWateringScore(plant.id!, warnings, recommendations);
      factors['watering'] = wateringScore;

      // Factor 2: pH Stability (25%)
      final phScore = await _calculatePhScore(plant.id!, warnings, recommendations);
      factors['ph_stability'] = phScore;

      // Factor 3: EC/Nutrient Trends (20%)
      final ecScore = await _calculateEcScore(plant.id!, warnings, recommendations);
      factors['nutrient_health'] = ecScore;

      // Factor 4: Photo Documentation (15%)
      final photoScore = await _calculatePhotoScore(plant.id!, warnings, recommendations);
      factors['documentation'] = photoScore;

      // Factor 5: Log Activity (10%)
      final activityScore = await _calculateActivityScore(plant.id!, warnings, recommendations);
      factors['activity'] = activityScore;

      // Calculate weighted total score
      final totalScore = (
        (wateringScore * 0.30) +
        (phScore * 0.25) +
        (ecScore * 0.20) +
        (photoScore * 0.15) +
        (activityScore * 0.10)
      ).round().clamp(0, 100);

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
  // FACTOR CALCULATIONS
  // ============================================================

  /// Factor 1: Watering Regularity (30%)
  Future<double> _calculateWateringScore(
    int plantId,
    List<String> warnings,
    List<String> recommendations,
  ) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);
      final waterLogs = logs.where((l) => l.waterAmount != null && l.waterAmount! > 0).toList();

      if (waterLogs.isEmpty) {
        warnings.add('Noch keine Bewässerungseinträge');
        recommendations.add('Beginne mit regelmäßigem Gießen');
        return 50.0;
      }

      if (waterLogs.length == 1) {
        return 70.0; // Has at least one log
      }

      // Check regularity (intervals between watering)
      waterLogs.sort((a, b) => a.logDate.compareTo(b.logDate));
      final intervals = <int>[];

      for (int i = 1; i < waterLogs.length; i++) {
        final daysDiff = waterLogs[i].logDate.difference(waterLogs[i - 1].logDate).inDays;
        intervals.add(daysDiff);
      }

      if (intervals.isEmpty) return 70.0;

      // Calculate standard deviation (measure of consistency)
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance = intervals.map((i) => (i - mean) * (i - mean)).reduce((a, b) => a + b) / intervals.length;
      final stdDev = variance.isNaN ? 0.0 : variance;

      // Check last watering
      final daysSinceLastWater = DateTime.now().difference(waterLogs.last.logDate).inDays;

      if (daysSinceLastWater > 5) {
        warnings.add('Zuletzt vor $daysSinceLastWater Tagen gegossen');
        recommendations.add('Prüfe, ob die Pflanze Wasser braucht');
      }

      // Score based on regularity and recency
      double score = 100.0;

      // Penalty for inconsistency
      if (stdDev > 2.0) {
        score -= 20;
        warnings.add('Unregelmäßiges Gießen');
        recommendations.add('Versuche es regelmäßiger');
      }

      // Penalty for long time since last watering
      if (daysSinceLastWater > 7) {
        score -= 30;
      } else if (daysSinceLastWater > 5) {
        score -= 15;
      } else if (daysSinceLastWater > 3) {
        score -= 5;
      }

      return score.clamp(0, 100);
    } catch (e) {
      return 50.0;
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

      if (phLogs.isEmpty) {
        return 70.0; // Neutral score if no pH data
      }

      if (phLogs.length < 3) {
        return 75.0; // Not enough data for trend
      }

      // Get recent pH values (last 10 logs)
      phLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final recentPh = phLogs.take(10).map((l) => l.phIn!).toList();

      // Calculate pH statistics
      final avgPh = recentPh.reduce((a, b) => a + b) / recentPh.length;
      final minPh = recentPh.reduce((a, b) => a < b ? a : b);
      final maxPh = recentPh.reduce((a, b) => a > b ? a : b);
      final range = maxPh - minPh;

      double score = 100.0;

      // Check if pH is in optimal range (5.5-6.5 for hydro, 6.0-7.0 for soil)
      if (avgPh < 5.0 || avgPh > 7.5) {
        score -= 30;
        warnings.add('pH außerhalb optimal (Ø ${avgPh.toStringAsFixed(1)})');
        recommendations.add('pH auf 5.8-6.5 anpassen');
      } else if (avgPh < 5.5 || avgPh > 7.0) {
        score -= 15;
        warnings.add('pH kann optimiert werden');
      }

      // Check pH stability
      if (range > 2.0) {
        score -= 25;
        warnings.add('pH schwankt stark (${minPh.toStringAsFixed(1)} - ${maxPh.toStringAsFixed(1)})');
        recommendations.add('pH stabilisieren');
      } else if (range > 1.0) {
        score -= 10;
        warnings.add('pH schwankt leicht');
      }

      return score.clamp(0, 100);
    } catch (e) {
      return 70.0;
    }
  }

  /// Factor 3: EC/Nutrient Health (20%)
  Future<double> _calculateEcScore(
    int plantId,
    List<String> warnings,
    List<String> recommendations,
  ) async {
    try {
      final logs = await _logRepo.findByPlant(plantId);
      final ecLogs = logs.where((l) => l.ecIn != null).toList();

      if (ecLogs.isEmpty) {
        return 70.0; // Neutral if no EC data
      }

      if (ecLogs.length < 3) {
        return 75.0;
      }

      // Get recent EC values
      ecLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final recentEc = ecLogs.take(10).map((l) => l.ecIn!).toList();

      final avgEc = recentEc.reduce((a, b) => a + b) / recentEc.length;

      double score = 100.0;

      // Check for EC trends
      if (recentEc.length >= 3) {
        final isIncreasing = recentEc[0] > recentEc[recentEc.length - 1];
        final change = (recentEc[0] - recentEc[recentEc.length - 1]).abs();

        if (change > 0.5 && isIncreasing) {
          score -= 15;
          warnings.add('EC steigt (Salzaufbau möglich)');
          recommendations.add('Flush mit pH-Wasser erwägen');
        }
      }

      // Check if EC is reasonable
      if (avgEc > 3.0) {
        score -= 25;
        warnings.add('EC sehr hoch (${avgEc.toStringAsFixed(2)})');
        recommendations.add('EC reduzieren, um Nährstoffverbrennung zu vermeiden');
      } else if (avgEc < 0.3) {
        score -= 15;
        warnings.add('EC sehr niedrig');
        recommendations.add('Mehr Nährstoffe geben');
      }

      return score.clamp(0, 100);
    } catch (e) {
      return 70.0;
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

      if (photos.isEmpty) {
        warnings.add('Noch keine Fotos');
        recommendations.add('Wöchentliche Fotos helfen beim Vergleich');
        return 40.0;
      }

      // Check photo frequency
      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final daysSinceLastPhoto = DateTime.now().difference(photos.first.createdAt).inDays;

      double score = 100.0;

      if (daysSinceLastPhoto > 14) {
        score -= 40;
        warnings.add('Lange kein Foto gemacht ($daysSinceLastPhoto Tage)');
        recommendations.add('Aktuelles Foto aufnehmen');
      } else if (daysSinceLastPhoto > 7) {
        score -= 20;
        warnings.add('Letztes Foto vor $daysSinceLastPhoto Tagen');
      }

      // Bonus for regular photo documentation
      if (photos.length >= 5) {
        score += 10;
      }

      return score.clamp(0, 100);
    } catch (e) {
      return 50.0;
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

      if (logs.isEmpty) {
        warnings.add('Noch keine Einträge');
        recommendations.add('Beginne mit regelmäßigen Einträgen');
        return 30.0;
      }

      logs.sort((a, b) => b.logDate.compareTo(a.logDate));
      final daysSinceLastLog = DateTime.now().difference(logs.first.logDate).inDays;

      double score = 100.0;

      if (daysSinceLastLog > 7) {
        score -= 50;
        warnings.add('Lange kein Eintrag ($daysSinceLastLog Tage)');
        recommendations.add('Regelmäßige Einträge verbessern das Tracking');
      } else if (daysSinceLastLog > 3) {
        score -= 20;
      }

      // Bonus for consistent logging
      if (logs.length >= 10) {
        score += 10;
      }

      return score.clamp(0, 100);
    } catch (e) {
      return 50.0;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  HealthScore _getDefaultScore() {
    return HealthScore(
      score: 50,
      level: HealthLevel.fair,
      factors: {
        'watering': 50.0,
        'ph_stability': 50.0,
        'nutrient_health': 50.0,
        'documentation': 50.0,
        'activity': 50.0,
      },
      warnings: ['Nicht genug Daten für Berechnung'],
      recommendations: ['Beginne mit regelmäßigem Logging'],
      calculatedAt: DateTime.now(),
    );
  }
}
