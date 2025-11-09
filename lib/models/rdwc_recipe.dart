// =============================================
// GROWLOG - RDWC Recipe Models
// =============================================

import 'rdwc_log_fertilizer.dart';

/// Fertilizer entry in a recipe
///
/// Stores the dosage per liter for a specific fertilizer in a recipe.
class RecipeFertilizer {
  final int? id;
  final int recipeId;
  final int fertilizerId;
  final double mlPerLiter;  // Dosage in ml per liter

  RecipeFertilizer({
    this.id,
    required this.recipeId,
    required this.fertilizerId,
    required this.mlPerLiter,
  });

  /// Factory: Create from database map
  factory RecipeFertilizer.fromMap(Map<String, dynamic> map) {
    return RecipeFertilizer(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int,
      fertilizerId: map['fertilizer_id'] as int,
      mlPerLiter: (map['ml_per_liter'] as num).toDouble(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'fertilizer_id': fertilizerId,
      'ml_per_liter': mlPerLiter,
    };
  }

  @override
  String toString() => 'RecipeFertilizer{fertilizerId: $fertilizerId, mlPerLiter: $mlPerLiter}';
}

/// RDWC Fertilizer Recipe
///
/// A reusable combination of fertilizers with specific dosages.
/// Used for quickly applying the same nutrient schedule to reservoir changes.
///
/// Example: "Bloom Week 3" recipe might contain:
/// - Flora Micro: 2ml/L
/// - Flora Grow: 1ml/L
/// - Flora Bloom: 2ml/L
/// - Target EC: 1.8 mS/cm
/// - Target pH: 5.8

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class RdwcRecipe {
  final int? id;
  final String name;                       // e.g., "Bloom Week 3"
  final String? description;               // Optional notes
  final List<RecipeFertilizer> fertilizers; // Fertilizers in this recipe
  final double? targetEc;                  // Desired EC after application
  final double? targetPh;                  // Desired pH after application
  final DateTime createdAt;

  RdwcRecipe({
    this.id,
    required this.name,
    this.description,
    this.fertilizers = const [],
    this.targetEc,
    this.targetPh,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Apply this recipe to a specific system volume
  ///
  /// Converts the per-liter dosages to RdwcLogFertilizer entries
  /// ready to be saved with an RDWC log.
  ///
  /// [systemVolumeLiters] The current volume of the RDWC system in liters
  ///
  /// Returns a list of RdwcLogFertilizer entries with perLiter amount type.
  List<RdwcLogFertilizer> applyToVolume(double systemVolumeLiters, {required int rdwcLogId}) {
    return fertilizers.map((recipeFert) {
      return RdwcLogFertilizer(
        rdwcLogId: rdwcLogId,
        fertilizerId: recipeFert.fertilizerId,
        amount: recipeFert.mlPerLiter,
        amountType: FertilizerAmountType.perLiter,
      );
    }).toList();
  }

  /// Calculate total amount of each fertilizer for a given volume
  ///
  /// Returns a map: fertilizerId → total ml needed
  Map<int, double> getTotalAmounts(double systemVolumeLiters) {
    final Map<int, double> totals = {};
    for (final fert in fertilizers) {
      totals[fert.fertilizerId] = fert.mlPerLiter * systemVolumeLiters;
    }
    return totals;
  }

  /// Factory: Create from database map (without fertilizers)
  factory RdwcRecipe.fromMap(Map<String, dynamic> map) {
    return RdwcRecipe(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      targetEc: (map['target_ec'] as num?)?.toDouble(),
      targetPh: (map['target_ph'] as num?)?.toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to database map (without fertilizers)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'target_ec': targetEc,
      'target_ph': targetPh,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy with changes
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  RdwcRecipe copyWith({
    int? id,
    String? name,
    Object? description = _undefined,
    List<RecipeFertilizer>? fertilizers,
    Object? targetEc = _undefined,
    Object? targetPh = _undefined,
    DateTime? createdAt,
  }) {
    return RdwcRecipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description == _undefined ? this.description : description as String?,
      fertilizers: fertilizers ?? this.fertilizers,
      targetEc: targetEc == _undefined ? this.targetEc : targetEc as double?,
      targetPh: targetPh == _undefined ? this.targetPh : targetPh as double?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'RdwcRecipe{id: $id, name: $name, fertilizers: ${fertilizers.length}, targetEc: $targetEc, targetPh: $targetPh}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RdwcRecipe &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
