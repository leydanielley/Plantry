// =============================================
// GROWLOG - PlantLog Model (mit Container Tracking)
// =============================================

import 'enums.dart';
import '../utils/app_logger.dart';

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class PlantLog {
  final int? id;
  final int plantId;
  final int dayNumber;
  final DateTime logDate;
  final String? loggedBy;
  final ActionType actionType;

  // ✅ v13: Phase-Tracking
  final PlantPhase? phase;
  final int? phaseDayNumber;

  // Wasser
  final double? waterAmount;

  // pH/EC
  final double? phIn;
  final double? ecIn;
  final double? phOut;
  final double? ecOut;

  // Umgebung
  final double? temperature;
  final double? humidity;

  // Flags
  final bool runoff;
  final bool cleanse;

  // Container (für Topf/Erde)
  final double? containerSize;           // Topfgröße in Liter
  final double? containerMediumAmount;   // Erde/Coco Menge in Liter
  final bool containerDrainage;          // Drainage vorhanden?
  final String? containerDrainageMaterial; // z.B. Blähton, Perlite

  // System (für RDWC/DWC/Hydro)
  final double? systemReservoirSize;     // Reservoir Größe in Liter
  final int? systemBucketCount;          // Anzahl Buckets
  final double? systemBucketSize;        // Größe pro Bucket

  // Notiz
  final String? note;

  final DateTime createdAt;

  PlantLog({
    this.id,
    required this.plantId,
    required this.dayNumber,
    DateTime? logDate,
    this.loggedBy,
    required this.actionType,
    this.phase,
    this.phaseDayNumber,
    this.waterAmount,
    this.phIn,
    this.ecIn,
    this.phOut,
    this.ecOut,
    this.temperature,
    this.humidity,
    this.runoff = false,
    this.cleanse = false,
    this.containerSize,
    this.containerMediumAmount,
    this.containerDrainage = false,
    this.containerDrainageMaterial,
    this.systemReservoirSize,
    this.systemBucketCount,
    this.systemBucketSize,
    this.note,
    DateTime? createdAt,
  })  : logDate = logDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// ✅ Helper: Parse ActionType from database string
  static ActionType _parseActionType(String dbValue) {
    try {
      final normalized = dbValue.toLowerCase();

      if (normalized == 'phase_change') {
        return ActionType.phaseChange;
      }

      final cleanName = normalized.replaceAll('_', '');
      return ActionType.values.byName(cleanName);
    } catch (e) {
      AppLogger.warning('PlantLog', 'Invalid action type: $dbValue, defaulting to note', e);
      return ActionType.note; // Fallback
    }
  }

  /// Factory: Aus Map erstellen (von Datenbank)
  factory PlantLog.fromMap(Map<String, dynamic> map) {
    return PlantLog(
      id: map['id'] as int?,
      plantId: map['plant_id'] as int,
      dayNumber: map['day_number'] as int,
      logDate: DateTime.parse(map['log_date'] as String),
      loggedBy: map['logged_by'] as String?,
      actionType: _parseActionType(map['action_type'] as String),
      phase: map['phase'] != null 
          ? PlantPhase.values.byName(map['phase'].toString().toLowerCase())
          : null,
      phaseDayNumber: map['phase_day_number'] as int?,
      waterAmount: (map['water_amount'] as num?)?.toDouble(),
      phIn: (map['ph_in'] as num?)?.toDouble(),
      ecIn: (map['ec_in'] as num?)?.toDouble(),
      phOut: (map['ph_out'] as num?)?.toDouble(),
      ecOut: (map['ec_out'] as num?)?.toDouble(),
      temperature: (map['temperature'] as num?)?.toDouble(),
      humidity: (map['humidity'] as num?)?.toDouble(),
      runoff: (map['runoff'] as int?) == 1,
      cleanse: (map['cleanse'] as int?) == 1,
      containerSize: (map['container_size'] as num?)?.toDouble(),
      containerMediumAmount: (map['container_medium_amount'] as num?)?.toDouble(),
      containerDrainage: (map['container_drainage'] as int?) == 1,
      containerDrainageMaterial: map['container_drainage_material'] as String?,
      systemReservoirSize: (map['system_reservoir_size'] as num?)?.toDouble(),
      systemBucketCount: map['system_bucket_count'] as int?,
      systemBucketSize: (map['system_bucket_size'] as num?)?.toDouble(),
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    // Convert ActionType enum to database format
    String dbActionType;
    switch (actionType) {
      case ActionType.water:
        dbActionType = 'WATER';
        break;
      case ActionType.feed:
        dbActionType = 'FEED';
        break;
      case ActionType.trim:
        dbActionType = 'TRIM';
        break;
      case ActionType.transplant:
        dbActionType = 'TRANSPLANT';
        break;
      case ActionType.training:
        dbActionType = 'TRAINING';
        break;
      case ActionType.note:
        dbActionType = 'NOTE';
        break;
      case ActionType.phaseChange:
        dbActionType = 'PHASE_CHANGE';
        break;
      case ActionType.harvest:
        dbActionType = 'HARVEST';
        break;
      case ActionType.other:
        dbActionType = 'OTHER';
        break;
    }

    return {
      'id': id,
      'plant_id': plantId,
      'day_number': dayNumber,
      'log_date': logDate.toIso8601String(),
      'logged_by': loggedBy,
      'action_type': dbActionType,
      'phase': phase?.name.toUpperCase(),
      'phase_day_number': phaseDayNumber,
      'water_amount': waterAmount,
      'ph_in': phIn,
      'ec_in': ecIn,
      'ph_out': phOut,
      'ec_out': ecOut,
      'temperature': temperature,
      'humidity': humidity,
      'runoff': runoff ? 1 : 0,
      'cleanse': cleanse ? 1 : 0,
      'container_size': containerSize,
      'container_medium_amount': containerMediumAmount,
      'container_drainage': containerDrainage ? 1 : 0,
      'container_drainage_material': containerDrainageMaterial,
      'system_reservoir_size': systemReservoirSize,
      'system_bucket_count': systemBucketCount,
      'system_bucket_size': systemBucketSize,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy mit Änderungen
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  PlantLog copyWith({
    int? id,
    int? plantId,
    int? dayNumber,
    DateTime? logDate,
    Object? loggedBy = _undefined,
    ActionType? actionType,
    Object? phase = _undefined,
    Object? phaseDayNumber = _undefined,
    Object? waterAmount = _undefined,
    Object? phIn = _undefined,
    Object? ecIn = _undefined,
    Object? phOut = _undefined,
    Object? ecOut = _undefined,
    Object? temperature = _undefined,
    Object? humidity = _undefined,
    bool? runoff,
    bool? cleanse,
    Object? containerSize = _undefined,
    Object? containerMediumAmount = _undefined,
    bool? containerDrainage,
    Object? containerDrainageMaterial = _undefined,
    Object? systemReservoirSize = _undefined,
    Object? systemBucketCount = _undefined,
    Object? systemBucketSize = _undefined,
    Object? note = _undefined,
    DateTime? createdAt,
  }) {
    return PlantLog(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      dayNumber: dayNumber ?? this.dayNumber,
      logDate: logDate ?? this.logDate,
      loggedBy: loggedBy == _undefined ? this.loggedBy : loggedBy as String?,
      actionType: actionType ?? this.actionType,
      phase: phase == _undefined ? this.phase : phase as PlantPhase?,
      phaseDayNumber: phaseDayNumber == _undefined ? this.phaseDayNumber : phaseDayNumber as int?,
      waterAmount: waterAmount == _undefined ? this.waterAmount : waterAmount as double?,
      phIn: phIn == _undefined ? this.phIn : phIn as double?,
      ecIn: ecIn == _undefined ? this.ecIn : ecIn as double?,
      phOut: phOut == _undefined ? this.phOut : phOut as double?,
      ecOut: ecOut == _undefined ? this.ecOut : ecOut as double?,
      temperature: temperature == _undefined ? this.temperature : temperature as double?,
      humidity: humidity == _undefined ? this.humidity : humidity as double?,
      runoff: runoff ?? this.runoff,
      cleanse: cleanse ?? this.cleanse,
      containerSize: containerSize == _undefined ? this.containerSize : containerSize as double?,
      containerMediumAmount: containerMediumAmount == _undefined ? this.containerMediumAmount : containerMediumAmount as double?,
      containerDrainage: containerDrainage ?? this.containerDrainage,
      containerDrainageMaterial: containerDrainageMaterial == _undefined ? this.containerDrainageMaterial : containerDrainageMaterial as String?,
      systemReservoirSize: systemReservoirSize == _undefined ? this.systemReservoirSize : systemReservoirSize as double?,
      systemBucketCount: systemBucketCount == _undefined ? this.systemBucketCount : systemBucketCount as int?,
      systemBucketSize: systemBucketSize == _undefined ? this.systemBucketSize : systemBucketSize as double?,
      note: note == _undefined ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Formatiertes Datum für Anzeige
  String get formattedDate {
    // ✅ AUDIT FIX: Safe month array access with bounds checking
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final monthIndex = logDate.month - 1;
    final monthName = (monthIndex >= 0 && monthIndex < months.length)
        ? months[monthIndex]
        : 'N/A';
    final hour = logDate.hour.toString().padLeft(2, '0');
    final minute = logDate.minute.toString().padLeft(2, '0');
    return '${logDate.day}. $monthName $hour:$minute';
  }

  /// Runoff percentage calculation
  double get runoffPercentage {
    // This is for backward compatibility - not actually used in current model
    // which uses runoff as a boolean flag
    return 0.0;
  }

  /// Check if has measurements
  bool get hasMeasurements {
    return phIn != null || ecIn != null || temperature != null || humidity != null;
  }

  /// Check if has runoff data
  bool get hasRunoffData {
    return phOut != null || ecOut != null || runoff;
  }

  @override
  String toString() {
    return 'PlantLog{id: $id, plantId: $plantId, day: $dayNumber, action: ${actionType.displayName}}';
  }
}
