// =============================================
// GROWLOG - RDWC Log Fertilizer Model
// =============================================

/// Type of fertilizer amount entry
enum FertilizerAmountType {
  /// Amount specified per liter (e.g., 2ml/L)
  /// Total amount = amount * system volume
  perLiter,

  /// Total amount for entire system (e.g., 100ml total)
  /// Per liter amount = amount / system volume
  total,
}

/// Fertilizer entry for an RDWC log
///
/// Tracks which fertilizers were added during an addback or reservoir change,
/// and how much (either per liter or as total amount).
class RdwcLogFertilizer {
  final int? id;
  final int rdwcLogId;
  final int fertilizerId;
  final double amount;                    // Amount in ml or g
  final FertilizerAmountType amountType;  // How amount is specified
  final DateTime createdAt;

  RdwcLogFertilizer({
    this.id,
    required this.rdwcLogId,
    required this.fertilizerId,
    required this.amount,
    required this.amountType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Get total amount for the system
  ///
  /// If amount type is per liter, multiply by system volume.
  /// If amount type is total, return amount directly.
  double getTotalAmount(double systemVolumeLiters) {
    if (amountType == FertilizerAmountType.perLiter) {
      return amount * systemVolumeLiters;
    }
    return amount;
  }

  /// Get amount per liter
  ///
  /// If amount type is total, divide by system volume.
  /// If amount type is per liter, return amount directly.
  double getPerLiterAmount(double systemVolumeLiters) {
    if (amountType == FertilizerAmountType.total) {
      return systemVolumeLiters > 0 ? amount / systemVolumeLiters : 0;
    }
    return amount;
  }

  /// Factory: Create from database map
  factory RdwcLogFertilizer.fromMap(Map<String, dynamic> map) {
    // Parse amountType from database format
    FertilizerAmountType amountType;
    final dbAmountType = map['amount_type'] as String;
    switch (dbAmountType) {
      case 'PER_LITER':
        amountType = FertilizerAmountType.perLiter;
        break;
      case 'TOTAL':
        amountType = FertilizerAmountType.total;
        break;
      default:
        throw ArgumentError('Unknown amount_type: $dbAmountType');
    }

    return RdwcLogFertilizer(
      id: map['id'] as int?,
      rdwcLogId: map['rdwc_log_id'] as int,
      fertilizerId: map['fertilizer_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      amountType: amountType,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    // Convert enum to database format: perLiter -> PER_LITER, total -> TOTAL
    String dbAmountType;
    switch (amountType) {
      case FertilizerAmountType.perLiter:
        dbAmountType = 'PER_LITER';
        break;
      case FertilizerAmountType.total:
        dbAmountType = 'TOTAL';
        break;
    }

    return {
      'id': id,
      'rdwc_log_id': rdwcLogId,
      'fertilizer_id': fertilizerId,
      'amount': amount,
      'amount_type': dbAmountType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy with changes
  RdwcLogFertilizer copyWith({
    int? id,
    int? rdwcLogId,
    int? fertilizerId,
    double? amount,
    FertilizerAmountType? amountType,
    DateTime? createdAt,
  }) {
    return RdwcLogFertilizer(
      id: id ?? this.id,
      rdwcLogId: rdwcLogId ?? this.rdwcLogId,
      fertilizerId: fertilizerId ?? this.fertilizerId,
      amount: amount ?? this.amount,
      amountType: amountType ?? this.amountType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    final typeStr = amountType == FertilizerAmountType.perLiter ? 'ml/L' : 'ml total';
    return 'RdwcLogFertilizer{id: $id, fertilizerId: $fertilizerId, amount: $amount $typeStr}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RdwcLogFertilizer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
