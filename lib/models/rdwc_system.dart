// =============================================
// GROWLOG - RDWC System Model
// =============================================

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

  RdwcSystem({
    this.id,
    required this.name,
    this.roomId,
    this.growId,
    required this.maxCapacity,
    this.currentLevel = 0.0,
    this.bucketCount = 4,           // Default: 4 buckets
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
  }) : assert(name.isNotEmpty, 'Name cannot be empty'),
       assert(maxCapacity > 0, 'Max capacity must be greater than 0'),
       assert(currentLevel >= 0, 'Current level cannot be negative'),
       assert(currentLevel <= maxCapacity, 'Current level cannot exceed max capacity'),
       assert(bucketCount > 0, 'Bucket count must be greater than 0'),
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
  RdwcSystem copyWith({
    int? id,
    String? name,
    int? roomId,
    int? growId,
    double? maxCapacity,
    double? currentLevel,
    int? bucketCount,
    String? description,
    String? pumpBrand,
    String? pumpModel,
    int? pumpWattage,
    double? pumpFlowRate,
    String? airPumpBrand,
    String? airPumpModel,
    int? airPumpWattage,
    double? airPumpFlowRate,
    String? chillerBrand,
    String? chillerModel,
    int? chillerWattage,
    int? chillerCoolingPower,
    String? accessories,
    DateTime? createdAt,
    bool? archived,
  }) {
    return RdwcSystem(
      id: id ?? this.id,
      name: name ?? this.name,
      roomId: roomId ?? this.roomId,
      growId: growId ?? this.growId,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentLevel: currentLevel ?? this.currentLevel,
      bucketCount: bucketCount ?? this.bucketCount,
      description: description ?? this.description,
      pumpBrand: pumpBrand ?? this.pumpBrand,
      pumpModel: pumpModel ?? this.pumpModel,
      pumpWattage: pumpWattage ?? this.pumpWattage,
      pumpFlowRate: pumpFlowRate ?? this.pumpFlowRate,
      airPumpBrand: airPumpBrand ?? this.airPumpBrand,
      airPumpModel: airPumpModel ?? this.airPumpModel,
      airPumpWattage: airPumpWattage ?? this.airPumpWattage,
      airPumpFlowRate: airPumpFlowRate ?? this.airPumpFlowRate,
      chillerBrand: chillerBrand ?? this.chillerBrand,
      chillerModel: chillerModel ?? this.chillerModel,
      chillerWattage: chillerWattage ?? this.chillerWattage,
      chillerCoolingPower: chillerCoolingPower ?? this.chillerCoolingPower,
      accessories: accessories ?? this.accessories,
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
