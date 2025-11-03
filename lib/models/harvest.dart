// =============================================
// GROWLOG - Harvest Model (Ernte-Tracking)
// =============================================

class Harvest {
  final int? id;
  final int plantId;
  
  // Ernte-Daten
  final DateTime harvestDate;
  final double? wetWeight;        // Nassgewicht in Gramm
  final double? dryWeight;        // Trockengewicht in Gramm
  
  // Trocknungs-Tracking
  final DateTime? dryingStartDate;
  final DateTime? dryingEndDate;
  final int? dryingDays;          // Automatisch berechnet
  final String? dryingMethod;     // z.B. "Hängend", "Netz", "Box"
  final double? dryingTemperature;
  final double? dryingHumidity;
  
  // Curing-Tracking
  final DateTime? curingStartDate;
  final DateTime? curingEndDate;
  final int? curingDays;          // Automatisch berechnet
  final String? curingMethod;     // z.B. "Glass Jars", "Grove Bags"
  final String? curingNotes;
  
  // Qualitäts-Daten (optional)
  final double? thcPercentage;
  final double? cbdPercentage;
  final String? terpeneProfile;   // z.B. "Myrcene, Limonene, Caryophyllene"
  
  // Bewertung & Notizen
  final int? rating;              // 1-5 Sterne
  final String? tasteNotes;
  final String? effectNotes;
  final String? overallNotes;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  Harvest({
    this.id,
    required this.plantId,
    required this.harvestDate,
    this.wetWeight,
    this.dryWeight,
    this.dryingStartDate,
    this.dryingEndDate,
    this.dryingDays,
    this.dryingMethod,
    this.dryingTemperature,
    this.dryingHumidity,
    this.curingStartDate,
    this.curingEndDate,
    this.curingDays,
    this.curingMethod,
    this.curingNotes,
    this.thcPercentage,
    this.cbdPercentage,
    this.terpeneProfile,
    this.rating,
    this.tasteNotes,
    this.effectNotes,
    this.overallNotes,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id'] as int?,
      plantId: map['plant_id'] as int,
      harvestDate: DateTime.parse(map['harvest_date'] as String),
      wetWeight: (map['wet_weight'] as num?)?.toDouble(),
      dryWeight: (map['dry_weight'] as num?)?.toDouble(),
      dryingStartDate: map['drying_start_date'] != null
          ? DateTime.parse(map['drying_start_date'] as String)
          : null,
      dryingEndDate: map['drying_end_date'] != null
          ? DateTime.parse(map['drying_end_date'] as String)
          : null,
      dryingDays: map['drying_days'] as int?,
      dryingMethod: map['drying_method'] as String?,
      dryingTemperature: (map['drying_temperature'] as num?)?.toDouble(),
      dryingHumidity: (map['drying_humidity'] as num?)?.toDouble(),
      curingStartDate: map['curing_start_date'] != null
          ? DateTime.parse(map['curing_start_date'] as String)
          : null,
      curingEndDate: map['curing_end_date'] != null
          ? DateTime.parse(map['curing_end_date'] as String)
          : null,
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
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
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
  Harvest copyWith({
    int? id,
    int? plantId,
    DateTime? harvestDate,
    double? wetWeight,
    double? dryWeight,
    DateTime? dryingStartDate,
    DateTime? dryingEndDate,
    int? dryingDays,
    String? dryingMethod,
    double? dryingTemperature,
    double? dryingHumidity,
    DateTime? curingStartDate,
    DateTime? curingEndDate,
    int? curingDays,
    String? curingMethod,
    String? curingNotes,
    double? thcPercentage,
    double? cbdPercentage,
    String? terpeneProfile,
    int? rating,
    String? tasteNotes,
    String? effectNotes,
    String? overallNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Harvest(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      harvestDate: harvestDate ?? this.harvestDate,
      wetWeight: wetWeight ?? this.wetWeight,
      dryWeight: dryWeight ?? this.dryWeight,
      dryingStartDate: dryingStartDate ?? this.dryingStartDate,
      dryingEndDate: dryingEndDate ?? this.dryingEndDate,
      dryingDays: dryingDays ?? this.dryingDays,
      dryingMethod: dryingMethod ?? this.dryingMethod,
      dryingTemperature: dryingTemperature ?? this.dryingTemperature,
      dryingHumidity: dryingHumidity ?? this.dryingHumidity,
      curingStartDate: curingStartDate ?? this.curingStartDate,
      curingEndDate: curingEndDate ?? this.curingEndDate,
      curingDays: curingDays ?? this.curingDays,
      curingMethod: curingMethod ?? this.curingMethod,
      curingNotes: curingNotes ?? this.curingNotes,
      thcPercentage: thcPercentage ?? this.thcPercentage,
      cbdPercentage: cbdPercentage ?? this.cbdPercentage,
      terpeneProfile: terpeneProfile ?? this.terpeneProfile,
      rating: rating ?? this.rating,
      tasteNotes: tasteNotes ?? this.tasteNotes,
      effectNotes: effectNotes ?? this.effectNotes,
      overallNotes: overallNotes ?? this.overallNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Berechne Trocknungs-Tage automatisch
  int? get calculatedDryingDays {
    if (dryingStartDate != null && dryingEndDate != null) {
      return dryingEndDate!.difference(dryingStartDate!).inDays;
    }
    return dryingDays;
  }

  /// Berechne Curing-Tage automatisch
  int? get calculatedCuringDays {
    if (curingStartDate != null && curingEndDate != null) {
      return curingEndDate!.difference(curingStartDate!).inDays;
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
  double? get weightLossPercentage {
    if (wetWeight != null && dryWeight != null && wetWeight! > 0) {
      return ((wetWeight! - dryWeight!) / wetWeight!) * 100;
    }
    return null;
  }

  /// Ist komplett fertig?
  bool get isComplete {
    return dryWeight != null && 
           dryingEndDate != null && 
           curingEndDate != null;
  }

  @override
  String toString() {
    return 'Harvest{id: $id, plantId: $plantId, dryWeight: ${dryWeight}g, status: $dryingStatus/$curingStatus}';
  }
}
