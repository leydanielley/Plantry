// =============================================
// GROWLOG - RDWC System Configuration
// ✅ AUDIT FIX: Centralized magic numbers from rdwc_system.dart
// =============================================

/// Configuration constants for RDWC (Recirculating Deep Water Culture) systems
///
/// Centralizes all threshold values for water level monitoring and alerts.
class RdwcSystemConfig {
  // ═══════════════════════════════════════════
  // WATER LEVEL THRESHOLDS (Percentage)
  // ═══════════════════════════════════════════

  /// Low water warning threshold (30% of max capacity)
  /// Below this level, system should be topped up soon
  /// Example: 100L reservoir at 30L triggers warning
  static const double lowWaterThreshold = 30.0;

  /// Critically low water threshold (15% of max capacity)
  /// Below this level, system is at risk - immediate action required
  /// Example: 100L reservoir at 15L triggers critical alert
  static const double criticallyLowThreshold = 15.0;

  /// Full reservoir threshold (95% of max capacity)
  /// At or above this level, system is considered full
  /// Example: 100L reservoir at 95L is full
  static const double fullThreshold = 95.0;

  // ═══════════════════════════════════════════
  // VALIDATION CONSTANTS
  // ═══════════════════════════════════════════

  /// Minimum valid max capacity in liters
  /// Used for validation in constructor
  static const double minimumCapacity = 1.0;

  /// Default max capacity if validation fails (100 liters)
  static const double defaultCapacity = 100.0;

  /// Minimum current level (0 liters - empty)
  static const double minimumLevel = 0.0;

  /// Minimum bucket count (1 bucket minimum)
  static const int minimumBucketCount = 1;

  /// Default bucket count for new systems (4 buckets)
  static const int defaultBucketCount = 4;

  /// Default name for unnamed systems
  static const String defaultSystemName = 'Unnamed System';

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Check if fill percentage indicates low water
  static bool isLowWater(double fillPercentage) {
    return fillPercentage < lowWaterThreshold;
  }

  /// Check if fill percentage indicates critically low water
  static bool isCriticallyLow(double fillPercentage) {
    return fillPercentage < criticallyLowThreshold;
  }

  /// Check if fill percentage indicates full reservoir
  static bool isFull(double fillPercentage) {
    return fillPercentage >= fullThreshold;
  }

  /// Validate and clamp capacity to safe range
  static double validateCapacity(double capacity) {
    return capacity > minimumCapacity ? capacity : defaultCapacity;
  }

  /// Validate and clamp level to safe range (0 to maxCapacity)
  static double validateLevel(double level, double maxCapacity) {
    if (level < minimumLevel) return minimumLevel;
    if (level > maxCapacity) return maxCapacity;
    return level;
  }

  /// Validate and clamp bucket count
  static int validateBucketCount(int count) {
    return count > minimumBucketCount ? count : defaultBucketCount;
  }

  /// Validate system name
  static String validateName(String name) {
    return name.trim().isEmpty ? defaultSystemName : name;
  }
}
