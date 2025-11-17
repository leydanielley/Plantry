// =============================================
// GROWLOG - Migration v16 → v17
// SAFE REBUILD: Re-implement critical v14 tables with SafeTableRebuild
// =============================================

import 'package:growlog_app/database/migrations/migration.dart';
import 'package:growlog_app/database/migrations/safe_table_rebuild.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Migration v17: Safe Table Rebuild for v14 tables
///
/// PROBLEM:
/// Migration v14 used manual DROP TABLE + RENAME TABLE pattern
/// which is not atomic and could lead to data loss if app crashes
/// between those two operations.
///
/// SOLUTION:
/// This migration verifies all v14 tables are correctly built and
/// uses SafeTableRebuild to ensure atomicity for any missing tables.
///
/// WHAT IT DOES:
/// 1. Validates v14 schema is correct
/// 2. If tables are already correct, does nothing (fast path)
/// 3. If tables need fixing, uses SafeTableRebuild (safe path)
/// 4. Verifies final state matches v16 schema
///
/// SAFETY:
/// - Non-destructive: Only fixes if needed
/// - Atomic: Uses SafeTableRebuild for guaranteed rollback
/// - Validated: Checks schema before and after
/// - Fast: Skips rebuild if tables are already correct
final Migration migrationV17 = Migration(
  version: 17,
  description: 'Safe rebuild: Ensure v14 tables use atomic pattern',
  up: (txn) async {
    AppLogger.info(
      'Migration_v17',
      '🔄 Starting Migration v17: Safe Table Rebuild',
    );

    // ===========================================
    // STEP 1: Validate Current Schema
    // ===========================================
    AppLogger.info(
      'Migration_v17',
      '🔍 Step 1/3: Validating current schema state',
    );

    // Get current database instance (for read-only validation)
    // Note: We're in a transaction (txn), so use txn for all operations

    // Check plant_logs schema
    final plantLogsColumns = await txn.rawQuery(
      'PRAGMA table_info(plant_logs)',
    );
    final plantLogsColNames = plantLogsColumns
        .map((col) => col['name'] as String)
        .toSet();

    final hasV14PlantLogsSchema = {
      'water_amount',
      'ph_in',
      'ec_in',
      'archived',
    }.every((col) => plantLogsColNames.contains(col));

    // Check photos schema
    final photosColumns = await txn.rawQuery('PRAGMA table_info(photos)');
    final photosColNames = photosColumns
        .map((col) => col['name'] as String)
        .toSet();

    final hasV14PhotosSchema =
        photosColNames.contains('image_path') &&
        photosColNames.contains('description') &&
        photosColNames.contains('taken_at');

    AppLogger.info(
      'Migration_v17',
      '  plant_logs v14 schema: ${hasV14PlantLogsSchema ? "✅" : "❌"}',
    );
    AppLogger.info(
      'Migration_v17',
      '  photos v14 schema: ${hasV14PhotosSchema ? "✅" : "❌"}',
    );

    // ===========================================
    // STEP 2: Fast Path - Skip if already correct
    // ===========================================
    if (hasV14PlantLogsSchema && hasV14PhotosSchema) {
      AppLogger.info(
        'Migration_v17',
        '✅ All tables already have correct v14+ schema, skipping rebuild',
      );

      // Still verify integrity
      final integrityCheck = await txn.rawQuery('PRAGMA integrity_check');
      final result = integrityCheck.first['integrity_check'];
      if (result != 'ok') {
        AppLogger.error(
          'Migration_v17',
          '❌ Database integrity check failed: $result',
        );
        throw Exception('Database integrity check failed after v17');
      }

      AppLogger.info(
        'Migration_v17',
        '🎉 Migration v17 complete (fast path - no changes needed)',
      );
      return;
    }

    // ===========================================
    // STEP 3: Safe Path - Rebuild tables that need it
    // ===========================================
    AppLogger.info(
      'Migration_v17',
      '📝 Step 2/3: Rebuilding tables with SafeTableRebuild',
    );

    // Only rebuild tables that actually need it
    if (!hasV14PlantLogsSchema) {
      AppLogger.warning(
        'Migration_v17',
        '  ⚠️ plant_logs schema incorrect, rebuilding...',
      );

      await SafeTableRebuild.rebuildTable(
        txn,
        tableName: 'plant_logs',
        newTableDdl: '''
          CREATE TABLE plant_logs_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plant_id INTEGER NOT NULL,
            day_number INTEGER NOT NULL,
            log_date TEXT NOT NULL DEFAULT (datetime('now')),
            logged_by TEXT,
            action_type TEXT NOT NULL CHECK(action_type IN ('WATER', 'FEED', 'NOTE', 'PHASE_CHANGE', 'TRANSPLANT', 'HARVEST', 'TRAINING', 'TRIM', 'OTHER')),
            phase TEXT CHECK(phase IN ('SEEDLING', 'VEG', 'BLOOM', 'HARVEST', 'ARCHIVED')),
            phase_day_number INTEGER,
            water_amount REAL,
            ph_in REAL,
            ph_out REAL,
            ec_in REAL,
            ec_out REAL,
            temperature REAL,
            humidity REAL,
            runoff INTEGER DEFAULT 0,
            cleanse INTEGER DEFAULT 0,
            container_size REAL,
            container_medium_amount REAL,
            container_drainage INTEGER DEFAULT 0,
            container_drainage_material TEXT,
            system_reservoir_size REAL,
            system_bucket_count INTEGER,
            system_bucket_size REAL,
            note TEXT,
            archived INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
          )
        ''',
        dataMigration: '''
          INSERT INTO plant_logs_new (
            id, plant_id, day_number, log_date, logged_by, action_type, phase, phase_day_number,
            water_amount, ph_in, ph_out, ec_in, ec_out, temperature, humidity,
            runoff, cleanse, container_size, container_medium_amount, container_drainage,
            container_drainage_material, system_reservoir_size, system_bucket_count,
            system_bucket_size, note, archived, created_at
          )
          SELECT
            id, plant_id, day_number, log_date,
            COALESCE(logged_by, NULL) as logged_by,
            action_type, phase, phase_day_number,
            COALESCE(water_amount, watering_ml) as water_amount,
            COALESCE(ph_in, ph) as ph_in,
            ph_out,
            COALESCE(ec_in, nutrient_ec) as ec_in,
            ec_out,
            temperature, humidity,
            COALESCE(runoff, 0) as runoff,
            COALESCE(cleanse, 0) as cleanse,
            container_size, container_medium_amount,
            COALESCE(container_drainage, 0) as container_drainage,
            container_drainage_material,
            system_reservoir_size, system_bucket_count, system_bucket_size,
            note,
            COALESCE(archived, 0) as archived,
            created_at
          FROM plant_logs
        ''',
        indexes: [
          'CREATE INDEX idx_logs_plant ON plant_logs(plant_id)',
          'CREATE INDEX idx_logs_date ON plant_logs(log_date DESC)',
          'CREATE INDEX idx_plant_logs_plant_archived ON plant_logs(plant_id, archived)',
          'CREATE INDEX idx_plant_logs_archived_date ON plant_logs(archived, log_date DESC)',
        ],
        validateAfter: (db) async {
          final columns = await db.rawQuery('PRAGMA table_info(plant_logs)');
          final colNames = columns.map((c) => c['name'] as String).toSet();
          return colNames.containsAll([
            'water_amount',
            'ph_in',
            'ec_in',
            'archived',
          ]);
        },
      );

      AppLogger.info('Migration_v17', '  ✅ plant_logs rebuilt successfully');
    }

    if (!hasV14PhotosSchema) {
      AppLogger.warning(
        'Migration_v17',
        '  ⚠️ photos schema incorrect, rebuilding...',
      );

      await SafeTableRebuild.rebuildTable(
        txn,
        tableName: 'photos',
        newTableDdl: '''
          CREATE TABLE photos_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            log_id INTEGER,
            image_path TEXT NOT NULL,
            description TEXT,
            taken_at TEXT DEFAULT (datetime('now')),
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE
          )
        ''',
        dataMigration: '''
          INSERT INTO photos_new (id, log_id, image_path, description, taken_at, created_at)
          SELECT
            id,
            log_id,
            COALESCE(image_path, file_path) as image_path,
            description,
            COALESCE(taken_at, created_at) as taken_at,
            created_at
          FROM photos
        ''',
        indexes: ['CREATE INDEX idx_photos_log ON photos(log_id)'],
        validateAfter: (db) async {
          final columns = await db.rawQuery('PRAGMA table_info(photos)');
          final colNames = columns.map((c) => c['name'] as String).toSet();
          return colNames.containsAll([
            'image_path',
            'description',
            'taken_at',
          ]);
        },
      );

      AppLogger.info('Migration_v17', '  ✅ photos rebuilt successfully');
    }

    // ===========================================
    // STEP 4: Final Validation
    // ===========================================
    AppLogger.info('Migration_v17', '🔍 Step 3/3: Final schema validation');

    // Verify plant_logs has required columns
    final finalPlantLogsCheck = await txn.rawQuery(
      'PRAGMA table_info(plant_logs)',
    );
    final finalPlantLogsColNames = finalPlantLogsCheck
        .map((col) => col['name'] as String)
        .toSet();

    final requiredPlantLogsCols = {
      'water_amount',
      'ph_in',
      'ec_in',
      'archived',
    };
    final missingCols = requiredPlantLogsCols.difference(
      finalPlantLogsColNames,
    );

    if (missingCols.isNotEmpty) {
      throw Exception(
        'Migration v17 failed: plant_logs missing columns: ${missingCols.join(", ")}',
      );
    }

    // Verify photos has required columns
    final finalPhotosCheck = await txn.rawQuery('PRAGMA table_info(photos)');
    final finalPhotosColNames = finalPhotosCheck
        .map((col) => col['name'] as String)
        .toSet();

    final requiredPhotosCols = {'image_path', 'description', 'taken_at'};
    final missingPhotosCols = requiredPhotosCols.difference(
      finalPhotosColNames,
    );

    if (missingPhotosCols.isNotEmpty) {
      throw Exception(
        'Migration v17 failed: photos missing columns: ${missingPhotosCols.join(", ")}',
      );
    }

    // Integrity check
    final integrityCheck = await txn.rawQuery('PRAGMA integrity_check');
    final result = integrityCheck.first['integrity_check'];
    if (result != 'ok') {
      throw Exception('Database integrity check failed after v17: $result');
    }

    AppLogger.info(
      'Migration_v17',
      '🎉 Migration v17 complete: All tables safely rebuilt',
    );
  },
);
