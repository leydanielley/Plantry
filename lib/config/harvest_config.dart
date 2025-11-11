// =============================================
// GROWLOG - Harvest Configuration
// Validation constants and helper methods
// =============================================

/// Configuration constants for Harvest model validation
class HarvestConfig {
  // ═══════════════════════════════════════════
  // VALIDATION CONSTANTS - Weights
  // ═══════════════════════════════════════════

  /// Minimum weight in grams
  static const double minimumWeight = 0.1;

  /// Maximum weight in grams (10kg = 10,000g)
  static const double maximumWeight = 10000.0;

  // ═══════════════════════════════════════════
  // VALIDATION CONSTANTS - Environment
  // ═══════════════════════════════════════════

  /// Minimum drying temperature in °C
  static const double minimumDryingTemp = 10.0;

  /// Maximum drying temperature in °C
  static const double maximumDryingTemp = 35.0;

  /// Minimum humidity percentage
  static const double minimumHumidity = 0.0;

  /// Maximum humidity percentage
  static const double maximumHumidity = 100.0;

  // ═══════════════════════════════════════════
  // VALIDATION CONSTANTS - Percentages
  // ═══════════════════════════════════════════

  /// Minimum percentage (THC, CBD)
  static const double minimumPercentage = 0.0;

  /// Maximum percentage (THC, CBD)
  static const double maximumPercentage = 100.0;

  // ═══════════════════════════════════════════
  // VALIDATION CONSTANTS - Rating
  // ═══════════════════════════════════════════

  /// Minimum rating (1 star)
  static const int minimumRating = 1;

  /// Maximum rating (5 stars)
  static const int maximumRating = 5;

  // ═══════════════════════════════════════════
  // VALIDATION CONSTANTS - Days
  // ═══════════════════════════════════════════

  /// Minimum days
  static const int minimumDays = 0;

  /// Maximum drying days (reasonable limit)
  static const int maximumDryingDays = 60;

  /// Maximum curing days (reasonable limit)
  static const int maximumCuringDays = 365;

  // ═══════════════════════════════════════════
  // HELPER METHODS - Soft Validation
  // ═══════════════════════════════════════════

  /// Validate weight (wet or dry)
  static double? validateWeight(double? weight) {
    if (weight == null) return null;
    if (weight < minimumWeight) return minimumWeight;
    if (weight > maximumWeight) return maximumWeight;
    return weight;
  }

  /// Validate drying temperature
  static double? validateDryingTemperature(double? temp) {
    if (temp == null) return null;
    if (temp < minimumDryingTemp) return minimumDryingTemp;
    if (temp > maximumDryingTemp) return maximumDryingTemp;
    return temp;
  }

  /// Validate humidity percentage
  static double? validateHumidity(double? humidity) {
    if (humidity == null) return null;
    if (humidity < minimumHumidity) return minimumHumidity;
    if (humidity > maximumHumidity) return maximumHumidity;
    return humidity;
  }

  /// Validate percentage (THC, CBD)
  static double? validatePercentage(double? percentage) {
    if (percentage == null) return null;
    if (percentage < minimumPercentage) return minimumPercentage;
    if (percentage > maximumPercentage) return maximumPercentage;
    return percentage;
  }

  /// Validate rating
  static int? validateRating(int? rating) {
    if (rating == null) return null;
    if (rating < minimumRating) return minimumRating;
    if (rating > maximumRating) return maximumRating;
    return rating;
  }

  /// Validate drying days
  static int? validateDryingDays(int? days) {
    if (days == null) return null;
    if (days < minimumDays) return minimumDays;
    if (days > maximumDryingDays) return maximumDryingDays;
    return days;
  }

  /// Validate curing days
  static int? validateCuringDays(int? days) {
    if (days == null) return null;
    if (days < minimumDays) return minimumDays;
    if (days > maximumCuringDays) return maximumCuringDays;
    return days;
  }

  // ═══════════════════════════════════════════
  // STRICT VALIDATION (throws exceptions for UI)
  // ═══════════════════════════════════════════

  /// Strictly validate weight
  static void validateWeightStrict(double? weight, String fieldName) {
    if (weight != null) {
      if (weight < minimumWeight) {
        throw ArgumentError('$fieldName must be at least $minimumWeight g');
      }
      if (weight > maximumWeight) {
        throw ArgumentError('$fieldName cannot exceed $maximumWeight g');
      }
    }
  }

  /// Validate that dry weight does not exceed wet weight
  static void validateWeightLogic(double? wetWeight, double? dryWeight) {
    if (wetWeight != null && dryWeight != null) {
      if (dryWeight > wetWeight) {
        throw ArgumentError('Dry weight cannot exceed wet weight');
      }
    }
  }

  /// Strictly validate temperature
  static void validateTemperatureStrict(double? temp) {
    if (temp != null) {
      if (temp < minimumDryingTemp) {
        throw ArgumentError(
          'Temperature must be at least $minimumDryingTemp °C',
        );
      }
      if (temp > maximumDryingTemp) {
        throw ArgumentError('Temperature cannot exceed $maximumDryingTemp °C');
      }
    }
  }

  /// Strictly validate humidity
  static void validateHumidityStrict(double? humidity) {
    if (humidity != null) {
      if (humidity < minimumHumidity) {
        throw ArgumentError('Humidity must be at least $minimumHumidity %');
      }
      if (humidity > maximumHumidity) {
        throw ArgumentError('Humidity cannot exceed $maximumHumidity %');
      }
    }
  }

  /// Strictly validate percentage
  static void validatePercentageStrict(double? percentage, String fieldName) {
    if (percentage != null) {
      if (percentage < minimumPercentage) {
        throw ArgumentError('$fieldName must be at least $minimumPercentage %');
      }
      if (percentage > maximumPercentage) {
        throw ArgumentError('$fieldName cannot exceed $maximumPercentage %');
      }
    }
  }

  /// Strictly validate rating
  static void validateRatingStrict(int? rating) {
    if (rating != null) {
      if (rating < minimumRating) {
        throw ArgumentError('Rating must be at least $minimumRating star');
      }
      if (rating > maximumRating) {
        throw ArgumentError('Rating cannot exceed $maximumRating stars');
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

  /// Validate harvest date chronology
  static void validateHarvestChronology({
    DateTime? harvestDate,
    DateTime? dryingStartDate,
    DateTime? dryingEndDate,
    DateTime? curingStartDate,
    DateTime? curingEndDate,
  }) {
    // Drying start must be after or same as harvest
    if (harvestDate != null && dryingStartDate != null) {
      if (dryingStartDate.isBefore(harvestDate)) {
        throw ArgumentError('Drying start date cannot be before harvest date');
      }
    }

    // Drying end must be after or same as drying start
    if (dryingStartDate != null && dryingEndDate != null) {
      if (dryingEndDate.isBefore(dryingStartDate)) {
        throw ArgumentError(
          'Drying end date cannot be before drying start date',
        );
      }
    }

    // Curing start should be after or same as drying end (if both set)
    if (dryingEndDate != null && curingStartDate != null) {
      if (curingStartDate.isBefore(dryingEndDate)) {
        throw ArgumentError(
          'Curing start date cannot be before drying end date',
        );
      }
    }

    // Curing end must be after or same as curing start
    if (curingStartDate != null && curingEndDate != null) {
      if (curingEndDate.isBefore(curingStartDate)) {
        throw ArgumentError(
          'Curing end date cannot be before curing start date',
        );
      }
    }
  }
}
