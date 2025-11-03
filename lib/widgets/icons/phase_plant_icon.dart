// =============================================
// GROWLOG - Phase-Based Plant Icon Helper
// =============================================

import 'package:flutter/material.dart';
import '../../models/enums.dart';
import 'plant_pot_icon.dart';

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
    final colors = _getPhaseColors(phase);
    
    return PlantPotIcon(
      size: size,
      leavesColor: colors['leaves'],
      stemColor: colors['stem'],
      potColor: colors['pot'],
      soilColor: colors['soil'],
    );
  }

  Map<String, Color> _getPhaseColors(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        // Light green - young plant
        return {
          'leaves': const Color(0xFF81C784),
          'stem': const Color(0xFF8D6E63),
          'pot': const Color(0xFF90A4AE),
          'soil': const Color(0xFF6D4C41),
        };

      case PlantPhase.veg:
        // Strong green - healthy growth
        return {
          'leaves': const Color(0xFF4CAF50),
          'stem': const Color(0xFF6D4C41),
          'pot': const Color(0xFF78909C),
          'soil': const Color(0xFF5D4037),
        };

      case PlantPhase.bloom:
        // Purple tones - flowering
        return {
          'leaves': const Color(0xFF9C27B0),
          'stem': const Color(0xFF4A148C),
          'pot': const Color(0xFF7E57C2),
          'soil': const Color(0xFF4A148C),
        };

      case PlantPhase.harvest:
        // Orange/golden - ready to harvest
        return {
          'leaves': const Color(0xFFFF9800),
          'stem': const Color(0xFFE65100),
          'pot': const Color(0xFFFFB74D),
          'soil': const Color(0xFFBF360C),
        };

      case PlantPhase.archived:
        // Grey - inactive
        return {
          'leaves': const Color(0xFF9E9E9E),
          'stem': const Color(0xFF616161),
          'pot': const Color(0xFF757575),
          'soil': const Color(0xFF424242),
        };
    }
  }
}

/// Helper function to get PlantPotIcon for a specific phase
PlantPotIcon getPlantIconForPhase(PlantPhase phase, {double size = 80}) {
  final colors = {
    PlantPhase.seedling: {
      'leaves': const Color(0xFF81C784),
      'stem': const Color(0xFF8D6E63),
      'pot': const Color(0xFF90A4AE),
    },
    PlantPhase.veg: {
      'leaves': const Color(0xFF4CAF50),
      'stem': const Color(0xFF6D4C41),
      'pot': const Color(0xFF78909C),
    },
    PlantPhase.bloom: {
      'leaves': const Color(0xFF9C27B0),
      'stem': const Color(0xFF4A148C),
      'pot': const Color(0xFF7E57C2),
    },
    PlantPhase.harvest: {
      'leaves': const Color(0xFFFF9800),
      'stem': const Color(0xFFE65100),
      'pot': const Color(0xFFFFB74D),
    },
    PlantPhase.archived: {
      'leaves': const Color(0xFF9E9E9E),
      'stem': const Color(0xFF616161),
      'pot': const Color(0xFF757575),
    },
  };

  final phaseColors = colors[phase]!;

  return PlantPotIcon(
    size: size,
    leavesColor: phaseColors['leaves'],
    stemColor: phaseColors['stem'],
    potColor: phaseColors['pot'],
  );
}
