// =============================================
// GROWLOG - BackupService Interface
// =============================================

import 'package:sqflite/sqflite.dart';

/// Progress callback for backup operations
/// [current] Current progress (e.g., photos copied)
/// [total] Total items to process
/// [message] Description of current operation
typedef BackupProgressCallback =
    void Function(int current, int total, String message);

abstract class IBackupService {
  /// Export all app data to a ZIP file
  /// Returns the path to the created backup file
  ///
  /// [db] Optional database instance (useful during migrations)
  /// [onProgress] Optional callback for progress updates
  Future<String> exportData({Database? db, BackupProgressCallback? onProgress});

  /// Import data from a backup ZIP file
  /// Validates data before importing
  Future<void> importData(String zipFilePath);

  /// Get backup info without importing
  Future<Map<String, dynamic>> getBackupInfo(String zipFilePath);
}
