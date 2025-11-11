// =============================================
// GROWLOG - Photo Model
// ✅ AUDIT FIX: Null safety for lastIndexOf operations
// =============================================

import 'package:growlog_app/utils/safe_parsers.dart'; // ✅ FIX: Safe parsing utilities

class Photo {
  final int? id;
  final int logId; // Zu welchem Log gehört das Foto
  final String filePath; // Pfad zum gespeicherten Foto
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
  /// ✅ FIX: DateTime.parse now uses safe parser
  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id: map['id'] as int?,
      // ✅ CRITICAL FIX: Null-safe casts for required fields
      logId: map['log_id'] as int? ?? 0,
      filePath: map['file_path'] as String? ?? '',
      createdAt: SafeParsers.parseDateTime(
        map['created_at'] as String?,
        fallback: DateTime.now(),
        context: 'Photo.fromMap.createdAt',
      ),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  /// ✅ HIGH PRIORITY FIX: Use ISO8601 format to match fromMap expectations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'log_id': logId,
      'file_path': filePath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy mit Änderungen
  Photo copyWith({int? id, int? logId, String? filePath, DateTime? createdAt}) {
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  /// Generate thumbnail path
  /// ✅ AUDIT FIX: Safe lastIndexOf with fallback for missing separators
  String get thumbnailPath {
    // Get directory safely
    final lastSlashIndex = filePath.lastIndexOf('/');
    final dir = lastSlashIndex != -1
        ? filePath.substring(0, lastSlashIndex)
        : '.'; // Current directory if no slash found

    // Get filename without extension safely
    final lastDotIndex = fileName.lastIndexOf('.');
    final name = lastDotIndex != -1
        ? fileName.substring(0, lastDotIndex)
        : fileName; // Use full filename if no extension

    final ext = fileExtension.isNotEmpty
        ? fileExtension
        : 'jpg'; // Default to jpg

    return '$dir/thumbs/${name}_thumb.$ext';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Photo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Photo{id: $id, logId: $logId, filePath: $filePath}';
  }
}
