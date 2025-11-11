// =============================================
// GROWLOG - Hardware Model
// =============================================

import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/utils/safe_parsers.dart'; // ✅ FIX: Safe parsing utilities
import 'package:growlog_app/config/validation_config.dart'; // ✅ FIX: Validation config

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class Hardware {
  final int? id;
  final int roomId;
  final String name;
  final HardwareType type;
  final String? brand;
  final String? model;

  // Allgemeine Felder
  final int? wattage; // Wattzahl (für Lampen, Lüfter, Klimatechnik)
  final int? quantity; // Anzahl

  // Beleuchtung
  final int? airflow; // Luftdurchsatz in m³/h (für Lüfter)
  final String? spectrum; // Lichtspektrum (LED)
  final String? colorTemperature; // Farbtemperatur (HPS/MH/CFL)
  final bool? dimmable; // Dimmbar? (Lampen, Lüfter)

  // Lüftung
  final String? flangeSize; // Flansch-Größe (Lüfter)
  final bool? controllable; // Regelbar? (Lüfter)
  final bool? oscillating; // Oszillierend? (Umluft)
  final int? diameter; // Durchmesser in cm (Umluft)

  // Klimatechnik
  final int? coolingPower; // Kühlleistung BTU (Klimaanlage)
  final int? heatingPower; // Heizleistung Watt (Heizung)
  final double? coverage; // Abdeckung m²/m³
  final bool? hasThermostat; // Thermostat? (Heizung)
  final int? humidificationRate; // Befeuchtungsleistung ml/h

  // Bewässerung
  final int? pumpRate; // Förderleistung L/h (Pumpe)
  final bool? isDigital; // Digital/Analog (Timer)
  final int? programCount; // Anzahl Programme (Timer)
  final int? dripperCount; // Anzahl Tropfer
  final int? capacity; // Kapazität Liter (Reservoir)
  final String? material; // Material (Reservoir)
  final bool? hasChiller; // Mit Chiller?
  final bool? hasAirPump; // Mit Luftpumpe?

  // Filter & Controller
  final String? filterDiameter; // Filter-Durchmesser (AKF)
  final int? filterLength; // Filter-Länge cm (AKF)
  final String? controllerType; // Controller-Typ
  final int? outputCount; // Anzahl Ausgänge (Controller)
  final String? controllerFunctions; // Funktionen (Controller)

  // Optionale Felder
  final String? specifications; // Zusätzliche Specs
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? notes;
  final bool active;
  final DateTime createdAt;

  Hardware({
    this.id,
    required this.roomId,
    required String name,
    required this.type,
    this.brand,
    this.model,
    int? wattage,
    int? quantity = 1,
    int? airflow,
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
    int? pumpRate,
    this.isDigital,
    this.programCount,
    this.dripperCount,
    int? capacity,
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
       // ✅ VALIDATION: Apply validation from ValidationConfig
       name = ValidationConfig.validateName(name),
       wattage = ValidationConfig.validatePositiveInt(
         wattage,
         ValidationConfig.maxWattage,
       ),
       quantity = ValidationConfig.validatePositiveInt(
         quantity,
         ValidationConfig.maxQuantity,
       ),
       airflow = ValidationConfig.validatePositiveInt(
         airflow,
         ValidationConfig.maxAirflow,
       ),
       pumpRate = ValidationConfig.validatePositiveInt(
         pumpRate,
         ValidationConfig.maxPumpRate,
       ),
       capacity = ValidationConfig.validatePositiveInt(
         capacity,
         ValidationConfig.maxCapacity,
       ),
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
      // ✅ CRITICAL FIX: Null-safe casts for required fields
      roomId: map['room_id'] as int? ?? 0,
      name: map['name'] as String? ?? 'Unknown',
      type: _parseHardwareType(map['type']?.toString() ?? 'other'),
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      wattage: map['wattage'] as int?,
      // ✅ LOW PRIORITY BUG FIX: Consistent default value with constructor (was ?? 1, now removed for consistency)
      // Constructor provides default of 1, so fromMap should too for database loads
      quantity: map['quantity'] as int? ?? 1,
      airflow: map['airflow'] as int?,
      spectrum: map['spectrum'] as String?,
      colorTemperature: map['color_temperature'] as String?,
      dimmable: map['dimmable'] != null ? (map['dimmable'] as int) == 1 : null,
      flangeSize: map['flange_size'] as String?,
      controllable: map['controllable'] != null
          ? (map['controllable'] as int) == 1
          : null,
      oscillating: map['oscillating'] != null
          ? (map['oscillating'] as int) == 1
          : null,
      diameter: map['diameter'] as int?,
      coolingPower: map['cooling_power'] as int?,
      heatingPower: map['heating_power'] as int?,
      coverage: (map['coverage'] as num?)?.toDouble(),
      hasThermostat: map['has_thermostat'] != null
          ? (map['has_thermostat'] as int) == 1
          : null,
      humidificationRate: map['humidification_rate'] as int?,
      pumpRate: map['pump_rate'] as int?,
      isDigital: map['is_digital'] != null
          ? (map['is_digital'] as int) == 1
          : null,
      programCount: map['program_count'] as int?,
      dripperCount: map['dripper_count'] as int?,
      capacity: map['capacity'] as int?,
      material: map['material'] as String?,
      hasChiller: map['has_chiller'] != null
          ? (map['has_chiller'] as int) == 1
          : null,
      hasAirPump: map['has_air_pump'] != null
          ? (map['has_air_pump'] as int) == 1
          : null,
      filterDiameter: map['filter_diameter'] as String?,
      filterLength: map['filter_length'] as int?,
      controllerType: map['controller_type'] as String?,
      outputCount: map['output_count'] as int?,
      controllerFunctions: map['controller_functions'] as String?,
      specifications: map['specifications'] as String?,
      purchaseDate: SafeParsers.parseDateTimeNullable(
        map['purchase_date'] as String?,
        context: 'Hardware.fromMap.purchaseDate',
      ),
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      active: map['active'] != null ? (map['active'] as int) == 1 : true,
      createdAt: SafeParsers.parseDateTime(
        map['created_at'] as String?,
        fallback: DateTime.now(),
        context: 'Hardware.fromMap.createdAt',
      ),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    // ✅ AUDIT FIX: Boolean to int conversion is intentional for SQLite compatibility
    // SQLite stores booleans as INTEGER (0/1). Pattern: bool? to int? or bool to int
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
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  Hardware copyWith({
    int? id,
    int? roomId,
    String? name,
    HardwareType? type,
    Object? brand = _undefined,
    Object? model = _undefined,
    Object? wattage = _undefined,
    Object? quantity = _undefined,
    Object? airflow = _undefined,
    Object? spectrum = _undefined,
    Object? colorTemperature = _undefined,
    Object? dimmable = _undefined,
    Object? flangeSize = _undefined,
    Object? controllable = _undefined,
    Object? oscillating = _undefined,
    Object? diameter = _undefined,
    Object? coolingPower = _undefined,
    Object? heatingPower = _undefined,
    Object? coverage = _undefined,
    Object? hasThermostat = _undefined,
    Object? humidificationRate = _undefined,
    Object? pumpRate = _undefined,
    Object? isDigital = _undefined,
    Object? programCount = _undefined,
    Object? dripperCount = _undefined,
    Object? capacity = _undefined,
    Object? material = _undefined,
    Object? hasChiller = _undefined,
    Object? hasAirPump = _undefined,
    Object? filterDiameter = _undefined,
    Object? filterLength = _undefined,
    Object? controllerType = _undefined,
    Object? outputCount = _undefined,
    Object? controllerFunctions = _undefined,
    Object? specifications = _undefined,
    Object? purchaseDate = _undefined,
    Object? purchasePrice = _undefined,
    Object? notes = _undefined,
    bool? active,
    DateTime? createdAt,
  }) {
    return Hardware(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand == _undefined ? this.brand : brand as String?,
      model: model == _undefined ? this.model : model as String?,
      wattage: wattage == _undefined ? this.wattage : wattage as int?,
      quantity: quantity == _undefined ? this.quantity : quantity as int?,
      airflow: airflow == _undefined ? this.airflow : airflow as int?,
      spectrum: spectrum == _undefined ? this.spectrum : spectrum as String?,
      colorTemperature: colorTemperature == _undefined
          ? this.colorTemperature
          : colorTemperature as String?,
      dimmable: dimmable == _undefined ? this.dimmable : dimmable as bool?,
      flangeSize: flangeSize == _undefined
          ? this.flangeSize
          : flangeSize as String?,
      controllable: controllable == _undefined
          ? this.controllable
          : controllable as bool?,
      oscillating: oscillating == _undefined
          ? this.oscillating
          : oscillating as bool?,
      diameter: diameter == _undefined ? this.diameter : diameter as int?,
      coolingPower: coolingPower == _undefined
          ? this.coolingPower
          : coolingPower as int?,
      heatingPower: heatingPower == _undefined
          ? this.heatingPower
          : heatingPower as int?,
      coverage: coverage == _undefined ? this.coverage : coverage as double?,
      hasThermostat: hasThermostat == _undefined
          ? this.hasThermostat
          : hasThermostat as bool?,
      humidificationRate: humidificationRate == _undefined
          ? this.humidificationRate
          : humidificationRate as int?,
      pumpRate: pumpRate == _undefined ? this.pumpRate : pumpRate as int?,
      isDigital: isDigital == _undefined ? this.isDigital : isDigital as bool?,
      programCount: programCount == _undefined
          ? this.programCount
          : programCount as int?,
      dripperCount: dripperCount == _undefined
          ? this.dripperCount
          : dripperCount as int?,
      capacity: capacity == _undefined ? this.capacity : capacity as int?,
      material: material == _undefined ? this.material : material as String?,
      hasChiller: hasChiller == _undefined
          ? this.hasChiller
          : hasChiller as bool?,
      hasAirPump: hasAirPump == _undefined
          ? this.hasAirPump
          : hasAirPump as bool?,
      filterDiameter: filterDiameter == _undefined
          ? this.filterDiameter
          : filterDiameter as String?,
      filterLength: filterLength == _undefined
          ? this.filterLength
          : filterLength as int?,
      controllerType: controllerType == _undefined
          ? this.controllerType
          : controllerType as String?,
      outputCount: outputCount == _undefined
          ? this.outputCount
          : outputCount as int?,
      controllerFunctions: controllerFunctions == _undefined
          ? this.controllerFunctions
          : controllerFunctions as String?,
      specifications: specifications == _undefined
          ? this.specifications
          : specifications as String?,
      purchaseDate: purchaseDate == _undefined
          ? this.purchaseDate
          : purchaseDate as DateTime?,
      purchasePrice: purchasePrice == _undefined
          ? this.purchasePrice
          : purchasePrice as double?,
      notes: notes == _undefined ? this.notes : notes as String?,
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

    if (brand != null &&
        brand!.isNotEmpty &&
        model != null &&
        model!.isNotEmpty) {
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
