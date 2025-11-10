// =============================================
// GROWLOG - Health Score Configuration
// =============================================
// ✅ PHASE 2 FIX: Centralized health score calculation constants

/// Health score calculation weights, thresholds, and defaults
class HealthConfig {
  // ============================================================
  // HEALTH SCORE WEIGHTS (Must sum to 1.0)
  // ============================================================

  static const double wateringWeight = 0.30;        // 30% - Most important factor
  static const double phStabilityWeight = 0.25;     // 25% - pH balance critical
  static const double nutrientHealthWeight = 0.20;  // 20% - EC/PPM levels
  static const double documentationWeight = 0.15;   // 15% - Photo tracking
  static const double activityWeight = 0.10;        // 10% - Log frequency

  // ============================================================
  // HEALTH LEVEL THRESHOLDS (0-100)
  // ============================================================

  static const int excellentThreshold = 90;  // 90-100
  static const int goodThreshold = 70;       // 70-89
  static const int fairThreshold = 50;       // 50-69
  static const int poorThreshold = 30;       // 30-49
  // Below 30 = critical

  // ============================================================
  // WATERING THRESHOLDS (in days) - Phase-specific
  // ============================================================

  // Seedling phase (needs frequent watering)
  static const int seedlingWateringWarningDays = 2;
  static const int seedlingWateringCriticalDays = 3;

  // Vegetative phase (moderate watering)
  static const int vegWateringWarningDays = 3;
  static const int vegWateringCriticalDays = 5;

  // Bloom phase (consistent watering needed)
  static const int bloomWateringWarningDays = 2;
  static const int bloomWateringCriticalDays = 4;

  // Harvest/Archived phase (less critical)
  static const int harvestWateringWarningDays = 7;
  static const int harvestWateringCriticalDays = 14;

  // ============================================================
  // EC/PPM THRESHOLDS - Phase-specific
  // ============================================================

  // Seedling phase (low EC)
  static const double seedlingEcMin = 0.3;
  static const double seedlingEcMax = 1.2;

  // Vegetative phase (moderate EC)
  static const double vegEcMin = 0.8;
  static const double vegEcMax = 2.0;

  // Bloom phase (higher EC)
  static const double bloomEcMin = 1.0;
  static const double bloomEcMax = 2.5;

  // Harvest/Archived phase (less strict)
  static const double harvestEcMin = 0.0;
  static const double harvestEcMax = 3.0;

  // ============================================================
  // pH THRESHOLDS
  // ============================================================

  // Optimal pH range (hydroponic systems)
  static const double phOptimalMin = 5.5;
  static const double phOptimalMax = 6.5;

  // Soil pH range (if applicable)
  static const double phSoilMin = 6.0;
  static const double phSoilMax = 7.0;

  // Critical pH thresholds (outside = major problems)
  static const double phCriticalMin = 5.0;
  static const double phCriticalMax = 7.5;

  // pH Stability ranges
  static const double phStabilityWarning = 1.0;   // pH fluctuation > 1.0 = warning
  static const double phStabilityCritical = 2.0;  // pH fluctuation > 2.0 = critical

  // ============================================================
  // PHOTO DOCUMENTATION THRESHOLDS
  // ============================================================

  static const int photoWarningDays = 7;           // 7 days without photo = warning
  static const int photoCriticalDays = 14;         // 14 days without photo = critical
  static const int photoCountBonus = 5;            // 5+ photos = bonus score

  // ============================================================
  // ACTIVITY/LOGGING THRESHOLDS
  // ============================================================

  static const int activityWarningDays = 3;        // 3 days without log = warning
  static const int activityCriticalDays = 7;       // 7 days without log = critical
  static const int activityCountBonus = 10;        // 10+ logs = bonus score

  // ============================================================
  // SCORE CALCULATION PARAMETERS
  // ============================================================

  // Watering consistency
  static const double wateringStdDevThreshold = 2.0;  // Standard deviation > 2.0 = inconsistent

  // EC trend detection
  static const double ecTrendChangeThreshold = 0.5;   // EC change > 0.5 = significant trend

  // Number of recent values to analyze
  static const int recentValuesCount = 10;            // Use last 10 logs for calculations

  // ============================================================
  // SCORE PENALTIES (negative adjustments)
  // ============================================================

  // Watering penalties
  static const double wateringInconsistencyPenalty = 20.0;
  static const double wateringCriticalPenalty = 30.0;
  static const double wateringWarningPenalty = 15.0;
  static const double wateringMinorPenalty = 5.0;

  // pH penalties
  static const double phCriticalRangePenalty = 30.0;
  static const double phSuboptimalRangePenalty = 15.0;
  static const double phCriticalFluctuationPenalty = 25.0;
  static const double phMinorFluctuationPenalty = 10.0;

  // EC penalties
  static const double ecOutOfRangeMajorPenalty = 25.0;
  static const double ecOutOfRangeMinorPenalty = 15.0;
  static const double ecTrendPenalty = 15.0;

  // Photo penalties
  static const double photoCriticalPenalty = 40.0;
  static const double photoWarningPenalty = 20.0;

  // Activity penalties
  static const double activityCriticalPenalty = 50.0;
  static const double activityWarningPenalty = 20.0;

  // ============================================================
  // SCORE BONUSES (positive adjustments)
  // ============================================================

  static const double photoCountBonusPoints = 10.0;
  static const double activityCountBonusPoints = 10.0;

  // ============================================================
  // DEFAULT SCORES (when insufficient data)
  // ============================================================

  static const double defaultScoreNoData = 50.0;
  static const double defaultScoreMinimalData = 70.0;
  static const double defaultScoreSingleEntry = 75.0;
  static const double defaultScorePhotoNone = 40.0;
  static const double defaultScoreActivityNone = 30.0;

  // ============================================================
  // MINIMUM DATA REQUIREMENTS
  // ============================================================

  static const int minLogsForTrendAnalysis = 3;

  // Private constructor to prevent instantiation
  HealthConfig._();
}
