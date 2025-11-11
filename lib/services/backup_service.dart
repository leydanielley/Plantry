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
  @override
  Future<String> exportData({Database? db}) async {
    // ✅ P1 FIX: Wrap entire export in timeout (5 minutes max)
    // ✅ AUDIT FIX: Magic numbers extracted to BackupConfig
    return await _exportDataInternal(db: db).timeout(
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
        throw Exception(
          'Nicht genügend Speicherplatz für Backup. $storageInfo',
        );
      }

      // Use provided database or get instance (avoid deadlock during migration)
      final database = db ?? await DatabaseHelper.instance.database;
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
        'data': {},
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

      // ✅ P1 FIX: Parallelize photo copying for better performance
      // ✅ FIX: Cast to avoid dynamic call error
      final photos =
          (backup['data'] as Map<String, dynamic>)['photos'] as List<dynamic>;
      int copiedCount = 0;
      int missingCount = 0;

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
          // ✅ HIGH PRIORITY FIX: Null-safe cast with validation
          final content = file.content;
          if (content == null) {
            AppLogger.warning('BackupService', 'Null content in archive entry', file.name);
            continue;
          }
          await outFile.writeAsBytes(content as List<int>);
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
}
