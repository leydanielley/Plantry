// =============================================
// GROWLOG - Universal Nutrient Calculation Model
// ✅ AUDIT FIX: Magic numbers extracted to NutrientCalculationConfig
// =============================================

import 'rdwc_recipe.dart';
import 'app_settings.dart';
import '../utils/unit_converter.dart';
import '../config/nutrient_calculation_config.dart';

/// Calculator modes
enum CalculatorMode {
  topUp,      // Top-up existing reservoir (increase/maintain PPM)
  batchMix,   // Mix fresh batch from 0L
  quickMix,   // Quick mixing for watering
  dilution,   // Dilute to lower PPM
}

/// Recipe usage mode
enum RecipeMode {
  manual,  // User enters target PPM manually
  recipe,  // User selects a recipe
  direct,  // User selects individual fertilizers directly
}

/// Universal nutrient calculation result
class NutrientCalculation {
  final double targetVolume;        // Target volume in liters
  final double currentVolume;       // Current volume in liters
  final double currentPPM;          // Current PPM
  final double targetPPM;           // Target PPM
  final RdwcRecipe? recipe;         // Optional recipe used
  final AppSettings settings;       // For unit conversions
  final CalculatorMode calculatorMode;  // Calculator mode
  final RecipeMode recipeMode;      // Recipe usage mode

  NutrientCalculation({
    required this.targetVolume,
    required this.currentVolume,
    required this.currentPPM,
    required this.targetPPM,
    this.recipe,
    required this.settings,
    this.calculatorMode = CalculatorMode.topUp,
    this.recipeMode = RecipeMode.manual,
  });

  /// Factory: Create calculation with recipe
  /// Note: targetPPM is for the ENTIRE system, not just the added solution
  factory NutrientCalculation.withRecipe({
    required double targetVolume,
    required double currentVolume,
    required double currentPPM,
    required double targetPPM,  // User-specified target for entire system
    required RdwcRecipe recipe,
    required AppSettings settings,
    CalculatorMode calculatorMode = CalculatorMode.topUp,
  }) {
    return NutrientCalculation(
      targetVolume: targetVolume,
      currentVolume: currentVolume,
      currentPPM: currentPPM,
      targetPPM: targetPPM,
      recipe: recipe,
      settings: settings,
      calculatorMode: calculatorMode,
      recipeMode: RecipeMode.recipe,
    );
  }

  /// Factory: Batch mix from scratch (0L)
  factory NutrientCalculation.batchMix({
    required double volume,
    required double targetPPM,
    RdwcRecipe? recipe,
    required AppSettings settings,
  }) {
    return NutrientCalculation(
      targetVolume: volume,
      currentVolume: 0,
      currentPPM: 0,
      targetPPM: targetPPM,
      recipe: recipe,
      settings: settings,
      calculatorMode: CalculatorMode.batchMix,
      recipeMode: recipe != null ? RecipeMode.recipe : RecipeMode.manual,
    );
  }

  /// Calculate volume to add in liters
  double get volumeToAdd => targetVolume - currentVolume;

  /// Calculate required PPM of solution to add
  /// Formula: (target_ppm × target_vol - current_ppm × current_vol) / vol_to_add
  double get requiredPPM {
    if (volumeToAdd <= 0) return 0;
    return (targetPPM * targetVolume - currentPPM * currentVolume) / volumeToAdd;
  }

  /// Calculate required EC of solution to add
  double get requiredEC {
    return UnitConverter.ppmToEc(requiredPPM, settings.ppmScale);
  }

  /// Get target EC (from recipe or converted from manual PPM)
  double get targetEC {
    return UnitConverter.ppmToEc(targetPPM, settings.ppmScale);
  }

  /// Calculate fertilizer amounts (only in recipe mode)
  /// Returns map: fertilizerId → total ml needed (UNSCALED - original recipe amounts)
  Map<int, double> getFertilizerAmounts() {
    if (recipe == null || volumeToAdd <= 0) return {};
    return recipe!.getTotalAmounts(volumeToAdd);
  }

  /// Calculate SCALED fertilizer amounts based on requiredPPM
  /// This scales the recipe to match the actual PPM needed in the solution
  /// Returns map: fertilizerId → total ml needed (SCALED)
  Map<int, double> getScaledFertilizerAmounts() {
    if (recipe == null || volumeToAdd <= 0 || recipe!.targetEc == null) return {};

    final scaleFactor = scalingFactor;
    final originalAmounts = recipe!.getTotalAmounts(volumeToAdd);

    return originalAmounts.map(
      (fertilizerId, ml) => MapEntry(fertilizerId, ml * scaleFactor),
    );
  }

  /// Get recipe's original target PPM
  /// ✅ CRITICAL FIX: Safer null handling to prevent crashes
  double? get recipeTargetPPM {
    final currentRecipe = recipe;
    if (currentRecipe == null) return null;

    final targetEc = currentRecipe.targetEc;
    if (targetEc == null) return null;

    return UnitConverter.ecToPpm(targetEc, settings.ppmScale);
  }

  /// Calculate scaling factor for recipe
  /// How much to multiply recipe dosages to reach requiredPPM
  /// Example: Recipe is 1260 PPM, but we need 1500 PPM → factor = 1.19
  double get scalingFactor {
    final recipeTarget = recipeTargetPPM;
    if (recipeTarget == null || recipeTarget == 0 || requiredPPM == 0) return 1.0;
    return requiredPPM / recipeTarget;
  }

  /// Check if scaling is moderate (1.2x - 1.5x)
  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isModerateScaling {
    return NutrientCalculationConfig.isModerateScaling(scalingFactor);
  }

  /// Check if scaling is high/dangerous (>1.5x)
  /// This could lead to nutrient burn
  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isHighScaling {
    return NutrientCalculationConfig.isHighScaling(scalingFactor);
  }

  /// Check if downscaling (< 0.8x)
  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isDownScaling {
    return NutrientCalculationConfig.isDownScaling(scalingFactor);
  }

  /// Validation checks
  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isValid {
    return volumeToAdd > NutrientCalculationConfig.minimumVolumeToAdd &&
           !needsDilution &&
           !isSystemFull;
  }

  bool get isSystemFull => currentVolume >= targetVolume;

  bool get volumeExceedsCapacity => currentVolume > targetVolume;

  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get needsDilution => NutrientCalculationConfig.needsDilution(requiredPPM);

  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isHighPPM => NutrientCalculationConfig.isHighPpm(requiredPPM);

  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isExtremePPM => NutrientCalculationConfig.isExtremePpm(requiredPPM);

  bool get hasRecipeWithoutEC => recipe != null && recipe!.targetEc == null;

  /// Get warning level color
  WarningLevel get warningLevel {
    if (needsDilution) return WarningLevel.error;
    if (isExtremePPM) return WarningLevel.error;
    if (isHighScaling) return WarningLevel.error;
    if (isHighPPM) return WarningLevel.warning;
    if (isModerateScaling) return WarningLevel.warning;
    return WarningLevel.safe;
  }

  /// Get warning message
  String? getWarningMessage(String Function(String) translate) {
    if (volumeExceedsCapacity) {
      return translate('error_volume_exceeds_capacity');
    }
    if (isSystemFull) {
      return translate('error_system_full');
    }
    if (needsDilution) {
      return translate('warning_dilution_needed');
    }
    if (isExtremePPM) {
      return translate('warning_extreme_ppm');
    }
    if (isHighPPM) {
      return translate('warning_high_ppm');
    }
    if (isHighScaling) {
      return translate('warning_high_scaling');
    }
    if (isModerateScaling) {
      return translate('warning_moderate_scaling');
    }
    if (hasRecipeWithoutEC) {
      return translate('warning_recipe_no_ec');
    }
    return null;
  }

  /// Check if this is a batch mix (starting from 0L)
  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isBatchMix => calculatorMode == CalculatorMode.batchMix ||
                         currentVolume == NutrientCalculationConfig.batchMixStartVolume;

  /// Check if this is a dilution (lowering PPM with water)
  /// ✅ AUDIT FIX: Uses config constants instead of magic numbers
  bool get isDilutionMode => calculatorMode == CalculatorMode.dilution ||
                             (targetPPM < currentPPM && currentVolume > NutrientCalculationConfig.minimumVolumeToAdd);

  @override
  String toString() {
    return 'NutrientCalculation{calculatorMode: ${calculatorMode.name}, recipeMode: ${recipeMode.name}, volumeToAdd: ${volumeToAdd}L, requiredPPM: $requiredPPM, recipe: ${recipe?.name}}';
  }
}

/// Warning levels for top-up calculation
enum WarningLevel {
  safe,     // Green - all good
  warning,  // Yellow - high PPM but acceptable
  error,    // Red - dilution needed or extreme PPM
}
