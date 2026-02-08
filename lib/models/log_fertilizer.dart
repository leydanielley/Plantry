// =============================================
// GROWLOG - LogFertilizer Model (Junction)
// =============================================

class LogFertilizer {
  final int? id;
  final int logId;
  final int fertilizerId;
  final double amount;
  final String unit;

  LogFertilizer({
    this.id,
    required this.logId,
    required this.fertilizerId,
    required this.amount,
    this.unit = 'ml',
  });

  /// Factory: Aus Map erstellen (von Datenbank)
  factory LogFertilizer.fromMap(Map<String, dynamic> map) {
    return LogFertilizer(
      id: map['id'] as int?,
      // ✅ CRITICAL FIX: Null-safe casts for required foreign keys
      logId: map['log_id'] as int? ?? 0,
      fertilizerId: map['fertilizer_id'] as int? ?? 0,
      // ✅ CRITICAL FIX: Null-safe cast to prevent crash on NULL/corrupted data
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'ml',
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'log_id': logId,
      'fertilizer_id': fertilizerId,
      'amount': amount,
      'unit': unit,
    };
  }

  @override
  String toString() {
    return 'LogFertilizer{id: $id, logId: $logId, fertilizerId: $fertilizerId, amount: $amount$unit}';
  }
}
