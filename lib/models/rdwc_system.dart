// =============================================
// GROWLOG - RDWC System Model
// =============================================

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class RdwcSystem {
  final int? id;
  final String name;
  final int? roomId;              // Optional: which room/tent
  final int? growId;              // Optional: which grow cycle
  final double maxCapacity;       // Maximum reservoir capacity in liters
  final double currentLevel;      // Current water level in liters
  final int bucketCount;          // Number of buckets/plant sites
  final String? description;
  // Hardware Specifications - Water Pump
  final String? pumpBrand;        // Pump manufacturer
  final String? pumpModel;        // Pump model name/number
  final int? pumpWattage;         // Pump power consumption in watts
  final double? pumpFlowRate;     // Pump flow rate in liters/hour
  // Hardware Specifications - Air Pump
  final String? airPumpBrand;     // Air pump manufacturer
  final String? airPumpModel;     // Air pump model name/number
  final int? airPumpWattage;      // Air pump power consumption in watts
  final double? airPumpFlowRate;  // Air pump flow rate in liters/hour
  // Hardware Specifications - Chiller
  final String? chillerBrand;     // Chiller manufacturer
  final String? chillerModel;     // Chiller model name/number
  final int? chillerWattage;      // Chiller power consumption in watts
  final int? chillerCoolingPower; // Chiller cooling power in watts
  final String? accessories;      // Additional equipment
  final DateTime createdAt;
  final bool archived;

  // ✅ FIX: Replace assertions with safe validation and clamping
  RdwcSystem({
    this.id,
    required String name,
    this.roomId,
    this.growId,
    required double maxCapacity,
    double currentLevel = 0.0,
    int bucketCount = 4,           // Default: 4 buckets
    this.description,
    this.pumpBrand,
    this.pumpModel,
    this.pumpWattage,
    this.pumpFlowRate,
    this.airPumpBrand,
    this.airPumpModel,
    this.airPumpWattage,
    this.airPumpFlowRate,
    this.chillerBrand,
    this.chillerModel,
    this.chillerWattage,
    this.chillerCoolingPower,
    this.accessories,
    DateTime? createdAt,
    this.archived = false,
  }) :
       // ✅ FIX: Validate and clamp values instead of assertions
       name = name.trim().isEmpty ? 'Unnamed System' : name,
       maxCapacity = maxCapacity > 0 ? maxCapacity : 100.0,
       currentLevel = currentLevel < 0 ? 0.0 : (currentLevel > maxCapacity ? maxCapacity : currentLevel),
       bucketCount = bucketCount > 0 ? bucketCount : 1,
       createdAt = createdAt ?? DateTime.now();

  /// Factory: Create from database map
  factory RdwcSystem.fromMap(Map<String, dynamic> map) {
    return RdwcSystem(
      id: map['id'] as int?,
      name: map['name'] as String,
      roomId: map['room_id'] as int?,
      growId: map['grow_id'] as int?,
      maxCapacity: (map['max_capacity'] as num).toDouble(),
      currentLevel: (map['current_level'] as num?)?.toDouble() ?? 0.0,
      bucketCount: (map['bucket_count'] as int?) ?? 4,
      description: map['description'] as String?,
      pumpBrand: map['pump_brand'] as String?,
      pumpModel: map['pump_model'] as String?,
      pumpWattage: map['pump_wattage'] as int?,
      pumpFlowRate: (map['pump_flow_rate'] as num?)?.toDouble(),
      airPumpBrand: map['air_pump_brand'] as String?,
      airPumpModel: map['air_pump_model'] as String?,
      airPumpWattage: map['air_pump_wattage'] as int?,
      airPumpFlowRate: (map['air_pump_flow_rate'] as num?)?.toDouble(),
      chillerBrand: map['chiller_brand'] as String?,
      chillerModel: map['chiller_model'] as String?,
      chillerWattage: map['chiller_wattage'] as int?,
      chillerCoolingPower: map['chiller_cooling_power'] as int?,
      accessories: map['accessories'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      archived: (map['archived'] as int?) == 1,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'room_id': roomId,
      'grow_id': growId,
      'max_capacity': maxCapacity,
      'current_level': currentLevel,
      'bucket_count': bucketCount,
      'description': description,
      'pump_brand': pumpBrand,
      'pump_model': pumpModel,
      'pump_wattage': pumpWattage,
      'pump_flow_rate': pumpFlowRate,
      'air_pump_brand': airPumpBrand,
      'air_pump_model': airPumpModel,
      'air_pump_wattage': airPumpWattage,
      'air_pump_flow_rate': airPumpFlowRate,
      'chiller_brand': chillerBrand,
      'chiller_model': chillerModel,
      'chiller_wattage': chillerWattage,
      'chiller_cooling_power': chillerCoolingPower,
      'accessories': accessories,
      'created_at': createdAt.toIso8601String(),
      'archived': archived ? 1 : 0,
    };
  }

  /// Copy with changes
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  RdwcSystem copyWith({
    int? id,
    String? name,
    Object? roomId = _undefined,
    Object? growId = _undefined,
    double? maxCapacity,
    double? currentLevel,
    int? bucketCount,
    Object? description = _undefined,
    Object? pumpBrand = _undefined,
    Object? pumpModel = _undefined,
    Object? pumpWattage = _undefined,
    Object? pumpFlowRate = _undefined,
    Object? airPumpBrand = _undefined,
    Object? airPumpModel = _undefined,
    Object? airPumpWattage = _undefined,
    Object? airPumpFlowRate = _undefined,
    Object? chillerBrand = _undefined,
    Object? chillerModel = _undefined,
    Object? chillerWattage = _undefined,
    Object? chillerCoolingPower = _undefined,
    Object? accessories = _undefined,
    DateTime? createdAt,
    bool? archived,
  }) {
    return RdwcSystem(
      id: id ?? this.id,
      name: name ?? this.name,
      roomId: roomId == _undefined ? this.roomId : roomId as int?,
      growId: growId == _undefined ? this.growId : growId as int?,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentLevel: currentLevel ?? this.currentLevel,
      bucketCount: bucketCount ?? this.bucketCount,
      description: description == _undefined ? this.description : description as String?,
      pumpBrand: pumpBrand == _undefined ? this.pumpBrand : pumpBrand as String?,
      pumpModel: pumpModel == _undefined ? this.pumpModel : pumpModel as String?,
      pumpWattage: pumpWattage == _undefined ? this.pumpWattage : pumpWattage as int?,
      pumpFlowRate: pumpFlowRate == _undefined ? this.pumpFlowRate : pumpFlowRate as double?,
      airPumpBrand: airPumpBrand == _undefined ? this.airPumpBrand : airPumpBrand as String?,
      airPumpModel: airPumpModel == _undefined ? this.airPumpModel : airPumpModel as String?,
      airPumpWattage: airPumpWattage == _undefined ? this.airPumpWattage : airPumpWattage as int?,
      airPumpFlowRate: airPumpFlowRate == _undefined ? this.airPumpFlowRate : airPumpFlowRate as double?,
      chillerBrand: chillerBrand == _undefined ? this.chillerBrand : chillerBrand as String?,
      chillerModel: chillerModel == _undefined ? this.chillerModel : chillerModel as String?,
      chillerWattage: chillerWattage == _undefined ? this.chillerWattage : chillerWattage as int?,
      chillerCoolingPower: chillerCoolingPower == _undefined ? this.chillerCoolingPower : chillerCoolingPower as int?,
      accessories: accessories == _undefined ? this.accessories : accessories as String?,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
    );
  }

  /// Calculate fill percentage
  double get fillPercentage {
    if (maxCapacity == 0) return 0.0;
    return (currentLevel / maxCapacity) * 100;
  }

  /// Calculate remaining capacity
  double get remainingCapacity {
    return maxCapacity - currentLevel;
  }

  /// Check if system is low on water (below 30%)
  bool get isLowWater {
    return fillPercentage < 30.0;
  }

  /// Check if system is critically low (below 15%)
  bool get isCriticallyLow {
    return fillPercentage < 15.0;
  }

  /// Check if system is full (above 95%)
  bool get isFull {
    return fillPercentage >= 95.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RdwcSystem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RdwcSystem{id: $id, name: $name, capacity: $maxCapacity L, level: $currentLevel L}';
  }
}
