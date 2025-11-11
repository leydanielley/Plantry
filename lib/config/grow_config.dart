// =============================================
// GROWLOG - Grow Configuration
// =============================================

class GrowConfig {
  static const String defaultGrowName = 'Unknown Grow';
  static const int minimumNameLength = 1;
  static const int maximumNameLength = 100;

  static String validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return defaultGrowName;
    if (trimmed.length > maximumNameLength) {
      return trimmed.substring(0, maximumNameLength);
    }
    return trimmed;
  }

  static void validateNameStrict(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Grow name cannot be empty');
    }
    if (name.trim().length > maximumNameLength) {
      throw ArgumentError(
        'Grow name cannot exceed $maximumNameLength characters',
      );
    }
  }

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

  static void validateDateOrder(DateTime? startDate, DateTime? endDate) {
    if (startDate != null && endDate != null) {
      if (endDate.isBefore(startDate)) {
        throw ArgumentError('End date cannot be before start date');
      }
    }
  }
}
