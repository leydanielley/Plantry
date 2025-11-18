// =============================================
// GROWLOG - Log Service Phase Change Tests
// Tests for Fix #1: Phase change date tracking
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/plant_log_repository.dart';
import 'package:growlog_app/repositories/log_fertilizer_repository.dart';
import 'package:growlog_app/repositories/photo_repository.dart';
import 'package:growlog_app/services/log_service.dart';

void main() {
  late Database db;
  late DatabaseHelper dbHelper;
  late PlantRepository plantRepo;
  late PlantLogRepository logRepo;
  late LogFertilizerRepository logFertRepo;
  late PhotoRepository photoRepo;
  late LogService logService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create in-memory database for testing
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 35,
        onCreate: (db, version) async {
          // Create minimal schema for testing
          await db.execute('''
            CREATE TABLE plants (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              seed_type TEXT NOT NULL,
              medium TEXT NOT NULL,
              phase TEXT DEFAULT 'SEEDLING',
              phase_start_date TEXT,
              veg_date TEXT,
              bloom_date TEXT,
              harvest_date TEXT,
              seed_date TEXT,
              grow_id INTEGER,
              room_id INTEGER,
              rdwc_system_id INTEGER,
              bucket_number INTEGER,
              feminized INTEGER DEFAULT 1,
              breeder TEXT,
              strain TEXT,
              created_at TEXT DEFAULT (datetime('now')),
              created_by TEXT,
              log_profile_name TEXT DEFAULT 'standard',
              archived INTEGER DEFAULT 0,
              current_container_size REAL,
              current_system_size REAL
            )
          ''');

          await db.execute('''
            CREATE TABLE plant_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              plant_id INTEGER NOT NULL,
              day_number INTEGER NOT NULL,
              log_date TEXT NOT NULL,
              logged_by TEXT,
              action_type TEXT NOT NULL,
              phase TEXT,
              phase_day_number INTEGER,
              water_amount REAL,
              ph_in REAL,
              ec_in REAL,
              ph_out REAL,
              ec_out REAL,
              temperature REAL,
              humidity REAL,
              runoff INTEGER DEFAULT 0,
              cleanse INTEGER DEFAULT 0,
              note TEXT,
              container_size REAL,
              container_medium_amount REAL,
              container_drainage INTEGER DEFAULT 0,
              container_drainage_material TEXT,
              system_reservoir_size REAL,
              system_bucket_count INTEGER,
              system_bucket_size REAL,
              archived INTEGER DEFAULT 0,
              created_at TEXT DEFAULT (datetime('now')),
              FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE RESTRICT
            )
          ''');

          await db.execute('''
            CREATE TABLE log_fertilizers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              log_id INTEGER NOT NULL,
              fertilizer_id INTEGER NOT NULL,
              amount REAL,
              unit TEXT DEFAULT 'ml',
              FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE photos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              log_id INTEGER NOT NULL,
              file_path TEXT NOT NULL,
              created_at TEXT DEFAULT (datetime('now')),
              FOREIGN KEY (log_id) REFERENCES plant_logs(id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );

    // Set test database
    DatabaseHelper.setTestDatabase(db);
    dbHelper = DatabaseHelper.instance;

    // Initialize repositories
    plantRepo = PlantRepository();
    logRepo = PlantLogRepository();
    logFertRepo = LogFertilizerRepository();
    photoRepo = PhotoRepository();

    // Initialize service
    logService = LogService(dbHelper, plantRepo);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('Fix #1: Phase Change Date Tracking', () {
    test('SEEDLING → VEG: Sets vegDate when transitioning to veg', () async {
      // Arrange: Create plant in seedling phase
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.seedling,
        seedDate: DateTime(2025, 1, 1),
      ));

      expect(plant.vegDate, isNull, reason: 'vegDate should initially be null');

      // Act: Create phase change log to VEG on 2025-01-15
      final log = PlantLog(
        plantId: plant.id!,
        dayNumber: 15,
        logDate: DateTime(2025, 1, 15),
        actionType: ActionType.phaseChange,
        phase: PlantPhase.veg,
      );

      await logService.saveSingleLog(
        plant: plant,
        log: log,
        fertilizers: {},
        photoPaths: [],
        newPhase: PlantPhase.veg,
      );

      // Assert: vegDate should now be set
      final updatedPlant = await plantRepo.findById(plant.id!);
      expect(updatedPlant, isNotNull);
      expect(updatedPlant!.phase, equals(PlantPhase.veg),
          reason: 'Phase should be updated to veg');
      expect(updatedPlant.vegDate, equals(DateTime(2025, 1, 15)),
          reason: 'vegDate should be set to phase change date');
      expect(updatedPlant.bloomDate, isNull,
          reason: 'bloomDate should still be null');
      expect(updatedPlant.harvestDate, isNull,
          reason: 'harvestDate should still be null');
    });

    test('VEG → BLOOM: Sets bloomDate when transitioning to bloom', () async {
      // Arrange: Create plant in veg phase
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
        vegDate: DateTime(2025, 1, 15),
      ));

      expect(plant.bloomDate, isNull,
          reason: 'bloomDate should initially be null');

      // Act: Create phase change log to BLOOM on 2025-02-01
      final log = PlantLog(
        plantId: plant.id!,
        dayNumber: 32,
        logDate: DateTime(2025, 2, 1),
        actionType: ActionType.phaseChange,
        phase: PlantPhase.bloom,
      );

      await logService.saveSingleLog(
        plant: plant,
        log: log,
        fertilizers: {},
        photoPaths: [],
        newPhase: PlantPhase.bloom,
      );

      // Assert: bloomDate should now be set
      final updatedPlant = await plantRepo.findById(plant.id!);
      expect(updatedPlant, isNotNull);
      expect(updatedPlant!.phase, equals(PlantPhase.bloom),
          reason: 'Phase should be updated to bloom');
      expect(updatedPlant.vegDate, equals(DateTime(2025, 1, 15)),
          reason: 'vegDate should remain unchanged');
      expect(updatedPlant.bloomDate, equals(DateTime(2025, 2, 1)),
          reason: 'bloomDate should be set to phase change date');
      expect(updatedPlant.harvestDate, isNull,
          reason: 'harvestDate should still be null');
    });

    test('BLOOM → HARVEST: Sets harvestDate when transitioning to harvest',
        () async {
      // Arrange: Create plant in bloom phase
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.bloom,
        seedDate: DateTime(2025, 1, 1),
        vegDate: DateTime(2025, 1, 15),
        bloomDate: DateTime(2025, 2, 1),
      ));

      expect(plant.harvestDate, isNull,
          reason: 'harvestDate should initially be null');

      // Act: Create phase change log to HARVEST on 2025-04-01
      final log = PlantLog(
        plantId: plant.id!,
        dayNumber: 91,
        logDate: DateTime(2025, 4, 1),
        actionType: ActionType.phaseChange,
        phase: PlantPhase.harvest,
      );

      await logService.saveSingleLog(
        plant: plant,
        log: log,
        fertilizers: {},
        photoPaths: [],
        newPhase: PlantPhase.harvest,
      );

      // Assert: harvestDate should now be set
      final updatedPlant = await plantRepo.findById(plant.id!);
      expect(updatedPlant, isNotNull);
      expect(updatedPlant!.phase, equals(PlantPhase.harvest),
          reason: 'Phase should be updated to harvest');
      expect(updatedPlant.vegDate, equals(DateTime(2025, 1, 15)),
          reason: 'vegDate should remain unchanged');
      expect(updatedPlant.bloomDate, equals(DateTime(2025, 2, 1)),
          reason: 'bloomDate should remain unchanged');
      expect(updatedPlant.harvestDate, equals(DateTime(2025, 4, 1)),
          reason: 'harvestDate should be set to phase change date');
    });

    test(
        'Phase change does NOT overwrite existing dates (idempotent behavior)',
        () async {
      // Arrange: Create plant with all dates already set
      final originalVegDate = DateTime(2025, 1, 10);
      final originalBloomDate = DateTime(2025, 2, 5);

      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.bloom,
        seedDate: DateTime(2025, 1, 1),
        vegDate: originalVegDate,
        bloomDate: originalBloomDate,
      ));

      // Act: Create another phase change log to BLOOM (simulating re-entry)
      final log = PlantLog(
        plantId: plant.id!,
        dayNumber: 45,
        logDate: DateTime(2025, 2, 15),
        actionType: ActionType.phaseChange,
        phase: PlantPhase.bloom,
      );

      await logService.saveSingleLog(
        plant: plant,
        log: log,
        fertilizers: {},
        photoPaths: [],
        newPhase: PlantPhase.bloom,
      );

      // Assert: Dates should NOT be overwritten (keep original)
      final updatedPlant = await plantRepo.findById(plant.id!);
      expect(updatedPlant, isNotNull);
      expect(updatedPlant!.vegDate, equals(originalVegDate),
          reason:
              'vegDate should NOT be overwritten when already set');
      expect(updatedPlant.bloomDate, equals(originalBloomDate),
          reason:
              'bloomDate should NOT be overwritten when already set');
    });

    test('Non-phase-change logs do NOT update phase dates', () async {
      // Arrange: Create plant in veg phase
      final plant = await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
        vegDate: DateTime(2025, 1, 15),
      ));

      // Act: Create regular WATER log (not phase change)
      final log = PlantLog(
        plantId: plant.id!,
        dayNumber: 20,
        logDate: DateTime(2025, 1, 20),
        actionType: ActionType.water,
        phase: PlantPhase.veg, // Same phase
        waterAmount: 2.0,
      );

      await logService.saveSingleLog(
        plant: plant,
        log: log,
        fertilizers: {},
        photoPaths: [],
      );

      // Assert: Phase dates should remain unchanged
      final updatedPlant = await plantRepo.findById(plant.id!);
      expect(updatedPlant, isNotNull);
      expect(updatedPlant!.vegDate, equals(DateTime(2025, 1, 15)),
          reason: 'vegDate should not change on non-phase-change logs');
      expect(updatedPlant.bloomDate, isNull,
          reason: 'bloomDate should remain null');
    });

    test('Bulk phase change updates multiple plants correctly', () async {
      // Arrange: Create multiple plants in veg phase
      final plant1 = await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
        vegDate: DateTime(2025, 1, 15),
      ));

      final plant2 = await plantRepo.save(Plant(
        name: 'Plant 2',
        seedType: SeedType.photo,
        medium: Medium.erde,
        phase: PlantPhase.veg,
        seedDate: DateTime(2025, 1, 1),
        vegDate: DateTime(2025, 1, 15),
      ));

      // Act: Bulk phase change to BLOOM on 2025-02-01
      await logService.saveBulkLog(
        plantIds: [plant1.id!, plant2.id!],
        actionType: ActionType.phaseChange,
        newPhase: PlantPhase.bloom,
        logDate: DateTime(2025, 2, 1),
        fertilizers: {},
        photoPaths: [],
      );

      // Assert: Both plants should have bloomDate set
      final updated1 = await plantRepo.findById(plant1.id!);
      final updated2 = await plantRepo.findById(plant2.id!);

      expect(updated1, isNotNull);
      expect(updated2, isNotNull);

      expect(updated1!.phase, equals(PlantPhase.bloom));
      expect(updated2!.phase, equals(PlantPhase.bloom));

      expect(updated1.bloomDate, equals(DateTime(2025, 2, 1)),
          reason: 'Plant 1 bloomDate should be set');
      expect(updated2.bloomDate, equals(DateTime(2025, 2, 1)),
          reason: 'Plant 2 bloomDate should be set');

      expect(updated1.vegDate, equals(DateTime(2025, 1, 15)),
          reason: 'Plant 1 vegDate should remain unchanged');
      expect(updated2.vegDate, equals(DateTime(2025, 1, 15)),
          reason: 'Plant 2 vegDate should remain unchanged');
    });
  });
}
