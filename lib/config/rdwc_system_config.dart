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

  /// Maximum capacity in liters (10,000L = very large system)
  static const double maximumCapacity = 10000.0;

  /// Maximum bucket count (50 buckets = commercial size)
  static const int maximumBucketCount = 50;

  /// Maximum wattage for equipment (5000W)
  static const int maximumWattage = 5000;

  /// Maximum flow rate in L/h (10,000 L/h)
  static const double maximumFlowRate = 10000.0;

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
    if (capacity < minimumCapacity) return defaultCapacity;
    if (capacity > maximumCapacity) return maximumCapacity;
    return capacity;
  }

  /// Validate and clamp level to safe range (0 to maxCapacity)
  static double validateLevel(double level, double maxCapacity) {
    if (level < minimumLevel) return minimumLevel;
    if (level > maxCapacity) return maxCapacity;
    return level;
  }

  /// Validate and clamp bucket count
  static int validateBucketCount(int count) {
    if (count < minimumBucketCount) return defaultBucketCount;
    if (count > maximumBucketCount) return maximumBucketCount;
    return count;
  }

  /// Validate system name
  static String validateName(String name) {
    return name.trim().isEmpty ? defaultSystemName : name.trim();
  }

  /// Validate wattage (for pumps, chillers, etc.)
  static int? validateWattage(int? wattage) {
    if (wattage == null) return null;
    if (wattage < 0) return 0;
    if (wattage > maximumWattage) return maximumWattage;
    return wattage;
  }

  /// Validate flow rate (for pumps)
  static double? validateFlowRate(double? flowRate) {
    if (flowRate == null) return null;
    if (flowRate < 0) return 0;
    if (flowRate > maximumFlowRate) return maximumFlowRate;
    return flowRate;
  }

  // ═══════════════════════════════════════════
  // STRICT VALIDATION (throws exceptions for UI)
  // ═══════════════════════════════════════════

  /// Strictly validate capacity - throws ArgumentError for UI validation
  static void validateCapacityStrict(double capacity) {
    if (capacity < minimumCapacity) {
      throw ArgumentError('Capacity must be at least $minimumCapacity liters');
    }
    if (capacity > maximumCapacity) {
      throw ArgumentError('Capacity cannot exceed $maximumCapacity liters');
    }
  }

  /// Strictly validate bucket count - throws ArgumentError for UI validation
  static void validateBucketCountStrict(int count) {
    if (count < minimumBucketCount) {
      throw ArgumentError('Bucket count must be at least $minimumBucketCount');
    }
    if (count > maximumBucketCount) {
      throw ArgumentError('Bucket count cannot exceed $maximumBucketCount');
    }
  }

  /// Strictly validate current level - throws ArgumentError for UI validation
  static void validateLevelStrict(double level, double maxCapacity) {
    if (level < minimumLevel) {
      throw ArgumentError('Water level cannot be negative');
    }
    if (level > maxCapacity) {
      throw ArgumentError(
        'Water level ($level L) cannot exceed max capacity ($maxCapacity L)',
      );
    }
  }

  /// Strictly validate system name - throws ArgumentError for UI validation
  static void validateNameStrict(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('System name cannot be empty');
    }
    if (name.trim().length < 2) {
      throw ArgumentError('System name must be at least 2 characters');
    }
    if (name.trim().length > 100) {
      throw ArgumentError('System name cannot exceed 100 characters');
    }
  }

  /// Strictly validate wattage - throws ArgumentError for UI validation
  static void validateWattageStrict(int? wattage) {
    if (wattage != null) {
      if (wattage < 0) {
        throw ArgumentError('Wattage cannot be negative');
      }
      if (wattage > maximumWattage) {
        throw ArgumentError('Wattage cannot exceed $maximumWattage W');
      }
    }
  }

  /// Strictly validate flow rate - throws ArgumentError for UI validation
  static void validateFlowRateStrict(double? flowRate) {
    if (flowRate != null) {
      if (flowRate < 0) {
        throw ArgumentError('Flow rate cannot be negative');
      }
      if (flowRate > maximumFlowRate) {
        throw ArgumentError('Flow rate cannot exceed $maximumFlowRate L/h');
      }
    }
  }
}
