// =============================================
// GROWLOG - Plant Model (mit Grow-Zuordnung & Container Tracking)
// =============================================

import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/utils/safe_parsers.dart'; // ✅ FIX: Safe parsing utilities
import 'package:growlog_app/config/plant_config.dart'; // ✅ FIX: Validation config

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class Plant {
  final int? id;
  final String name;
  final String? breeder;
  final String? strain;
  final bool feminized;
  final SeedType seedType;
  final Medium medium;
  final PlantPhase phase;
  final int? growId; // NEU: Zuordnung zu einem Grow (optional)
  final int? roomId; // OPTIONAL: Pflanze kann auch ohne Zelt existieren
  final int? rdwcSystemId; // RDWC System ID (if medium is RDWC)
  final int? bucketNumber; // Position in RDWC system (1, 2, 3, 4...)
  final DateTime? seedDate;
  final DateTime?
  phaseStartDate; // Deprecated - use vegDate/bloomDate/harvestDate

  // ✅ v10: Phase History
  final DateTime? vegDate; // When veg phase started
  final DateTime? bloomDate; // When bloom phase started
  final DateTime? harvestDate; // When harvest phase started

  final DateTime createdAt;
  final String? createdBy;
  final String logProfileName;
  final bool archived;

  // Container Tracking
  final double? currentContainerSize; // Aktueller Topf in Liter
  final double? currentSystemSize; // Aktuelles System in Liter (RDWC/DWC)

  Plant({
    this.id,
    required String name,
    this.breeder,
    this.strain,
    this.feminized = true,
    required this.seedType,
    required this.medium,
    this.phase = PlantPhase.seedling,
    this.growId, // NEU: growId als optionaler Parameter
    this.roomId,
    this.rdwcSystemId,
    int? bucketNumber,
    this.seedDate,
    this.phaseStartDate,
    this.vegDate,
    this.bloomDate,
    this.harvestDate,
    DateTime? createdAt,
    this.createdBy,
    String logProfileName = 'standard',
    this.archived = false,
    double? currentContainerSize,
    double? currentSystemSize,
  }) : // ✅ VALIDATION: Apply validation from PlantConfig
       name = PlantConfig.validateName(name),
       bucketNumber = PlantConfig.validateBucketNumber(bucketNumber),
       logProfileName = PlantConfig.validateLogProfileName(logProfileName),
       currentContainerSize = PlantConfig.validateContainerSize(
         currentContainerSize,
       ),
       currentSystemSize = PlantConfig.validateSystemSize(currentSystemSize),
       createdAt = createdAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  /// ✅ FIX: All DateTime.parse and enum parsing now use safe parsers
  factory Plant.fromMap(Map<String, dynamic> map) {
    return Plant(
      id: map['id'] as int?,
      // ✅ CRITICAL FIX: Null-safe casts for required fields
      name: map['name'] as String? ?? 'Unknown Plant',
      breeder: map['breeder'] as String?,
      strain: map['strain'] as String?,
      feminized: (map['feminized'] as int? ?? 0) == 1,
      seedType: SafeParsers.parseEnum<SeedType>(
        SeedType.values,
        map['seed_type']?.toString(),
        fallback: SeedType.photo,
        context: 'Plant.fromMap.seedType',
      ),
      medium: SafeParsers.parseEnum<Medium>(
        Medium.values,
        map['medium']?.toString(),
        fallback: Medium.erde,
        context: 'Plant.fromMap.medium',
      ),
      phase: SafeParsers.parseEnum<PlantPhase>(
        PlantPhase.values,
        map['phase']?.toString(),
        fallback: PlantPhase.veg,
        context: 'Plant.fromMap.phase',
      ),
      growId: map['grow_id'] as int?,
      roomId: map['room_id'] as int?,
      rdwcSystemId: map['rdwc_system_id'] as int?,
      bucketNumber: map['bucket_number'] as int?,
      seedDate: SafeParsers.parseDateTimeNullable(
        map['seed_date'] as String?,
        context: 'Plant.fromMap.seedDate',
      ),
      phaseStartDate: SafeParsers.parseDateTimeNullable(
        map['phase_start_date'] as String?,
        context: 'Plant.fromMap.phaseStartDate',
      ),
      vegDate: SafeParsers.parseDateTimeNullable(
        map['veg_date'] as String?,
        context: 'Plant.fromMap.vegDate',
      ),
      bloomDate: SafeParsers.parseDateTimeNullable(
        map['bloom_date'] as String?,
        context: 'Plant.fromMap.bloomDate',
      ),
      harvestDate: SafeParsers.parseDateTimeNullable(
        map['harvest_date'] as String?,
        context: 'Plant.fromMap.harvestDate',
      ),
      createdAt: SafeParsers.parseDateTime(
        map['created_at'] as String?,
        fallback: DateTime.now(),
        context: 'Plant.fromMap.createdAt',
      ),
      createdBy: map['created_by'] as String?,
      logProfileName: map['log_profile_name'] as String? ?? 'standard',
      archived: (map['archived'] as int?) == 1,
      currentContainerSize: (map['current_container_size'] as num?)?.toDouble(),
      currentSystemSize: (map['current_system_size'] as num?)?.toDouble(),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'breeder': breeder,
      'strain': strain,
      'feminized': feminized ? 1 : 0,
      'seed_type': seedType.name.toUpperCase(),
      'medium': medium.name.toUpperCase(),
      'phase': phase.name.toUpperCase(),
      'grow_id': growId,
      'room_id': roomId,
      'rdwc_system_id': rdwcSystemId,
      'bucket_number': bucketNumber,
      'seed_date': seedDate?.toIso8601String().split('T')[0],
      'phase_start_date': phaseStartDate?.toIso8601String().split('T')[0],
      'veg_date': vegDate?.toIso8601String().split('T')[0],
      'bloom_date': bloomDate?.toIso8601String().split('T')[0],
      'harvest_date': harvestDate?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'log_profile_name': logProfileName,
      'archived': archived ? 1 : 0,
      'current_container_size': currentContainerSize,
      'current_system_size': currentSystemSize,
    };
  }

  /// Copy mit Änderungen
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  Plant copyWith({
    int? id,
    String? name,
    Object? breeder = _undefined,
    Object? strain = _undefined,
    bool? feminized,
    SeedType? seedType,
    Medium? medium,
    PlantPhase? phase,
    Object? growId = _undefined,
    Object? roomId = _undefined,
    Object? rdwcSystemId = _undefined,
    Object? bucketNumber = _undefined,
    Object? seedDate = _undefined,
    Object? phaseStartDate = _undefined,
    Object? vegDate = _undefined,
    Object? bloomDate = _undefined,
    Object? harvestDate = _undefined,
    DateTime? createdAt,
    Object? createdBy = _undefined,
    String? logProfileName,
    bool? archived,
    Object? currentContainerSize = _undefined,
    Object? currentSystemSize = _undefined,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      breeder: breeder == _undefined ? this.breeder : breeder as String?,
      strain: strain == _undefined ? this.strain : strain as String?,
      feminized: feminized ?? this.feminized,
      seedType: seedType ?? this.seedType,
      medium: medium ?? this.medium,
      phase: phase ?? this.phase,
      growId: growId == _undefined ? this.growId : growId as int?,
      roomId: roomId == _undefined ? this.roomId : roomId as int?,
      rdwcSystemId: rdwcSystemId == _undefined
          ? this.rdwcSystemId
          : rdwcSystemId as int?,
      bucketNumber: bucketNumber == _undefined
          ? this.bucketNumber
          : bucketNumber as int?,
      seedDate: seedDate == _undefined ? this.seedDate : seedDate as DateTime?,
      phaseStartDate: phaseStartDate == _undefined
          ? this.phaseStartDate
          : phaseStartDate as DateTime?,
      vegDate: vegDate == _undefined ? this.vegDate : vegDate as DateTime?,
      bloomDate: bloomDate == _undefined
          ? this.bloomDate
          : bloomDate as DateTime?,
      harvestDate: harvestDate == _undefined
          ? this.harvestDate
          : harvestDate as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy == _undefined
          ? this.createdBy
          : createdBy as String?,
      logProfileName: logProfileName ?? this.logProfileName,
      archived: archived ?? this.archived,
      currentContainerSize: currentContainerSize == _undefined
          ? this.currentContainerSize
          : currentContainerSize as double?,
      currentSystemSize: currentSystemSize == _undefined
          ? this.currentSystemSize
          : currentSystemSize as double?,
    );
  }

  /// Tage seit Seed-Datum
  /// Day 1 = Seeding day, Day 2 = Next day, etc.
  int get totalDays {
    if (seedDate == null) return 0;
    // ✅ Nur Datums-Teil vergleichen
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final seedDay = DateTime(seedDate!.year, seedDate!.month, seedDate!.day);
    // ✅ FIX: +1 for 1-indexed days (Day 1 = seeding day)
    final days = todayDay.difference(seedDay).inDays + 1;
    return days > 0 ? days : 0;
  }

  /// Tage in aktueller Phase
  /// Day 1 = Phase start day, Day 2 = Next day, etc.
  int get phaseDays {
    // ✅ FIX: Use phase-specific dates instead of deprecated phaseStartDate
    DateTime? effectivePhaseStart;

    switch (phase) {
      case PlantPhase.harvest:
        effectivePhaseStart = harvestDate ?? phaseStartDate;
        break;
      case PlantPhase.bloom:
        effectivePhaseStart = bloomDate ?? phaseStartDate;
        break;
      case PlantPhase.veg:
        effectivePhaseStart = vegDate ?? phaseStartDate;
        break;
      case PlantPhase.seedling:
      case PlantPhase.archived:
        effectivePhaseStart = seedDate ?? phaseStartDate;
        break;
    }

    if (effectivePhaseStart == null) return 0;

    // ✅ Nur Datums-Teil vergleichen
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final phaseDay = DateTime(
      effectivePhaseStart.year,
      effectivePhaseStart.month,
      effectivePhaseStart.day,
    );
    // ✅ FIX: +1 for 1-indexed days (Day 1 = phase start day)
    final days = todayDay.difference(phaseDay).inDays + 1;
    return days > 0 ? days : 0;
  }

  /// Zeigt aktuellen Container/System Info Text
  String get containerInfo {
    if (medium == Medium.dwc ||
        medium == Medium.rdwc ||
        medium == Medium.hydro) {
      if (currentSystemSize != null) {
        return '${currentSystemSize!.toStringAsFixed(0)}L System';
      }
      // ✅ FIX: Fallback wenn System verknüpft aber Größe fehlt (Migration v18 Datenverlust)
      if (rdwcSystemId != null) {
        return 'System verknüpft (Größe fehlt)';
      }
      return 'System nicht erfasst';
    } else {
      if (currentContainerSize != null) {
        return '${currentContainerSize!.toStringAsFixed(0)}L Topf';
      }
      return 'Topf nicht erfasst';
    }
  }

  @override
  String toString() {
    return 'Plant{id: $id, name: $name, strain: $strain, phase: ${phase.displayName}}';
  }
}
