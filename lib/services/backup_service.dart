// =============================================
// GROWLOG - Backup & Restore Service
// =============================================

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
import 'interfaces/i_backup_service.dart';

class BackupService implements IBackupService {
  static const int _backupVersion = 1;

  /// Export all app data to a ZIP file
  /// Returns the path to the created backup file
  ///
  /// [db] Optional database instance. If not provided, will get instance from DatabaseHelper.
  /// This is useful during migrations to avoid circular dependency.
  @override
  Future<String> exportData({Database? db}) async {
    try {
      AppLogger.info('BackupService', 'Starting export...');

      // ✅ P0 FIX: Check storage BEFORE starting export
      final hasSpace = await StorageHelper.hasEnoughStorage(
        bytesNeeded: 200 * 1024 * 1024, // 200MB for safe backup
      );

      if (!hasSpace) {
        final storageInfo = await StorageHelper.getStorageInfo();
        throw Exception('Nicht genügend Speicherplatz für Backup. $storageInfo');
      }

      // Use provided database or get instance (avoid deadlock during migration)
      final database = db ?? await DatabaseHelper.instance.database;
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final tempDir = await getTemporaryDirectory();
      final exportDir = Directory('${tempDir.path}/plantry_export_$timestamp');

      // Create export directory
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
      await exportDir.create(recursive: true);

      AppLogger.debug('BackupService', 'Export directory created', exportDir.path);

      // Export all tables to JSON
      final Map<String, dynamic> backup = {
        'version': _backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': AppVersion.version,
        'data': {},
      };

      // Export each table
      final tables = [
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
      ];

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
      final jsonFile = File('${exportDir.path}/data.json');
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backup),
      );

      AppLogger.info('BackupService', 'JSON data saved');

      // Copy all photos
      final photos = backup['data']['photos'] as List<dynamic>;
      int copiedCount = 0;
      int missingCount = 0;

      if (photos.isNotEmpty) {
        final photosDir = Directory('${exportDir.path}/photos');
        await photosDir.create();

        for (final photo in photos) {
          final filePath = photo['file_path'] as String;
          final sourceFile = File(filePath);

          if (await sourceFile.exists()) {
            final fileName = path.basename(filePath);
            final destFile = File('${photosDir.path}/$fileName');
            await sourceFile.copy(destFile.path);
            copiedCount++;
          } else {
            missingCount++;
            AppLogger.warning('BackupService', 'Photo missing', path.basename(filePath));
          }
        }
        AppLogger.info('BackupService', 'Copied photos', 'count=$copiedCount');
        if (missingCount > 0) {
          AppLogger.warning('BackupService', 'Missing photos', 'count=$missingCount');
        }
      }

      // Create ZIP file
      final appDir = await getApplicationDocumentsDirectory();
      final zipPath = '${appDir.path}/plantry_backup_$timestamp.zip';

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
    Directory? importDir;

    try {
      AppLogger.info('BackupService', 'Starting import from', zipFilePath);

      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        throw Exception('Backup file not found');
      }

      final tempDir = await getTemporaryDirectory();
      importDir = Directory('${tempDir.path}/plantry_import_${DateTime.now().millisecondsSinceEpoch}');

      // Extract ZIP
      AppLogger.info('BackupService', 'Extracting ZIP...');
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      await importDir.create(recursive: true);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final outFile = File('${importDir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      AppLogger.info('BackupService', 'ZIP extracted');

      // Find and read JSON file
      final jsonFile = File('${importDir.path}/data.json');
      if (!await jsonFile.exists()) {
        // Try to find in subdirectory
        final files = await importDir.list(recursive: true).toList();
        final dataJsonFile = files.firstWhere(
          (f) => f.path.endsWith('data.json'),
          orElse: () => throw Exception('data.json not found in backup'),
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
    final version = backup['version'] as int?;
    if (version == null || version > _backupVersion) {
      throw Exception('Incompatible backup version');
    }

    AppLogger.info('BackupService', 'Backup version', 'version=$version');
    AppLogger.info('BackupService', 'Export date', backup['exportDate']);

    final data = backup['data'] as Map<String, dynamic>;
    final db = await DatabaseHelper.instance.database;

    // Clear existing data
    AppLogger.info('BackupService', 'Clearing existing data...');
    await db.execute('PRAGMA foreign_keys = OFF');

    final tables = [
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
    await _importTable(db, 'rooms', data['rooms'] as List<dynamic>?);
    await _importTable(db, 'grows', data['grows'] as List<dynamic>?);
    await _importTable(db, 'rdwc_systems', data['rdwc_systems'] as List<dynamic>?);
    await _importTable(db, 'plants', data['plants'] as List<dynamic>?);
    await _importTable(db, 'fertilizers', data['fertilizers'] as List<dynamic>?);
    await _importTable(db, 'plant_logs', data['plant_logs'] as List<dynamic>?);
    await _importTable(db, 'log_fertilizers', data['log_fertilizers'] as List<dynamic>?);
    await _importTable(db, 'rdwc_logs', data['rdwc_logs'] as List<dynamic>?);
    await _importTable(db, 'rdwc_log_fertilizers', data['rdwc_log_fertilizers'] as List<dynamic>?);
    await _importTable(db, 'rdwc_recipes', data['rdwc_recipes'] as List<dynamic>?);
    await _importTable(db, 'rdwc_recipe_fertilizers', data['rdwc_recipe_fertilizers'] as List<dynamic>?);
    await _importTable(db, 'hardware', data['hardware'] as List<dynamic>?);
    await _importTable(db, 'log_templates', data['log_templates'] as List<dynamic>?);
    await _importTable(db, 'template_fertilizers', data['template_fertilizers'] as List<dynamic>?);
    await _importTable(db, 'harvests', data['harvests'] as List<dynamic>?);
    await _importTable(db, 'app_settings', data['app_settings'] as List<dynamic>?);

    // Import photos and restore image files
    await _importPhotos(db, data['photos'] as List<dynamic>?, importDir);

    await db.execute('PRAGMA foreign_keys = ON');

    AppLogger.info('BackupService', 'Data import complete');
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
    final photosDir = Directory('${appDir.path}/photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    int copiedCount = 0;

    for (final photo in photos) {
      final oldPath = photo['file_path'] as String;
      final fileName = path.basename(oldPath);

      // Find photo in import directory
      final importPhotoFile = File('${importDir.path}/photos/$fileName');

      if (await importPhotoFile.exists()) {
        // Copy to app photos directory
        final newPath = '${photosDir.path}/$fileName';
        await importPhotoFile.copy(newPath);

        // Insert photo record with new path
        await db.insert('photos', {
          'id': photo['id'],
          'log_id': photo['log_id'],
          'file_path': newPath,
          'created_at': photo['created_at'],
        });

        copiedCount++;
      } else {
        AppLogger.warning('BackupService', 'Photo not found', fileName);
      }
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
