// =============================================
// GROWLOG - Health Score Configuration
// ✅ AUDIT FIX: Centralized magic numbers from health_score_service.dart
// =============================================

import 'package:growlog_app/models/enums.dart';

/// Configuration constants for health score calculations
///
/// Centralizes all scoring weights, thresholds, and penalties used in
/// plant health score calculations to prevent magic numbers.
class HealthScoreConfig {
  // ═══════════════════════════════════════════
  // SCORING WEIGHTS (Must sum to 1.0)
  // ═══════════════════════════════════════════

  /// Weight for watering regularity factor (30%)
  static const double wateringWeight = 0.30;

  /// Weight for pH stability factor (25%)
  static const double phStabilityWeight = 0.25;

  /// Weight for EC/nutrient trends factor (20%)
  static const double ecWeight = 0.20;

  /// Weight for photo documentation factor (15%)
  static const double photoWeight = 0.15;

  /// Weight for log activity factor (10%)
  static const double activityWeight = 0.10;

  // ═══════════════════════════════════════════
  // WATERING THRESHOLDS (Phase-specific, in days)
  // ═══════════════════════════════════════════

  // Seedling phase
  static const int seedlingWateringWarningDays = 2;
  static const int seedlingWateringCriticalDays = 3;

  // Vegetative phase
  static const int vegWateringWarningDays = 3;
  static const int vegWateringCriticalDays = 5;

  // Bloom phase
  static const int bloomWateringWarningDays = 2;
  static const int bloomWateringCriticalDays = 4;

  // Harvest/Archived phase
  static const int harvestWateringWarningDays = 7;
  static const int harvestWateringCriticalDays = 14;

  // ═══════════════════════════════════════════
  // EC/PPM THRESHOLDS (Phase-specific)
  // ═══════════════════════════════════════════

  // Seedling phase
  static const double seedlingEcMin = 0.3;
  static const double seedlingEcMax = 1.2;

  // Vegetative phase
  static const double vegEcMin = 0.8;
  static const double vegEcMax = 2.0;

  // Bloom phase
  static const double bloomEcMin = 1.0;
  static const double bloomEcMax = 2.5;

  // Harvest/Archived phase
  static const double harvestEcMin = 0.0;
  static const double harvestEcMax = 3.0;

  // ═══════════════════════════════════════════
  // PH RANGES
  // ═══════════════════════════════════════════

  /// Optimal pH minimum (5.5)
  static const double phOptimalMin = 5.5;

  /// Optimal pH maximum (6.5 for hydro)
  static const double phOptimalMax = 6.5;

  /// Acceptable pH minimum (5.0)
  static const double phAcceptableMin = 5.0;

  /// Acceptable pH maximum (7.0 for soil)
  static const double phAcceptableMax = 7.0;

  /// Critical pH minimum (below 5.0 is bad)
  static const double phCriticalMin = 5.0;

  /// Critical pH maximum (above 7.5 is bad)
  static const double phCriticalMax = 7.5;

  /// pH range threshold for stability warning (>1.0)
  static const double phStabilityWarningRange = 1.0;

  /// pH range threshold for critical stability warning (>2.0)
  static const double phStabilityCriticalRange = 2.0;

  // ═══════════════════════════════════════════
  // SCORING PENALTIES & BONUSES
  // ═══════════════════════════════════════════

  // Watering penalties
  static const double wateringInconsistencyPenalty = 20.0;
  static const double wateringInconsistencyStdDevThreshold = 2.0;
  static const double wateringCriticalPenalty = 30.0;
  static const double wateringWarningPenalty = 15.0;
  static const double wateringMinorPenalty = 5.0;

  // pH penalties
  static const double phCriticalRangePenalty = 30.0;
  static const double phAcceptableRangePenalty = 15.0;
  static const double phStabilityCriticalPenalty = 25.0;
  static const double phStabilityWarningPenalty = 10.0;

  // EC penalties
  static const double ecTrendPenalty = 15.0;
  static const double ecTrendChangeThreshold = 0.5;
  static const double ecOutOfRangeHighPenalty = 25.0;
  static const double ecOutOfRangeLowPenalty = 15.0;

  // Photo penalties
  static const double photoNoPhotoPenalty = 60.0;
  static const double photoCriticalPenalty = 40.0;
  static const double photoWarningPenalty = 20.0;
  static const int photoCriticalDays = 14;
  static const int photoWarningDays = 7;
  static const double photoBonus = 10.0;
  static const int photoBonusMinCount = 5;

  // Activity penalties
  static const double activityCriticalPenalty = 50.0;
  static const double activityWarningPenalty = 20.0;
  static const int activityCriticalDays = 7;
  static const int activityWarningDays = 3;
  static const double activityBonus = 10.0;
  static const int activityBonusMinCount = 10;

  // ═══════════════════════════════════════════
  // DEFAULT SCORES
  // ═══════════════════════════════════════════

  /// Default score when no data available
  static const double defaultScore = 50.0;

  /// Default score when no watering logs exist
  static const double noWateringLogsScore = 50.0;

  /// Score for having at least one watering log
  static const double singleWateringLogScore = 70.0;

  /// Default score for no pH logs
  static const double noPhLogsScore = 70.0;

  /// Score when not enough pH data for trends
  static const double insufficientPhDataScore = 75.0;

  /// Default score for no EC logs
  static const double noEcLogsScore = 70.0;

  /// Score when not enough EC data for trends
  static const double insufficientEcDataScore = 75.0;

  /// Score for no photos
  static const double noPhotosScore = 40.0;

  /// Score for no logs
  static const double noLogsScore = 30.0;

  /// Base score before penalties
  static const double baseScore = 100.0;

  /// Maximum possible score
  static const double maxScore = 100.0;

  /// Minimum possible score
  static const double minScore = 0.0;

  // ═══════════════════════════════════════════
  // DATA THRESHOLDS
  // ═══════════════════════════════════════════

  /// Minimum pH logs needed for trend analysis
  static const int minPhLogsForTrend = 3;

  /// Number of recent pH values to analyze
  static const int recentPhLogsCount = 10;

  /// Minimum EC logs needed for trend analysis
  static const int minEcLogsForTrend = 3;

  /// Number of recent EC values to analyze
  static const int recentEcLogsCount = 10;

  /// Minimum EC logs needed for trend detection
  static const int minEcLogsForTrendDetection = 3;

  /// Number of recent water amounts to compare
  static const int recentWaterLogsCount = 10;

  /// Water amount multiplier for abnormality detection
  static const double waterAmountAbnormalityMultiplier = 2.0;

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Get phase-specific watering thresholds
  static Map<String, int> getWateringThresholds(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return {
          'warning': seedlingWateringWarningDays,
          'critical': seedlingWateringCriticalDays,
        };
      case PlantPhase.veg:
        return {
          'warning': vegWateringWarningDays,
          'critical': vegWateringCriticalDays,
        };
      case PlantPhase.bloom:
        return {
          'warning': bloomWateringWarningDays,
          'critical': bloomWateringCriticalDays,
        };
      case PlantPhase.harvest:
      case PlantPhase.archived:
        return {
          'warning': harvestWateringWarningDays,
          'critical': harvestWateringCriticalDays,
        };
    }
  }

  /// Get phase-specific EC thresholds
  static Map<String, double> getEcThresholds(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return {'min': seedlingEcMin, 'max': seedlingEcMax};
      case PlantPhase.veg:
        return {'min': vegEcMin, 'max': vegEcMax};
      case PlantPhase.bloom:
        return {'min': bloomEcMin, 'max': bloomEcMax};
      case PlantPhase.harvest:
      case PlantPhase.archived:
        return {'min': harvestEcMin, 'max': harvestEcMax};
    }
  }

  /// Check if pH is in optimal range
  static bool isPhInOptimalRange(double ph) =>
      ph >= phOptimalMin && ph <= phOptimalMax;

  /// Check if pH is in acceptable range
  static bool isPhInAcceptableRange(double ph) =>
      ph >= phAcceptableMin && ph <= phAcceptableMax;

  /// Check if pH is in critical range
  static bool isPhInCriticalRange(double ph) =>
      ph < phCriticalMin || ph > phCriticalMax;
}
