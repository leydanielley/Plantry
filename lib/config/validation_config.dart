// =============================================
// GROWLOG - General Validation Configuration
// Shared validation for Hardware, PlantLog, Fertilizer, Photo
// =============================================

class ValidationConfig {
  // Names
  static const String defaultName = 'Unknown';
  static const int maxNameLength = 100;

  // Numbers - General
  static const int minPositiveInt = 1;
  static const int maxWattage = 10000;
  static const int maxQuantity = 1000;
  static const int maxAirflow = 10000; // m³/h
  static const int maxPumpRate = 100000; // L/h
  static const int maxCapacity = 10000; // L

  // Measurements - Environment
  static const double minTemperature = -50.0; // °C
  static const double maxTemperature = 100.0; // °C
  static const double minHumidity = 0.0; // %
  static const double maxHumidity = 100.0; // %
  static const double minPH = 0.0;
  static const double maxPH = 14.0;
  static const double minEC = 0.0;
  static const double maxEC = 10.0; // mS/cm

  // Measurements - Water
  static const double minWaterAmount = 0.0; // L
  static const double maxWaterAmount = 10000.0; // L

  // Measurements - Container/System
  static const double minContainerSize = 0.1; // L
  static const double maxContainerSize = 1000.0; // L

  // Nutrients - Percentages
  static const double minPercentage = 0.0;
  static const double maxPercentage = 100.0;
  static const double minPurity = 0.0;
  static const double maxPurity = 1.0;

  // Validate name
  static String validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return defaultName;
    if (trimmed.length > maxNameLength) {
      return trimmed.substring(0, maxNameLength);
    }
    return trimmed;
  }

  // Validate positive integer
  static int? validatePositiveInt(int? value, int max) {
    if (value == null) return null;
    if (value < minPositiveInt) return minPositiveInt;
    if (value > max) return max;
    return value;
  }

  // Validate double in range
  static double? validateDouble(double? value, double min, double max) {
    if (value == null) return null;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  // Validate percentage
  static double? validatePercentage(double? value) {
    return validateDouble(value, minPercentage, maxPercentage);
  }

  // Validate purity (0.0 - 1.0)
  static double? validatePurity(double? value) {
    return validateDouble(value, minPurity, maxPurity);
  }

  // Validate file path
  static String validateFilePath(String path) {
    return path.trim().isEmpty ? 'unknown.jpg' : path.trim();
  }
}
