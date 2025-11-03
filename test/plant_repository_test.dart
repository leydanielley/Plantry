// =============================================
// GROWLOG - Plant Repository Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/enums.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PlantRepository Tests', () {
    late Database db;

    setUp(() async {
      // Jeder Test bekommt seine eigene In-Memory DB!
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            // Minimales Schema für Tests
            await db.execute('''
              CREATE TABLE plants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                breeder TEXT,
                strain TEXT,
                feminized INTEGER DEFAULT 1,
                seed_type TEXT NOT NULL,
                medium TEXT NOT NULL,
                phase TEXT DEFAULT 'SEEDLING',
                room_id INTEGER,
                grow_id INTEGER,
                seed_date TEXT,
                phase_start_date TEXT,
                created_at TEXT DEFAULT (datetime('now')),
                created_by TEXT,
                log_profile_name TEXT DEFAULT 'standard',
                archived INTEGER DEFAULT 0,
                current_container_size REAL,
                current_system_size REAL
              )
            ''');
          },
        ),
      );

      // Note: In a real scenario, you'd inject the DB or use a mock
      // PlantRepository would need to accept a Database parameter
    });

    tearDown(() async {
      await db.close();
    });

    test('Plant Model - Serialisierung funktioniert', () async {
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.coco,
      );

      final map = plant.toMap();
      expect(map['name'], equals('Test Plant'));
      expect(map['seed_type'], equals('PHOTO'));

      final reconstructed = Plant.fromMap(map);
      expect(reconstructed.name, equals(plant.name));
    });

    test('Container Info Formatierung', () {
      final plant1 = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.coco,
        currentContainerSize: 11.0,
      );

      final plant2 = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.rdwc,
        currentSystemSize: 80.0,
      );

      expect(plant1.containerInfo, contains('11L Topf'));
      expect(plant2.containerInfo, contains('80L System'));
    });
  });
}