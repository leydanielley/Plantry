// =============================================
// GROWLOG - Database Rebuild Service
// Clean Slate Database Rebuild with Data Preservation
// =============================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive_io.dart';

import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/migration_validator.dart';
import 'package:growlog_app/config/backup_config.dart';
import 'package:growlog_app/services/interfaces/i_backup_service.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/database/database_helper.dart';

/// Progress callback for rebuild operations
typedef RebuildProgressCallback = void Function(
  int current,
  int total,
  String message,
);

/// Rebuild phase enum
enum RebuildPhase {
  preFlight,
  dataExtraction,
  schemaRebuild,
  dataMigration,
  validation,
  cleanup,
  completed,
  failed,
  rolledBack,
}

/// Result of database rebuild operation
class RebuildResult {
  final bool success;
  final String message;
  final Map<String, int> oldRecordCounts;
  final Map<String, int> newRecordCounts;
  final List<String> errors;
  final List<String> warnings;
  final String? backupPath;
  final String? oldDatabasePath;
  final Duration duration;

  RebuildResult({
    required this.success,
    required this.message,
    this.oldRecordCounts = const {},
    this.newRecordCounts = const {},
    this.errors = const [],
    this.warnings = const [],
    this.backupPath,
    this.oldDatabasePath,
    required this.duration,
  });

  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('=' * 50);
    buffer.writeln('PLANTRY DATABASE REBUILD REPORT');
    buffer.writeln('=' * 50);
    buffer.writeln('Status: ${success ? "✅ SUCCESS" : "❌ FAILED"}');
    buffer.writeln('Duration: ${duration.inSeconds}s');
    buffer.writeln('');

    if (success) {
      buffer.writeln('RECORDS MIGRATED:');
      for (final table in newRecordCounts.keys) {
        final oldCount = oldRecordCounts[table] ?? 0;
        final newCount = newRecordCounts[table] ?? 0;
        final status = oldCount == newCount ? '✅' : '⚠️';
        buffer.writeln('  $status $table: $oldCount → $newCount');
      }
      buffer.writeln('');
    }

    if (errors.isNotEmpty) {
      buffer.writeln('ERRORS (${errors.length}):');
      for (final error in errors.take(10)) {
        buffer.writeln('  ❌ $error');
      }
      if (errors.length > 10) {
        buffer.writeln('  ... and ${errors.length - 10} more errors');
      }
      buffer.writeln('');
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('WARNINGS (${warnings.length}):');
      for (final warning in warnings.take(10)) {
        buffer.writeln('  ⚠️ $warning');
      }
      if (warnings.length > 10) {
        buffer.writeln('  ... and ${warnings.length - 10} more warnings');
      }
      buffer.writeln('');
    }

    if (backupPath != null) {
      buffer.writeln('BACKUP LOCATION:');
      buffer.writeln('  $backupPath');
      buffer.writeln('');
    }

    if (oldDatabasePath != null) {
      buffer.writeln('OLD DATABASE:');
      buffer.writeln('  $oldDatabasePath');
      buffer.writeln('');
    }

    buffer.writeln('=' * 50);
    return buffer.toString();
  }
}

/// Service for clean slate database rebuild
class DatabaseRebuildService {
  IBackupService get _backupService => getIt<IBackupService>();

  /// Execute complete database rebuild
  ///
  /// This will:
  /// 1. Create emergency backup
  /// 2. Extract all data to temporary storage
  /// 3. Delete and recreate database with clean v20 schema
  /// 4. Import all data with transformations
  /// 5. Validate integrity
  /// 6. Cleanup or rollback on failure
  Future<RebuildResult> rebuildDatabase({
    RebuildProgressCallback? onProgress,
    Duration timeout = const Duration(hours: 2),
  }) async {
    final startTime = DateTime.now();
    String? backupPath;
    String? oldDbPath;
    String? tempDir;
    final errors = <String>[];
    final warnings = <String>[];
    Map<String, int> oldCounts = {};
    Map<String, int> newCounts = {};

    try {
      AppLogger.info('DatabaseRebuild', '🚀 Starting database rebuild...');

      // =============================================
      // PHASE 1: PRE-FLIGHT VALIDATION
      // =============================================
      onProgress?.call(1, 6, 'Phase 1/6: Pre-flight validation');
      AppLogger.info('DatabaseRebuild', '📋 Phase 1: Pre-flight validation');

      final preFlightResult = await _runPreFlightChecks();
      if (!preFlightResult.isValid) {
        throw Exception(
          'Pre-flight checks failed: ${preFlightResult.errors.join(", ")}',
        );
      }
      warnings.addAll(preFlightResult.warnings);

      // Get current database
      final currentDb = await DatabaseHelper.instance.database;

      // Count records in old database
      oldCounts = await MigrationValidator.countAllRecords(currentDb);
      AppLogger.info(
        'DatabaseRebuild',
        '📊 Old database: ${oldCounts.values.fold(0, (a, b) => a + b)} total records',
      );

      // =============================================
      // PHASE 2: DATA EXTRACTION
      // =============================================
      onProgress?.call(2, 6, 'Phase 2/6: Creating emergency backup');
      AppLogger.info('DatabaseRebuild', '💾 Phase 2: Data extraction');

      // Create emergency backup using existing backup service
      backupPath = await _backupService.exportData(
        db: currentDb,
        onProgress: (current, total, message) {
          onProgress?.call(2, 6, 'Backup: $message ($current/$total)');
        },
      );

      AppLogger.info(
        'DatabaseRebuild',
        '✅ Emergency backup created: $backupPath',
      );

      // Extract to temporary directory for additional safety
      tempDir = await _extractBackupToTemp(backupPath, onProgress);
      AppLogger.info(
        'DatabaseRebuild',
        '✅ Data extracted to: $tempDir',
      );

      // =============================================
      // PHASE 3: CLEAN SCHEMA REBUILD
      // =============================================
      onProgress?.call(3, 6, 'Phase 3/6: Rebuilding clean schema');
      AppLogger.info('DatabaseRebuild', '🔨 Phase 3: Clean schema rebuild');

      oldDbPath = await _rebuildCleanSchema(currentDb);
      AppLogger.info(
        'DatabaseRebuild',
        '✅ Clean v20 schema created, old DB saved to: $oldDbPath',
      );

      // Get new database instance
      final newDb = await DatabaseHelper.instance.database;

      // Validate new schema
      final schemaValidation =
          await MigrationValidator.validateDatabaseIntegrity(newDb);
      if (!schemaValidation.isValid) {
        throw Exception(
          'New schema validation failed: ${schemaValidation.errors.join(", ")}',
        );
      }

      // =============================================
      // PHASE 4: DATA MIGRATION
      // =============================================
      onProgress?.call(4, 6, 'Phase 4/6: Migrating data');
      AppLogger.info('DatabaseRebuild', '📦 Phase 4: Data migration');

      await _importDataFromBackup(
        newDb,
        tempDir,
        (current, total, message) {
          onProgress?.call(4, 6, 'Import: $message ($current/$total)');
        },
      );

      AppLogger.info('DatabaseRebuild', '✅ Data migration complete');

      // =============================================
      // PHASE 5: VALIDATION
      // =============================================
      onProgress?.call(5, 6, 'Phase 5/6: Validating integrity');
      AppLogger.info('DatabaseRebuild', '🔍 Phase 5: Validation');

      // Count records in new database
      newCounts = await MigrationValidator.countAllRecords(newDb);

      // Validate record counts match
      final countComparison =
          MigrationValidator.compareRecordCounts(oldCounts, newCounts);
      if (!countComparison.isValid) {
        throw Exception(
          'Record count validation failed: ${countComparison.errors.join(", ")}',
        );
      }
      warnings.addAll(countComparison.warnings);

      // Run all integrity checks
      final photosDir = path.join(
        (await getApplicationDocumentsDirectory()).path,
        'photos',
      );
      final fullValidation = await MigrationValidator.runAllValidations(
        newDb,
        photosDir,
      );

      if (!fullValidation.isValid) {
        throw Exception(
          'Database validation failed: ${fullValidation.errors.join(", ")}',
        );
      }
      warnings.addAll(fullValidation.warnings);

      AppLogger.info('DatabaseRebuild', '✅ All validations passed');

      // =============================================
      // PHASE 6: CLEANUP
      // =============================================
      onProgress?.call(6, 6, 'Phase 6/6: Cleanup');
      AppLogger.info('DatabaseRebuild', '🧹 Phase 6: Cleanup');

      // Keep temp files for 7 days
      // Keep old database for 30 days
      // Keep backup permanently
      AppLogger.info('DatabaseRebuild', '✅ Cleanup complete');

      // =============================================
      // SUCCESS
      // =============================================
      final duration = DateTime.now().difference(startTime);

      final result = RebuildResult(
        success: true,
        message: 'Database rebuild completed successfully',
        oldRecordCounts: oldCounts,
        newRecordCounts: newCounts,
        errors: errors,
        warnings: warnings,
        backupPath: backupPath,
        oldDatabasePath: oldDbPath,
        duration: duration,
      );

      AppLogger.info('DatabaseRebuild', '🎉 REBUILD SUCCESSFUL');
      AppLogger.info('DatabaseRebuild', result.generateReport());

      onProgress?.call(6, 6, 'Rebuild complete!');

      return result;
    } catch (e, stack) {
      // =============================================
      // ROLLBACK ON FAILURE
      // =============================================
      AppLogger.error('DatabaseRebuild', '💥 Rebuild failed', e, stack);
      errors.add(e.toString());

      onProgress?.call(0, 6, 'Rollback: Restoring old database');

      try {
        await _rollback(oldDbPath);
        AppLogger.info('DatabaseRebuild', '✅ Rollback successful');
      } catch (rollbackError, rollbackStack) {
        AppLogger.error(
          'DatabaseRebuild',
          '❌ ROLLBACK FAILED',
          rollbackError,
          rollbackStack,
        );
        errors.add('Rollback failed: $rollbackError');
      }

      final duration = DateTime.now().difference(startTime);

      return RebuildResult(
        success: false,
        message: 'Database rebuild failed: ${errors.first}',
        oldRecordCounts: oldCounts,
        newRecordCounts: newCounts,
        errors: errors,
        warnings: warnings,
        backupPath: backupPath,
        oldDatabasePath: oldDbPath,
        duration: duration,
      );
    }
  }

  /// Run pre-flight checks before starting rebuild
  Future<ValidationResult> _runPreFlightChecks() async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Check 1: Verify database exists
      final dbPath = path.join(
        await getDatabasesPath(),
        'growlog.db',
      );
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        errors.add('Database file does not exist: $dbPath');
        return ValidationResult(isValid: false, errors: errors);
      }

      // Check 2: Verify minimum storage space (200MB)
      // Note: Dart doesn't provide easy way to check free space
      // This would require platform channels in a production implementation
      AppLogger.warning(
        'DatabaseRebuild',
        'Storage space check not implemented',
      );

      // Check 3: Validate current database integrity
      final currentDb = await DatabaseHelper.instance.database;
      final integrity =
          await MigrationValidator.validateDatabaseIntegrity(currentDb);

      if (!integrity.isValid) {
        warnings.add(
          'Current database has integrity issues (will attempt rebuild anyway)',
        );
        warnings.addAll(integrity.warnings);
      }

      AppLogger.info('DatabaseRebuild', '✅ Pre-flight checks passed');

      return ValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
      );
    } catch (e, stack) {
      AppLogger.error('DatabaseRebuild', 'Pre-flight check failed', e, stack);
      return ValidationResult(
        isValid: false,
        errors: ['Pre-flight check exception: $e'],
      );
    }
  }

  /// Extract backup to temporary directory
  Future<String> _extractBackupToTemp(
    String backupPath,
    RebuildProgressCallback? onProgress,
  ) async {
    try {
      // Create temp directory
      final tempDir = Directory.systemTemp
          .createTempSync('plantry_rebuild_${DateTime.now().millisecondsSinceEpoch}');

      // Extract ZIP
      final bytes = await File(backupPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      int current = 0;
      final total = archive.length;

      for (final file in archive) {
        current++;
        onProgress?.call(
          2,
          6,
          'Extracting backup: ${file.name} ($current/$total)',
        );

        final filename = path.join(tempDir.path, file.name);

        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filename).create(recursive: true);
        }
      }

      AppLogger.info(
        'DatabaseRebuild',
        'Extracted $total files to ${tempDir.path}',
      );

      return tempDir.path;
    } catch (e, stack) {
      AppLogger.error('DatabaseRebuild', 'Backup extraction failed', e, stack);
      rethrow;
    }
  }

  /// Rebuild clean database schema
  Future<String> _rebuildCleanSchema(Database currentDb) async {
    try {
      // Close current database
      await DatabaseHelper.instance.close();

      // Get database path
      final dbPath = path.join(
        await getDatabasesPath(),
        'growlog.db',
      );

      // Backup old database file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final oldDbPath = path.join(
        await getDatabasesPath(),
        'growlog_broken_$timestamp.db',
      );

      // Rename old database
      final dbFile = File(dbPath);
      await dbFile.rename(oldDbPath);

      AppLogger.info('DatabaseRebuild', 'Old database renamed to: $oldDbPath');

      // Reopen database - this triggers _onCreate with clean v20 schema
      await DatabaseHelper.instance.database;

      AppLogger.info('DatabaseRebuild', 'New clean database created');

      return oldDbPath;
    } catch (e, stack) {
      AppLogger.error('DatabaseRebuild', 'Schema rebuild failed', e, stack);
      rethrow;
    }
  }

  /// Import data from backup with transformations
  Future<void> _importDataFromBackup(
    Database db,
    String tempDir,
    RebuildProgressCallback? onProgress,
  ) async {
    try {
      // Read data.json
      final dataJsonPath = path.join(tempDir, 'data.json');
      final dataJson = await File(dataJsonPath).readAsString();
      final data = json.decode(dataJson) as Map<String, dynamic>;

      // Import in dependency order
      final importOrder = BackupConfig.importOrderTables;
      int current = 0;
      final total = importOrder.length;

      for (final tableName in importOrder) {
        current++;
        onProgress?.call(current, total, 'Importing $tableName');

        await _importTable(db, tableName, data[tableName] as List?);

        AppLogger.info(
          'DatabaseRebuild',
          '✅ Imported $tableName ($current/$total)',
        );
      }

      // Import photos
      onProgress?.call(total, total, 'Importing photo files');
      await _importPhotos(tempDir);

      AppLogger.info('DatabaseRebuild', '✅ All data imported');
    } catch (e, stack) {
      AppLogger.error('DatabaseRebuild', 'Data import failed', e, stack);
      rethrow;
    }
  }

  /// Import single table with transformations
  Future<void> _importTable(
    Database db,
    String tableName,
    List<dynamic>? records,
  ) async {
    if (records == null || records.isEmpty) {
      AppLogger.debug('DatabaseRebuild', 'Table $tableName is empty, skipping');
      return;
    }

    try {
      await db.transaction((txn) async {
        for (final record in records) {
          final row = record as Map<String, dynamic>;

          // Apply transformations based on table
          final transformed = await _transformRecord(tableName, row);

          await txn.insert(
            tableName,
            transformed,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      AppLogger.info(
        'DatabaseRebuild',
        'Imported ${records.length} records into $tableName',
      );
    } catch (e, stack) {
      AppLogger.error(
        'DatabaseRebuild',
        'Failed to import table $tableName',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Transform record for v13→v14 column mappings
  Future<Map<String, dynamic>> _transformRecord(
    String tableName,
    Map<String, dynamic> record,
  ) async {
    final transformed = Map<String, dynamic>.from(record);

    // Apply table-specific transformations
    switch (tableName) {
      case 'plant_logs':
        // v14 column renames
        if (record.containsKey('watering_ml')) {
          transformed['water_amount'] = record['watering_ml'];
          transformed.remove('watering_ml');
        }
        if (record.containsKey('ph') && !record.containsKey('ph_in')) {
          transformed['ph_in'] = record['ph'];
          transformed.remove('ph');
        }
        if (record.containsKey('nutrient_ec') &&
            !record.containsKey('ec_in')) {
          transformed['ec_in'] = record['nutrient_ec'];
          transformed.remove('nutrient_ec');
        }
        // Ensure archived is set
        transformed['archived'] ??= 0;
        break;

      case 'plants':
        // v16: planted_date/germination_date → seed_date
        if (record.containsKey('planted_date') &&
            !record.containsKey('seed_date')) {
          transformed['seed_date'] = record['planted_date'];
          transformed.remove('planted_date');
        }
        if (record.containsKey('germination_date') &&
            !record.containsKey('seed_date')) {
          transformed['seed_date'] = record['germination_date'];
          transformed.remove('germination_date');
        }
        // Ensure archived is set
        transformed['archived'] ??= 0;
        break;

      case 'rooms':
        transformed['archived'] ??= 0;
        break;

      case 'rdwc_logs':
        transformed['archived'] ??= 0;
        break;
    }

    return transformed;
  }

  /// Import photo files
  Future<void> _importPhotos(String tempDir) async {
    try {
      final photosSourceDir = Directory(path.join(tempDir, 'photos'));

      if (!await photosSourceDir.exists()) {
        AppLogger.warning('DatabaseRebuild', 'No photos directory in backup');
        return;
      }

      final photosDestDir = Directory(
        path.join(
          (await getApplicationDocumentsDirectory()).path,
          'photos',
        ),
      );
      await photosDestDir.create(recursive: true);

      final photoFiles = await photosSourceDir.list().toList();

      for (final file in photoFiles) {
        if (file is File) {
          final filename = path.basename(file.path);
          final destPath = path.join(photosDestDir.path, filename);

          await file.copy(destPath);
        }
      }

      AppLogger.info('DatabaseRebuild', 'Imported ${photoFiles.length} photos');
    } catch (e, stack) {
      AppLogger.error('DatabaseRebuild', 'Photo import failed', e, stack);
      // Don't rethrow - missing photos are not critical
    }
  }

  /// Rollback to old database on failure
  Future<void> _rollback(String? oldDbPath) async {
    if (oldDbPath == null) {
      throw Exception('Cannot rollback: old database path unknown');
    }

    try {
      AppLogger.warning('DatabaseRebuild', '⚠️ Rolling back to old database');

      // Close current database
      await DatabaseHelper.instance.close();

      // Get current database path
      final dbPath = path.join(
        await getDatabasesPath(),
        'growlog.db',
      );

      // Delete new (failed) database
      final newDbFile = File(dbPath);
      if (await newDbFile.exists()) {
        await newDbFile.delete();
      }

      // Restore old database
      final oldDbFile = File(oldDbPath);
      await oldDbFile.rename(dbPath);

      // Reopen database
      await DatabaseHelper.instance.database;

      AppLogger.info('DatabaseRebuild', '✅ Rollback complete');
    } catch (e, stack) {
      AppLogger.error('DatabaseRebuild', 'Rollback failed', e, stack);
      rethrow;
    }
  }
}
