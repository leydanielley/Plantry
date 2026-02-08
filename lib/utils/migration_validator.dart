// =============================================
// GROWLOG - Migration Validator
// =============================================

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/config/backup_config.dart';

/// Validation results for database migration
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, int> recordCounts;

  ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.recordCounts = const {},
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Validates database integrity and data consistency during migrations
class MigrationValidator {
  /// Validate database integrity using SQLite PRAGMA checks
  static Future<ValidationResult> validateDatabaseIntegrity(
    Database db,
  ) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Check 1: Database integrity
      AppLogger.info('MigrationValidator', 'Running PRAGMA integrity_check...');
      final integrityCheck = await db.rawQuery('PRAGMA integrity_check');
      final integrityResult = integrityCheck.first['integrity_check'];

      if (integrityResult != 'ok') {
        errors.add('Database integrity check failed: $integrityResult');
        AppLogger.error(
          'MigrationValidator',
          '❌ PRAGMA integrity_check failed',
          integrityResult,
        );
      } else {
        AppLogger.info('MigrationValidator', '✅ Database integrity: OK');
      }

      // Check 2: Foreign key violations
      AppLogger.info(
        'MigrationValidator',
        'Running PRAGMA foreign_key_check...',
      );
      final fkCheck = await db.rawQuery('PRAGMA foreign_key_check');

      if (fkCheck.isNotEmpty) {
        errors.add('Foreign key violations detected: ${fkCheck.length}');
        for (final violation in fkCheck.take(10)) {
          errors.add('  FK violation: $violation');
          AppLogger.error(
            'MigrationValidator',
            '❌ FK violation',
            violation,
          );
        }
      } else {
        AppLogger.info('MigrationValidator', '✅ Foreign key integrity: OK');
      }

      return ValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
      );
    } catch (e, stack) {
      AppLogger.error(
        'MigrationValidator',
        'Integrity validation failed',
        e,
        stack,
      );
      return ValidationResult(
        isValid: false,
        errors: ['Integrity validation exception: $e'],
      );
    }
  }

  /// Count records in all user data tables
  static Future<Map<String, int>> countAllRecords(Database db) async {
    final counts = <String, int>{};

    for (final table in BackupConfig.exportTables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        counts[table] = Sqflite.firstIntValue(result) ?? 0;
      } catch (e) {
        AppLogger.warning(
          'MigrationValidator',
          'Failed to count table $table',
          e,
        );
        counts[table] = -1; // Indicates error
      }
    }

    return counts;
  }

  /// Compare record counts between two databases
  static ValidationResult compareRecordCounts(
    Map<String, int> oldCounts,
    Map<String, int> newCounts,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    for (final table in oldCounts.keys) {
      final oldCount = oldCounts[table] ?? 0;
      final newCount = newCounts[table] ?? 0;

      if (oldCount == -1 || newCount == -1) {
        warnings.add('Table $table: Count check failed');
        continue;
      }

      if (oldCount != newCount) {
        final diff = (oldCount - newCount).abs();
        final percentDiff = oldCount > 0 ? (diff / oldCount * 100) : 0;

        if (percentDiff > 0.1) {
          // More than 0.1% difference is an error
          errors.add(
            'Table $table: Record count mismatch (old=$oldCount, new=$newCount, diff=$diff)',
          );
        } else {
          warnings.add(
            'Table $table: Minor count difference (old=$oldCount, new=$newCount)',
          );
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      recordCounts: newCounts,
    );
  }

  /// Detect orphaned records (records with invalid FK references)
  static Future<ValidationResult> detectOrphanedRecords(Database db) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Check 1: Photos without logs
      AppLogger.info(
        'MigrationValidator',
        'Checking for orphaned photos...',
      );
      final orphanedPhotos = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM photos
        WHERE log_id NOT IN (SELECT id FROM plant_logs)
      ''');
      final photoCount = Sqflite.firstIntValue(orphanedPhotos) ?? 0;
      if (photoCount > 0) {
        warnings.add('Found $photoCount orphaned photos (invalid log_id)');
      }

      // Check 2: Log fertilizers without logs
      AppLogger.info(
        'MigrationValidator',
        'Checking for orphaned log_fertilizers...',
      );
      final orphanedLogFerts = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM log_fertilizers
        WHERE log_id NOT IN (SELECT id FROM plant_logs)
      ''');
      final logFertCount = Sqflite.firstIntValue(orphanedLogFerts) ?? 0;
      if (logFertCount > 0) {
        warnings.add(
          'Found $logFertCount orphaned log_fertilizers (invalid log_id)',
        );
      }

      // Check 3: Plant logs without plants
      AppLogger.info(
        'MigrationValidator',
        'Checking for orphaned plant_logs...',
      );
      final orphanedLogs = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM plant_logs
        WHERE plant_id NOT IN (SELECT id FROM plants)
      ''');
      final logCount = Sqflite.firstIntValue(orphanedLogs) ?? 0;
      if (logCount > 0) {
        warnings.add(
          'Found $logCount orphaned plant_logs (invalid plant_id)',
        );
      }

      // Check 4: Harvests without plants
      AppLogger.info(
        'MigrationValidator',
        'Checking for orphaned harvests...',
      );
      final orphanedHarvests = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM harvests
        WHERE plant_id NOT IN (SELECT id FROM plants)
      ''');
      final harvestCount = Sqflite.firstIntValue(orphanedHarvests) ?? 0;
      if (harvestCount > 0) {
        warnings.add(
          'Found $harvestCount orphaned harvests (invalid plant_id)',
        );
      }

      // Check 5: Plants with invalid FK references
      AppLogger.info(
        'MigrationValidator',
        'Checking for plants with invalid references...',
      );

      final plantsInvalidRoom = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM plants
        WHERE room_id IS NOT NULL
          AND room_id NOT IN (SELECT id FROM rooms)
      ''');
      final invalidRoomCount = Sqflite.firstIntValue(plantsInvalidRoom) ?? 0;
      if (invalidRoomCount > 0) {
        warnings.add(
          'Found $invalidRoomCount plants with invalid room_id',
        );
      }

      final plantsInvalidGrow = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM plants
        WHERE grow_id IS NOT NULL
          AND grow_id NOT IN (SELECT id FROM grows)
      ''');
      final invalidGrowCount = Sqflite.firstIntValue(plantsInvalidGrow) ?? 0;
      if (invalidGrowCount > 0) {
        warnings.add(
          'Found $invalidGrowCount plants with invalid grow_id',
        );
      }

      AppLogger.info(
        'MigrationValidator',
        'Orphan check complete: ${warnings.length} issues found',
      );

      return ValidationResult(
        isValid: true, // Orphans are warnings, not errors
        errors: errors,
        warnings: warnings,
      );
    } catch (e, stack) {
      AppLogger.error(
        'MigrationValidator',
        'Orphan detection failed',
        e,
        stack,
      );
      return ValidationResult(
        isValid: false,
        errors: ['Orphan detection exception: $e'],
      );
    }
  }

  /// Validate photo files exist on disk
  static Future<ValidationResult> validatePhotoFiles(
    Database db,
    String photosDirectory,
  ) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Get all photo records
      final photos = await db.query('photos', columns: ['id', 'file_path']);

      final int totalPhotos = photos.length;
      int foundPhotos = 0;
      int missingPhotos = 0;

      AppLogger.info(
        'MigrationValidator',
        'Validating $totalPhotos photo files...',
      );

      for (final photo in photos) {
        final filePath = photo['file_path'] as String?;
        if (filePath == null || filePath.isEmpty) {
          warnings.add('Photo ${photo['id']}: Empty file path');
          missingPhotos++;
          continue;
        }

        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize == 0) {
            warnings.add('Photo ${photo['id']}: File is empty (0 bytes)');
            missingPhotos++;
          } else {
            foundPhotos++;
          }
        } else {
          warnings.add('Photo ${photo['id']}: File not found at $filePath');
          missingPhotos++;
        }
      }

      AppLogger.info(
        'MigrationValidator',
        'Photo validation: $foundPhotos found, $missingPhotos missing',
      );

      if (missingPhotos > 0) {
        warnings.add(
          'Photo file check: $foundPhotos/$totalPhotos files found',
        );
      }

      return ValidationResult(
        isValid: true, // Missing photos are warnings, not errors
        errors: errors,
        warnings: warnings,
      );
    } catch (e, stack) {
      AppLogger.error(
        'MigrationValidator',
        'Photo validation failed',
        e,
        stack,
      );
      return ValidationResult(
        isValid: false,
        errors: ['Photo validation exception: $e'],
      );
    }
  }

  /// Validate plant phase history dates are consistent
  static Future<ValidationResult> validatePhaseHistory(Database db) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      AppLogger.info(
        'MigrationValidator',
        'Validating plant phase history...',
      );

      // Check plants in BLOOM phase have bloom_date
      final plantsInBloom = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM plants
        WHERE phase = 'BLOOM' AND bloom_date IS NULL
      ''');
      final bloomMissing = Sqflite.firstIntValue(plantsInBloom) ?? 0;
      if (bloomMissing > 0) {
        warnings.add(
          '$bloomMissing plants in BLOOM phase missing bloom_date',
        );
      }

      // Check plants in HARVEST phase have harvest_date
      final plantsInHarvest = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM plants
        WHERE phase = 'HARVEST' AND harvest_date IS NULL
      ''');
      final harvestMissing = Sqflite.firstIntValue(plantsInHarvest) ?? 0;
      if (harvestMissing > 0) {
        warnings.add(
          '$harvestMissing plants in HARVEST phase missing harvest_date',
        );
      }

      // Check illogical date sequences (bloom before veg)
      final illogicalDates = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM plants
        WHERE veg_date IS NOT NULL
          AND bloom_date IS NOT NULL
          AND bloom_date < veg_date
      ''');
      final illogicalCount = Sqflite.firstIntValue(illogicalDates) ?? 0;
      if (illogicalCount > 0) {
        warnings.add(
          '$illogicalCount plants have bloom_date before veg_date (illogical)',
        );
      }

      AppLogger.info(
        'MigrationValidator',
        'Phase history validation: ${warnings.length} issues found',
      );

      return ValidationResult(
        isValid: true,
        errors: errors,
        warnings: warnings,
      );
    } catch (e, stack) {
      AppLogger.error(
        'MigrationValidator',
        'Phase history validation failed',
        e,
        stack,
      );
      return ValidationResult(
        isValid: false,
        errors: ['Phase history validation exception: $e'],
      );
    }
  }

  /// Run all validation checks and combine results
  static Future<ValidationResult> runAllValidations(
    Database db,
    String photosDirectory,
  ) async {
    final allErrors = <String>[];
    final allWarnings = <String>[];
    final allCounts = <String, int>{};

    AppLogger.info('MigrationValidator', '🔍 Running all validation checks...');

    // 1. Database integrity
    final integrityResult = await validateDatabaseIntegrity(db);
    allErrors.addAll(integrityResult.errors);
    allWarnings.addAll(integrityResult.warnings);

    // 2. Orphaned records
    final orphanResult = await detectOrphanedRecords(db);
    allErrors.addAll(orphanResult.errors);
    allWarnings.addAll(orphanResult.warnings);

    // 3. Photo files
    final photoResult = await validatePhotoFiles(db, photosDirectory);
    allErrors.addAll(photoResult.errors);
    allWarnings.addAll(photoResult.warnings);

    // 4. Phase history
    final phaseResult = await validatePhaseHistory(db);
    allErrors.addAll(phaseResult.errors);
    allWarnings.addAll(phaseResult.warnings);

    // 5. Record counts
    final counts = await countAllRecords(db);
    allCounts.addAll(counts);

    AppLogger.info(
      'MigrationValidator',
      '✅ Validation complete: ${allErrors.length} errors, ${allWarnings.length} warnings',
    );

    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: allWarnings,
      recordCounts: allCounts,
    );
  }
}
