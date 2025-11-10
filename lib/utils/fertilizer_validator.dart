// =============================================
// GROWLOG - Fertilizer Validator
// =============================================
// Validates and classifies fertilizers from DBF imports
// Extracted from UI layer for testability and reusability

import '../models/fertilizer.dart';

class FertilizerValidator {
  // =============================================
  // CONSTANTS - Magic Numbers Extracted
  // =============================================

  // Nutrient validation thresholds
  static const int kMinNutrientCountForCompleteness = 3;
  static const double kMinNutrientValue = 0.01;
  static const int kMaxReasonableNutrientValue = 50;

  // Name validation thresholds
  static const int kMinNameLength = 3;
  static const int kMaxNameLength = 100;

  // Recipe detection thresholds
  static const int kDigitToLetterRatioThreshold = 3;

  // Recipe detection keywords
  static const List<String> kRecipeKeywords = [
    'recipe',
    'series',
    'week',
    'stage',
    'phase',
    'schedule',
    'program',
    'bloom',
    'veg',
    'grow',
    'flowering',
  ];

  // Brand name keywords (for recipe detection)
  static const List<String> kBrandKeywords = [
    'gh ',
    'general hydro',
    'advanced nutrients',
    'canna',
    'biobizz',
    'plagron',
    'hesi',
  ];

  // Invalid entry indicators (URLs and domains)
  static const List<String> kUrlIndicators = [
    'http://',
    'https://',
    'www.',
    'amazon.',
    'amzn.to',
    '.com',
    '.de',
    '.co.uk',
    '.to/',
  ];

  // =============================================
  // PUBLIC VALIDATION METHODS
  // =============================================

  /// Checks if a fertilizer entry is invalid/corrupted
  /// Returns true if the entry should be marked as invalid
  ///
  /// Detects:
  /// - URLs and web links
  /// - Corrupted/truncated names
  /// - Names that are mostly numbers
  /// - Names without proper letter structure
  static bool isInvalid(Fertilizer fertilizer) {
    final name = fertilizer.name.trim();
    final nameLower = name.toLowerCase();

    // 1. Too short (likely corrupted)
    if (name.length < kMinNameLength) {
      return true;
    }

    // 2. URLs and links
    if (nameLower.contains('http://') || nameLower.contains('https://')) {
      return true;
    }
    if (nameLower.contains('www.')) {
      return true;
    }
    if (nameLower.contains('amazon.') || nameLower.contains('amzn.to')) {
      return true;
    }
    if (nameLower.contains('.com') || nameLower.contains('.de') ||
        nameLower.contains('.co.uk') || nameLower.contains('.to/')) {
      return true;
    }
    if (nameLower.startsWith('http') || nameLower.startsWith('www')) {
      return true;
    }

    // 3. Only numbers, dots, and zeros (e.g. "0.00000000", "1.00000000", "000")
    final cleanName = name.replaceAll(RegExp(r'[0-9\.\s]'), '');
    if (cleanName.isEmpty) {
      return true;
    }

    // 4. Starts with number or special char (likely corrupted, e.g. "7.93223900A", ".to/365sSi6")
    if (!RegExp(r'^[A-Za-z]').hasMatch(name)) {
      return true;
    }

    // 5. Looks like truncated/corrupted text (ends with incomplete word)
    // Examples: "ate)", "c Acid", "alcium Nitrate"
    if (name.length < 10 && (name.endsWith(')') || name.startsWith('c ') || !name.contains(' '))) {
      // Very short names that look incomplete
      final hasVowel = RegExp(r'[aeiouAEIOU]').hasMatch(name);
      if (!hasVowel) {
        return true; // No vowels = likely abbreviation or corrupted
      }
    }

    // 6. Mostly numbers with few letters (e.g. "44.08146528B", "55.09356426B")
    final digitCount = name.replaceAll(RegExp(r'[^0-9]'), '').length;
    final letterCount = name.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    if (digitCount > letterCount * kDigitToLetterRatioThreshold) {
      return true; // More than 3x digits vs letters = likely code/corrupted
    }

    return false;
  }

  /// Checks if fertilizer data is incomplete (valid but missing info)
  /// Returns true if entry has some data but is missing critical nutrients
  ///
  /// Incomplete = only NPK without detailed micro/macro nutrients
  /// These won't work well in the Top-up Calculator
  static bool isIncomplete(Fertilizer fertilizer) {
    // Count how many nutrient values are available (including micronutrients)
    int nutrientCount = 0;
    if ((fertilizer.nNO3 ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.nNH4 ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.p ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.k ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.mg ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.ca ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.s ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.fe ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.mn ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.zn ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.cu ?? 0) > kMinNutrientValue) nutrientCount++;
    if ((fertilizer.b ?? 0) > kMinNutrientValue) nutrientCount++;

    // If less than 3 nutrients, it's too incomplete
    // (commercial products often only have NPK = 3 values)
    return nutrientCount < kMinNutrientCountForCompleteness;
  }

  /// Checks if entry is likely a recipe/schedule rather than a fertilizer
  /// Returns true if the name suggests it's a feeding schedule
  static bool isLikelyRecipe(Fertilizer fertilizer) {
    final name = fertilizer.name.toLowerCase();

    // Recipe indicators - expanded list from actual implementation
    final recipeKeywords = [
      'recipe',
      'series',
      'program',
      'schedule',
      'kit',
      'system',
      'complete',
      'starter',
      'finisher',
      'expert',
      'professional',
      'flora',
      'micro',
      'bloom',
      'grow',
      'trio',
      'duo',
    ];

    // Brand names that typically indicate pre-made formulas
    final brandKeywords = [
      'gh ',
      'general hydro',
      'advanced nutrients',
      'canna',
      'plagron',
      'biobizz',
      'house & garden',
      'dutch pro',
      'petery',
      'flora series',
      'lucas formula',
    ];

    // Check for recipe keywords
    if (recipeKeywords.any((keyword) => name.contains(keyword))) {
      return true;
    }

    // Check for brand keywords
    if (brandKeywords.any((keyword) => name.contains(keyword))) {
      return true;
    }

    // Very long names are usually recipes (but not URLs)
    if (name.length > 40 && !isInvalid(fertilizer)) {
      return true;
    }

    // Names with 4+ words are usually recipes
    if (name.split(' ').length >= 4) {
      return true;
    }

    return false;
  }

  /// Classifies fertilizer into category for UI display
  /// Returns classification type as string
  static String classify(Fertilizer fertilizer) {
    if (isInvalid(fertilizer)) return 'invalid';
    if (isLikelyRecipe(fertilizer)) return 'recipe';
    if (isIncomplete(fertilizer)) return 'incomplete';
    return 'valid';
  }


  // =============================================
  // BATCH VALIDATION METHODS
  // =============================================

  /// Filters list to only valid, complete fertilizers
  static List<Fertilizer> filterValid(List<Fertilizer> fertilizers) {
    return fertilizers
        .where((f) => !isInvalid(f) && !isLikelyRecipe(f) && !isIncomplete(f))
        .toList();
  }

  /// Filters list to only invalid entries
  static List<Fertilizer> filterInvalid(List<Fertilizer> fertilizers) {
    return fertilizers.where((f) => isInvalid(f)).toList();
  }

  /// Filters list to only incomplete entries
  static List<Fertilizer> filterIncomplete(List<Fertilizer> fertilizers) {
    return fertilizers.where((f) => isIncomplete(f)).toList();
  }

  /// Filters list to only likely recipes
  static List<Fertilizer> filterRecipes(List<Fertilizer> fertilizers) {
    return fertilizers.where((f) => isLikelyRecipe(f)).toList();
  }

  /// Gets statistics about fertilizer list quality
  static Map<String, int> getStatistics(List<Fertilizer> fertilizers) {
    return {
      'total': fertilizers.length,
      'valid': filterValid(fertilizers).length,
      'invalid': filterInvalid(fertilizers).length,
      'incomplete': filterIncomplete(fertilizers).length,
      'recipes': filterRecipes(fertilizers).length,
    };
  }
}
