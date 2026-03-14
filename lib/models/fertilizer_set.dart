// =============================================
// GROWLOG - FertilizerSet Model
// =============================================

class FertilizerSetItem {
  final int? id;
  final int setId;
  final int fertilizerId;
  final double amount;

  const FertilizerSetItem({
    this.id,
    required this.setId,
    required this.fertilizerId,
    required this.amount,
  });

  factory FertilizerSetItem.fromMap(Map<String, dynamic> map) {
    return FertilizerSetItem(
      id: map['id'] as int?,
      setId: map['set_id'] as int,
      fertilizerId: map['fertilizer_id'] as int,
      amount: (map['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'set_id': setId,
    'fertilizer_id': fertilizerId,
    'amount': amount,
  };
}

class FertilizerSet {
  final int? id;
  final String name;
  final DateTime createdAt;
  final int itemCount; // populated by repository

  const FertilizerSet({
    this.id,
    required this.name,
    required this.createdAt,
    this.itemCount = 0,
  });

  factory FertilizerSet.fromMap(Map<String, dynamic> map, {int itemCount = 0}) {
    return FertilizerSet(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      itemCount: itemCount,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };
}
