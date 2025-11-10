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
import '../database/database_helper.dart';
import '../utils/app_logger.dart';
import '../utils/app_version.dart';
import '../utils/storage_helper.dart';
import '../config/backup_config.dart';  // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
import 'interfaces/i_backup_service.dart';

class BackupService implements IBackupService {

  /// Export all app data to a ZIP file
  /// Returns the path to the created backup file
  ///
  /// [db] Optional database instance. If not provided, will get instance from DatabaseHelper.
  /// This is useful during migrations to avoid circular dependency.
  @override
  Future<String> exportData({Database? db}) async {
    // ✅ P1 FIX: Wrap entire export in timeout (5 minutes max)
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    return await _exportDataInternal(db: db).timeout(
      BackupConfig.exportTimeout,
      onTimeout: () {
        AppLogger.error('BackupService', 'Export timeout after ${BackupConfig.exportTimeoutMinutes} minutes');
        throw TimeoutException('Export operation took too long (>${BackupConfig.exportTimeoutMinutes} minutes)');
      },
    );
  }

  Future<String> _exportDataInternal({Database? db}) async {
    try {
      AppLogger.info('BackupService', 'Starting export...');

      // ✅ P0 FIX: Check storage BEFORE starting export
      // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
      final hasSpace = await StorageHelper.hasEnoughStorage(
        bytesNeeded: BackupConfig.minimumStorageBytes,
      );

      if (!hasSpace) {
        final storageInfo = await StorageHelper.getStorageInfo();
        throw Exception('Nicht genügend Speicherplatz für Backup. $storageInfo');
      }

      // Use provided database or get instance (avoid deadlock during migration)
      final database = db ?? await DatabaseHelper.instance.database;
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final tempDir = await getTemporaryDirectory();
      // ✅ P1 FIX: Use path.join instead of string concatenation
      final exportDir = Directory(path.join(tempDir.path, 'plantry_export_$timestamp'));

      // Create export directory
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
      await exportDir.create(recursive: true);

      AppLogger.debug('BackupService', 'Export directory created', exportDir.path);

      // Export all tables to JSON
      // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
      final Map<String, dynamic> backup = {
        'version': BackupConfig.backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': AppVersion.version,
        'data': {},
      };

      // Export each table
      final tables = BackupConfig.exportTables;

      for (final table in tables) {
        try {
          final data = await database.query(table);
          backup['data'][table] = data;
          AppLogger.debug('BackupService', 'Exported table', '$table: ${data.length} rows');
        } catch (e) {
          // Table might not exist yet (e.g., during migration)
          AppLogger.debug('BackupService', 'Skipped table', '$table (table does not exist or is not accessible)');
          backup['data'][table] = [];
        }
      }

      // Save JSON to file
      // ✅ P1 FIX: Use path.join instead of string concatenation
      final jsonFile = File(path.join(exportDir.path, 'data.json'));
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backup),
      );

      AppLogger.info('BackupService', 'JSON data saved');

      // ✅ P1 FIX: Parallelize photo copying for better performance
      final photos = backup['data']['photos'] as List<dynamic>;
      int copiedCount = 0;
      int missingCount = 0;

      if (photos.isNotEmpty) {
        // ✅ P1 FIX: Use path.join instead of string concatenation
        // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
        final photosDir = Directory(path.join(exportDir.path, BackupConfig.photosDirectoryName));
        await photosDir.create();

        // Process photos in parallel batches for optimal performance
        final batchSize = BackupConfig.photoBatchSize;
        for (int i = 0; i < photos.length; i += batchSize) {
          final batch = photos.skip(i).take(batchSize);

          final results = await Future.wait(
            batch.map((photo) async {
              final filePath = photo['file_path'] as String;
              final sourceFile = File(filePath);

              if (await sourceFile.exists()) {
                final fileName = path.basename(filePath);
                // ✅ P1 FIX: Use path.join instead of string concatenation
                final destFile = File(path.join(photosDir.path, fileName));
                await sourceFile.copy(destFile.path);
                return true; // Copied successfully
              } else {
                AppLogger.warning('BackupService', 'Photo missing', path.basename(filePath));
                return false; // Missing
              }
            }),
          );

          // Count successes and failures
          copiedCount += results.where((r) => r == true).length;
          missingCount += results.where((r) => r == false).length;
        }
        AppLogger.info('BackupService', 'Copied photos', 'count=$copiedCount');
        if (missingCount > 0) {
          AppLogger.warning('BackupService', 'Missing photos', 'count=$missingCount');
        }
      }

      // Create ZIP file
      final appDir = await getApplicationDocumentsDirectory();
      // ✅ P1 FIX: Use path.join instead of string concatenation
      final zipPath = path.join(appDir.path, 'plantry_backup_$timestamp.zip');

      AppLogger.info('BackupService', 'Creating ZIP file...');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addDirectory(exportDir);
      encoder.close();

      // Clean up temp directory
      await exportDir.delete(recursive: true);

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
        AppLogger.error('BackupService', 'Import timeout after ${BackupConfig.importTimeoutMinutes} minutes');
        throw TimeoutException('Import operation took too long (>${BackupConfig.importTimeoutMinutes} minutes)');
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
      importDir = Directory(path.join(tempDir.path, 'plantry_import_${DateTime.now().millisecondsSinceEpoch}'));

      // Extract ZIP
      AppLogger.info('BackupService', 'Extracting ZIP...');
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      await importDir.create(recursive: true);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          // ✅ P1 FIX: Use path.join instead of string concatenation
          final outFile = File(path.join(importDir.path, filename));
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      AppLogger.info('BackupService', 'ZIP extracted');

      // Find and read JSON file
      // ✅ P1 FIX: Use path.join instead of string concatenation
      // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
      final jsonFile = File(path.join(importDir.path, BackupConfig.dataJsonFilename));
      if (!await jsonFile.exists()) {
        // Try to find in subdirectory
        final files = await importDir.list(recursive: true).toList();
        final dataJsonFile = files.firstWhere(
          (f) => f.path.endsWith(BackupConfig.dataJsonFilename),
          orElse: () => throw Exception('${BackupConfig.dataJsonFilename} not found in backup'),
        );
        if (dataJsonFile is File) {
          final content = await dataJsonFile.readAsString();
          final backup = jsonDecode(content) as Map<String, dynamic>;
          await _importBackupData(backup, importDir);
        }
      } else {
        final content = await jsonFile.readAsString();
        final backup = jsonDecode(content) as Map<String, dynamic>;
        await _importBackupData(backup, importDir);
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

    // Clear existing data
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    AppLogger.info('BackupService', 'Clearing existing data...');
    await db.execute('PRAGMA foreign_keys = OFF');

    final tables = BackupConfig.deletionOrderTables;

    for (final table in tables) {
      try {
        await db.delete(table);
      } catch (e) {
        // Table might not exist yet
        AppLogger.debug('BackupService', 'Skipped deleting table', '$table (table does not exist)');
      }
    }

    AppLogger.info('BackupService', 'Existing data cleared');

    // Import data in correct order (respecting foreign keys)
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    for (final tableName in BackupConfig.importOrderTables) {
      await _importTable(db, tableName, data[tableName] as List<dynamic>?);
    }

    // Import photos and restore image files
    await _importPhotos(db, data['photos'] as List<dynamic>?, importDir);

    await db.execute('PRAGMA foreign_keys = ON');

    // ✅ P2 FIX: Validate foreign key constraints after import
    AppLogger.info('BackupService', 'Validating foreign key constraints...');
    final fkErrors = await db.rawQuery('PRAGMA foreign_key_check');
    if (fkErrors.isNotEmpty) {
      AppLogger.error('BackupService', 'Foreign key constraint violations found', fkErrors);
      throw Exception('Import failed: ${fkErrors.length} foreign key constraint violations detected');
    }

    AppLogger.info('BackupService', '✅ Data import complete and validated');
  }

  Future<void> _importTable(
    dynamic db,
    String tableName,
    List<dynamic>? rows,
  ) async {
    if (rows == null || rows.isEmpty) {
      AppLogger.debug('BackupService', 'Imported table', '$tableName: 0 rows');
      return;
    }

    for (final row in rows) {
      await db.insert(tableName, row as Map<String, dynamic>);
    }

    AppLogger.debug('BackupService', 'Imported table', '$tableName: ${rows.length} rows');
  }

  Future<void> _importPhotos(
    dynamic db,
    List<dynamic>? photos,
    Directory importDir,
  ) async {
    if (photos == null || photos.isEmpty) {
      AppLogger.debug('BackupService', 'Imported photos', '0 rows');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    // ✅ P1 FIX: Use path.join instead of string concatenation
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    final photosDir = Directory(path.join(appDir.path, BackupConfig.photosDirectoryName));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // ✅ P1 FIX: Parallelize photo import for better performance
    int copiedCount = 0;

    // Process photos in parallel batches
    final batchSize = BackupConfig.photoBatchSize;
    for (int i = 0; i < photos.length; i += batchSize) {
      final batch = photos.skip(i).take(batchSize).toList();

      final results = await Future.wait(
        batch.map((photo) async {
          final oldPath = photo['file_path'] as String;
          final fileName = path.basename(oldPath);

          // Find photo in import directory
          // ✅ P1 FIX: Use path.join instead of string concatenation
          // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
          final importPhotoFile = File(path.join(importDir.path, BackupConfig.photosDirectoryName, fileName));

          if (await importPhotoFile.exists()) {
            // Copy to app photos directory
            // ✅ P1 FIX: Use path.join instead of string concatenation
            final newPath = path.join(photosDir.path, fileName);
            await importPhotoFile.copy(newPath);

            // Insert photo record with new path
            // Note: Database inserts must be sequential, so this is still correct
            await db.insert('photos', {
              'id': photo['id'],
              'log_id': photo['log_id'],
              'file_path': newPath,
              'created_at': photo['created_at'],
            });

            return true; // Copied successfully
          } else {
            AppLogger.warning('BackupService', 'Photo not found', fileName);
            return false; // Not found
          }
        }),
      );

      copiedCount += results.where((r) => r == true).length;
    }

    AppLogger.info('BackupService', 'Photos imported', 'rows=${photos.length}, files=$copiedCount');
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
      final backup = jsonDecode(content) as Map<String, dynamic>;
      final data = backup['data'] as Map<String, dynamic>;

      // Count records
      int totalPlants = (data['plants'] as List?)?.length ?? 0;
      int totalLogs = (data['plant_logs'] as List?)?.length ?? 0;
      int totalPhotos = (data['photos'] as List?)?.length ?? 0;
      int totalRooms = (data['rooms'] as List?)?.length ?? 0;
      int totalGrows = (data['grows'] as List?)?.length ?? 0;

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
}
