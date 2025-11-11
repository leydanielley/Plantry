// =============================================
// GROWLOG - Form Validation Utilities
// Centralized validation logic for all forms
// =============================================

/// Form validation functions for Plant forms
class PlantFormValidator {
  /// Validate plant name field
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length > 100) {
      return 'Name cannot exceed 100 characters';
    }
    return null;
  }

  /// Validate bucket number field
  static String? validateBucketNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final number = int.tryParse(value);
    if (number == null) {
      return 'Must be a valid number';
    }
    if (number < 1) {
      return 'Must be at least 1';
    }
    if (number > 50) {
      return 'Cannot exceed 50';
    }
    return null;
  }

  /// Validate container size field
  static String? validateContainerSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Must be a valid number';
    }
    if (number < 0.1) {
      return 'Must be at least 0.1 L';
    }
    if (number > 1000) {
      return 'Cannot exceed 1000 L';
    }
    return null;
  }

  /// Validate system size field
  static String? validateSystemSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Must be a valid number';
    }
    if (number < 1.0) {
      return 'Must be at least 1 L';
    }
    if (number > 10000) {
      return 'Cannot exceed 10000 L';
    }
    return null;
  }

  /// Validate that date is not in the future
  static String? validateNotFuture(DateTime? date) {
    if (date == null) {
      return null; // Optional field
    }
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay.isAfter(todayDay)) {
      return 'Date cannot be in the future';
    }
    return null;
  }
}

/// Form validation functions for RDWC System forms
class RdwcSystemFormValidator {
  /// Validate system name field
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  /// Validate bucket count field
  static String? validateBucketCount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bucket count is required';
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) {
      return 'Must be greater than 0';
    }
    return null;
  }

  /// Validate max capacity field
  static String? validateMaxCapacity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Max capacity is required';
    }
    final number = double.tryParse(value);
    if (number == null || number <= 0) {
      return 'Must be greater than 0';
    }
    return null;
  }

  /// Validate current level field
  static String? validateCurrentLevel(String? value, String? maxCapacityStr) {
    if (value == null || value.trim().isEmpty) {
      return 'Current level is required';
    }
    final number = double.tryParse(value);
    if (number == null || number < 0) {
      return 'Must be 0 or greater';
    }

    // Check if exceeds max capacity
    if (maxCapacityStr != null) {
      final maxCapacity = double.tryParse(maxCapacityStr);
      if (maxCapacity != null && number > maxCapacity) {
        return 'Cannot exceed max capacity';
      }
    }

    return null;
  }

  /// Validate optional wattage field (pump, chiller, etc.)
  static String? validateWattage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) {
      return 'Must be > 0';
    }
    return null;
  }

  /// Validate optional flow rate field
  static String? validateFlowRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final number = double.tryParse(value);
    if (number == null || number <= 0) {
      return 'Must be > 0';
    }
    return null;
  }

  /// Validate optional cooling power field
  static String? validateCoolingPower(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) {
      return 'Must be > 0';
    }
    return null;
  }
}
