// =============================================
// GROWLOG - Fertilizer Model
// =============================================

class Fertilizer {
  final int? id;
  final String name;
  final String? brand;
  final String? npk;
  final String? type;
  final String? description;
  final DateTime createdAt;

  Fertilizer({
    this.id,
    required this.name,
    this.brand,
    this.npk,
    this.type,
    this.description,
    DateTime? createdAt,
  }) : assert(name.isNotEmpty, 'Name cannot be empty'),
        createdAt = createdAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  factory Fertilizer.fromMap(Map<String, dynamic> map) {
    return Fertilizer(
      id: map['id'] as int?,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      npk: map['npk'] as String?,
      type: map['type'] as String?,
      description: map['description'] as String?,
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
      'brand': brand,
      'npk': npk,
      'type': type,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy mit Änderungen
  Fertilizer copyWith({
    int? id,
    String? name,
    String? brand,
    String? npk,
    String? type,
    String? description,
    DateTime? createdAt,
  }) {
    return Fertilizer(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      npk: npk ?? this.npk,
      type: type ?? this.type,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get N value from NPK string
  double get nValue {
    if (npk == null || npk!.isEmpty) return 0.0;
    try {
      final parts = npk!.split('-');
      if (parts.isNotEmpty) {
        return double.parse(parts[0].trim());
      }
    } catch (e) {
      // Invalid format
    }
    return 0.0;
  }

  /// Get P value from NPK string
  double get pValue {
    if (npk == null || npk!.isEmpty) return 0.0;
    try {
      final parts = npk!.split('-');
      if (parts.length > 1) {
        return double.parse(parts[1].trim());
      }
    } catch (e) {
      // Invalid format
    }
    return 0.0;
  }

  /// Get K value from NPK string
  double get kValue {
    if (npk == null || npk!.isEmpty) return 0.0;
    try {
      final parts = npk!.split('-');
      if (parts.length > 2) {
        return double.parse(parts[2].trim());
      }
    } catch (e) {
      // Invalid format
    }
    return 0.0;
  }

  /// Calculate NPK ratio
  String get npkRatio {
    if (npk == null || npk!.isEmpty) return '';
    
    final n = nValue;
    final p = pValue;
    final k = kValue;
    
    if (n == 0 && p == 0 && k == 0) return '0:0:0';
    
    // Find GCD to simplify ratio
    final minValue = [n, p, k].where((v) => v > 0).fold<double?>(null, 
      (min, v) => min == null || v < min ? v : min) ?? 1;
    
    return '${(n / minValue).round()}:${(p / minValue).round()}:${(k / minValue).round()}';
  }

  /// Determine fertilizer category based on NPK
  String get category {
    final n = nValue;
    final p = pValue;
    final k = kValue;
    
    if (n == 0 && p == 0 && k == 0) return 'Supplement';
    if (n > p && n > k) return 'Growth';
    if (p > n && p >= k) return 'Bloom';
    if (n == p && p == k && n > 0) return 'Balanced';
    return 'Custom';
  }

  /// Display name with brand and NPK
  String get displayName {
    final parts = <String>[];
    if (brand != null && brand!.isNotEmpty) parts.add(brand!);
    parts.add(name);
    if (npk != null && npk!.isNotEmpty) parts.add('($npk)');
    return parts.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fertilizer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Fertilizer{id: $id, name: $name, brand: $brand, npk: $npk}';
  }
}
