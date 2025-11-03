// =============================================
// GROWLOG - Grow Model (Mehrere Pflanzen zusammenfassen)
// =============================================

// Sentinel value für copyWith
const _undefined = Object();

class Grow {
  final int? id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final int? roomId;  // NEU: Standard-Raum für diesen Grow
  final bool archived;
  final DateTime createdAt;

  Grow({
    this.id,
    required this.name,
    this.description,
    DateTime? startDate,
    this.endDate,
    this.roomId,  // NEU
    this.archived = false,
    DateTime? createdAt,
  })  : startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  factory Grow.fromMap(Map<String, dynamic> map) {
    return Grow(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      roomId: map['room_id'] as int?,  // NEU
      archived: (map['archived'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'room_id': roomId,  // NEU
      'archived': archived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy mit Änderungen
  Grow copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    Object? roomId = _undefined,  // NEU: Object statt int? für null-Unterstützung
    bool? archived,
    DateTime? createdAt,
  }) {
    return Grow(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      roomId: roomId == _undefined ? this.roomId : roomId as int?,  // NEU: Explizite Prüfung
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Tage seit Start
  int get totalDays {
    final now = DateTime.now();
    return now.difference(startDate).inDays;
  }

  /// Duration des Grows (in Tagen)
  int get duration {
    if (endDate != null) {
      return endDate!.difference(startDate).inDays;
    }
    // For ongoing grows, return days since start
    return totalDays;
  }

  /// Ist der Grow abgeschlossen?
  bool get isComplete => endDate != null;

  /// Status basierend auf Start/End-Datum
  String get status {
    if (archived) return 'Archiviert';
    if (endDate != null && DateTime.now().isAfter(endDate!)) {
      return 'Abgeschlossen';
    }
    return 'Aktiv';
  }

  @override
  String toString() {
    return 'Grow{id: $id, name: $name, status: $status}';
  }
}
