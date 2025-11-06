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
    return RdwcLog(
      id: map['id'] as int?,
      systemId: map['system_id'] as int,
      logDate: DateTime.parse(map['log_date'] as String),
      logType: RdwcLogType.values.byName(map['log_type'].toString().toLowerCase()),
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
    return {
      'id': id,
      'system_id': systemId,
      'log_date': logDate.toIso8601String(),
      'log_type': logType.name.toUpperCase(),
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
  RdwcLog copyWith({
    int? id,
    int? systemId,
    DateTime? logDate,
    RdwcLogType? logType,
    double? levelBefore,
    double? waterAdded,
    double? levelAfter,
    double? waterConsumed,
    double? phBefore,
    double? phAfter,
    double? ecBefore,
    double? ecAfter,
    String? note,
    String? loggedBy,
    DateTime? createdAt,
    List<RdwcLogFertilizer>? fertilizers,
  }) {
    return RdwcLog(
      id: id ?? this.id,
      systemId: systemId ?? this.systemId,
      logDate: logDate ?? this.logDate,
      logType: logType ?? this.logType,
      levelBefore: levelBefore ?? this.levelBefore,
      waterAdded: waterAdded ?? this.waterAdded,
      levelAfter: levelAfter ?? this.levelAfter,
      waterConsumed: waterConsumed ?? this.waterConsumed,
      phBefore: phBefore ?? this.phBefore,
      phAfter: phAfter ?? this.phAfter,
      ecBefore: ecBefore ?? this.ecBefore,
      ecAfter: ecAfter ?? this.ecAfter,
      note: note ?? this.note,
      loggedBy: loggedBy ?? this.loggedBy,
      createdAt: createdAt ?? this.createdAt,
      fertilizers: fertilizers ?? this.fertilizers,
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
