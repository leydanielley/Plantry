// =============================================
// GROWLOG - Schema Registry
// Central source of truth for database schemas
// =============================================

import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/utils/app_logger.dart';

/// Schema definition for a database version
class SchemaDefinition {
  final int version;
  final Map<String, Set<String>> requiredTables;
  final Map<String, Set<String>> requiredIndexes;

  SchemaDefinition({
    required this.version,
    required this.requiredTables,
    this.requiredIndexes = const {},
  });
}

/// Central registry of all database schemas
///
/// Provides a single source of truth for what each database version should look like.
/// Used for validation before and after migrations.
///
/// WHY THIS EXISTS:
/// - Manual validation in each migration is error-prone
/// - No way to verify database state matches expected schema
/// - Hard to catch schema drift over time
///
/// USAGE:
/// ```dart
/// final isValid = await SchemaRegistry.validateSchema(db, 14);
/// if (!isValid) {
///   throw Exception('Database schema v14 is invalid!');
/// }
/// ```
class SchemaRegistry {
  // ===========================================
  // Schema Definitions (per version)
  // ===========================================

  /// Schema for v13: Pre-soft-delete (old column names)
  static final schemaV13 = SchemaDefinition(
    version: 13,
    requiredTables: {
      'plants': {
        'id',
        'name',
        'strain',
        'grow_id',
        'room_id',
        'planted_date',
        'created_at',
      },
      'plant_logs': {
        'id',
        'plant_id',
        'day_number',
        'log_date',
        'action_type',
        'phase',
        'phase_day_number',
        'watering_ml', // v13 name (renamed to water_amount in v14)
        'ph', // v13 name (split to ph_in/ph_out in v14)
        'nutrient_ec', // v13 name (split to ec_in/ec_out in v14)
        'temperature',
        'humidity',
        'note',
        'created_at',
      },
      'photos': {
        'id',
        'log_id',
        'file_path', // v13 name (renamed to image_path in v14)
        'created_at',
      },
      'harvests': {
        'id',
        'plant_id',
        'harvest_date',
        'wet_weight',
        'dry_weight',
        'created_at',
      },
      'rdwc_logs': {
        'id',
        'system_id',
        'log_date',
        'log_type',
        'level_before',
        'water_added',
        'level_after',
        'water_consumed',
        'ph_before',
        'ph_after',
        'ec_before',
        'ec_after',
        'note',
        'logged_by',
        'created_at',
      },
      'rooms': {'id', 'name', 'created_at'},
    },
    requiredIndexes: {
      'plant_logs': {'idx_logs_plant', 'idx_logs_date'},
      'photos': {'idx_photos_log'},
    },
  );

  /// Schema for v14: Soft-delete system
  static final schemaV14 = SchemaDefinition(
    version: 14,
    requiredTables: {
      'plants': {
        'id',
        'name',
        'strain',
        'grow_id',
        'room_id',
        'planted_date',
        'created_at',
      },
      'plant_logs': {
        'id',
        'plant_id',
        'day_number',
        'log_date',
        'logged_by',
        'action_type',
        'phase',
        'phase_day_number',
        'water_amount', // v14 renamed from watering_ml
        'ph_in', // v14 renamed from ph
        'ph_out', // v14 new field
        'ec_in', // v14 renamed from nutrient_ec
        'ec_out', // v14 new field
        'temperature',
        'humidity',
        'runoff', // v14 new field
        'cleanse', // v14 new field
        'container_size', // v14 new field
        'container_medium_amount', // v14 new field
        'container_drainage', // v14 new field
        'container_drainage_material', // v14 new field
        'system_reservoir_size', // v14 new field
        'system_bucket_count', // v14 new field
        'system_bucket_size', // v14 new field
        'note',
        'archived', // v14 new field
        'created_at',
      },
      'photos': {
        'id',
        'log_id',
        'image_path', // v14 renamed from file_path
        'description', // v14 new field
        'taken_at', // v14 new field
        'created_at',
      },
      'harvests': {
        'id',
        'plant_id',
        'harvest_date',
        'wet_weight',
        'dry_weight',
        'created_at',
        // v14 note: Many fields still missing, added in v16
      },
      'rdwc_logs': {
        'id',
        'system_id',
        'log_date',
        'log_type',
        'level_before',
        'water_added',
        'level_after',
        'water_consumed',
        'ph_before',
        'ph_after',
        'ec_before',
        'ec_after',
        'note',
        'logged_by',
        'archived', // v14 new field
        'created_at',
      },
      'rooms': {
        'id',
        'name',
        'archived', // v14 new field
        'created_at',
      },
    },
    requiredIndexes: {
      'plant_logs': {
        'idx_logs_plant',
        'idx_logs_date',
        'idx_plant_logs_plant_archived',
        'idx_plant_logs_archived_date',
      },
      'photos': {'idx_photos_log'},
    },
  );

  /// Schema for v15: Data integrity constraints
  static final schemaV15 = SchemaDefinition(
    version: 15,
    requiredTables: schemaV14.requiredTables, // Same tables as v14
    requiredIndexes: {
      ...schemaV14.requiredIndexes,
      'plant_logs': {
        ...?schemaV14.requiredIndexes['plant_logs'],
        'idx_plant_logs_unique_day', // v15 adds UNIQUE constraint
      },
    },
  );

  /// Schema for v16: Healing migration
  static final schemaV16 = SchemaDefinition(
    version: 16,
    requiredTables: {
      ...schemaV15.requiredTables,
      'harvests': {
        ...?schemaV15.requiredTables['harvests'],
        // v16 adds all missing harvests fields
        'drying_start_date',
        'drying_end_date',
        'drying_days',
        'drying_method',
        'drying_temperature',
        'drying_humidity',
        'curing_start_date',
        'curing_end_date',
        'curing_days',
        'curing_method',
        'curing_notes',
        'thc_percentage',
        'cbd_percentage',
        'terpene_profile',
        'rating',
        'taste_notes',
        'effect_notes',
        'overall_notes',
        'updated_at',
      },
    },
    requiredIndexes: schemaV15.requiredIndexes,
  );

  /// Schema for v17: Safe rebuild (same as v16)
  static final schemaV17 = SchemaDefinition(
    version: 17,
    requiredTables: schemaV16.requiredTables, // Same as v16
    requiredIndexes: schemaV16.requiredIndexes, // Same as v16
  );

  /// Schema for v18: FK constraint fix (same schema as v17, just FK changes)
  static final schemaV18 = SchemaDefinition(
    version: 18,
    requiredTables: schemaV17.requiredTables, // Same as v17
    requiredIndexes: schemaV17.requiredIndexes, // Same as v17
  );

  /// Schema for v19: Emergency data recovery (same schema as v18)
  static final schemaV19 = SchemaDefinition(
    version: 19,
    requiredTables: schemaV18.requiredTables, // Same as v18
    requiredIndexes: schemaV18.requiredIndexes, // Same as v18
  );

  /// Schema for v20: Harvests FK constraint fix (same schema as v19)
  static final schemaV20 = SchemaDefinition(
    version: 20,
    requiredTables: schemaV19.requiredTables, // Same as v19
    requiredIndexes: schemaV19.requiredIndexes, // Same as v19
  );

  // NOTE: Schemas v21-v35 are not defined in this registry
  // These migrations were implemented without schema registry updates
  // v35: CRITICAL HEALING - Recovery from v34 downgrade error
  // If validation is needed for these versions, schemas should be added retroactively

  /// Schema for v36: FK CASCADE Standardization
  /// Migration v36 changed FK constraints on harvests and hardware tables
  /// from CASCADE to RESTRICT (no new columns or indexes)
  static final schemaV36 = SchemaDefinition(
    version: 36,
    requiredTables: schemaV20.requiredTables, // Same as v20
    requiredIndexes: schemaV20.requiredIndexes, // Same as v20
  );

  /// Schema for v37: Performance - Add fertilizers.name index
  /// Migration v37 adds idx_fertilizers_name index for ORDER BY optimization
  static final schemaV37 = SchemaDefinition(
    version: 37,
    requiredTables: schemaV36.requiredTables, // Same as v36
    requiredIndexes: {
      ...schemaV36.requiredIndexes,
      'fertilizers': {
        'idx_fertilizers_name', // v37 adds name index for ORDER BY optimization
      },
    },
  );

  /// Map of all schema definitions
  static final Map<int, SchemaDefinition> schemas = {
    13: schemaV13,
    14: schemaV14,
    15: schemaV15,
    16: schemaV16,
    17: schemaV17,
    18: schemaV18,
    19: schemaV19,
    20: schemaV20,
    // 21-35: Not defined (migrations exist without schema registry)
    36: schemaV36,
    37: schemaV37,
  };

  // ===========================================
  // Validation Functions
  // ===========================================

  /// Validate database schema matches expected version
  ///
  /// Returns true if database schema is valid for the given version
  ///
  /// [executor] Database or Transaction instance to validate
  /// [version] Expected database version
  /// [strict] If true, extra columns/tables are errors. If false, warnings.
  static Future<bool> validateSchema(
    DatabaseExecutor executor,
    int version, {
    bool strict = false,
  }) async {
    try {
      AppLogger.info(
        'SchemaRegistry',
        '🔍 Validating database schema for v$version...',
      );

      final schemaDef = schemas[version];
      if (schemaDef == null) {
        AppLogger.warning(
          'SchemaRegistry',
          '⚠️ No schema definition for v$version',
        );
        return false;
      }

      bool isValid = true;

      // ===========================================
      // Validate Tables & Columns
      // ===========================================
      for (final entry in schemaDef.requiredTables.entries) {
        final tableName = entry.key;
        final requiredColumns = entry.value;

        // Check table exists
        final tableCheck = await executor.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName],
        );

        if (tableCheck.isEmpty) {
          AppLogger.error('SchemaRegistry', '❌ Missing table: $tableName');
          isValid = false;
          continue;
        }

        // Check columns
        final columns = await executor.rawQuery('PRAGMA table_info($tableName)');
        final actualColumns = columns
            .map((col) => col['name'] as String)
            .toSet();

        final missingColumns = requiredColumns.difference(actualColumns);
        if (missingColumns.isNotEmpty) {
          AppLogger.error(
            'SchemaRegistry',
            '❌ Table $tableName missing columns: ${missingColumns.join(", ")}',
          );
          isValid = false;
        }

        if (strict) {
          final extraColumns = actualColumns.difference(requiredColumns);
          if (extraColumns.isNotEmpty) {
            AppLogger.error(
              'SchemaRegistry',
              '❌ Table $tableName has unexpected columns: ${extraColumns.join(", ")}',
            );
            isValid = false;
          }
        }
      }

      // ===========================================
      // Validate Indexes
      // ===========================================
      if (schemaDef.requiredIndexes.isNotEmpty) {
        for (final entry in schemaDef.requiredIndexes.entries) {
          final tableName = entry.key;
          final requiredIndexes = entry.value;

          final indexes = await executor.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?",
            [tableName],
          );
          final actualIndexes = indexes
              .map((idx) => idx['name'] as String)
              .toSet();

          final missingIndexes = requiredIndexes.difference(actualIndexes);
          if (missingIndexes.isNotEmpty) {
            AppLogger.warning(
              'SchemaRegistry',
              '⚠️ Table $tableName missing indexes: ${missingIndexes.join(", ")}',
            );
            // Indexes missing is warning, not error
          }
        }
      }

      // ===========================================
      // Foreign Key Integrity Check
      // ===========================================
      final fkCheck = await executor.rawQuery('PRAGMA foreign_key_check');
      if (fkCheck.isNotEmpty) {
        AppLogger.error(
          'SchemaRegistry',
          '❌ Foreign key violations detected: ${fkCheck.length}',
        );
        for (final violation in fkCheck.take(5)) {
          AppLogger.error('SchemaRegistry', '  - $violation');
        }
        isValid = false;
      }

      // ===========================================
      // Database Integrity Check
      // ===========================================
      final integrityCheck = await executor.rawQuery('PRAGMA integrity_check');
      final result = integrityCheck.first['integrity_check'];
      if (result != 'ok') {
        AppLogger.error(
          'SchemaRegistry',
          '❌ Database integrity check failed: $result',
        );
        isValid = false;
      }

      if (isValid) {
        AppLogger.info(
          'SchemaRegistry',
          '✅ Schema validation passed for v$version',
        );
      } else {
        AppLogger.error(
          'SchemaRegistry',
          '❌ Schema validation failed for v$version',
        );
      }

      return isValid;
    } catch (e, stackTrace) {
      AppLogger.error(
        'SchemaRegistry',
        'Schema validation error',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Get schema definition for a version
  static SchemaDefinition? getSchema(int version) {
    return schemas[version];
  }

  /// Check if a table has all required columns
  static Future<bool> tableHasColumns(
    DatabaseExecutor executor,
    String tableName,
    Set<String> requiredColumns,
  ) async {
    try {
      final columns = await executor.rawQuery('PRAGMA table_info($tableName)');
      final actualColumns = columns.map((col) => col['name'] as String).toSet();

      return requiredColumns.every((col) => actualColumns.contains(col));
    } catch (e) {
      AppLogger.error('SchemaRegistry', 'Failed to check table columns', e);
      return false;
    }
  }
}
