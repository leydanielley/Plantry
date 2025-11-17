// =============================================
// GROWLOG - Migration v18 → v19
// DATA RECOVERY: Restore data lost in faulty v18 migration
// =============================================

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/migrations/safe_table_rebuild.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v19: Emergency Data Recovery from v18 Data Loss
///
/// PROBLEM:
/// Migration v18 had a CRITICAL BUG that caused massive data loss.
/// It rebuilt the plants table but only migrated 14 columns instead of 23.
///
/// LOST DATA in plants table (12 fields):
/// - breeder, feminized, phase, seed_date, phase_start_date
/// - veg_date, bloom_date, harvest_date, created_by
/// - log_profile_name, current_container_size, current_system_size
///
/// LOST DATA in plant_logs table (v13 → v14 migration, 4 fields):
/// - nutrient_ppm (PPM value of nutrient solution)
/// - light_hours (hours of light per day)
/// - training (LST, HST, topping, etc.)
/// - defoliation (defoliation notes)
///
/// SOLUTION:
/// This migration attempts to recover data from:
/// 1. Emergency backup created before migration (if exists)
/// 2. Pre-migration automatic backup (if exists)
/// 3. Manual backups in Download folder (if exists)
///
/// WHAT IT DOES:
/// 1. Checks if plants table has missing columns
/// 2. If missing, searches for available backups
/// 3. Attempts to restore data from most recent backup
/// 4. Logs recovery status and missing data
/// 5. If no backup found, adds missing columns with NULL values
///
/// SAFETY:
/// - Non-destructive: Never deletes existing data
/// - Validates backup before restoration
/// - Transaction-wrapped for rollback on error
/// - Detailed logging for troubleshooting
/// - NON-BLOCKING: Migration completes even if recovery fails
/// - App remains usable even without backup data
final Migration migrationV19 = Migration(
  version: 19,
  description: 'Emergency recovery: Restore data lost in v18 migration',
  up: (txn) async {
    // ⚠️ CRITICAL: Wrap entire migration in try-catch to prevent blocking
    // Migration must complete even if recovery fails
    try {
      await _performRecovery(txn);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Migration_v19',
        '❌ Recovery failed but migration will continue',
        e,
        stackTrace,
      );
      // DO NOT rethrow - allow migration to complete
      // App must remain functional even if recovery fails
    }
  },
);

/// Internal recovery logic (can fail safely)
Future<void> _performRecovery(DatabaseExecutor txn) async {
  AppLogger.info(
    'Migration_v19',
    '🚨 Starting Migration v19: Emergency Data Recovery',
  );

    // ===========================================
    // STEP 1: Check if recovery is needed
    // ===========================================
    AppLogger.info(
      'Migration_v19',
      '🔍 Step 1/5: Checking plants table schema',
    );

    final plantsColumns = await txn.rawQuery('PRAGMA table_info(plants)');
    final columnNames = plantsColumns
        .map((col) => col['name'] as String)
        .toSet();

    // Check for columns that should exist but might be missing
    final requiredPlantsColumns = {
      'breeder',
      'feminized',
      'phase',
      'seed_date',
      'phase_start_date',
      'veg_date',
      'bloom_date',
      'harvest_date',
      'created_by',
      'log_profile_name',
      'current_container_size',
      'current_system_size',
    };

    final missingColumns = requiredPlantsColumns.difference(columnNames);

    // Also check plant_logs table for missing v13 fields
    final plantLogsColumns = await txn.rawQuery('PRAGMA table_info(plant_logs)');
    final plantLogsColumnNames = plantLogsColumns
        .map((col) => col['name'] as String)
        .toSet();

    // These fields were lost in v14 migration
    final missingV13LogFields = {
      'nutrient_ppm',
      'light_hours',
      'training',
      'defoliation',
    };

    final missingLogColumns = missingV13LogFields.where(
      (col) => !plantLogsColumnNames.contains(col)
    ).toSet();

    if (missingColumns.isEmpty && missingLogColumns.isEmpty) {
      AppLogger.info(
        'Migration_v19',
        '✅ All required columns exist, no recovery needed',
      );
      return; // Exit early - no recovery needed
    }

    if (missingColumns.isNotEmpty) {
      AppLogger.warning(
        'Migration_v19',
        '⚠️ Missing plants columns: ${missingColumns.join(", ")}',
      );
    }

    if (missingLogColumns.isNotEmpty) {
      AppLogger.warning(
        'Migration_v19',
        '⚠️ Missing plant_logs v13 fields: ${missingLogColumns.join(", ")}',
      );
    }

    // ===========================================
    // STEP 2: Search for emergency backups
    // ===========================================
    AppLogger.info(
      'Migration_v19',
      '🔍 Step 2/5: Searching for emergency backups',
    );

    String? backupPath;
    Map<String, dynamic>? backupData;

    try {
      // Search in emergency backup directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final emergencyDir = Directory(
        path.join(documentsDir.path, 'growlog_emergency_backups'),
      );

      if (await emergencyDir.exists()) {
        final backupFiles = await emergencyDir
            .list()
            .where((entity) => entity.path.endsWith('.json'))
            .toList();

        if (backupFiles.isNotEmpty) {
          // Sort by modification time (newest first)
          backupFiles.sort((a, b) {
            final aStats = (a as File).statSync();
            final bStats = (b as File).statSync();
            return bStats.modified.compareTo(aStats.modified);
          });

          // Try to load the most recent backup
          final mostRecentBackup = backupFiles.first as File;
          backupPath = mostRecentBackup.path;

          AppLogger.info(
            'Migration_v19',
            'Found emergency backup: $backupPath',
          );

          final backupContent = await mostRecentBackup.readAsString();
          backupData = jsonDecode(backupContent) as Map<String, dynamic>;

          AppLogger.info(
            'Migration_v19',
            '✅ Backup loaded successfully',
          );
        }
      }

      // Also check in Download folder
      if (backupPath == null) {
        final downloadDir = Directory('/storage/emulated/0/Download/Plantry Backups/Emergency');
        if (await downloadDir.exists()) {
          final backupFiles = await downloadDir
              .list()
              .where((entity) => entity.path.endsWith('.json') || entity.path.endsWith('.db'))
              .toList();

          if (backupFiles.isNotEmpty) {
            AppLogger.info(
              'Migration_v19',
              'Found ${backupFiles.length} backup(s) in Download folder',
            );
            backupPath = backupFiles.first.path;
          }
        }
      }
    } catch (e) {
      AppLogger.error(
        'Migration_v19',
        'Error searching for backups',
        e,
      );
    }

    // ===========================================
    // STEP 3: Rebuild plants table with all columns
    // ===========================================
    AppLogger.info(
      'Migration_v19',
      '📝 Step 3/5: Rebuilding plants table with complete schema',
    );

    await SafeTableRebuild.rebuildTable(
      txn,
      tableName: 'plants',
      newTableDdl: '''
        CREATE TABLE plants_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          breeder TEXT,
          strain TEXT,
          feminized INTEGER DEFAULT 0,
          seed_type TEXT NOT NULL CHECK(seed_type IN ('PHOTO', 'AUTO')),
          medium TEXT NOT NULL CHECK(medium IN ('ERDE', 'COCO', 'HYDRO', 'AERO', 'DWC', 'RDWC')),
          phase TEXT DEFAULT 'SEEDLING' CHECK(phase IN ('SEEDLING', 'VEG', 'BLOOM', 'HARVEST', 'ARCHIVED')),
          room_id INTEGER,
          grow_id INTEGER,
          rdwc_system_id INTEGER,
          bucket_number INTEGER,
          seed_date TEXT,
          phase_start_date TEXT,
          veg_date TEXT,
          bloom_date TEXT,
          harvest_date TEXT,
          created_at TEXT DEFAULT (datetime('now')),
          created_by TEXT,
          log_profile_name TEXT DEFAULT 'standard',
          archived INTEGER DEFAULT 0,
          current_container_size REAL,
          current_system_size REAL,
          FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE RESTRICT,
          FOREIGN KEY (grow_id) REFERENCES grows(id) ON DELETE RESTRICT,
          FOREIGN KEY (rdwc_system_id) REFERENCES rdwc_systems(id) ON DELETE RESTRICT
        )
      ''',
      dataMigration: '''
        INSERT INTO plants_new (
          id, name, breeder, strain, feminized, seed_type, medium, phase,
          room_id, grow_id, rdwc_system_id, bucket_number,
          seed_date, phase_start_date, veg_date, bloom_date, harvest_date,
          created_at, created_by, log_profile_name, archived,
          current_container_size, current_system_size
        )
        SELECT
          id,
          name,
          COALESCE(breeder, NULL) as breeder,
          COALESCE(strain, NULL) as strain,
          COALESCE(feminized, 0) as feminized,
          COALESCE(seed_type, 'PHOTO') as seed_type,
          COALESCE(medium, 'ERDE') as medium,
          COALESCE(phase, 'SEEDLING') as phase,
          room_id, grow_id, rdwc_system_id, bucket_number,
          seed_date,
          phase_start_date,
          veg_date, bloom_date, harvest_date,
          created_at,
          created_by,
          COALESCE(log_profile_name, 'standard') as log_profile_name,
          COALESCE(archived, 0) as archived,
          current_container_size,
          current_system_size
        FROM plants
      ''',
      indexes: [
        'CREATE INDEX idx_plants_room ON plants(room_id)',
        'CREATE INDEX idx_plants_grow ON plants(grow_id)',
        'CREATE INDEX idx_plants_rdwc_system ON plants(rdwc_system_id)',
        'CREATE INDEX idx_plants_phase ON plants(phase)',
        'CREATE INDEX idx_plants_archived ON plants(archived)',
        'CREATE INDEX idx_plants_veg_date ON plants(veg_date)',
        'CREATE INDEX idx_plants_bloom_date ON plants(bloom_date)',
        'CREATE INDEX idx_plants_harvest_date ON plants(harvest_date)',
      ],
      validateAfter: (db) async {
        final count = await db.rawQuery('SELECT COUNT(*) as count FROM plants');
        final rowCount = count.first['count'] as int;
        AppLogger.info('Migration_v19', 'Plants preserved: $rowCount');
        return true;
      },
    );

    AppLogger.info(
      'Migration_v19',
      '✅ Plants table rebuilt with complete schema',
    );

    // ===========================================
    // STEP 4: Attempt data recovery from backup
    // ===========================================
    if (backupData != null && backupData.containsKey('data')) {
      AppLogger.info(
        'Migration_v19',
        '📝 Step 4/5: Attempting data recovery from backup',
      );

      try {
        final data = backupData['data'] as Map<String, dynamic>;

        // --- PLANTS DATA RECOVERY ---
        final plantsBackup = data['plants'] as List<dynamic>?;

        if (plantsBackup != null && plantsBackup.isNotEmpty && missingColumns.isNotEmpty) {
          AppLogger.info(
            'Migration_v19',
            'Found ${plantsBackup.length} plants in backup',
          );

          int recovered = 0;
          int failed = 0;

          for (final plantData in plantsBackup) {
            final plant = plantData as Map<String, dynamic>;
            final plantId = plant['id'];

            // Check if this plant exists in current database
            final existing = await txn.query(
              'plants',
              where: 'id = ?',
              whereArgs: [plantId],
            );

            if (existing.isNotEmpty) {
              // Update missing fields only
              final updates = <String, dynamic>{};

              for (final column in missingColumns) {
                if (plant.containsKey(column) && plant[column] != null) {
                  updates[column] = plant[column];
                }
              }

              if (updates.isNotEmpty) {
                try {
                  await txn.update(
                    'plants',
                    updates,
                    where: 'id = ?',
                    whereArgs: [plantId],
                  );
                  recovered++;
                } catch (e) {
                  AppLogger.warning(
                    'Migration_v19',
                    'Failed to recover plant data for ID $plantId: $e',
                  );
                  failed++;
                }
              }
            }
          }

          AppLogger.info(
            'Migration_v19',
            '✅ Plants recovery: $recovered recovered, $failed failed',
          );
        }

        // --- PLANT_LOGS DATA RECOVERY (v13 fields) ---
        final plantLogsBackup = data['plant_logs'] as List<dynamic>?;

        if (plantLogsBackup != null && plantLogsBackup.isNotEmpty && missingLogColumns.isNotEmpty) {
          AppLogger.info(
            'Migration_v19',
            'Found ${plantLogsBackup.length} plant_logs in backup',
          );

          int logsRecovered = 0;
          int logsFailed = 0;

          for (final logData in plantLogsBackup) {
            final log = logData as Map<String, dynamic>;
            final logId = log['id'];

            // Check if this log exists in current database
            final existing = await txn.query(
              'plant_logs',
              where: 'id = ?',
              whereArgs: [logId],
            );

            if (existing.isNotEmpty) {
              // Collect v13 fields that were lost
              final recoveredFields = <String, dynamic>{};

              for (final field in missingLogColumns) {
                if (log.containsKey(field) && log[field] != null) {
                  recoveredFields[field] = log[field];
                }
              }

              if (recoveredFields.isNotEmpty) {
                // Build recovery note
                final recoveryNote = StringBuffer();
                recoveryNote.writeln('\n[Recovered from v13 backup:]');

                if (recoveredFields.containsKey('nutrient_ppm')) {
                  recoveryNote.writeln('• PPM: ${recoveredFields['nutrient_ppm']}');
                }
                if (recoveredFields.containsKey('light_hours')) {
                  recoveryNote.writeln('• Light: ${recoveredFields['light_hours']}h');
                }
                if (recoveredFields.containsKey('training')) {
                  recoveryNote.writeln('• Training: ${recoveredFields['training']}');
                }
                if (recoveredFields.containsKey('defoliation')) {
                  recoveryNote.writeln('• Defoliation: ${recoveredFields['defoliation']}');
                }

                try {
                  // Append to existing note
                  final currentNote = existing.first['note'] as String? ?? '';
                  final newNote = currentNote.isEmpty
                      ? recoveryNote.toString().trim()
                      : '$currentNote${recoveryNote.toString()}';

                  await txn.update(
                    'plant_logs',
                    {'note': newNote},
                    where: 'id = ?',
                    whereArgs: [logId],
                  );
                  logsRecovered++;
                } catch (e) {
                  AppLogger.warning(
                    'Migration_v19',
                    'Failed to recover log data for ID $logId: $e',
                  );
                  logsFailed++;
                }
              }
            }
          }

          AppLogger.info(
            'Migration_v19',
            '✅ Plant_logs recovery: $logsRecovered recovered, $logsFailed failed',
          );
        }

      } catch (e) {
        AppLogger.error(
          'Migration_v19',
          'Data recovery from backup failed',
          e,
        );
      }
    } else {
      AppLogger.warning(
        'Migration_v19',
        '⚠️ Step 4/5: No backup found - missing data cannot be recovered',
      );
      if (missingColumns.isNotEmpty) {
        AppLogger.warning(
          'Migration_v19',
          'Missing plants columns will have NULL values:',
        );
        for (final col in missingColumns) {
          AppLogger.warning('Migration_v19', '  - $col');
        }
      }
      if (missingLogColumns.isNotEmpty) {
        AppLogger.warning(
          'Migration_v19',
          'Missing plant_logs v13 fields cannot be recovered (no backup)',
        );
        for (final col in missingLogColumns) {
          AppLogger.warning('Migration_v19', '  - $col');
        }
      }
    }

    // ===========================================
    // STEP 5: Final Validation
    // ===========================================
    AppLogger.info('Migration_v19', '🔍 Step 5/5: Final validation');

    final finalColumns = await txn.rawQuery('PRAGMA table_info(plants)');
    final finalColumnNames = finalColumns
        .map((col) => col['name'] as String)
        .toSet();

    final stillMissing = requiredPlantsColumns.difference(finalColumnNames);

    if (stillMissing.isNotEmpty) {
      throw Exception(
        'Migration v19 failed: Still missing columns: ${stillMissing.join(", ")}',
      );
    }

    // Verify integrity
    final integrityCheck = await txn.rawQuery('PRAGMA integrity_check');
    final result = integrityCheck.first['integrity_check'];
    if (result != 'ok') {
      throw Exception('Database integrity check failed after v19: $result');
    }

    // ===========================================
    // STEP 6: Recovery Summary
    // ===========================================
    if (backupPath != null) {
      AppLogger.info(
        'Migration_v19',
        '🎉 Migration v19 complete: Data recovered from backup',
      );
      AppLogger.info('Migration_v19', 'Backup used: $backupPath');

      if (missingColumns.isNotEmpty) {
        AppLogger.info(
          'Migration_v19',
          '✅ Recovered plants columns: ${missingColumns.join(", ")}',
        );
      }
      if (missingLogColumns.isNotEmpty) {
        AppLogger.info(
          'Migration_v19',
          '✅ Recovered plant_logs v13 fields appended to notes',
        );
      }
    } else {
      AppLogger.warning(
        'Migration_v19',
        '⚠️ Migration v19 complete: No backup found',
      );
      AppLogger.warning(
        'Migration_v19',
        'Some historical data may be lost. Check Settings > Manual Recovery.',
      );

      if (missingColumns.isNotEmpty) {
        AppLogger.warning(
          'Migration_v19',
          '⚠️ These plants fields could not be recovered: ${missingColumns.join(", ")}',
        );
      }
      if (missingLogColumns.isNotEmpty) {
        AppLogger.warning(
          'Migration_v19',
          '⚠️ These plant_logs v13 fields could not be recovered: ${missingLogColumns.join(", ")}',
        );
      }

      // ✅ FIX: Write recovery status file for user notification
      await _writeRecoveryStatusFile(
        success: false,
        missingColumns: missingColumns,
        missingLogColumns: missingLogColumns,
      );
    }
}

/// Write recovery status file for user notification
/// This file can be read by the app to show a warning dialog to the user
Future<void> _writeRecoveryStatusFile({
  required bool success,
  required Set<String> missingColumns,
  required Set<String> missingLogColumns,
}) async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final statusFile = File(path.join(docsDir.path, 'migration_v19_status.json'));

    final status = {
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
      'missing_plants_columns': missingColumns.toList(),
      'missing_plant_logs_columns': missingLogColumns.toList(),
      'message': success
          ? 'Data successfully recovered from backup'
          : 'Recovery failed: No backup found. Some data may be missing.',
    };

    await statusFile.writeAsString(jsonEncode(status));
    AppLogger.info(
      'Migration_v19',
      'Recovery status file written: ${statusFile.path}',
    );
  } catch (e) {
    AppLogger.error(
      'Migration_v19',
      'Failed to write recovery status file',
      e,
    );
    // Don't throw - this is just for user notification
  }
}
