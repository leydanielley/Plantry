// =============================================
// GROWLOG - Validators Utility Class
// =============================================

class Validators {
  // pH validation (0-14)
  static bool isValidPh(double value) {
    if (value.isNaN || value.isInfinite) return false;
    return value >= 0.0 && value <= 14.0;
  }

  // EC validation (must be between 0 and 10.0 mS/cm)
  // ✅ FIX: Add upper bound to prevent unrealistic EC values
  static bool isValidEc(double value) {
    if (value.isNaN || value.isInfinite) return false;
    return value >= 0.0 && value <= 10.0;
  }

  // Temperature validation (-50 to 50°C)
  static bool isValidTemperature(double value) {
    if (value.isNaN || value.isInfinite) return false;
    return value >= -50.0 && value <= 50.0;
  }

  // Humidity validation (0-100%)
  static bool isValidHumidity(double value) {
    if (value.isNaN || value.isInfinite) return false;
    return value >= 0.0 && value <= 100.0;
  }

  // Water amount validation (must be non-negative)
  static bool isValidWaterAmount(double value) {
    if (value.isNaN || value.isInfinite) return false;
    return value >= 0.0;
  }

  // Name validation (not empty, max 255 chars)
  static bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.length <= 255;
  }

  // NPK format validation (e.g., "10-10-10" or "4.5-2.3-6.7")
  static bool isValidNpk(String npk) {
    if (npk.isEmpty) return false;

    final regex = RegExp(r'^\d+(\.\d+)?-\d+(\.\d+)?-\d+(\.\d+)?$');
    return regex.hasMatch(npk);
  }

  // Email validation
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;

    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email);
  }

  // Date validation - not in future
  static bool isNotFutureDate(DateTime date) {
    final now = DateTime.now();
    return !date.isAfter(now);
  }

  // Date validation - is in past
  static bool isPastDate(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(now);
  }

  // Date range validation
  static bool isValidDateRange(DateTime start, DateTime end) {
    return !end.isBefore(start);
  }

  // Dimension validation (non-negative)
  static bool isValidDimension(double value) {
    if (value.isNaN || value.isInfinite) return false;
    return value >= 0.0;
  }

  // Percentage validation (0-100)
  static bool isValidPercentage(double value) {
    if (value.isNaN || value.isInfinite) return false;
    return value >= 0.0 && value <= 100.0;
  }

  // Integer validation
  static bool isPositiveInteger(int value) {
    return value > 0;
  }

  static bool isNonNegativeInteger(int value) {
    return value >= 0;
  }

  // String length validation
  static bool hasMinLength(String value, int minLength) {
    return value.length >= minLength;
  }

  static bool hasMaxLength(String value, int maxLength) {
    return value.length <= maxLength;
  }

  static bool isLengthInRange(String value, int min, int max) {
    return value.length >= min && value.length <= max;
  }

  // Form validators for Flutter
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validatePh(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field

    final parsed = double.tryParse(value);
    if (parsed == null) return 'Invalid pH value';
    if (!isValidPh(parsed)) return 'pH value must be between 0 and 14';

    return null;
  }

  static String? validateEc(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field

    final parsed = double.tryParse(value);
    if (parsed == null) return 'Invalid EC value';
    // ✅ FIX: Updated error message to reflect upper bound
    if (!isValidEc(parsed)) return 'EC must be between 0 and 10.0 mS/cm';

    return null;
  }

  static String? validateTemperature(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field

    final parsed = double.tryParse(value);
    if (parsed == null) return 'Invalid temperature';
    if (!isValidTemperature(parsed)) return 'Temperature must be between -50°C and 50°C';

    return null;
  }

  static String? validateHumidity(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field

    final parsed = double.tryParse(value);
    if (parsed == null) return 'Invalid humidity';
    if (!isValidHumidity(parsed)) return 'Humidity must be between 0% and 100%';

    return null;
  }

  static String? validateWaterAmount(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field

    final parsed = double.tryParse(value);
    if (parsed == null) return 'Invalid water amount';
    if (!isValidWaterAmount(parsed)) return 'Water amount must be positive';

    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field

    if (!isValidEmail(value)) return 'Invalid email address';

    return null;
  }

  static String? validateNpk(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field

    if (!isValidNpk(value)) return 'Invalid NPK format (e.g. 10-10-10)';

    return null;
  }

  static String? validateIntegerRange(String? value, String fieldName, int min, int max) {
    if (value == null || value.isEmpty) return null; // Optional field

    final parsed = int.tryParse(value);
    if (parsed == null) return 'Invalid number';
    if (parsed < min || parsed > max) return '$fieldName must be between $min and $max';

    return null;
  }

  // =============================================
  // NEW METHODS FOR SCREEN COMPATIBILITY
  // =============================================

  // validatePositiveNumber with optional min/max parameters
  static String? validatePositiveNumber(
      String? value, {
        double min = 0.0,
        double max = double.infinity,
      }) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Invalid number';
    }

    if (parsed < min) {
      return 'Value must be at least $min';
    }

    if (parsed > max) {
      return 'Value must be at most $max';
    }

    return null;
  }

  // validatePositiveNumber as REQUIRED field with required parameter
  static String? validatePositiveNumberRequired(
      String? value, {
        required String fieldName,
        double min = 0.0,
        double max = double.infinity,
      }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Invalid number';
    }

    if (parsed < min) {
      return 'Value must be at least $min';
    }

    if (parsed > max) {
      return 'Value must be at most $max';
    }

    return null;
  }

  // validateInteger - for bucket count etc.
  static String? validateInteger(
      String? value, {
        int min = 0,
        int max = 999999,
      }) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Please enter a whole number';
    }

    if (parsed < min) {
      return 'Value must be at least $min';
    }

    if (parsed > max) {
      return 'Value must be at most $max';
    }

    return null;
  }

  // validateNotEmpty - for required fields
  static String? validateNotEmpty(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // validatePH - Alias for validatePh (uppercase)
  static String? validatePH(String? value) {
    return validatePh(value);
  }

  // validateEC - Alias for validateEc (uppercase)
  static String? validateEC(String? value) {
    return validateEc(value);
  }

  // =============================================
  // LOG DATE VALIDATIONS (für nachträgliches Logging)
  // =============================================

  /// Validiert dass Log-Datum nicht vor Pflanz-Datum liegt
  static String? validateLogDate({
    required DateTime logDate,
    required DateTime? seedDate,
    DateTime? phaseStartDate,
  }) {
    // ✅ Nur Datums-Teil vergleichen
    final logDay = DateTime(logDate.year, logDate.month, logDate.day);
    
    // Prüfe seedDate
    if (seedDate != null) {
      final seedDay = DateTime(seedDate.year, seedDate.month, seedDate.day);
      if (logDay.isBefore(seedDay)) {
        final diff = seedDay.difference(logDay).inDays;
        return 'Log-Datum liegt $diff Tag(e) vor dem Pflanz-Datum (${_formatDate(seedDate)})';
      }
    }

    // Prüfe phaseStartDate (optional)
    if (phaseStartDate != null) {
      final phaseDay = DateTime(phaseStartDate.year, phaseStartDate.month, phaseStartDate.day);
      if (logDay.isBefore(phaseDay)) {
        final diff = phaseDay.difference(logDay).inDays;
        return 'Log-Datum liegt $diff Tag(e) vor dem Phasen-Start (${_formatDate(phaseStartDate)})';
      }
    }

    return null; // Valid!
  }

  /// Prüft ob Log-Datum plausibel ist
  static String? validateLogDatePlausibility({
    required DateTime logDate,
    required DateTime? seedDate,
  }) {
    final logDay = DateTime(logDate.year, logDate.month, logDate.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    
    // Nicht in der Zukunft
    if (logDay.isAfter(todayDay)) {
      return 'Log-Datum kann nicht in der Zukunft liegen';
    }

    // Nicht vor seedDate
    if (seedDate != null) {
      final seedDay = DateTime(seedDate.year, seedDate.month, seedDate.day);
      if (logDay.isBefore(seedDay)) {
        return 'Log-Datum kann nicht vor dem Pflanz-Datum liegen';
      }
      
      // Warnung bei sehr alten Logs (>365 Tage)
      final daysSinceSeed = logDay.difference(seedDay).inDays;
      if (daysSinceSeed > 365) {
        return 'Achtung: Log liegt $daysSinceSeed Tage nach Pflanz-Datum';
      }
    }

    return null;
  }

  /// Berechnet Day Number aus Log-Datum und Seed-Datum
  static int calculateDayNumber(DateTime logDate, DateTime seedDate) {
    // ✅ Nur Datums-Teil vergleichen (ohne Uhrzeit!)
    final logDay = DateTime(logDate.year, logDate.month, logDate.day);
    final seedDay = DateTime(seedDate.year, seedDate.month, seedDate.day);
    
    final days = logDay.difference(seedDay).inDays + 1;
    return days > 0 ? days : 1;
  }

  /// Helper: Formatiert Datum für Fehlermeldungen
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
