// =============================================
// GROWLOG - Plant Model (mit Grow-Zuordnung & Container Tracking)
// =============================================

import 'enums.dart';

class Plant {
  final int? id;
  final String name;
  final String? breeder;
  final String? strain;
  final bool feminized;
  final SeedType seedType;
  final Medium medium;
  final PlantPhase phase;
  final int? growId;  // NEU: Zuordnung zu einem Grow (optional)
  final int? roomId;  // OPTIONAL: Pflanze kann auch ohne Zelt existieren
  final int? rdwcSystemId;  // RDWC System ID (if medium is RDWC)
  final int? bucketNumber;  // Position in RDWC system (1, 2, 3, 4...)
  final DateTime? seedDate;
  final DateTime? phaseStartDate;  // Deprecated - use vegDate/bloomDate/harvestDate

  // ✅ v10: Phase History
  final DateTime? vegDate;       // When veg phase started
  final DateTime? bloomDate;     // When bloom phase started
  final DateTime? harvestDate;   // When harvest phase started

  final DateTime createdAt;
  final String? createdBy;
  final String logProfileName;
  final bool archived;

  // Container Tracking
  final double? currentContainerSize;  // Aktueller Topf in Liter
  final double? currentSystemSize;     // Aktuelles System in Liter (RDWC/DWC)

  Plant({
    this.id,
    required this.name,
    this.breeder,
    this.strain,
    this.feminized = true,
    required this.seedType,
    required this.medium,
    this.phase = PlantPhase.seedling,
    this.growId,  // NEU: growId als optionaler Parameter
    this.roomId,
    this.rdwcSystemId,
    this.bucketNumber,
    this.seedDate,
    this.phaseStartDate,
    this.vegDate,
    this.bloomDate,
    this.harvestDate,
    DateTime? createdAt,
    this.createdBy,
    this.logProfileName = 'standard',
    this.archived = false,
    this.currentContainerSize,
    this.currentSystemSize,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  factory Plant.fromMap(Map<String, dynamic> map) {
    return Plant(
      id: map['id'] as int?,
      name: map['name'] as String,
      breeder: map['breeder'] as String?,
      strain: map['strain'] as String?,
      feminized: (map['feminized'] as int) == 1,
      seedType: SeedType.values.byName(map['seed_type'].toString().toLowerCase()),
      medium: Medium.values.byName(map['medium'].toString().toLowerCase()),
      phase: PlantPhase.values.byName(map['phase'].toString().toLowerCase()),
      growId: map['grow_id'] as int?,
      roomId: map['room_id'] as int?,
      rdwcSystemId: map['rdwc_system_id'] as int?,
      bucketNumber: map['bucket_number'] as int?,
      seedDate: map['seed_date'] != null ? DateTime.parse(map['seed_date'] as String) : null,
      phaseStartDate: map['phase_start_date'] != null ? DateTime.parse(map['phase_start_date'] as String) : null,
      vegDate: map['veg_date'] != null ? DateTime.parse(map['veg_date'] as String) : null,
      bloomDate: map['bloom_date'] != null ? DateTime.parse(map['bloom_date'] as String) : null,
      harvestDate: map['harvest_date'] != null ? DateTime.parse(map['harvest_date'] as String) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
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
  Plant copyWith({
    int? id,
    String? name,
    String? breeder,
    String? strain,
    bool? feminized,
    SeedType? seedType,
    Medium? medium,
    PlantPhase? phase,
    int? growId,
    int? roomId,
    int? rdwcSystemId,
    int? bucketNumber,
    DateTime? seedDate,
    DateTime? phaseStartDate,
    DateTime? vegDate,
    DateTime? bloomDate,
    DateTime? harvestDate,
    DateTime? createdAt,
    String? createdBy,
    String? logProfileName,
    bool? archived,
    double? currentContainerSize,
    double? currentSystemSize,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      breeder: breeder ?? this.breeder,
      strain: strain ?? this.strain,
      feminized: feminized ?? this.feminized,
      seedType: seedType ?? this.seedType,
      medium: medium ?? this.medium,
      phase: phase ?? this.phase,
      growId: growId ?? this.growId,
      roomId: roomId ?? this.roomId,
      rdwcSystemId: rdwcSystemId ?? this.rdwcSystemId,
      bucketNumber: bucketNumber ?? this.bucketNumber,
      seedDate: seedDate ?? this.seedDate,
      phaseStartDate: phaseStartDate ?? this.phaseStartDate,
      vegDate: vegDate ?? this.vegDate,
      bloomDate: bloomDate ?? this.bloomDate,
      harvestDate: harvestDate ?? this.harvestDate,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      logProfileName: logProfileName ?? this.logProfileName,
      archived: archived ?? this.archived,
      currentContainerSize: currentContainerSize ?? this.currentContainerSize,
      currentSystemSize: currentSystemSize ?? this.currentSystemSize,
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
    if (phaseStartDate == null) return 0;
    // ✅ Nur Datums-Teil vergleichen
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final phaseDay = DateTime(phaseStartDate!.year, phaseStartDate!.month, phaseStartDate!.day);
    // ✅ FIX: +1 for 1-indexed days (Day 1 = phase start day)
    final days = todayDay.difference(phaseDay).inDays + 1;
    return days > 0 ? days : 0;
  }

  /// Zeigt aktuellen Container/System Info Text
  String get containerInfo {
    if (medium == Medium.dwc || medium == Medium.rdwc || medium == Medium.hydro) {
      if (currentSystemSize != null) {
        return '${currentSystemSize!.toStringAsFixed(0)}L System';
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
