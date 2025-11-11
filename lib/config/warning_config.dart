// =============================================
// GROWLOG - Warning Service Configuration
// ✅ AUDIT FIX: Centralized magic numbers from warning_service.dart
// =============================================

/// Configuration constants for plant warning system
///
/// Centralizes all threshold values and limits used in
/// warning detection to prevent magic numbers.
class WarningConfig {
  // ═══════════════════════════════════════════
  // WATERING THRESHOLDS (in days)
  // ═══════════════════════════════════════════

  /// Days since watering to trigger critical warning
  static const int wateringCriticalDays = 7;

  /// Days since watering to trigger warning
  static const int wateringWarningDays = 4;

  /// Number of recent watering logs to analyze for trends
  static const int recentWaterLogsCount = 10;

  /// Minimum watering logs needed for trend analysis
  static const int minWaterLogsForTrend = 3;

  /// Water amount multiplier for abnormality detection (2x average)
  static const double waterAmountAbnormalityMultiplier = 2.0;

  // ═══════════════════════════════════════════
  // PH THRESHOLDS
  // ═══════════════════════════════════════════

  /// Critical pH minimum (below 4.5 is critical)
  static const double phCriticalMin = 4.5;

  /// Critical pH maximum (above 8.0 is critical)
  static const double phCriticalMax = 8.0;

  /// Warning pH minimum (below 5.3 triggers warning)
  static const double phWarningMin = 5.3;

  /// Warning pH maximum (above 7.2 triggers warning)
  static const double phWarningMax = 7.2;

  /// Optimal pH minimum for recommendation
  static const double phOptimalMin = 5.8;

  /// Optimal pH maximum for recommendation
  static const double phOptimalMax = 6.5;

  /// Minimum pH logs needed for fluctuation analysis
  static const int minPhLogsForFluctuation = 5;

  /// Number of recent pH logs to analyze
  static const int recentPhLogsCount = 5;

  /// pH range threshold for fluctuation warning
  static const double phFluctuationWarningRange = 2.0;

  // ═══════════════════════════════════════════
  // EC/PPM THRESHOLDS
  // ═══════════════════════════════════════════

  /// Critical EC maximum (above 3.5 is critical)
  static const double ecCriticalMax = 3.5;

  /// Warning EC maximum (above 2.8 triggers warning)
  static const double ecWarningMax = 2.8;

  /// Warning EC minimum (below 0.3 is too low)
  static const double ecWarningMin = 0.3;

  /// Minimum EC logs needed for trend analysis
  static const int minEcLogsForTrend = 5;

  /// Number of recent EC logs to analyze
  static const int recentEcLogsCount = 5;

  /// EC change threshold to detect rising trend
  static const double ecTrendChangeThreshold = 0.5;

  // ═══════════════════════════════════════════
  // ACTIVITY THRESHOLDS (in days)
  // ═══════════════════════════════════════════

  /// Days since last log entry to trigger warning
  static const int activityWarningDays = 10;

  // ═══════════════════════════════════════════
  // PHOTO THRESHOLDS (in days)
  // ═══════════════════════════════════════════

  /// Days since last photo to trigger info message
  static const int photoInfoDays = 14;

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Check if pH is in critical range
  static bool isPhCritical(double ph) =>
      ph < phCriticalMin || ph > phCriticalMax;

  /// Check if pH should trigger warning
  static bool isPhWarning(double ph) => ph < phWarningMin || ph > phWarningMax;

  /// Check if pH is in optimal range
  static bool isPhOptimal(double ph) =>
      ph >= phOptimalMin && ph <= phOptimalMax;

  /// Check if EC is critical
  static bool isEcCritical(double ec) => ec > ecCriticalMax;

  /// Check if EC should trigger warning
  static bool isEcWarning(double ec) => ec > ecWarningMax || ec < ecWarningMin;

  /// Check if pH fluctuation is concerning
  static bool isPhFluctuationConcerning(double range) =>
      range > phFluctuationWarningRange;

  /// Check if EC trend change is significant
  static bool isEcTrendSignificant(double change) =>
      change > ecTrendChangeThreshold;
}
