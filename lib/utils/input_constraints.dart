// =============================================
// GROWLOG - Input Constraints
// =============================================
// ✅ FIX: Centralized maxLength constraints to prevent database overflow

import 'package:flutter/material.dart';

/// Maximum length constraints for text inputs
class InputConstraints {
  // Primary text fields
  static const int nameMaxLength =
      100; // Names (plant, room, grow, fertilizer, etc.)
  static const int shortNameMaxLength = 50; // Short names (hardware, strain)
  static const int descriptionMaxLength = 500; // Descriptions
  static const int longTextMaxLength = 2000; // Long text (notes, observations)

  // Specific fields
  static const int brandMaxLength = 50; // Brand names
  static const int npkMaxLength = 20; // NPK values (e.g., "10-10-10")
  static const int formulaMaxLength = 100; // Chemical formulas
  static const int urlMaxLength = 500; // URLs

  // Numeric constraints
  static const int numericMaxLength =
      10; // Numeric inputs (allows up to 9,999,999.99)

  // Private constructor to prevent instantiation
  InputConstraints._();
}

/// Decoration helper for hiding character counter
class InputDecorationHelper {
  /// Returns InputDecoration with hidden counter
  static InputDecoration withHiddenCounter(InputDecoration decoration) {
    return decoration.copyWith(counterText: '');
  }

  /// Returns InputDecoration with visible counter
  static InputDecoration withVisibleCounter(InputDecoration decoration) {
    return decoration; // Default shows counter
  }

  // Private constructor
  InputDecorationHelper._();
}
