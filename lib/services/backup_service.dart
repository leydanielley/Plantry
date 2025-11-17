// =============================================
// GROWLOG - Backup & Restore Service
// =============================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/app_version.dart';
import 'package:growlog_app/utils/storage_helper.dart';
import 'package:growlog_app/config/backup_config.dart'; // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
import 'package:growlog_app/services/interfaces/i_backup_service.dart';

// ✅ FIX: Custom exception for security violations
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

class BackupService implements IBackupService {
  /// Export all app data to a ZIP file
  /// Returns the path to the created backup file
  ///
  /// [db] Optional database instance. If not provided, will get instance from DatabaseHelper.
  /// This is useful during migrations to avoid circular dependency.
  /// [onProgress] Optional callback for progress updates during backup
  @override
  Future<String> exportData({
    Database? db,
    BackupProgressCallback? onProgress,
  }) async {
    // ✅ P1 FIX: Wrap entire export in timeout (5 minutes max)
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    return await _exportDataInternal(db: db, onProgress: onProgress).timeout(
      BackupConfig.exportTimeout,
      onTimeout: () {
        AppLogger.error(
          'BackupService',
          'Export timeout after ${BackupConfig.exportTimeoutMinutes} minutes',
        );
        throw TimeoutException(
          'Export operation took too long (>${BackupConfig.exportTimeoutMinutes} minutes)',
        );
      },
    );
  }

  Future<String> _exportDataInternal({
    Database? db,
    BackupProgressCallback? onProgress,
  }) async {
    try {
      AppLogger.info('BackupService', 'Starting export...');

      // ✅ P0 FIX: Check storage BEFORE starting export
      // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
      final hasSpace = await StorageHelper.hasEnoughStorage(
        bytesNeeded: BackupConfig.minimumStorageBytes,
      );

      if (!hasSpace) {
        final storageInfo = await StorageHelper.getStorageInfo();
        throw Exception(
          'Nicht genügend Speicherplatz für Backup. $storageInfo',
        );
      }

      // Use provided database or get instance (avoid deadlock during migration)
      final database = db ?? await DatabaseHelper.instance.database;

      // ✅ NEW: Get database version for backup metadata
      final dbVersionResult = await database.rawQuery('PRAGMA user_version');
      final dbVersion = Sqflite.firstIntValue(dbVersionResult) ?? 0;

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final tempDir = await getTemporaryDirectory();
      // ✅ P1 FIX: Use path.join instead of string concatenation
      final exportDir = Directory(
        path.join(tempDir.path, 'plantry_export_$timestamp'),
      );

      // Create export directory
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
      await exportDir.create(recursive: true);

      AppLogger.debug(
        'BackupService',
        'Export directory created',
        exportDir.path,
      );

      // Export all tables to JSON
      // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
      final Map<String, dynamic> backup = {
        'version': BackupConfig.backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': AppVersion.version,
        'data': <String, dynamic>{},
      };

      // Export each table
      const tables = BackupConfig.exportTables;

      for (final table in tables) {
        try {
          final data = await database.query(table);
          // ✅ FIX: Cast to avoid dynamic call error
          (backup['data'] as Map<String, dynamic>)[table] = data;
          AppLogger.debug(
            'BackupService',
            'Exported table',
            '$table: ${data.length} rows',
          );
        } catch (e) {
          // Table might not exist yet (e.g., during migration)
          AppLogger.debug(
            'BackupService',
            'Skipped table',
            '$table (table does not exist or is not accessible)',
          );
          // ✅ FIX: Cast to avoid dynamic call error
          (backup['data'] as Map<String, dynamic>)[table] = [];
        }
      }

      // Save JSON to file
      // ✅ P1 FIX: Use path.join instead of string concatenation
      final jsonFile = File(path.join(exportDir.path, 'data.json'));
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backup),
      );

      AppLogger.info('BackupService', 'JSON data saved');

      // ✅ NEW: Create backup metadata file
      final backupData = backup['data'] as Map<String, dynamic>;
      final metadata = {
        'backup_version': BackupConfig.backupVersion,
        'db_version': dbVersion,
        'app_version': AppVersion.version,
        'backup_type': 'auto', // Will be overridden by caller if needed
        'timestamp': DateTime.now().toIso8601String(),
        'plants_count': (backupData['plants'] as List?)?.length ?? 0,
        'logs_count': (backupData['plant_logs'] as List?)?.length ?? 0,
        'grows_count': (backupData['grows'] as List?)?.length ?? 0,
        'rooms_count': (backupData['rooms'] as List?)?.length ?? 0,
        'rdwc_systems_count': (backupData['rdwc_systems'] as List?)?.length ?? 0,
      };

      final metadataFile = File(path.join(exportDir.path, 'backup_metadata.json'));
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata),
      );

      AppLogger.info('BackupService', 'Metadata saved', 'DB v$dbVersion');

      // ✅ P1 FIX: Parallelize photo copying for better performance
      // ✅ FIX: Cast to avoid dynamic call error
      final photos =
          (backup['data'] as Map<String, dynamic>)['photos'] as List<dynamic>;
      int copiedCount = 0;
      int missingCount = 0;

      // Report initial progress
      onProgress?.call(0, photos.length, 'Datenbank exportiert');

      if (photos.isNotEmpty) {
        // ✅ P1 FIX: Use path.join instead of string concatenation
        // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
        final photosDir = Directory(
          path.join(exportDir.path, BackupConfig.photosDirectoryName),
        );
        await photosDir.create();

        // Process photos in parallel batches for optimal performance
        const batchSize = BackupConfig.photoBatchSize;
        for (int i = 0; i < photos.length; i += batchSize) {
          final batch = photos.skip(i).take(batchSize);

          final results = await Future.wait(
            batch.map((photo) async {
              // ✅ FIX: Cast to avoid dynamic call error
              final filePath =
                  (photo as Map<String, dynamic>)['file_path'] as String;
              final sourceFile = File(filePath);

              if (await sourceFile.exists()) {
                final fileName = path.basename(filePath);
                // ✅ P1 FIX: Use path.join instead of string concatenation
                final destFile = File(path.join(photosDir.path, fileName));
                await sourceFile.copy(destFile.path);
                return true; // Copied successfully
              } else {
                AppLogger.warning(
                  'BackupService',
                  'Photo missing',
                  path.basename(filePath),
                );
                return false; // Missing
              }
            }),
          );

          // Count successes and failures
          copiedCount += results.where((r) => r == true).length;
          missingCount += results.where((r) => r == false).length;

          // Report progress after each batch
          onProgress?.call(
            copiedCount,
            photos.length,
            'Fotos werden kopiert: $copiedCount/${photos.length}',
          );
        }
        AppLogger.info('BackupService', 'Copied photos', 'count=$copiedCount');
        if (missingCount > 0) {
          AppLogger.warning(
            'BackupService',
            'Missing photos',
            'count=$missingCount',
          );
        }
      }

      // Create ZIP file
      final appDir = await getApplicationDocumentsDirectory();
      // ✅ P1 FIX: Use path.join instead of string concatenation
      // ✅ NEW: Include DB version in filename for easier identification
      final zipPath = path.join(appDir.path, 'plantry_backup_v${dbVersion}_$timestamp.zip');

      AppLogger.info('BackupService', 'Creating ZIP file...');
      onProgress?.call(photos.length, photos.length, 'ZIP wird erstellt...');

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addDirectory(exportDir);
      encoder.close();

      // Clean up temp directory
      await exportDir.delete(recursive: true);

      // ✅ NEW: Copy backup to Download folder for persistence
      try {
        final downloadBackupPath = await _copyToDownloadFolder(zipPath);
        AppLogger.info('BackupService', '✅ Backup also saved to Downloads', downloadBackupPath);

        // Cleanup old backups in Download folder
        await _cleanupOldBackups('/storage/emulated/0/Download/Plantry Backups/Auto', maxBackups: 5);
      } catch (e) {
        // Don't fail the entire backup if Download copy fails
        AppLogger.warning('BackupService', '⚠️ Could not copy to Downloads (backup still in app)', e);
      }

      // ✅ NEW: Cleanup old backups in app documents folder
      await _cleanupOldBackups(appDir.path, maxBackups: 5);

      AppLogger.info('BackupService', '✅ Export complete', zipPath);
      return zipPath;
    } catch (e, stackTrace) {
      AppLogger.error('BackupService', 'Export failed', e, stackTrace);
      rethrow;
    }
  }

  /// Import data from a backup ZIP file
  /// Validates data before importing
  @override
  Future<void> importData(String zipFilePath) async {
    // ✅ P1 FIX: Wrap entire import in timeout (10 minutes max)
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    return await _importDataInternal(zipFilePath).timeout(
      BackupConfig.importTimeout,
      onTimeout: () {
        AppLogger.error(
          'BackupService',
          'Import timeout after ${BackupConfig.importTimeoutMinutes} minutes',
        );
        throw TimeoutException(
          'Import operation took too long (>${BackupConfig.importTimeoutMinutes} minutes)',
        );
      },
    );
  }

  Future<void> _importDataInternal(String zipFilePath) async {
    Directory? importDir;

    try {
      AppLogger.info('BackupService', 'Starting import from', zipFilePath);

      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        throw Exception('Backup file not found');
      }

      final tempDir = await getTemporaryDirectory();
      // ✅ P1 FIX: Use path.join instead of string concatenation
      importDir = Directory(
        path.join(
          tempDir.path,
          'plantry_import_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      // Extract ZIP
      AppLogger.info('BackupService', 'Extracting ZIP...');
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      await importDir.create(recursive: true);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          // ✅ CRITICAL FIX: Sanitize filename to prevent path traversal attacks
          final sanitizedName = path.basename(filename);

          // Skip invalid filenames
          if (sanitizedName.isEmpty ||
              sanitizedName == '.' ||
              sanitizedName == '..') {
            AppLogger.warning(
              'BackupService',
              'Skipping invalid filename in ZIP: $filename',
            );
            continue;
          }

          final outFile = File(path.join(importDir.path, sanitizedName));

          // ✅ CRITICAL FIX: Verify final path is within import directory
          final canonicalOut = outFile.absolute.path;
          final canonicalImport = importDir.absolute.path;
          if (!canonicalOut.startsWith(canonicalImport)) {
            AppLogger.error(
              'BackupService',
              'Path traversal attempt detected: $filename',
            );
            throw SecurityException(
              'Path traversal attempt detected in backup file',
            );
          }

          await outFile.create(recursive: true);
          // ✅ FIXED: content is non-nullable in archive 4.x
          await outFile.writeAsBytes(file.content);
        }
      }

      AppLogger.info('BackupService', 'ZIP extracted');

      // Find and read JSON file
      // ✅ P1 FIX: Use path.join instead of string concatenation
      // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
      final jsonFile = File(
        path.join(importDir.path, BackupConfig.dataJsonFilename),
      );
      if (!await jsonFile.exists()) {
        // Try to find in subdirectory
        final files = await importDir.list(recursive: true).toList();
        final dataJsonFile = files.firstWhere(
          (f) => f.path.endsWith(BackupConfig.dataJsonFilename),
          orElse: () => throw Exception(
            '${BackupConfig.dataJsonFilename} not found in backup',
          ),
        );
        if (dataJsonFile is File) {
          final content = await dataJsonFile.readAsString();
          // ✅ CRITICAL FIX: Validate JSON before casting
          try {
            final decoded = jsonDecode(content);
            if (decoded is! Map<String, dynamic>) {
              throw Exception('Invalid backup format: expected JSON object');
            }
            final backup = decoded;
            await _importBackupData(backup, importDir);
          } on FormatException catch (e) {
            throw Exception(
              'Backup file is corrupted or invalid: ${e.message}',
            );
          }
        }
      } else {
        final content = await jsonFile.readAsString();
        // ✅ CRITICAL FIX: Validate JSON before casting
        try {
          final decoded = jsonDecode(content);
          if (decoded is! Map<String, dynamic>) {
            throw Exception('Invalid backup format: expected JSON object');
          }
          final backup = decoded;
          await _importBackupData(backup, importDir);
        } on FormatException catch (e) {
          throw Exception('Backup file is corrupted or invalid: ${e.message}');
        }
      }

      AppLogger.info('BackupService', '✅ Import complete');
    } catch (e, stackTrace) {
      AppLogger.error('BackupService', 'Import failed', e, stackTrace);
      rethrow;
    } finally {
      // Always clean up temp directory
      if (importDir != null) {
        try {
          if (await importDir.exists()) {
            await importDir.delete(recursive: true);
            AppLogger.debug('BackupService', 'Temp directory cleaned up');
          }
        } catch (e) {
          AppLogger.warning('BackupService', 'Failed to cleanup temp dir', e);
        }
      }
    }
  }

  Future<void> _importBackupData(
    Map<String, dynamic> backup,
    Directory importDir,
  ) async {
    // Validate backup version
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    final version = backup['version'] as int?;
    if (version == null || version > BackupConfig.backupVersion) {
      throw Exception('Incompatible backup version');
    }

    AppLogger.info('BackupService', 'Backup version', 'version=$version');
    AppLogger.info('BackupService', 'Export date', backup['exportDate']);

    final data = backup['data'] as Map<String, dynamic>;
    final db = await DatabaseHelper.instance.database;

    // ✅ CRITICAL FIX: Pre-validate backup data BEFORE deleting existing data
    AppLogger.info('BackupService', 'Pre-validating backup data...');
    await _preValidateBackupData(data);
    AppLogger.info('BackupService', '✅ Backup data validation passed');

    // ✅ CRITICAL FIX: Wrap entire import in transaction for atomicity
    // If anything fails, database rolls back to pre-import state
    try {
      await db.transaction((txn) async {
        // Clear existing data
        AppLogger.info('BackupService', 'Clearing existing data...');

        // ✅ CRITICAL FIX: Keep foreign keys ON during transaction
        // The deletion order in BackupConfig respects FK constraints
        // Transaction provides atomicity without disabling FK checks
        const tables = BackupConfig.deletionOrderTables;

        for (final table in tables) {
          try {
            await txn.delete(table);
          } catch (e) {
            // Table might not exist yet
            AppLogger.debug(
              'BackupService',
              'Skipped deleting table',
              '$table (table does not exist)',
            );
          }
        }

        AppLogger.info('BackupService', 'Existing data cleared');

        // Import data in correct order (respecting foreign keys)
        for (final tableName in BackupConfig.importOrderTables) {
          await _importTableInTransaction(
            txn,
            tableName,
            data[tableName] as List<dynamic>?,
          );
        }

        // Import photos (DB records only, files imported outside transaction)
        final photosData = data['photos'] as List<dynamic>?;
        if (photosData != null) {
          await _importTableInTransaction(txn, 'photos', photosData);
        }

        // ✅ CRITICAL FIX: Validate FK integrity BEFORE committing transaction
        AppLogger.info(
          'BackupService',
          'Validating foreign key constraints...',
        );
        final fkErrors = await txn.rawQuery('PRAGMA foreign_key_check');
        if (fkErrors.isNotEmpty) {
          AppLogger.error(
            'BackupService',
            'Foreign key constraint violations found',
            fkErrors,
          );
          throw Exception(
            'Import failed: ${fkErrors.length} foreign key constraint violations detected',
          );
        }

        AppLogger.info(
          'BackupService',
          '✅ Database import validated, committing transaction',
        );
      });

      // Transaction committed successfully, now restore photo files
      await _importPhotoFiles(data['photos'] as List<dynamic>?, importDir);

      AppLogger.info('BackupService', '✅ Data import complete and validated');
    } catch (e) {
      AppLogger.error(
        'BackupService',
        'Import failed, transaction rolled back',
        e,
      );
      rethrow;
    }
  }

  /// ✅ CRITICAL FIX: Transaction-safe table import
  Future<void> _importTableInTransaction(
    DatabaseExecutor txn,
    String tableName,
    List<dynamic>? rows,
  ) async {
    if (rows == null || rows.isEmpty) {
      AppLogger.debug('BackupService', 'Imported table', '$tableName: 0 rows');
      return;
    }

    for (final row in rows) {
      await txn.insert(tableName, row as Map<String, dynamic>);
    }

    AppLogger.debug(
      'BackupService',
      'Imported table',
      '$tableName: ${rows.length} rows',
    );
  }

  /// ✅ CRITICAL FIX: Import photo files AFTER transaction commits
  /// This prevents file copies from being mixed with DB transaction
  Future<void> _importPhotoFiles(
    List<dynamic>? photos,
    Directory importDir,
  ) async {
    if (photos == null || photos.isEmpty) {
      AppLogger.debug('BackupService', 'No photo files to import');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(
      path.join(appDir.path, BackupConfig.photosDirectoryName),
    );
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    int copiedCount = 0;

    // Process photos in parallel batches
    const batchSize = BackupConfig.photoBatchSize;
    for (int i = 0; i < photos.length; i += batchSize) {
      final batch = photos.skip(i).take(batchSize).toList();

      final results = await Future.wait(
        batch.map((photo) async {
          // ✅ FIX: Cast to avoid dynamic call error
          final oldPath =
              (photo as Map<String, dynamic>)['file_path'] as String;

          // ✅ CRITICAL FIX: Validate oldPath
          if (oldPath.contains('\u0000') || oldPath.contains('..')) {
            AppLogger.warning('BackupService', 'Invalid photo path', oldPath);
            return false;
          }

          final fileName = path.basename(oldPath);

          // ✅ CRITICAL FIX: Whitelist file extensions
          const allowedExtensions = [
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.webp',
            '.heic',
          ];
          if (!allowedExtensions.any(
            (ext) => fileName.toLowerCase().endsWith(ext),
          )) {
            AppLogger.warning(
              'BackupService',
              'Invalid photo extension',
              fileName,
            );
            return false;
          }

          // Find photo in import directory
          final importPhotoFile = File(
            path.join(
              importDir.path,
              BackupConfig.photosDirectoryName,
              fileName,
            ),
          );

          try {
            if (await importPhotoFile.exists()) {
              // Copy to app photos directory
              final newPath = path.join(photosDir.path, fileName);
              await importPhotoFile.copy(newPath);
              return true;
            } else {
              AppLogger.warning('BackupService', 'Photo not found', fileName);
              return false;
            }
          } catch (e) {
            AppLogger.warning('BackupService', 'Photo copy failed', e);
            return false;
          }
        }),
      );

      copiedCount += results.where((r) => r == true).length;
    }

    AppLogger.info(
      'BackupService',
      'Photo files copied',
      '$copiedCount/${photos.length}',
    );
  }

  /// Get backup info without importing
  @override
  Future<Map<String, dynamic>> getBackupInfo(String zipFilePath) async {
    try {
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        throw Exception('Backup file not found');
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find data.json
      final dataFile = archive.firstWhere(
        (f) => f.name.endsWith('data.json'),
        orElse: () => throw Exception('Invalid backup file'),
      );

      final content = utf8.decode(dataFile.content as List<int>);
      // ✅ CRITICAL FIX: Validate JSON before casting
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid backup format: expected JSON object');
      }
      final backup = decoded;
      if (!backup.containsKey('data') || backup['data'] is! Map) {
        throw Exception(
          'Invalid backup format: missing or invalid data section',
        );
      }
      final data = backup['data'] as Map<String, dynamic>;

      // Count records
      final int totalPlants = (data['plants'] as List?)?.length ?? 0;
      final int totalLogs = (data['plant_logs'] as List?)?.length ?? 0;
      final int totalPhotos = (data['photos'] as List?)?.length ?? 0;
      final int totalRooms = (data['rooms'] as List?)?.length ?? 0;
      final int totalGrows = (data['grows'] as List?)?.length ?? 0;

      return {
        'version': backup['version'],
        'exportDate': backup['exportDate'],
        'appVersion': backup['appVersion'],
        'totalPlants': totalPlants,
        'totalLogs': totalLogs,
        'totalPhotos': totalPhotos,
        'totalRooms': totalRooms,
        'totalGrows': totalGrows,
      };
    } catch (e) {
      AppLogger.error('BackupService', 'Failed to read backup info', e);
      rethrow;
    }
  }

  /// ✅ CRITICAL FIX: Pre-validate backup data before importing
  ///
  /// This method validates backup data structure and content BEFORE
  /// deleting existing database data. If validation fails, the import
  /// is aborted without touching existing data.
  ///
  /// Validates:
  /// - Required tables exist in backup
  /// - Data structure is valid (List of Maps)
  /// - Critical fields are present
  /// - FK references are consistent
  Future<void> _preValidateBackupData(Map<String, dynamic> data) async {
    // Step 1: Validate all required tables exist
    const requiredTables = BackupConfig.importOrderTables;
    for (final table in requiredTables) {
      if (!data.containsKey(table)) {
        throw Exception('Invalid backup: Missing required table "$table"');
      }

      final tableData = data[table];
      if (tableData is! List) {
        throw Exception(
          'Invalid backup: Table "$table" must be a list, got ${tableData.runtimeType}',
        );
      }
    }

    // Step 2: Validate data structure for critical tables
    final plants = data['plants'] as List?;
    if (plants != null && plants.isNotEmpty) {
      for (final plant in plants) {
        if (plant is! Map) {
          throw Exception('Invalid backup: Plant record must be a Map');
        }

        // Validate required fields
        final requiredFields = ['id', 'name', 'seed_type', 'medium'];
        for (final field in requiredFields) {
          if (!plant.containsKey(field) || plant[field] == null) {
            throw Exception(
              'Invalid backup: Plant missing required field "$field"',
            );
          }
        }
      }
    }

    // Step 3: Validate FK references (plant_logs → plants)
    final plantLogs = data['plant_logs'] as List?;
    if (plantLogs != null && plantLogs.isNotEmpty && plants != null) {
      final plantIds = plants
          .cast<Map<String, dynamic>>()
          .map((p) => p['id'] as int?)
          .whereType<int>()
          .toSet();

      for (final log in plantLogs) {
        if (log is! Map) continue;

        final plantId = log['plant_id'] as int?;
        if (plantId != null && !plantIds.contains(plantId)) {
          throw Exception(
            'Invalid backup: plant_log references non-existent plant_id=$plantId',
          );
        }
      }
    }

    // Step 4: Validate photos references
    final photos = data['photos'] as List?;
    if (photos != null && photos.isNotEmpty && plantLogs != null) {
      final logIds = plantLogs
          .cast<Map<String, dynamic>>()
          .map((l) => l['id'] as int?)
          .whereType<int>()
          .toSet();

      for (final photo in photos) {
        if (photo is! Map) continue;

        final logId = photo['log_id'] as int?;
        if (logId != null && !logIds.contains(logId)) {
          AppLogger.warning(
            'BackupService',
            'Photo references non-existent log_id=$logId (will be skipped)',
          );
        }
      }
    }

    AppLogger.info(
      'BackupService',
      'Pre-validation complete: ${plants?.length ?? 0} plants, '
          '${plantLogs?.length ?? 0} logs, ${photos?.length ?? 0} photos',
    );
  }

  /// Copy backup to Download folder for persistence
  /// Returns path to copy in Download folder
  Future<String> _copyToDownloadFolder(String backupPath) async {
    // Create Download/Plantry Backups/Auto directory
    final downloadDir = Directory('/storage/emulated/0/Download/Plantry Backups/Auto');

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
      AppLogger.info('BackupService', 'Created Download backup directory', downloadDir.path);
    }

    // Copy backup file
    final backupFile = File(backupPath);
    final fileName = path.basename(backupPath);
    final targetPath = path.join(downloadDir.path, fileName);

    await backupFile.copy(targetPath);

    return targetPath;
  }

  /// Clean up old backups, keeping only the last [maxBackups] files
  /// Searches for plantry_backup_*.zip files and sorts by modification time
  Future<void> _cleanupOldBackups(String backupDir, {int maxBackups = 5}) async {
    try {
      final dir = Directory(backupDir);
      if (!await dir.exists()) return;

      // Find all backup files
      final allFiles = await dir.list().toList();
      final backupFiles = allFiles
          .whereType<File>()
          .where((f) => path.basename(f.path).startsWith('plantry_backup_'))
          .where((f) => path.basename(f.path).endsWith('.zip'))
          .toList();

      if (backupFiles.length <= maxBackups) {
        // No cleanup needed
        return;
      }

      // Sort by modification time (newest first)
      backupFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // Delete old backups (keep only maxBackups)
      int deletedCount = 0;
      for (int i = maxBackups; i < backupFiles.length; i++) {
        try {
          await backupFiles[i].delete();
          deletedCount++;
          AppLogger.debug(
            'BackupService',
            'Deleted old backup',
            path.basename(backupFiles[i].path),
          );
        } catch (e) {
          AppLogger.warning(
            'BackupService',
            'Could not delete old backup',
            e,
          );
        }
      }

      if (deletedCount > 0) {
        AppLogger.info(
          'BackupService',
          'Cleanup complete',
          'Deleted $deletedCount old backups, kept $maxBackups',
        );
      }
    } catch (e) {
      // Don't fail backup if cleanup fails
      AppLogger.warning('BackupService', 'Backup cleanup failed', e);
    }
  }
}
