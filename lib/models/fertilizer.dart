// =============================================
// GROWLOG - Fertilizer Model
// =============================================

import 'package:growlog_app/utils/safe_parsers.dart'; // ✅ FIX: Safe parsing utilities

/// Sentinel object for copyWith to distinguish between null and undefined
const Object _undefined = Object();

class Fertilizer {
  final int? id;
  final String name;
  final String? brand;
  final String? npk;
  final String? type;
  final String? description;
  final double? ecValue; // v8: EC contribution per ml (for RDWC calculations)
  final double? ppmValue; // v8: PPM contribution per ml (for RDWC calculations)

  // v0.9.1: HydroBuddy-compatible detailed composition
  final String? formula; // Chemical formula (e.g. "KNO3", "Ca(NO3)2")
  final String? source; // Source URL or reference
  final double? purity; // Purity (0.0 - 1.0)
  final bool? isLiquid; // Is liquid fertilizer
  final double? density; // Density for liquid (g/ml)

  // Macronutrients (as percentages)
  final double? nNO3; // N as Nitrate (NO3-)
  final double? nNH4; // N as Ammonium (NH4+)
  final double? p; // Phosphorus (P)
  final double? k; // Potassium (K)
  final double? mg; // Magnesium (Mg)
  final double? ca; // Calcium (Ca)
  final double? s; // Sulfur (S)

  // Micronutrients (as percentages)
  final double? b; // Boron (B)
  final double? fe; // Iron (Fe)
  final double? zn; // Zinc (Zn)
  final double? cu; // Copper (Cu)
  final double? mn; // Manganese (Mn)
  final double? mo; // Molybdenum (Mo)
  final double? na; // Sodium (Na)
  final double? si; // Silicon (Si)
  final double? cl; // Chlorine (Cl)

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
      // ✅ CRITICAL FIX: Null-safe cast for required field
      name: map['name'] as String? ?? 'Unknown Fertilizer',
      brand: map['brand'] as String?,
      npk: map['npk'] as String?,
      type: map['type'] as String?,
      description: map['description'] as String?,
      ecValue: (map['ec_value'] as num?)?.toDouble(),
      ppmValue: (map['ppm_value'] as num?)?.toDouble(),
      formula: map['formula'] as String?,
      source: map['source'] as String?,
      purity: (map['purity'] as num?)?.toDouble(),
      isLiquid: map['is_liquid'] == 1
          ? true
          : (map['is_liquid'] == 0 ? false : null),
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
      createdAt: SafeParsers.parseDateTime(
        map['created_at'] as String?,
        fallback: DateTime.now(),
        context: 'Fertilizer.fromMap.createdAt',
      ),
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
  /// ✅ FIX: Nullable Felder können jetzt auf null gesetzt werden
  Fertilizer copyWith({
    int? id,
    String? name,
    Object? brand = _undefined,
    Object? npk = _undefined,
    Object? type = _undefined,
    Object? description = _undefined,
    Object? ecValue = _undefined,
    Object? ppmValue = _undefined,
    Object? formula = _undefined,
    Object? source = _undefined,
    Object? purity = _undefined,
    Object? isLiquid = _undefined,
    Object? density = _undefined,
    Object? nNO3 = _undefined,
    Object? nNH4 = _undefined,
    Object? p = _undefined,
    Object? k = _undefined,
    Object? mg = _undefined,
    Object? ca = _undefined,
    Object? s = _undefined,
    Object? b = _undefined,
    Object? fe = _undefined,
    Object? zn = _undefined,
    Object? cu = _undefined,
    Object? mn = _undefined,
    Object? mo = _undefined,
    Object? na = _undefined,
    Object? si = _undefined,
    Object? cl = _undefined,
    DateTime? createdAt,
  }) {
    return Fertilizer(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand == _undefined ? this.brand : brand as String?,
      npk: npk == _undefined ? this.npk : npk as String?,
      type: type == _undefined ? this.type : type as String?,
      description: description == _undefined
          ? this.description
          : description as String?,
      ecValue: ecValue == _undefined ? this.ecValue : ecValue as double?,
      ppmValue: ppmValue == _undefined ? this.ppmValue : ppmValue as double?,
      formula: formula == _undefined ? this.formula : formula as String?,
      source: source == _undefined ? this.source : source as String?,
      purity: purity == _undefined ? this.purity : purity as double?,
      isLiquid: isLiquid == _undefined ? this.isLiquid : isLiquid as bool?,
      density: density == _undefined ? this.density : density as double?,
      nNO3: nNO3 == _undefined ? this.nNO3 : nNO3 as double?,
      nNH4: nNH4 == _undefined ? this.nNH4 : nNH4 as double?,
      p: p == _undefined ? this.p : p as double?,
      k: k == _undefined ? this.k : k as double?,
      mg: mg == _undefined ? this.mg : mg as double?,
      ca: ca == _undefined ? this.ca : ca as double?,
      s: s == _undefined ? this.s : s as double?,
      b: b == _undefined ? this.b : b as double?,
      fe: fe == _undefined ? this.fe : fe as double?,
      zn: zn == _undefined ? this.zn : zn as double?,
      cu: cu == _undefined ? this.cu : cu as double?,
      mn: mn == _undefined ? this.mn : mn as double?,
      mo: mo == _undefined ? this.mo : mo as double?,
      na: na == _undefined ? this.na : na as double?,
      si: si == _undefined ? this.si : si as double?,
      cl: cl == _undefined ? this.cl : cl as double?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get N value from NPK string
  /// ✅ CRITICAL FIX: Use tryParse instead of parse to prevent crashes
  double get nValue {
    if (npk == null || npk!.isEmpty) return 0.0;
    final parts = npk!.split('-');
    if (parts.isEmpty) return 0.0;
    return double.tryParse(parts[0].trim()) ?? 0.0;
  }

  /// Get P value from NPK string
  /// ✅ CRITICAL FIX: Use tryParse instead of parse to prevent crashes
  double get pValue {
    if (npk == null || npk!.isEmpty) return 0.0;
    final parts = npk!.split('-');
    if (parts.length <= 1) return 0.0;
    return double.tryParse(parts[1].trim()) ?? 0.0;
  }

  /// Get K value from NPK string
  /// ✅ CRITICAL FIX: Use tryParse instead of parse to prevent crashes
  double get kValue {
    if (npk == null || npk!.isEmpty) return 0.0;
    final parts = npk!.split('-');
    if (parts.length <= 2) return 0.0;
    return double.tryParse(parts[2].trim()) ?? 0.0;
  }

  /// Calculate NPK ratio
  String get npkRatio {
    if (npk == null || npk!.isEmpty) return '';

    final n = nValue;
    final p = pValue;
    final k = kValue;

    if (n == 0 && p == 0 && k == 0) return '0:0:0';

    // Find GCD to simplify ratio
    final minValue =
        [n, p, k]
            .where((v) => v > 0)
            .fold<double?>(
              null,
              (min, v) => min == null || v < min ? v : min,
            ) ??
        1;

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
      other is Fertilizer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Fertilizer{id: $id, name: $name, brand: $brand, npk: $npk}';
  }
}
