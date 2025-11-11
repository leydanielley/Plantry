// =============================================
// GROWLOG - Plant Configuration
// Validation constants and helper methods
// =============================================

/// Configuration constants for Plant model validation
class PlantConfig {
  // ═══════════════════════════════════════════
  // VALIDATION CONSTANTS
  // ═══════════════════════════════════════════

  /// Minimum name length
  static const int minimumNameLength = 1;

  /// Maximum name length
  static const int maximumNameLength = 100;

  /// Default name for plants
  static const String defaultPlantName = 'Unknown Plant';

  /// Minimum bucket number (RDWC systems)
  static const int minimumBucketNumber = 1;

  /// Maximum bucket number (RDWC systems)
  static const int maximumBucketNumber = 50;

  /// Minimum container size in liters
  static const double minimumContainerSize = 0.1;

  /// Maximum container size in liters (1000L = very large)
  static const double maximumContainerSize = 1000.0;

  /// Minimum system size in liters
  static const double minimumSystemSize = 1.0;

  /// Maximum system size in liters (10,000L = commercial)
  static const double maximumSystemSize = 10000.0;

  /// Default log profile name
  static const String defaultLogProfileName = 'standard';

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Validate and sanitize plant name
  static String validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return defaultPlantName;
    if (trimmed.length > maximumNameLength) {
      return trimmed.substring(0, maximumNameLength);
    }
    return trimmed;
  }

  /// Validate bucket number
  static int? validateBucketNumber(int? bucketNumber) {
    if (bucketNumber == null) return null;
    if (bucketNumber < minimumBucketNumber) return minimumBucketNumber;
    if (bucketNumber > maximumBucketNumber) return maximumBucketNumber;
    return bucketNumber;
  }

  /// Validate container size
  static double? validateContainerSize(double? size) {
    if (size == null) return null;
    if (size < minimumContainerSize) return minimumContainerSize;
    if (size > maximumContainerSize) return maximumContainerSize;
    return size;
  }

  /// Validate system size
  static double? validateSystemSize(double? size) {
    if (size == null) return null;
    if (size < minimumSystemSize) return minimumSystemSize;
    if (size > maximumSystemSize) return maximumSystemSize;
    return size;
  }

  /// Validate log profile name
  static String validateLogProfileName(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? defaultLogProfileName : trimmed;
  }

  // ═══════════════════════════════════════════
  // STRICT VALIDATION (throws exceptions for UI)
  // ═══════════════════════════════════════════

  /// Strictly validate plant name
  static void validateNameStrict(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Plant name cannot be empty');
    }
    if (name.trim().length < minimumNameLength) {
      throw ArgumentError('Plant name must be at least $minimumNameLength character');
    }
    if (name.trim().length > maximumNameLength) {
      throw ArgumentError('Plant name cannot exceed $maximumNameLength characters');
    }
  }

  /// Strictly validate bucket number
  static void validateBucketNumberStrict(int? bucketNumber) {
    if (bucketNumber != null) {
      if (bucketNumber < minimumBucketNumber) {
        throw ArgumentError('Bucket number must be at least $minimumBucketNumber');
      }
      if (bucketNumber > maximumBucketNumber) {
        throw ArgumentError('Bucket number cannot exceed $maximumBucketNumber');
      }
    }
  }

  /// Strictly validate container size
  static void validateContainerSizeStrict(double? size) {
    if (size != null) {
      if (size < minimumContainerSize) {
        throw ArgumentError('Container size must be at least $minimumContainerSize L');
      }
      if (size > maximumContainerSize) {
        throw ArgumentError('Container size cannot exceed $maximumContainerSize L');
      }
    }
  }

  /// Strictly validate system size
  static void validateSystemSizeStrict(double? size) {
    if (size != null) {
      if (size < minimumSystemSize) {
        throw ArgumentError('System size must be at least $minimumSystemSize L');
      }
      if (size > maximumSystemSize) {
        throw ArgumentError('System size cannot exceed $maximumSystemSize L');
      }
    }
  }

  /// Validate that date is not in the future
  static void validateNotFuture(DateTime? date, String fieldName) {
    if (date != null) {
      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);
      final dateDay = DateTime(date.year, date.month, date.day);

      if (dateDay.isAfter(todayDay)) {
        throw ArgumentError('$fieldName cannot be in the future');
      }
    }
  }

  /// Validate phase date chronology
  static void validatePhaseChronology({
    DateTime? seedDate,
    DateTime? vegDate,
    DateTime? bloomDate,
    DateTime? harvestDate,
  }) {
    // Seed date must be earliest
    if (seedDate != null && vegDate != null && vegDate.isBefore(seedDate)) {
      throw ArgumentError('Veg date cannot be before seed date');
    }

    if (seedDate != null && bloomDate != null && bloomDate.isBefore(seedDate)) {
      throw ArgumentError('Bloom date cannot be before seed date');
    }

    if (seedDate != null && harvestDate != null && harvestDate.isBefore(seedDate)) {
      throw ArgumentError('Harvest date cannot be before seed date');
    }

    // Veg must be before bloom
    if (vegDate != null && bloomDate != null && bloomDate.isBefore(vegDate)) {
      throw ArgumentError('Bloom date cannot be before veg date');
    }

    // Bloom must be before harvest
    if (bloomDate != null && harvestDate != null && harvestDate.isBefore(bloomDate)) {
      throw ArgumentError('Harvest date cannot be before bloom date');
    }

    // Veg must be before harvest
    if (vegDate != null && harvestDate != null && harvestDate.isBefore(vegDate)) {
      throw ArgumentError('Harvest date cannot be before veg date');
    }
  }
}
