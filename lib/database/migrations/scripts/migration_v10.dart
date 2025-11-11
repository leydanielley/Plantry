// =============================================
// GROWLOG - Migration v9 → v10
// Phase History: Intelligente Rekonstruktion
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v10: Phase History System
///
/// PROBLEM:
/// - Plant Model hat nur phaseStartDate (aktuelle Phase)
/// - Phase-Historie geht verloren bei Phase-Wechsel
/// - Keine retroaktive Korrektur von Phase-Starts möglich
///
/// LÖSUNG:
/// - Neue Felder: veg_date, bloom_date, harvest_date
/// - Intelligente Rekonstruktion aus bestehenden Logs
/// - Ermöglicht retroaktive Phase-Datum-Änderungen
///
/// SICHERHEIT:
/// - Automatic backup vor Migration (vom MigrationManager)
/// - Transaction mit Rollback bei Fehler
/// - Keine Daten gehen verloren
/// - phaseStartDate bleibt als Fallback erhalten
///
/// REKONSTRUKTIONS-LOGIK:
/// 1. Lese alle Logs pro Pflanze chronologisch
/// 2. Finde ersten Log mit phase="VEG" → vegDate
/// 3. Finde ersten Log mit phase="BLOOM" → bloomDate
/// 4. Finde ersten Log mit phase="HARVEST" → harvestDate
/// 5. Fallback auf phaseStartDate wenn keine Logs existieren
final Migration migrationV10 = Migration(
  version: 10,
  description: 'Phase History System - veg_date, bloom_date, harvest_date',
  up: (DatabaseExecutor txn) async {
    AppLogger.info(
      'Migration_v10',
      '🌱 Starting Phase History Migration',
      'Adding veg_date, bloom_date, harvest_date to plants table',
    );

    // ================================================================
    // STEP 1: Add new columns to plants table
    // ================================================================

    AppLogger.info('Migration_v10', '1/4: Adding new date columns...');

    await txn.execute('''
      ALTER TABLE plants ADD COLUMN veg_date TEXT
    ''');

    await txn.execute('''
      ALTER TABLE plants ADD COLUMN bloom_date TEXT
    ''');

    await txn.execute('''
      ALTER TABLE plants ADD COLUMN harvest_date TEXT
    ''');

    AppLogger.info('Migration_v10', '✅ New columns added');

    // ================================================================
    // STEP 2: Intelligent reconstruction from logs
    // ================================================================

    AppLogger.info('Migration_v10', '2/4: Reconstructing phase history from logs...');

    // Get all plants
    final plants = await txn.query('plants');
    int plantsUpdated = 0;
    int plantsWithLogs = 0;
    int plantsWithPhaseStartDate = 0;

    for (final plant in plants) {
      final plantId = plant['id'] as int;
      final currentPhase = plant['phase'] as String?;
      final phaseStartDate = plant['phase_start_date'] as String?;

      AppLogger.debug('Migration_v10', 'Processing plant $plantId (phase: $currentPhase)');

      // Get all logs for this plant, ordered chronologically
      final logs = await txn.query(
        'plant_logs',
        where: 'plant_id = ?',
        whereArgs: [plantId],
        orderBy: 'log_date ASC',
      );

      final Map<String, dynamic> updates = {};

      if (logs.isNotEmpty) {
        plantsWithLogs++;

        // Find first occurrence of each phase
        DateTime? firstVeg;
        DateTime? firstBloom;
        DateTime? firstHarvest;

        for (final log in logs) {
          final phase = log['phase'] as String?;
          if (phase == null) continue;

          final logDate = DateTime.parse(log['log_date'] as String);

          // Record first occurrence of each phase
          if (phase.toUpperCase() == 'VEG' && firstVeg == null) {
            firstVeg = logDate;
          } else if (phase.toUpperCase() == 'BLOOM' && firstBloom == null) {
            firstBloom = logDate;
          } else if (phase.toUpperCase() == 'HARVEST' && firstHarvest == null) {
            firstHarvest = logDate;
          }
        }

        // Store reconstructed dates
        if (firstVeg != null) {
          updates['veg_date'] = firstVeg.toIso8601String();
          AppLogger.debug('Migration_v10', '  → Reconstructed veg_date: $firstVeg');
        }
        if (firstBloom != null) {
          updates['bloom_date'] = firstBloom.toIso8601String();
          AppLogger.debug('Migration_v10', '  → Reconstructed bloom_date: $firstBloom');
        }
        if (firstHarvest != null) {
          updates['harvest_date'] = firstHarvest.toIso8601String();
          AppLogger.debug('Migration_v10', '  → Reconstructed harvest_date: $firstHarvest');
        }
      }

      // FALLBACK: If no logs exist, use phaseStartDate based on current phase
      if (updates.isEmpty && phaseStartDate != null && currentPhase != null) {
        plantsWithPhaseStartDate++;

        switch (currentPhase.toUpperCase()) {
          case 'VEG':
            updates['veg_date'] = phaseStartDate;
            AppLogger.debug('Migration_v10', '  → Fallback: veg_date from phaseStartDate');
            break;
          case 'BLOOM':
            updates['bloom_date'] = phaseStartDate;
            AppLogger.debug('Migration_v10', '  → Fallback: bloom_date from phaseStartDate');
            break;
          case 'HARVEST':
            updates['harvest_date'] = phaseStartDate;
            AppLogger.debug('Migration_v10', '  → Fallback: harvest_date from phaseStartDate');
            break;
        }
      }

      // Apply updates if any
      if (updates.isNotEmpty) {
        await txn.update(
          'plants',
          updates,
          where: 'id = ?',
          whereArgs: [plantId],
        );
        plantsUpdated++;
      }
    }

    AppLogger.info('Migration_v10', '✅ Phase history reconstructed:');
    AppLogger.info('Migration_v10', '  - Total plants: ${plants.length}');
    AppLogger.info('Migration_v10', '  - Updated with log data: $plantsWithLogs');
    AppLogger.info('Migration_v10', '  - Updated with phaseStartDate: $plantsWithPhaseStartDate');
    AppLogger.info('Migration_v10', '  - Total updated: $plantsUpdated');

    // ================================================================
    // STEP 3: Create indices for performance
    // ================================================================

    AppLogger.info('Migration_v10', '3/4: Creating indices...');

    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_plants_veg_date ON plants(veg_date)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_plants_bloom_date ON plants(bloom_date)',
    );
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_plants_harvest_date ON plants(harvest_date)',
    );

    AppLogger.info('Migration_v10', '✅ Indices created');

    // ================================================================
    // STEP 4: Verification
    // ================================================================

    AppLogger.info('Migration_v10', '4/4: Verifying migration...');

    // Count plants with each phase date
    final vegCount = Sqflite.firstIntValue(
      await txn.rawQuery('SELECT COUNT(*) FROM plants WHERE veg_date IS NOT NULL'),
    ) ?? 0;
    final bloomCount = Sqflite.firstIntValue(
      await txn.rawQuery('SELECT COUNT(*) FROM plants WHERE bloom_date IS NOT NULL'),
    ) ?? 0;
    final harvestCount = Sqflite.firstIntValue(
      await txn.rawQuery('SELECT COUNT(*) FROM plants WHERE harvest_date IS NOT NULL'),
    ) ?? 0;

    AppLogger.info('Migration_v10', '📊 Final statistics:');
    AppLogger.info('Migration_v10', '  - Plants with veg_date: $vegCount');
    AppLogger.info('Migration_v10', '  - Plants with bloom_date: $bloomCount');
    AppLogger.info('Migration_v10', '  - Plants with harvest_date: $harvestCount');

    // Sample verification: Get one plant with phase dates
    final samplePlants = await txn.query(
      'plants',
      where: 'veg_date IS NOT NULL OR bloom_date IS NOT NULL',
      limit: 1,
    );

    if (samplePlants.isNotEmpty) {
      final sample = samplePlants.first;
      AppLogger.info('Migration_v10', '🔍 Sample plant verification:');
      AppLogger.info('Migration_v10', '  - ID: ${sample['id']}');
      AppLogger.info('Migration_v10', '  - veg_date: ${sample['veg_date']}');
      AppLogger.info('Migration_v10', '  - bloom_date: ${sample['bloom_date']}');
      AppLogger.info('Migration_v10', '  - harvest_date: ${sample['harvest_date']}');
      AppLogger.info('Migration_v10', '  - phase_start_date (old): ${sample['phase_start_date']}');
    }

    AppLogger.info(
      'Migration_v10',
      '🎉 PHASE HISTORY MIGRATION COMPLETE!',
      'Plants now have full phase history tracking',
    );
  },
);
