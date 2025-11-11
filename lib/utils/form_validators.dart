// =============================================
// GROWLOG - Form Validation Utilities
// Centralized validation logic for all forms
// =============================================

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
