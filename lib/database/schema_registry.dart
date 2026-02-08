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
  ///
  /// ⚠️ IMPORTANT: This schema matches the ACTUAL production database structure
  /// (NOT inherited from v20 which has incorrect column names)
  static final schemaV36 = SchemaDefinition(
    version: 36,
    requiredTables: {
      'plants': {
        'id',
        'name',
        'breeder',
        'strain',
        'feminized',
        'seed_type',
        'medium',
        'phase',
        'room_id',
        'grow_id',
        'rdwc_system_id',
        'bucket_number',
        'seed_date', // ✅ CORRECT: seed_date (NOT planted_date)
        'phase_start_date',
        'veg_date',
        'bloom_date',
        'harvest_date',
        'created_at',
        'created_by',
        'log_profile_name',
        'archived',
        'current_container_size',
        'current_system_size',
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
        'water_amount',
        'ph_in',
        'ph_out',
        'ec_in',
        'ec_out',
        'temperature',
        'humidity',
        'runoff',
        'cleanse',
        'note',
        'container_size',
        'container_medium_amount',
        'container_drainage',
        'container_drainage_material',
        'system_reservoir_size',
        'system_bucket_count',
        'system_bucket_size',
        'archived',
        'created_at',
      },
      'photos': {
        'id',
        'log_id',
        'file_path', // ✅ CORRECT: file_path (NOT image_path)
        'created_at',
        // ✅ CORRECT: NO description or taken_at columns
      },
      'harvests': {
        'id',
        'plant_id',
        'harvest_date',
        'wet_weight',
        'dry_weight',
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
        'created_at',
        'updated_at',
      },
      'rooms': {
        'id',
        'name',
        'description',
        'grow_type',
        'watering_system',
        'rdwc_system_id',
        'width',
        'depth',
        'height',
        'archived',
        'created_at',
        'updated_at',
      },
      'grows': {
        'id',
        'name',
        'description',
        'start_date',
        'end_date',
        'room_id',
        'archived',
        'created_at',
      },
      'fertilizers': {
        'id',
        'name',
        'brand',
        'npk',
        'type',
        'description',
        'ec_value',
        'ppm_value',
        'formula',
        'source',
        'purity',
        'is_liquid',
        'density',
        'n_no3',
        'n_nh4',
        'p',
        'k',
        'mg',
        'ca',
        's',
        'b',
        'fe',
        'zn',
        'cu',
        'mn',
        'mo',
        'na',
        'si',
        'cl',
        'created_at',
      },
      'hardware': {
        'id',
        'room_id',
        'name',
        'type',
        'brand',
        'model',
        'wattage',
        'quantity',
        'airflow',
        'spectrum',
        'color_temperature',
        'dimmable',
        'flange_size',
        'controllable',
        'oscillating',
        'diameter',
        'cooling_power',
        'heating_power',
        'coverage',
        'has_thermostat',
        'humidification_rate',
        'pump_rate',
        'is_digital',
        'program_count',
        'dripper_count',
        'capacity',
        'material',
        'has_chiller',
        'has_air_pump',
        'filter_diameter',
        'filter_length',
        'controller_type',
        'output_count',
        'controller_functions',
        'specifications',
        'purchase_date',
        'purchase_price',
        'notes',
        'active',
        'created_at',
      },
      'rdwc_systems': {
        'id',
        'name',
        'room_id',
        'grow_id',
        'max_capacity',
        'current_level',
        'bucket_count',
        'description',
        'pump_brand',
        'pump_model',
        'pump_wattage',
        'pump_flow_rate',
        'air_pump_brand',
        'air_pump_model',
        'air_pump_wattage',
        'air_pump_flow_rate',
        'chiller_brand',
        'chiller_model',
        'chiller_wattage',
        'chiller_cooling_power',
        'accessories',
        'created_at',
        'archived',
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
        'archived',
        'created_at',
      },
    },
    requiredIndexes: {
      'plants': {
        'idx_plants_room',
        'idx_plants_grow',
        'idx_plants_rdwc_system',
        'idx_plants_phase',
        'idx_plants_archived',
        'idx_plants_veg_date',
        'idx_plants_bloom_date',
        'idx_plants_harvest_date',
      },
      'plant_logs': {
        'idx_logs_plant',
        'idx_logs_date',
        'idx_logs_action',
        'idx_plant_logs_lookup',
        'idx_plant_logs_action_date',
        'idx_plant_logs_plant_day_unique', // ✅ CORRECT: plant_day_unique (NOT unique_day)
        'idx_plant_logs_plant_archived',
        'idx_plant_logs_archived_date',
      },
      'photos': {
        'idx_photos_log',
        'idx_photos_log_lookup',
      },
      'harvests': {
        'idx_harvests_plant',
        'idx_harvests_date',
      },
      'rooms': {
        'idx_rooms_rdwc_system',
      },
      'grows': {
        'idx_grows_archived',
        'idx_grows_room',
      },
      'hardware': {
        'idx_hardware_room',
        'idx_hardware_type',
        'idx_hardware_active',
      },
      'rdwc_systems': {
        'idx_rdwc_systems_room',
        'idx_rdwc_systems_grow',
        'idx_rdwc_systems_archived',
      },
      'rdwc_logs': {
        'idx_rdwc_logs_system',
        'idx_rdwc_logs_date',
        'idx_rdwc_logs_type',
      },
    },
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

  /// Schema for v38: CRITICAL FIX - Allow multiple logs per day per plant
  /// Migration v38 changes unique constraint from (plant_id, day_number)
  /// to (plant_id, day_number, action_type) to allow multiple different
  /// action types on the same day while preventing duplicate actions
  static final schemaV38 = SchemaDefinition(
    version: 38,
    requiredTables: schemaV37.requiredTables, // Same as v37
    requiredIndexes: {
      ...schemaV37.requiredIndexes,
      'plant_logs': {
        // Remove old unique index
        ...schemaV37.requiredIndexes['plant_logs']!
            .where((idx) => idx != 'idx_plant_logs_plant_day_unique')
            .toSet(),
        // Add new unique index with action_type
        'idx_plant_logs_unique_per_action', // v38 replaces old unique constraint
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
    38: schemaV38,
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
