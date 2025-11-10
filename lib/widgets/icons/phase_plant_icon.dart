// =============================================
// GROWLOG - Phase-Based Plant Icon Helper
// =============================================

import 'package:flutter/material.dart';
import '../../models/enums.dart';
import 'plant_pot_icon.dart';

/// ✅ AUDIT FIX: Consolidated color definitions to eliminate duplication
/// Phase color definitions used by both PhasePlantIcon widget and helper function
class _PhaseColors {
  // Seedling - Light green (young plant)
  static const Color seedlingLeaves = Color(0xFF81C784);
  static const Color seedlingStem = Color(0xFF8D6E63);
  static const Color seedlingPot = Color(0xFF90A4AE);
  static const Color seedlingSoil = Color(0xFF6D4C41);

  // Veg - Strong green (healthy growth)
  static const Color vegLeaves = Color(0xFF4CAF50);
  static const Color vegStem = Color(0xFF6D4C41);
  static const Color vegPot = Color(0xFF78909C);
  static const Color vegSoil = Color(0xFF5D4037);

  // Bloom - Purple tones (flowering)
  static const Color bloomLeaves = Color(0xFF9C27B0);
  static const Color bloomStem = Color(0xFF4A148C);
  static const Color bloomPot = Color(0xFF7E57C2);
  static const Color bloomSoil = Color(0xFF4A148C);

  // Harvest - Orange/golden (ready to harvest)
  static const Color harvestLeaves = Color(0xFFFF9800);
  static const Color harvestStem = Color(0xFFE65100);
  static const Color harvestPot = Color(0xFFFFB74D);
  static const Color harvestSoil = Color(0xFFBF360C);

  // Archived - Grey (inactive)
  static const Color archivedLeaves = Color(0xFF9E9E9E);
  static const Color archivedStem = Color(0xFF616161);
  static const Color archivedPot = Color(0xFF757575);
  static const Color archivedSoil = Color(0xFF424242);

  /// Get color map for a specific phase
  static Map<String, Color> getColors(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return {
          'leaves': seedlingLeaves,
          'stem': seedlingStem,
          'pot': seedlingPot,
          'soil': seedlingSoil,
        };
      case PlantPhase.veg:
        return {
          'leaves': vegLeaves,
          'stem': vegStem,
          'pot': vegPot,
          'soil': vegSoil,
        };
      case PlantPhase.bloom:
        return {
          'leaves': bloomLeaves,
          'stem': bloomStem,
          'pot': bloomPot,
          'soil': bloomSoil,
        };
      case PlantPhase.harvest:
        return {
          'leaves': harvestLeaves,
          'stem': harvestStem,
          'pot': harvestPot,
          'soil': harvestSoil,
        };
      case PlantPhase.archived:
        return {
          'leaves': archivedLeaves,
          'stem': archivedStem,
          'pot': archivedPot,
          'soil': archivedSoil,
        };
    }
  }
}

/// Helper class to get PlantPotIcon with colors based on plant phase
class PhasePlantIcon extends StatelessWidget {
  final PlantPhase phase;
  final double size;

  const PhasePlantIcon({
    super.key,
    required this.phase,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _PhaseColors.getColors(phase);

    return PlantPotIcon(
      size: size,
      leavesColor: colors['leaves'],
      stemColor: colors['stem'],
      potColor: colors['pot'],
      soilColor: colors['soil'],
    );
  }
}

/// Helper function to get PlantPotIcon for a specific phase
PlantPotIcon getPlantIconForPhase(PlantPhase phase, {double size = 80}) {
  final colors = _PhaseColors.getColors(phase);

  return PlantPotIcon(
    size: size,
    leavesColor: colors['leaves'],
    stemColor: colors['stem'],
    potColor: colors['pot'],
  );
}
