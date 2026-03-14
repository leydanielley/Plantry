// =============================================
// GROWLOG - Backup Service Configuration
// ✅ AUDIT FIX: Centralized magic numbers from backup_service.dart
// =============================================

/// Configuration constants for backup/restore service
///
/// Centralizes all timeout values, batch sizes, and storage
/// requirements to prevent magic numbers.
class BackupConfig {
  // ═══════════════════════════════════════════
  // VERSION
  // ═══════════════════════════════════════════

  /// Current backup format version
  static const int backupVersion = 1;

  // ═══════════════════════════════════════════
  // TIMEOUT SETTINGS
  // ═══════════════════════════════════════════

  /// Maximum duration for export operation (in minutes)
  static const int exportTimeoutMinutes = 5;

  /// Maximum duration for import operation (in minutes)
  static const int importTimeoutMinutes = 10;

  // ═══════════════════════════════════════════
  // STORAGE REQUIREMENTS
  // ═══════════════════════════════════════════

  /// Minimum free storage needed for backup (in MB)
  static const int minimumStorageMB = 200;

  /// Minimum free storage needed for backup (in bytes)
  static const int minimumStorageBytes = 200 * 1024 * 1024;

  // ═══════════════════════════════════════════
  // PHOTO PROCESSING
  // ═══════════════════════════════════════════

  /// Number of photos to process in parallel during export/import
  static const int photoBatchSize = 10;

  // ═══════════════════════════════════════════
  // DIRECTORY NAMES
  // ═══════════════════════════════════════════

  /// Photos subdirectory name in backup
  static const String photosDirectoryName = 'photos';

  /// Data JSON filename
  static const String dataJsonFilename = 'data.json';

  // ═══════════════════════════════════════════
  // TABLE NAMES (for export/import order)
  // ═══════════════════════════════════════════

  /// List of all tables to export
  static const List<String> exportTables = [
    'rooms',
    'grows',
    'plants',
    'plant_logs',
    'fertilizers',
    'log_fertilizers',
    'hardware',
    'photos',
    'log_templates',
    'template_fertilizers',
    'harvests',
    'app_settings',
    'rdwc_systems',
    'rdwc_logs',
    'rdwc_log_fertilizers',
    'rdwc_recipes',
    'rdwc_recipe_fertilizers',
    'fertilizer_sets',
    'fertilizer_set_items',
  ];

  /// List of tables in deletion order (respects foreign keys)
  static const List<String> deletionOrderTables = [
    'fertilizer_set_items',
    'fertilizer_sets',
    'rdwc_recipe_fertilizers',
    'rdwc_log_fertilizers',
    'rdwc_logs',
    'rdwc_recipes',
    'log_fertilizers',
    'template_fertilizers',
    'photos',
    'plant_logs',
    'harvests',
    'log_templates',
    'hardware',
    'fertilizers',
    'plants',
    'rdwc_systems',
    'grows',
    'rooms',
    'app_settings',
  ];

  /// List of tables in import order (respects foreign keys)
  static const List<String> importOrderTables = [
    'rdwc_systems',
    'rooms',
    'grows',
    'plants',
    'fertilizers',
    'plant_logs',
    'log_fertilizers',
    'rdwc_logs',
    'rdwc_log_fertilizers',
    'rdwc_recipes',
    'rdwc_recipe_fertilizers',
    'hardware',
    'log_templates',
    'template_fertilizers',
    'harvests',
    'app_settings',
    'fertilizer_sets',
    'fertilizer_set_items',
  ];

  // ═══════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════

  /// Get export timeout duration
  static Duration get exportTimeout =>
      const Duration(minutes: exportTimeoutMinutes);

  /// Get import timeout duration
  static Duration get importTimeout =>
      const Duration(minutes: importTimeoutMinutes);
}
