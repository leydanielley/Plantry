// =============================================
// GROWLOG - BackupService Interface
// =============================================

import 'package:sqflite/sqflite.dart';

abstract class IBackupService {
  /// Export all app data to a ZIP file
  /// Returns the path to the created backup file
  Future<String> exportData({Database? db});

  /// Import data from a backup ZIP file
  /// Validates data before importing
  Future<void> importData(String zipFilePath);

  /// Get backup info without importing
  Future<Map<String, dynamic>> getBackupInfo(String zipFilePath);
}
