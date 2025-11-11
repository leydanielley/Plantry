// =============================================
// PLANTRY - Safe Parsing Utilities
// Prevents crashes from invalid data during deserialization
// =============================================

import 'package:growlog_app/utils/app_logger.dart';

class SafeParsers {
  /// Safely parse DateTime string, returns fallback on error
  ///
  /// Usage:
  /// ```dart
  /// createdAt: SafeParsers.parseDateTime(
  ///   map['created_at'] as String?,
  ///   fallback: DateTime.now(),
  /// )
  /// ```
  static DateTime parseDateTime(
    String? dateString, {
    required DateTime fallback,
    String context = 'Unknown',
  }) {
    if (dateString == null || dateString.isEmpty) {
      return fallback;
    }

    try {
      return DateTime.parse(dateString);
    } catch (e) {
      AppLogger.warning(
        'SafeParsers',
        'Invalid DateTime string in $context: "$dateString", using fallback',
      );
      return fallback;
    }
  }

  /// Safely parse nullable DateTime string
  ///
  /// Usage:
  /// ```dart
  /// endDate: SafeParsers.parseDateTimeNullable(map['end_date'] as String?)
  /// ```
  static DateTime? parseDateTimeNullable(
    String? dateString, {
    String context = 'Unknown',
  }) {
    if (dateString == null || dateString.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(dateString);
    } catch (e) {
      AppLogger.warning(
        'SafeParsers',
        'Invalid DateTime string in $context: "$dateString", returning null',
      );
      return null;
    }
  }

  /// Safely parse enum by name with fallback
  ///
  /// Usage:
  /// ```dart
  /// phase: SafeParsers.parseEnum<PlantPhase>(
  ///   PlantPhase.values,
  ///   map['phase']?.toString(),
  ///   fallback: PlantPhase.vegetative,
  ///   context: 'Plant.fromMap',
  /// )
  /// ```
  static T parseEnum<T extends Enum>(
    List<T> values,
    String? enumString, {
    required T fallback,
    String context = 'Unknown',
  }) {
    if (enumString == null || enumString.isEmpty) {
      return fallback;
    }

    try {
      // Try exact match first
      return values.byName(enumString);
    } catch (e) {
      // Try case-insensitive match
      try {
        final lowerName = enumString.toLowerCase();
        return values.firstWhere(
          (v) => v.name.toLowerCase() == lowerName,
          orElse: () => fallback,
        );
      } catch (e2) {
        AppLogger.warning(
          'SafeParsers',
          'Invalid enum value in $context: "$enumString" for ${T.toString()}, using fallback: ${fallback.name}',
        );
        return fallback;
      }
    }
  }

  /// Safely parse nullable enum by name
  ///
  /// Usage:
  /// ```dart
  /// type: SafeParsers.parseEnumNullable<MyType>(
  ///   MyType.values,
  ///   map['type']?.toString(),
  /// )
  /// ```
  static T? parseEnumNullable<T extends Enum>(
    List<T> values,
    String? enumString, {
    String context = 'Unknown',
  }) {
    if (enumString == null || enumString.isEmpty) {
      return null;
    }

    try {
      return values.byName(enumString);
    } catch (e) {
      // Try case-insensitive match
      try {
        final lowerName = enumString.toLowerCase();
        return values.firstWhere(
          (v) => v.name.toLowerCase() == lowerName,
        );
      } catch (e2) {
        AppLogger.warning(
          'SafeParsers',
          'Invalid enum value in $context: "$enumString" for ${T.toString()}, returning null',
        );
        return null;
      }
    }
  }

  /// Safely parse double from dynamic value
  ///
  /// Usage:
  /// ```dart
  /// amount: SafeParsers.parseDouble(map['amount'], fallback: 0.0)
  /// ```
  static double parseDouble(
    dynamic value, {
    double fallback = 0.0,
    String context = 'Unknown',
  }) {
    if (value == null) return fallback;

    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.parse(value);
      if (value is num) return value.toDouble();

      AppLogger.warning(
        'SafeParsers',
        'Unexpected type for double in $context: ${value.runtimeType}, using fallback',
      );
      return fallback;
    } catch (e) {
      AppLogger.warning(
        'SafeParsers',
        'Failed to parse double in $context: "$value", using fallback',
      );
      return fallback;
    }
  }

  /// Safely parse int from dynamic value
  ///
  /// Usage:
  /// ```dart
  /// count: SafeParsers.parseInt(map['count'], fallback: 0)
  /// ```
  static int parseInt(
    dynamic value, {
    int fallback = 0,
    String context = 'Unknown',
  }) {
    if (value == null) return fallback;

    try {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.parse(value);
      if (value is num) return value.toInt();

      AppLogger.warning(
        'SafeParsers',
        'Unexpected type for int in $context: ${value.runtimeType}, using fallback',
      );
      return fallback;
    } catch (e) {
      AppLogger.warning(
        'SafeParsers',
        'Failed to parse int in $context: "$value", using fallback',
      );
      return fallback;
    }
  }
}
