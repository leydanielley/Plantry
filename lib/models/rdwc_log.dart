// =============================================
// GROWLOG - RDWC Log Model (Water Addback Tracking)
// =============================================

import 'rdwc_log_fertilizer.dart';

enum RdwcLogType {
  addback,        // Water addback/refill
  fullChange,     // Complete reservoir change
  maintenance,    // Cleaning/maintenance
  measurement,    // Just measurement, no action
}

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class RdwcLog {
  final int? id;
  final int systemId;
  final DateTime logDate;
  final RdwcLogType logType;

  // Water tracking
  final double? levelBefore;      // Water level before action (liters)
  final double? waterAdded;       // Amount of water added (liters)
  final double? levelAfter;       // Water level after action (liters)
  final double? waterConsumed;    // Calculated consumption since last log

  // pH/EC tracking
  final double? phBefore;
  final double? phAfter;
  final double? ecBefore;
  final double? ecAfter;

  // Notes
  final String? note;
  final String? loggedBy;
  final DateTime createdAt;

  // v8: Fertilizers added in this log (loaded separately)
  final List<RdwcLogFertilizer>? fertilizers;

  RdwcLog({
    this.id,
    required this.systemId,
    DateTime? logDate,
    required this.logType,
    this.levelBefore,
    this.waterAdded,
    this.levelAfter,
    this.waterConsumed,
    this.phBefore,
    this.phAfter,
    this.ecBefore,
    this.ecAfter,
    this.note,
    this.loggedBy,
    DateTime? createdAt,
    this.fertilizers,
  }) : logDate = logDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  /// Factory: Create from database map
  factory RdwcLog.fromMap(Map<String, dynamic> map) {
    // Parse logType from database format
    RdwcLogType logType;
    final dbLogType = map['log_type'].toString();
    switch (dbLogType) {
      case 'ADDBACK':
        logType = RdwcLogType.addback;
        break;
      case 'FULLCHANGE':
        logType = RdwcLogType.fullChange;
        break;
      case 'MAINTENANCE':
        logType = RdwcLogType.maintenance;
        break;
      case 'MEASUREMENT':
        logType = RdwcLogType.measurement;
        break;
      default:
        throw ArgumentError('Unknown log_type: $dbLogType');
    }

    return RdwcLog(
      id: map['id'] as int?,
      systemId: map['system_id'] as int,
      logDate: DateTime.parse(map['log_date'] as String),
      logType: logType,
      levelBefore: (map['level_before'] as num?)?.toDouble(),
      waterAdded: (map['water_added'] as num?)?.toDouble(),
      levelAfter: (map['level_after'] as num?)?.toDouble(),
      waterConsumed: (map['water_consumed'] as num?)?.toDouble(),
      phBefore: (map['ph_before'] as num?)?.toDouble(),
      phAfter: (map['ph_after'] as num?)?.toDouble(),
      ecBefore: (map['ec_before'] as num?)?.toDouble(),
      ecAfter: (map['ec_after'] as num?)?.toDouble(),
      note: map['note'] as String?,
      loggedBy: map['logged_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    // Convert enum to database format
    String dbLogType;
    switch (logType) {
      case RdwcLogType.addback:
        dbLogType = 'ADDBACK';
        break;
      case RdwcLogType.fullChange:
        dbLogType = 'FULLCHANGE';
        break;
      case RdwcLogType.maintenance:
        dbLogType = 'MAINTENANCE';
        break;
      case RdwcLogType.measurement:
        dbLogType = 'MEASUREMENT';
        break;
    }

    return {
      'id': id,
      'system_id': systemId,
      'log_date': logDate.toIso8601String(),
      'log_type': dbLogType,
      'level_before': levelBefore,
      'water_added': waterAdded,
      'level_after': levelAfter,
      'water_consumed': waterConsumed,
      'ph_before': phBefore,
      'ph_after': phAfter,
      'ec_before': ecBefore,
      'ec_after': ecAfter,
      'note': note,
      'logged_by': loggedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy with changes
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  RdwcLog copyWith({
    int? id,
    int? systemId,
    DateTime? logDate,
    RdwcLogType? logType,
    Object? levelBefore = _undefined,
    Object? waterAdded = _undefined,
    Object? levelAfter = _undefined,
    Object? waterConsumed = _undefined,
    Object? phBefore = _undefined,
    Object? phAfter = _undefined,
    Object? ecBefore = _undefined,
    Object? ecAfter = _undefined,
    Object? note = _undefined,
    Object? loggedBy = _undefined,
    DateTime? createdAt,
    Object? fertilizers = _undefined,
  }) {
    return RdwcLog(
      id: id ?? this.id,
      systemId: systemId ?? this.systemId,
      logDate: logDate ?? this.logDate,
      logType: logType ?? this.logType,
      levelBefore: levelBefore == _undefined ? this.levelBefore : levelBefore as double?,
      waterAdded: waterAdded == _undefined ? this.waterAdded : waterAdded as double?,
      levelAfter: levelAfter == _undefined ? this.levelAfter : levelAfter as double?,
      waterConsumed: waterConsumed == _undefined ? this.waterConsumed : waterConsumed as double?,
      phBefore: phBefore == _undefined ? this.phBefore : phBefore as double?,
      phAfter: phAfter == _undefined ? this.phAfter : phAfter as double?,
      ecBefore: ecBefore == _undefined ? this.ecBefore : ecBefore as double?,
      ecAfter: ecAfter == _undefined ? this.ecAfter : ecAfter as double?,
      note: note == _undefined ? this.note : note as String?,
      loggedBy: loggedBy == _undefined ? this.loggedBy : loggedBy as String?,
      createdAt: createdAt ?? this.createdAt,
      fertilizers: fertilizers == _undefined ? this.fertilizers : fertilizers as List<RdwcLogFertilizer>?,
    );
  }

  /// Calculate EC drift (increase or decrease)
  double? get ecDrift {
    if (ecBefore == null || ecAfter == null) return null;
    return ecAfter! - ecBefore!;
  }

  /// Calculate pH drift
  double? get phDrift {
    if (phBefore == null || phAfter == null) return null;
    return phAfter! - phBefore!;
  }

  /// Check if EC increased
  bool get ecIncreased => (ecDrift ?? 0) > 0;

  /// Check if pH increased
  bool get phIncreased => (phDrift ?? 0) > 0;

  /// Formatted date for display
  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    final hour = logDate.hour.toString().padLeft(2, '0');
    final minute = logDate.minute.toString().padLeft(2, '0');
    return '${logDate.day}. ${months[logDate.month - 1]} $hour:$minute';
  }

  @override
  String toString() {
    return 'RdwcLog{id: $id, systemId: $systemId, type: ${logType.name}, waterAdded: $waterAdded L}';
  }
}
