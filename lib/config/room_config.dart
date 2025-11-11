// =============================================
// GROWLOG - Room Configuration
// =============================================

class RoomConfig {
  static const String defaultRoomName = 'Unknown Room';
  static const int minimumNameLength = 1;
  static const int maximumNameLength = 100;
  static const double minimumDimension = 0.0;
  static const double maximumDimension = 10.0; // 10 meters

  static String validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return defaultRoomName;
    if (trimmed.length > maximumNameLength) {
      return trimmed.substring(0, maximumNameLength);
    }
    return trimmed;
  }

  static double validateDimension(double dimension) {
    if (dimension < minimumDimension) return minimumDimension;
    if (dimension > maximumDimension) return maximumDimension;
    return dimension;
  }

  static void validateNameStrict(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Room name cannot be empty');
    }
    if (name.trim().length > maximumNameLength) {
      throw ArgumentError('Room name cannot exceed $maximumNameLength characters');
    }
  }

  static void validateDimensionStrict(double dimension, String fieldName) {
    if (dimension < minimumDimension) {
      throw ArgumentError('$fieldName must be at least $minimumDimension m');
    }
    if (dimension > maximumDimension) {
      throw ArgumentError('$fieldName cannot exceed $maximumDimension m');
    }
  }
}
