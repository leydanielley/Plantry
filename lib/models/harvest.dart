// =============================================
// GROWLOG - Harvest Model (Ernte-Tracking)
// =============================================

import 'package:growlog_app/utils/safe_parsers.dart'; // ✅ FIX: Safe parsing utilities
import 'package:growlog_app/config/harvest_config.dart'; // ✅ FIX: Validation config

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class Harvest {
  final int? id;
  final int plantId;

  // Ernte-Daten
  final DateTime harvestDate;
  final double? wetWeight; // Nassgewicht in Gramm
  final double? dryWeight; // Trockengewicht in Gramm

  // Trocknungs-Tracking
  final DateTime? dryingStartDate;
  final DateTime? dryingEndDate;
  final int? dryingDays; // Automatisch berechnet
  final String? dryingMethod; // z.B. "Hängend", "Netz", "Box"
  final double? dryingTemperature;
  final double? dryingHumidity;

  // Curing-Tracking
  final DateTime? curingStartDate;
  final DateTime? curingEndDate;
  final int? curingDays; // Automatisch berechnet
  final String? curingMethod; // z.B. "Glass Jars", "Grove Bags"
  final String? curingNotes;

  // Qualitäts-Daten (optional)
  final double? thcPercentage;
  final double? cbdPercentage;
  final String? terpeneProfile; // z.B. "Myrcene, Limonene, Caryophyllene"

  // Bewertung & Notizen
  final int? rating; // 1-5 Sterne
  final String? tasteNotes;
  final String? effectNotes;
  final String? overallNotes;

  final DateTime createdAt;
  final DateTime? updatedAt;

  Harvest({
    this.id,
    required this.plantId,
    required this.harvestDate,
    double? wetWeight,
    double? dryWeight,
    this.dryingStartDate,
    this.dryingEndDate,
    int? dryingDays,
    this.dryingMethod,
    double? dryingTemperature,
    double? dryingHumidity,
    this.curingStartDate,
    this.curingEndDate,
    int? curingDays,
    this.curingMethod,
    this.curingNotes,
    double? thcPercentage,
    double? cbdPercentage,
    this.terpeneProfile,
    int? rating,
    this.tasteNotes,
    this.effectNotes,
    this.overallNotes,
    DateTime? createdAt,
    this.updatedAt,
  }) : // ✅ VALIDATION: Apply validation from HarvestConfig
       wetWeight = HarvestConfig.validateWeight(wetWeight),
       dryWeight = HarvestConfig.validateWeight(dryWeight),
       dryingDays = HarvestConfig.validateDryingDays(dryingDays),
       dryingTemperature = HarvestConfig.validateDryingTemperature(dryingTemperature),
       dryingHumidity = HarvestConfig.validateHumidity(dryingHumidity),
       curingDays = HarvestConfig.validateCuringDays(curingDays),
       thcPercentage = HarvestConfig.validatePercentage(thcPercentage),
       cbdPercentage = HarvestConfig.validatePercentage(cbdPercentage),
       rating = HarvestConfig.validateRating(rating),
       createdAt = createdAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  /// ✅ FIX: All 7 DateTime.parse now use safe parsers
  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id'] as int?,
      plantId: map['plant_id'] as int,
      harvestDate: SafeParsers.parseDateTime(
        map['harvest_date'] as String?,
        fallback: DateTime.now(),
        context: 'Harvest.fromMap.harvestDate',
      ),
      wetWeight: (map['wet_weight'] as num?)?.toDouble(),
      dryWeight: (map['dry_weight'] as num?)?.toDouble(),
      dryingStartDate: SafeParsers.parseDateTimeNullable(
        map['drying_start_date'] as String?,
        context: 'Harvest.fromMap.dryingStartDate',
      ),
      dryingEndDate: SafeParsers.parseDateTimeNullable(
        map['drying_end_date'] as String?,
        context: 'Harvest.fromMap.dryingEndDate',
      ),
      dryingDays: map['drying_days'] as int?,
      dryingMethod: map['drying_method'] as String?,
      dryingTemperature: (map['drying_temperature'] as num?)?.toDouble(),
      dryingHumidity: (map['drying_humidity'] as num?)?.toDouble(),
      curingStartDate: SafeParsers.parseDateTimeNullable(
        map['curing_start_date'] as String?,
        context: 'Harvest.fromMap.curingStartDate',
      ),
      curingEndDate: SafeParsers.parseDateTimeNullable(
        map['curing_end_date'] as String?,
        context: 'Harvest.fromMap.curingEndDate',
      ),
      curingDays: map['curing_days'] as int?,
      curingMethod: map['curing_method'] as String?,
      curingNotes: map['curing_notes'] as String?,
      thcPercentage: (map['thc_percentage'] as num?)?.toDouble(),
      cbdPercentage: (map['cbd_percentage'] as num?)?.toDouble(),
      terpeneProfile: map['terpene_profile'] as String?,
      rating: map['rating'] as int?,
      tasteNotes: map['taste_notes'] as String?,
      effectNotes: map['effect_notes'] as String?,
      overallNotes: map['overall_notes'] as String?,
      createdAt: SafeParsers.parseDateTime(
        map['created_at'] as String?,
        fallback: DateTime.now(),
        context: 'Harvest.fromMap.createdAt',
      ),
      updatedAt: SafeParsers.parseDateTimeNullable(
        map['updated_at'] as String?,
        context: 'Harvest.fromMap.updatedAt',
      ),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'plant_id': plantId,
      'harvest_date': harvestDate.toIso8601String(),
      'wet_weight': wetWeight,
      'dry_weight': dryWeight,
      'drying_start_date': dryingStartDate?.toIso8601String(),
      'drying_end_date': dryingEndDate?.toIso8601String(),
      'drying_days': dryingDays,
      'drying_method': dryingMethod,
      'drying_temperature': dryingTemperature,
      'drying_humidity': dryingHumidity,
      'curing_start_date': curingStartDate?.toIso8601String(),
      'curing_end_date': curingEndDate?.toIso8601String(),
      'curing_days': curingDays,
      'curing_method': curingMethod,
      'curing_notes': curingNotes,
      'thc_percentage': thcPercentage,
      'cbd_percentage': cbdPercentage,
      'terpene_profile': terpeneProfile,
      'rating': rating,
      'taste_notes': tasteNotes,
      'effect_notes': effectNotes,
      'overall_notes': overallNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    // Nur ID hinzufügen wenn sie nicht null ist (für UPDATE)
    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  /// Copy mit Änderungen
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  Harvest copyWith({
    int? id,
    int? plantId,
    DateTime? harvestDate,
    Object? wetWeight = _undefined,
    Object? dryWeight = _undefined,
    Object? dryingStartDate = _undefined,
    Object? dryingEndDate = _undefined,
    Object? dryingDays = _undefined,
    Object? dryingMethod = _undefined,
    Object? dryingTemperature = _undefined,
    Object? dryingHumidity = _undefined,
    Object? curingStartDate = _undefined,
    Object? curingEndDate = _undefined,
    Object? curingDays = _undefined,
    Object? curingMethod = _undefined,
    Object? curingNotes = _undefined,
    Object? thcPercentage = _undefined,
    Object? cbdPercentage = _undefined,
    Object? terpeneProfile = _undefined,
    Object? rating = _undefined,
    Object? tasteNotes = _undefined,
    Object? effectNotes = _undefined,
    Object? overallNotes = _undefined,
    DateTime? createdAt,
    Object? updatedAt = _undefined,
  }) {
    return Harvest(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      harvestDate: harvestDate ?? this.harvestDate,
      wetWeight: wetWeight == _undefined
          ? this.wetWeight
          : wetWeight as double?,
      dryWeight: dryWeight == _undefined
          ? this.dryWeight
          : dryWeight as double?,
      dryingStartDate: dryingStartDate == _undefined
          ? this.dryingStartDate
          : dryingStartDate as DateTime?,
      dryingEndDate: dryingEndDate == _undefined
          ? this.dryingEndDate
          : dryingEndDate as DateTime?,
      dryingDays: dryingDays == _undefined
          ? this.dryingDays
          : dryingDays as int?,
      dryingMethod: dryingMethod == _undefined
          ? this.dryingMethod
          : dryingMethod as String?,
      dryingTemperature: dryingTemperature == _undefined
          ? this.dryingTemperature
          : dryingTemperature as double?,
      dryingHumidity: dryingHumidity == _undefined
          ? this.dryingHumidity
          : dryingHumidity as double?,
      curingStartDate: curingStartDate == _undefined
          ? this.curingStartDate
          : curingStartDate as DateTime?,
      curingEndDate: curingEndDate == _undefined
          ? this.curingEndDate
          : curingEndDate as DateTime?,
      curingDays: curingDays == _undefined
          ? this.curingDays
          : curingDays as int?,
      curingMethod: curingMethod == _undefined
          ? this.curingMethod
          : curingMethod as String?,
      curingNotes: curingNotes == _undefined
          ? this.curingNotes
          : curingNotes as String?,
      thcPercentage: thcPercentage == _undefined
          ? this.thcPercentage
          : thcPercentage as double?,
      cbdPercentage: cbdPercentage == _undefined
          ? this.cbdPercentage
          : cbdPercentage as double?,
      terpeneProfile: terpeneProfile == _undefined
          ? this.terpeneProfile
          : terpeneProfile as String?,
      rating: rating == _undefined ? this.rating : rating as int?,
      tasteNotes: tasteNotes == _undefined
          ? this.tasteNotes
          : tasteNotes as String?,
      effectNotes: effectNotes == _undefined
          ? this.effectNotes
          : effectNotes as String?,
      overallNotes: overallNotes == _undefined
          ? this.overallNotes
          : overallNotes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _undefined
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  /// Berechne Trocknungs-Tage automatisch
  /// ✅ FIX: Add +1 to include both start and end dates (was off-by-one)
  int? get calculatedDryingDays {
    if (dryingStartDate != null && dryingEndDate != null) {
      return dryingEndDate!.difference(dryingStartDate!).inDays + 1;
    }
    return dryingDays;
  }

  /// Berechne Curing-Tage automatisch
  /// ✅ FIX: Add +1 to include both start and end dates (was off-by-one)
  int? get calculatedCuringDays {
    if (curingStartDate != null && curingEndDate != null) {
      return curingEndDate!.difference(curingStartDate!).inDays + 1;
    }
    return curingDays;
  }

  /// Trocknungs-Status
  String get dryingStatus {
    if (dryingEndDate != null) return 'Abgeschlossen';
    if (dryingStartDate != null) return 'In Trocknung';
    return 'Nicht gestartet';
  }

  /// Curing-Status
  String get curingStatus {
    if (curingEndDate != null) return 'Abgeschlossen';
    if (curingStartDate != null) return 'In Curing';
    return 'Nicht gestartet';
  }

  /// Gewichtsverlust in Prozent
  /// ✅ FIX: Prevent negative percentages when dryWeight > wetWeight
  double? get weightLossPercentage {
    final wet = wetWeight;
    final dry = dryWeight;

    // ✅ FIX: Check all conditions and avoid force unwraps
    if (wet == null || dry == null || wet <= 0) {
      return null;
    }

    // Validate that dry weight is not greater than wet weight
    if (dry > wet) {
      return 0.0; // Invalid data, return 0 instead of negative
    }

    return ((wet - dry) / wet) * 100;
  }

  /// Ist komplett fertig?
  bool get isComplete {
    return dryWeight != null && dryingEndDate != null && curingEndDate != null;
  }

  @override
  String toString() {
    return 'Harvest{id: $id, plantId: $plantId, dryWeight: ${dryWeight}g, status: $dryingStatus/$curingStatus}';
  }
}
