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
  final double? ecValue;    // v8: EC contribution per ml (for RDWC calculations)
  final double? ppmValue;   // v8: PPM contribution per ml (for RDWC calculations)

  // v0.9.1: HydroBuddy-compatible detailed composition
  final String? formula;      // Chemical formula (e.g. "KNO3", "Ca(NO3)2")
  final String? source;       // Source URL or reference
  final double? purity;       // Purity (0.0 - 1.0)
  final bool? isLiquid;       // Is liquid fertilizer
  final double? density;      // Density for liquid (g/ml)

  // Macronutrients (as percentages)
  final double? nNO3;         // N as Nitrate (NO3-)
  final double? nNH4;         // N as Ammonium (NH4+)
  final double? p;            // Phosphorus (P)
  final double? k;            // Potassium (K)
  final double? mg;           // Magnesium (Mg)
  final double? ca;           // Calcium (Ca)
  final double? s;            // Sulfur (S)

  // Micronutrients (as percentages)
  final double? b;            // Boron (B)
  final double? fe;           // Iron (Fe)
  final double? zn;           // Zinc (Zn)
  final double? cu;           // Copper (Cu)
  final double? mn;           // Manganese (Mn)
  final double? mo;           // Molybdenum (Mo)
  final double? na;           // Sodium (Na)
  final double? si;           // Silicon (Si)
  final double? cl;           // Chlorine (Cl)

  final DateTime createdAt;

  Fertilizer({
    this.id,
    required this.name,
    this.brand,
    this.npk,
    this.type,
    this.description,
    this.ecValue,
    this.ppmValue,
    this.formula,
    this.source,
    this.purity,
    this.isLiquid,
    this.density,
    this.nNO3,
    this.nNH4,
    this.p,
    this.k,
    this.mg,
    this.ca,
    this.s,
    this.b,
    this.fe,
    this.zn,
    this.cu,
    this.mn,
    this.mo,
    this.na,
    this.si,
    this.cl,
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
      ecValue: (map['ec_value'] as num?)?.toDouble(),
      ppmValue: (map['ppm_value'] as num?)?.toDouble(),
      formula: map['formula'] as String?,
      source: map['source'] as String?,
      purity: (map['purity'] as num?)?.toDouble(),
      isLiquid: map['is_liquid'] == 1 ? true : (map['is_liquid'] == 0 ? false : null),
      density: (map['density'] as num?)?.toDouble(),
      nNO3: (map['n_no3'] as num?)?.toDouble(),
      nNH4: (map['n_nh4'] as num?)?.toDouble(),
      p: (map['p'] as num?)?.toDouble(),
      k: (map['k'] as num?)?.toDouble(),
      mg: (map['mg'] as num?)?.toDouble(),
      ca: (map['ca'] as num?)?.toDouble(),
      s: (map['s'] as num?)?.toDouble(),
      b: (map['b'] as num?)?.toDouble(),
      fe: (map['fe'] as num?)?.toDouble(),
      zn: (map['zn'] as num?)?.toDouble(),
      cu: (map['cu'] as num?)?.toDouble(),
      mn: (map['mn'] as num?)?.toDouble(),
      mo: (map['mo'] as num?)?.toDouble(),
      na: (map['na'] as num?)?.toDouble(),
      si: (map['si'] as num?)?.toDouble(),
      cl: (map['cl'] as num?)?.toDouble(),
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
      'ec_value': ecValue,
      'ppm_value': ppmValue,
      'formula': formula,
      'source': source,
      'purity': purity,
      'is_liquid': isLiquid == null ? null : (isLiquid! ? 1 : 0),
      'density': density,
      'n_no3': nNO3,
      'n_nh4': nNH4,
      'p': p,
      'k': k,
      'mg': mg,
      'ca': ca,
      's': s,
      'b': b,
      'fe': fe,
      'zn': zn,
      'cu': cu,
      'mn': mn,
      'mo': mo,
      'na': na,
      'si': si,
      'cl': cl,
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
    double? ecValue,
    double? ppmValue,
    String? formula,
    String? source,
    double? purity,
    bool? isLiquid,
    double? density,
    double? nNO3,
    double? nNH4,
    double? p,
    double? k,
    double? mg,
    double? ca,
    double? s,
    double? b,
    double? fe,
    double? zn,
    double? cu,
    double? mn,
    double? mo,
    double? na,
    double? si,
    double? cl,
    DateTime? createdAt,
  }) {
    return Fertilizer(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      npk: npk ?? this.npk,
      type: type ?? this.type,
      description: description ?? this.description,
      ecValue: ecValue ?? this.ecValue,
      ppmValue: ppmValue ?? this.ppmValue,
      formula: formula ?? this.formula,
      source: source ?? this.source,
      purity: purity ?? this.purity,
      isLiquid: isLiquid ?? this.isLiquid,
      density: density ?? this.density,
      nNO3: nNO3 ?? this.nNO3,
      nNH4: nNH4 ?? this.nNH4,
      p: p ?? this.p,
      k: k ?? this.k,
      mg: mg ?? this.mg,
      ca: ca ?? this.ca,
      s: s ?? this.s,
      b: b ?? this.b,
      fe: fe ?? this.fe,
      zn: zn ?? this.zn,
      cu: cu ?? this.cu,
      mn: mn ?? this.mn,
      mo: mo ?? this.mo,
      na: na ?? this.na,
      si: si ?? this.si,
      cl: cl ?? this.cl,
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
