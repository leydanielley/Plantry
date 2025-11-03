// =============================================
// GROWLOG - Hardware Model
// =============================================

import 'enums.dart';

class Hardware {
  final int? id;
  final int roomId;
  final String name;
  final HardwareType type;
  final String? brand;
  final String? model;
  
  // Allgemeine Felder
  final int? wattage;              // Wattzahl (für Lampen, Lüfter, Klimatechnik)
  final int? quantity;             // Anzahl
  
  // Beleuchtung
  final int? airflow;              // Luftdurchsatz in m³/h (für Lüfter)
  final String? spectrum;          // Lichtspektrum (LED)
  final String? colorTemperature;  // Farbtemperatur (HPS/MH/CFL)
  final bool? dimmable;            // Dimmbar? (Lampen, Lüfter)
  
  // Lüftung
  final String? flangeSize;        // Flansch-Größe (Lüfter)
  final bool? controllable;        // Regelbar? (Lüfter)
  final bool? oscillating;         // Oszillierend? (Umluft)
  final int? diameter;             // Durchmesser in cm (Umluft)
  
  // Klimatechnik
  final int? coolingPower;         // Kühlleistung BTU (Klimaanlage)
  final int? heatingPower;         // Heizleistung Watt (Heizung)
  final double? coverage;          // Abdeckung m²/m³
  final bool? hasThermostat;       // Thermostat? (Heizung)
  final int? humidificationRate;   // Befeuchtungsleistung ml/h
  
  // Bewässerung
  final int? pumpRate;             // Förderleistung L/h (Pumpe)
  final bool? isDigital;           // Digital/Analog (Timer)
  final int? programCount;         // Anzahl Programme (Timer)
  final int? dripperCount;         // Anzahl Tropfer
  final int? capacity;             // Kapazität Liter (Reservoir)
  final String? material;          // Material (Reservoir)
  final bool? hasChiller;          // Mit Chiller?
  final bool? hasAirPump;          // Mit Luftpumpe?
  
  // Filter & Controller
  final String? filterDiameter;    // Filter-Durchmesser (AKF)
  final int? filterLength;         // Filter-Länge cm (AKF)
  final String? controllerType;    // Controller-Typ
  final int? outputCount;          // Anzahl Ausgänge (Controller)
  final String? controllerFunctions; // Funktionen (Controller)
  
  // Optionale Felder
  final String? specifications;    // Zusätzliche Specs
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? notes;
  final bool active;
  final DateTime createdAt;

  Hardware({
    this.id,
    required this.roomId,
    required this.name,
    required this.type,
    this.brand,
    this.model,
    this.wattage,
    this.quantity = 1,
    this.airflow,
    this.spectrum,
    this.colorTemperature,
    this.dimmable,
    this.flangeSize,
    this.controllable,
    this.oscillating,
    this.diameter,
    this.coolingPower,
    this.heatingPower,
    this.coverage,
    this.hasThermostat,
    this.humidificationRate,
    this.pumpRate,
    this.isDigital,
    this.programCount,
    this.dripperCount,
    this.capacity,
    this.material,
    this.hasChiller,
    this.hasAirPump,
    this.filterDiameter,
    this.filterLength,
    this.controllerType,
    this.outputCount,
    this.controllerFunctions,
    this.specifications,
    this.purchaseDate,
    this.purchasePrice,
    this.notes,
    this.active = true,
    DateTime? createdAt,
  }) : assert(roomId > 0, 'Room ID must be greater than 0'),
        assert(name.isNotEmpty, 'Name cannot be empty'),
        createdAt = createdAt ?? DateTime.now();

  /// Helper: Parse Hardware Type mit Fallback für alte DB-Einträge
  static HardwareType _parseHardwareType(String value) {
    // Handle both camelCase and lowercase formats
    final normalized = value.toLowerCase();
    
    final typeMap = <String, HardwareType>{
      'ledpanel': HardwareType.ledPanel,
      'hpslamp': HardwareType.hpsLamp,
      'mhlamp': HardwareType.mhLamp,
      'cfllamp': HardwareType.cflLamp,
      'exhaustfan': HardwareType.exhaustFan,
      'circulationfan': HardwareType.circulationFan,
      'airconditioner': HardwareType.airConditioner,
      'dripsystem': HardwareType.dripSystem,
      'phmeter': HardwareType.phMeter,
      'ecmeter': HardwareType.ecMeter,
      'co2sensor': HardwareType.co2Sensor,
    };
    
    if (typeMap.containsKey(normalized)) {
      return typeMap[normalized]!;
    }
    
    // Try to match by enum name
    try {
      return HardwareType.values.firstWhere(
        (e) => e.name.toLowerCase() == normalized,
        orElse: () => HardwareType.other,
      );
    } catch (e) {
      // Unknown type: $value, falling back to "other"
      return HardwareType.other;
    }
  }

  /// Factory: Aus Map erstellen (von Datenbank)
  factory Hardware.fromMap(Map<String, dynamic> map) {
    return Hardware(
      id: map['id'] as int?,
      roomId: map['room_id'] as int,
      name: map['name'] as String,
      type: _parseHardwareType(map['type'].toString()),
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      wattage: map['wattage'] as int?,
      quantity: map['quantity'] as int? ?? 1,
      airflow: map['airflow'] as int?,
      spectrum: map['spectrum'] as String?,
      colorTemperature: map['color_temperature'] as String?,
      dimmable: map['dimmable'] != null ? (map['dimmable'] as int) == 1 : null,
      flangeSize: map['flange_size'] as String?,
      controllable: map['controllable'] != null ? (map['controllable'] as int) == 1 : null,
      oscillating: map['oscillating'] != null ? (map['oscillating'] as int) == 1 : null,
      diameter: map['diameter'] as int?,
      coolingPower: map['cooling_power'] as int?,
      heatingPower: map['heating_power'] as int?,
      coverage: (map['coverage'] as num?)?.toDouble(),
      hasThermostat: map['has_thermostat'] != null ? (map['has_thermostat'] as int) == 1 : null,
      humidificationRate: map['humidification_rate'] as int?,
      pumpRate: map['pump_rate'] as int?,
      isDigital: map['is_digital'] != null ? (map['is_digital'] as int) == 1 : null,
      programCount: map['program_count'] as int?,
      dripperCount: map['dripper_count'] as int?,
      capacity: map['capacity'] as int?,
      material: map['material'] as String?,
      hasChiller: map['has_chiller'] != null ? (map['has_chiller'] as int) == 1 : null,
      hasAirPump: map['has_air_pump'] != null ? (map['has_air_pump'] as int) == 1 : null,
      filterDiameter: map['filter_diameter'] as String?,
      filterLength: map['filter_length'] as int?,
      controllerType: map['controller_type'] as String?,
      outputCount: map['output_count'] as int?,
      controllerFunctions: map['controller_functions'] as String?,
      specifications: map['specifications'] as String?,
      purchaseDate: map['purchase_date'] != null 
          ? DateTime.parse(map['purchase_date'] as String) 
          : null,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      active: map['active'] != null ? (map['active'] as int) == 1 : true,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'type': type.name,
      'brand': brand,
      'model': model,
      'wattage': wattage,
      'quantity': quantity,
      'airflow': airflow,
      'spectrum': spectrum,
      'color_temperature': colorTemperature,
      'dimmable': dimmable != null ? (dimmable! ? 1 : 0) : null,
      'flange_size': flangeSize,
      'controllable': controllable != null ? (controllable! ? 1 : 0) : null,
      'oscillating': oscillating != null ? (oscillating! ? 1 : 0) : null,
      'diameter': diameter,
      'cooling_power': coolingPower,
      'heating_power': heatingPower,
      'coverage': coverage,
      'has_thermostat': hasThermostat != null ? (hasThermostat! ? 1 : 0) : null,
      'humidification_rate': humidificationRate,
      'pump_rate': pumpRate,
      'is_digital': isDigital != null ? (isDigital! ? 1 : 0) : null,
      'program_count': programCount,
      'dripper_count': dripperCount,
      'capacity': capacity,
      'material': material,
      'has_chiller': hasChiller != null ? (hasChiller! ? 1 : 0) : null,
      'has_air_pump': hasAirPump != null ? (hasAirPump! ? 1 : 0) : null,
      'filter_diameter': filterDiameter,
      'filter_length': filterLength,
      'controller_type': controllerType,
      'output_count': outputCount,
      'controller_functions': controllerFunctions,
      'specifications': specifications,
      'purchase_date': purchaseDate?.toIso8601String().split('T')[0],
      'purchase_price': purchasePrice,
      'notes': notes,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy mit Änderungen
  Hardware copyWith({
    int? id,
    int? roomId,
    String? name,
    HardwareType? type,
    String? brand,
    String? model,
    int? wattage,
    int? quantity,
    int? airflow,
    String? spectrum,
    String? colorTemperature,
    bool? dimmable,
    String? flangeSize,
    bool? controllable,
    bool? oscillating,
    int? diameter,
    int? coolingPower,
    int? heatingPower,
    double? coverage,
    bool? hasThermostat,
    int? humidificationRate,
    int? pumpRate,
    bool? isDigital,
    int? programCount,
    int? dripperCount,
    int? capacity,
    String? material,
    bool? hasChiller,
    bool? hasAirPump,
    String? filterDiameter,
    int? filterLength,
    String? controllerType,
    int? outputCount,
    String? controllerFunctions,
    String? specifications,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? notes,
    bool? active,
    DateTime? createdAt,
  }) {
    return Hardware(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      wattage: wattage ?? this.wattage,
      quantity: quantity ?? this.quantity,
      airflow: airflow ?? this.airflow,
      spectrum: spectrum ?? this.spectrum,
      colorTemperature: colorTemperature ?? this.colorTemperature,
      dimmable: dimmable ?? this.dimmable,
      flangeSize: flangeSize ?? this.flangeSize,
      controllable: controllable ?? this.controllable,
      oscillating: oscillating ?? this.oscillating,
      diameter: diameter ?? this.diameter,
      coolingPower: coolingPower ?? this.coolingPower,
      heatingPower: heatingPower ?? this.heatingPower,
      coverage: coverage ?? this.coverage,
      hasThermostat: hasThermostat ?? this.hasThermostat,
      humidificationRate: humidificationRate ?? this.humidificationRate,
      pumpRate: pumpRate ?? this.pumpRate,
      isDigital: isDigital ?? this.isDigital,
      programCount: programCount ?? this.programCount,
      dripperCount: dripperCount ?? this.dripperCount,
      capacity: capacity ?? this.capacity,
      material: material ?? this.material,
      hasChiller: hasChiller ?? this.hasChiller,
      hasAirPump: hasAirPump ?? this.hasAirPump,
      filterDiameter: filterDiameter ?? this.filterDiameter,
      filterLength: filterLength ?? this.filterLength,
      controllerType: controllerType ?? this.controllerType,
      outputCount: outputCount ?? this.outputCount,
      controllerFunctions: controllerFunctions ?? this.controllerFunctions,
      specifications: specifications ?? this.specifications,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Voller Display-Name mit Menge
  String get displayName {
    if (quantity != null && quantity! > 1) {
      return '$quantity× $name';
    }
    return name;
  }

  /// Hardware-Info Text (Brand + Model)
  String get hardwareInfo {
    final parts = <String>[];
    if (brand != null) parts.add(brand!);
    if (model != null) parts.add(model!);
    if (parts.isEmpty) return 'Keine Details';
    return parts.join(' ');
  }

  /// Wattage Display Text
  String get wattageDisplay {
    if (wattage == null) return '';
    final total = wattage! * (quantity ?? 1);
    if (quantity != null && quantity! > 1) {
      return '$wattage W × $quantity = $total W';
    }
    return '$wattage W';
  }

  /// Total wattage (wattage * quantity)
  int get totalWattage {
    if (wattage == null) return 0;
    return wattage! * (quantity ?? 1);
  }

  /// Display info for lists
  String get displayInfo {
    final parts = <String>[];
    
    // Logic: 
    // - If both brand and model exist: brand + model
    // - If only brand exists: brand + name
    // - If only model exists: model
    // - If neither: name
    
    if (brand != null && brand!.isNotEmpty && model != null && model!.isNotEmpty) {
      // Both brand and model
      parts.add(brand!);
      parts.add(model!);
    } else if (brand != null && brand!.isNotEmpty) {
      // Only brand - add brand + name
      parts.add(brand!);
      parts.add(name);
    } else if (model != null && model!.isNotEmpty) {
      // Only model
      parts.add(model!);
    } else {
      // Neither brand nor model - use name
      parts.add(name);
    }
    
    // Add wattage if available
    if (wattage != null) {
      parts.add('(${wattage}W)');
    }
    
    return parts.join(' ');
  }

  /// Validate hardware
  bool get isValid {
    return roomId > 0 && name.isNotEmpty;
  }

  @override
  String toString() {
    return 'Hardware{id: $id, name: $name, type: ${type.displayName}, room: $roomId}';
  }
}
