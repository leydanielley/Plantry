// =============================================
// GROWLOG - Photo Model
// =============================================

class Photo {
  final int? id;
  final int logId;           // Zu welchem Log gehört das Foto
  final String filePath;     // Pfad zum gespeicherten Foto
  final DateTime createdAt;

  Photo({
    this.id,
    required this.logId,
    required this.filePath,
    DateTime? createdAt,
  }) : assert(logId > 0, 'Log ID must be greater than 0'),
        assert(filePath.isNotEmpty, 'File path cannot be empty'),
        createdAt = createdAt ?? DateTime.now();

  /// Factory: Aus Map erstellen (von Datenbank)
  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id: map['id'] as int?,
      logId: map['log_id'] as int,
      filePath: map['file_path'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    // Format: '2024-01-15 10:30:00.000'
    final formattedDate = '${createdAt.year.toString().padLeft(4, '0')}-'
        '${createdAt.month.toString().padLeft(2, '0')}-'
        '${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}:'
        '${createdAt.second.toString().padLeft(2, '0')}.'
        '${createdAt.millisecond.toString().padLeft(3, '0')}';
    
    return {
      'id': id,
      'log_id': logId,
      'file_path': filePath,
      'created_at': formattedDate,
    };
  }

  /// Copy mit Änderungen
  Photo copyWith({
    int? id,
    int? logId,
    String? filePath,
    DateTime? createdAt,
  }) {
    return Photo(
      id: id ?? this.id,
      logId: logId ?? this.logId,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get filename from path
  String get fileName {
    if (filePath.contains('/')) {
      return filePath.split('/').last;
    }
    if (filePath.contains('\\')) {
      return filePath.split('\\').last;
    }
    return filePath;
  }

  /// Get file extension
  String get fileExtension {
    if (!filePath.contains('.')) return '';
    return filePath.split('.').last.toLowerCase();
  }

  /// Format creation date
  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  /// Generate thumbnail path
  String get thumbnailPath {
    final dir = filePath.substring(0, filePath.lastIndexOf('/'));
    final name = fileName.substring(0, fileName.lastIndexOf('.'));
    final ext = fileExtension;
    return '$dir/thumbs/${name}_thumb.$ext';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Photo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Photo{id: $id, logId: $logId, filePath: $filePath}';
  }
}
