// =============================================
// GROWLOG - Room Model (✅ BUG FIX: WateringSystem Mapping)
// =============================================

import 'enums.dart';

class Room {
  final int? id;
  final String name;
  final String? description;
  final GrowType? growType;
  final WateringSystem? wateringSystem;
  final int? rdwcSystemId;  // Link to RDWC System
  final double width;
  final double depth;
  final double height;
  final DateTime createdAt;
  final DateTime updatedAt;

  Room({
    this.id,
    required this.name,
    this.description,
    this.growType,
    this.wateringSystem,
    this.rdwcSystemId,
    this.width = 0.0,
    this.depth = 0.0,
    this.height = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  factory Room.fromMap(Map<String, dynamic> map) {
    WateringSystem? parseWateringSystem(String? value) {
      if (value == null) return null;
      final normalized = value.toLowerCase().replaceAll('_', '');

      // ✅ BUG FIX: Korrektes Mapping von DB zu Enum
      switch (normalized) {
        case 'manual':
          return WateringSystem.manual;
        case 'drip':
          return WateringSystem.drip;
        case 'autopot':
          return WateringSystem.autopot;
        case 'rdwc':
          return WateringSystem.rdwc;
        case 'flooddrain':
          return WateringSystem.floodDrain;
        default:
          return null;
      }
    }

    return Room(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      growType: map['grow_type'] != null
          ? GrowType.values.byName(map['grow_type'].toString().toLowerCase())
          : null,
      wateringSystem: parseWateringSystem(map['watering_system']?.toString()),
      rdwcSystemId: map['rdwc_system_id'] as int?,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      depth: (map['depth'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    String? wateringSystemToDb(WateringSystem? ws) {
      if (ws == null) return null;

      // ✅ BUG FIX: Korrektes Mapping von Enum zu DB
      switch (ws) {
        case WateringSystem.manual:
          return 'MANUAL';
        case WateringSystem.drip:
          return 'DRIP';
        case WateringSystem.autopot:
          return 'AUTOPOT';
        case WateringSystem.rdwc:
          return 'RDWC';
        case WateringSystem.floodDrain:
          return 'FLOOD_DRAIN';
      }
    }

    return {
      'id': id,
      'name': name,
      'description': description,
      'grow_type': growType?.name.toUpperCase(),
      'watering_system': wateringSystemToDb(wateringSystem),
      'rdwc_system_id': rdwcSystemId,
      'width': width,
      'depth': depth,
      'height': height,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copy mit Änderungen
  Room copyWith({
    int? id,
    String? name,
    String? description,
    GrowType? growType,
    WateringSystem? wateringSystem,
    int? rdwcSystemId,
    double? width,
    double? depth,
    double? height,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      growType: growType ?? this.growType,
      wateringSystem: wateringSystem ?? this.wateringSystem,
      rdwcSystemId: rdwcSystemId ?? this.rdwcSystemId,
      width: width ?? this.width,
      depth: depth ?? this.depth,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Volumen in m³
  double get volume => width * depth * height;

  /// Grundfläche in m²
  double get area => width * depth;

  @override
  String toString() {
    return 'Room{id: $id, name: $name, ${width}x${depth}x${height}m}';
  }
}