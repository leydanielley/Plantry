// =============================================
// GROWLOG - Nutrient Calculation Configuration
// ✅ AUDIT FIX: Centralized magic numbers from nutrient_calculation.dart
// =============================================

/// Configuration constants for nutrient calculations
///
/// Centralizes all threshold values and scaling factors used in
/// nutrient mixing calculations to prevent magic numbers.
class NutrientCalculationConfig {
  // ═══════════════════════════════════════════
  // SCALING FACTORS
  // ═══════════════════════════════════════════

  /// Minimum scaling factor for moderate scaling warning (1.2x recipe)
  /// Example: Recipe is 1000 PPM, scaling to 1200 PPM triggers moderate warning
  static const double moderateScalingMin = 1.2;

  /// Maximum scaling factor before high scaling warning (1.5x recipe)
  /// Example: Recipe is 1000 PPM, scaling to 1500 PPM is still moderate
  static const double moderateScalingMax = 1.5;

  /// Scaling factor threshold for high/dangerous scaling (>1.5x recipe)
  /// Above this value can lead to nutrient burn
  /// Example: Recipe is 1000 PPM, scaling above 1500 PPM is dangerous
  static const double highScalingThreshold = 1.5;

  /// Scaling factor threshold for downscaling warning (<0.8x recipe)
  /// Below this value indicates significant recipe adjustment
  /// Example: Recipe is 1000 PPM, scaling below 800 PPM triggers warning
  static const double downScalingThreshold = 0.8;

  // ═══════════════════════════════════════════
  // PPM THRESHOLDS
  // ═══════════════════════════════════════════

  /// High PPM threshold (3000 PPM) - triggers warning
  /// Acceptable but requires caution, suitable for late bloom
  static const double highPpmMin = 3000.0;

  /// High PPM maximum (5000 PPM) - still in warning range
  /// Very high but technically possible for some advanced grows
  static const double highPpmMax = 5000.0;

  /// Extreme PPM threshold (>5000 PPM) - triggers error
  /// Above this is almost certainly a mistake or will cause nutrient burn
  static const double extremePpmThreshold = 5000.0;

  /// Negative PPM indicates dilution needed (calculation error state)
  /// When required PPM < 0, system needs water added to dilute
  static const double dilutionNeededThreshold = 0.0;

  // ═══════════════════════════════════════════
  // VOLUME THRESHOLDS
  // ═══════════════════════════════════════════

  /// Minimum volume to add for valid calculation (0 liters)
  /// Below this, no nutrients need to be added
  static const double minimumVolumeToAdd = 0.0;

  /// Minimum volume for batch mix mode (0 liters starting point)
  static const double batchMixStartVolume = 0.0;

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Check if scaling factor is in moderate range
  static bool isModerateScaling(double scalingFactor) {
    return scalingFactor > moderateScalingMin &&
        scalingFactor <= moderateScalingMax;
  }

  /// Check if scaling factor is high/dangerous
  static bool isHighScaling(double scalingFactor) {
    return scalingFactor > highScalingThreshold;
  }

  /// Check if scaling factor indicates downscaling
  static bool isDownScaling(double scalingFactor) {
    return scalingFactor < downScalingThreshold;
  }

  /// Check if PPM is in high range
  static bool isHighPpm(double ppm) {
    return ppm > highPpmMin && ppm <= highPpmMax;
  }

  /// Check if PPM is in extreme range
  static bool isExtremePpm(double ppm) {
    return ppm > extremePpmThreshold;
  }

  /// Check if dilution is needed (negative required PPM)
  static bool needsDilution(double requiredPpm) {
    return requiredPpm < dilutionNeededThreshold;
  }
}
