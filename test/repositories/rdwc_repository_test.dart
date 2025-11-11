// =============================================
// GROWLOG - RdwcRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/rdwc_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late RdwcRepository repository;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    repository = RdwcRepository();
    await TestDatabaseHelper.seedTestData(testDb);
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('RdwcRepository - CRUD Operations', () {
    test('createSystem() - should create new system', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Test RDWC System',
        roomId: 1,
        maxCapacity: 100.0,
        currentLevel: 90.0,
        bucketCount: 4,
      );

      // Act
      final id = await repository.createSystem(system);

      // Assert
      expect(id, greaterThan(0));

      final found = await repository.getSystemById(id);
      expect(found, isNotNull);
      expect(found!.name, equals('Test RDWC System'));
      expect(found.maxCapacity, equals(100.0));
      expect(found.bucketCount, equals(4));
    });

    test(
      'createSystem() - should create system with all pump/chiller specs',
      () async {
        // Arrange
        final system = RdwcSystem(
          name: 'Premium RDWC System',
          roomId: 1,
          maxCapacity: 200.0,
          currentLevel: 180.0,
          bucketCount: 8,
          pumpBrand: 'Hailea',
          pumpModel: 'HX-6550',
          pumpWattage: 55,
          airPumpBrand: 'Hailea',
          airPumpModel: 'HAP-120',
          airPumpWattage: 120,
          chillerBrand: 'Teco',
          chillerModel: 'TK-500',
          chillerWattage: 200,
          description: 'Premium setup',
        );

        // Act
        final id = await repository.createSystem(system);

        // Assert
        final found = await repository.getSystemById(id);
        expect(found, isNotNull);
        expect(found!.pumpBrand, equals('Hailea'));
        expect(found.pumpModel, equals('HX-6550'));
        expect(found.pumpWattage, equals(55));
        expect(found.airPumpBrand, equals('Hailea'));
        expect(found.airPumpWattage, equals(120));
        expect(found.chillerBrand, equals('Teco'));
        expect(found.chillerWattage, equals(200));
        expect(found.description, equals('Premium setup'));
      },
    );

    test('createSystem() - should create system with minimal data', () async {
      // Arrange - Only required fields
      final system = RdwcSystem(
        name: 'Minimal System',
        maxCapacity: 50.0,
        currentLevel: 50.0,
        bucketCount: 2,
      );

      // Act
      final id = await repository.createSystem(system);

      // Assert
      expect(id, greaterThan(0));

      final found = await repository.getSystemById(id);
      expect(found, isNotNull);
      expect(found!.name, equals('Minimal System'));
      expect(found.bucketCount, equals(2));
      expect(found.archived, isFalse);
    });

    test('updateSystem() - should update existing system', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Original Name',
        maxCapacity: 100.0,
        currentLevel: 90.0,
        bucketCount: 4,
      );
      final id = await repository.createSystem(system);

      // Act
      final updated = system.copyWith(
        id: id,
        name: 'Updated Name',
        currentLevel: 85.0,
        pumpBrand: 'New Pump Brand',
      );
      final result = await repository.updateSystem(updated);

      // Assert
      expect(result, equals(1));

      final found = await repository.getSystemById(id);
      expect(found, isNotNull);
      expect(found!.name, equals('Updated Name'));
      expect(found.currentLevel, equals(85.0));
      expect(found.pumpBrand, equals('New Pump Brand'));
    });

    test('getSystemById() - should return system when exists', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Find Me',
        maxCapacity: 100.0,
        currentLevel: 90.0,
        bucketCount: 4,
      );
      final id = await repository.createSystem(system);

      // Act
      final found = await repository.getSystemById(id);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(id));
      expect(found.name, equals('Find Me'));
    });

    test('getSystemById() - should return null when not exists', () async {
      // Act
      final found = await repository.getSystemById(99999);

      // Assert
      expect(found, isNull);
    });

    test('deleteSystem() - should remove system', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'To Delete',
        maxCapacity: 100.0,
        currentLevel: 90.0,
        bucketCount: 4,
      );
      final id = await repository.createSystem(system);

      // Act
      final deleted = await repository.deleteSystem(id);

      // Assert
      expect(deleted, equals(1));

      final found = await repository.getSystemById(id);
      expect(found, isNull);
    });

    test('deleteSystem() - should return 0 for non-existent system', () async {
      // Act
      final deleted = await repository.deleteSystem(99999);

      // Assert
      expect(deleted, equals(0));
    });
  });

  group('RdwcRepository - Query Operations', () {
    test('getAllSystems() - should return all non-archived systems', () async {
      // Arrange - Create 2 active systems
      await repository.createSystem(
        RdwcSystem(
          name: 'Active System 1',
          maxCapacity: 100.0,
          currentLevel: 90.0,
          bucketCount: 4,
          archived: false,
        ),
      );
      await repository.createSystem(
        RdwcSystem(
          name: 'Active System 2',
          maxCapacity: 150.0,
          currentLevel: 140.0,
          bucketCount: 6,
          archived: false,
        ),
      );

      // Act
      final systems = await repository.getAllSystems();

      // Assert
      expect(systems, isNotEmpty);
      expect(systems.length, greaterThanOrEqualTo(2));
      for (final system in systems) {
        expect(system.archived, isFalse);
      }
    });

    test(
      'getAllSystems() - should exclude archived systems by default',
      () async {
        // Arrange - Create 1 active and 1 archived system
        await repository.createSystem(
          RdwcSystem(
            name: 'Active System',
            maxCapacity: 100.0,
            currentLevel: 90.0,
            bucketCount: 4,
            archived: false,
          ),
        );

        final archivedId = await repository.createSystem(
          RdwcSystem(
            name: 'Archived System',
            maxCapacity: 100.0,
            currentLevel: 90.0,
            bucketCount: 4,
            archived: true,
          ),
        );

        // Act
        final systems = await repository.getAllSystems();

        // Assert
        expect(systems, isNotEmpty);
        final systemIds = systems.map((s) => s.id).toList();
        expect(systemIds, isNot(contains(archivedId)));
      },
    );

    test(
      'getAllSystems(includeArchived: true) - should include archived',
      () async {
        // Arrange - Create 1 active and 1 archived system
        await repository.createSystem(
          RdwcSystem(
            name: 'Active System',
            maxCapacity: 100.0,
            currentLevel: 90.0,
            bucketCount: 4,
            archived: false,
          ),
        );

        final archivedId = await repository.createSystem(
          RdwcSystem(
            name: 'Archived System',
            maxCapacity: 100.0,
            currentLevel: 90.0,
            bucketCount: 4,
            archived: true,
          ),
        );

        // Act
        final systems = await repository.getAllSystems(includeArchived: true);

        // Assert
        expect(systems, isNotEmpty);
        expect(systems.length, greaterThanOrEqualTo(2));
        final systemIds = systems.map((s) => s.id).toList();
        expect(systemIds, contains(archivedId));
      },
    );

    test(
      'getSystemsByRoom() - should return systems for specific room',
      () async {
        // Arrange - Create systems in different rooms
        await repository.createSystem(
          RdwcSystem(
            name: 'Room 1 System',
            roomId: 1,
            maxCapacity: 100.0,
            currentLevel: 90.0,
            bucketCount: 4,
          ),
        );

        await testDb.insert('rooms', {
          'id': 2,
          'name': 'Test Room 2',
          'grow_type': 'INDOOR',
        });

        await repository.createSystem(
          RdwcSystem(
            name: 'Room 2 System',
            roomId: 2,
            maxCapacity: 150.0,
            currentLevel: 140.0,
            bucketCount: 6,
          ),
        );

        // Act
        final systems = await repository.getSystemsByRoom(1);

        // Assert
        expect(systems, isNotEmpty);
        for (final system in systems) {
          expect(system.roomId, equals(1));
        }
      },
    );

    test(
      'getSystemsByRoom() - should return empty list for room without systems',
      () async {
        // Arrange - Create room without systems
        await testDb.insert('rooms', {
          'id': 99,
          'name': 'Empty Room',
          'grow_type': 'INDOOR',
        });

        // Act
        final systems = await repository.getSystemsByRoom(99);

        // Assert
        expect(systems, isEmpty);
      },
    );

    test('getSystemsByGrow() - should return systems used in a grow', () async {
      // Arrange - Create RDWC system assigned to grow
      final systemId = await repository.createSystem(
        RdwcSystem(
          name: 'Grow System',
          roomId: 1,
          growId: 1, // Directly assign system to grow
          maxCapacity: 100.0,
          currentLevel: 90.0,
          bucketCount: 4,
        ),
      );

      // Act
      final systems = await repository.getSystemsByGrow(1);

      // Assert
      expect(systems, isNotEmpty);
      expect(systems.length, greaterThanOrEqualTo(1));
      expect(systems.first.id, equals(systemId));
    });

    test(
      'getSystemsByGrow() - should return empty list for grow without systems',
      () async {
        // Arrange - Create grow without RDWC systems
        await testDb.insert('grows', {
          'id': 99,
          'name': 'Grow Without RDWC',
          'start_date': DateTime.now().toIso8601String(),
        });

        // Act
        final systems = await repository.getSystemsByGrow(99);

        // Assert
        expect(systems, isEmpty);
      },
    );
  });

  group('RdwcRepository - Archive Management', () {
    test('archiveSystem() - should mark system as archived', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'To Archive',
        maxCapacity: 100.0,
        currentLevel: 90.0,
        bucketCount: 4,
        archived: false,
      );
      final id = await repository.createSystem(system);

      // Act
      await repository.archiveSystem(id, true);

      // Assert
      final found = await repository.getSystemById(id);
      expect(found, isNotNull);
      expect(found!.archived, isTrue);
    });

    test('archiveSystem() - should mark system as not archived', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'To Unarchive',
        maxCapacity: 100.0,
        currentLevel: 90.0,
        bucketCount: 4,
        archived: true,
      );
      final id = await repository.createSystem(system);

      // Act
      await repository.archiveSystem(id, false);

      // Assert
      final found = await repository.getSystemById(id);
      expect(found, isNotNull);
      expect(found!.archived, isFalse);
    });
  });

  group('RdwcRepository - Edge Cases', () {
    test(
      'createSystem() - should handle multiple systems in same room',
      () async {
        // Arrange
        final system1 = RdwcSystem(
          name: 'System 1',
          roomId: 1,
          maxCapacity: 100.0,
          currentLevel: 90.0,
          bucketCount: 4,
        );
        final system2 = RdwcSystem(
          name: 'System 2',
          roomId: 1,
          maxCapacity: 150.0,
          currentLevel: 140.0,
          bucketCount: 6,
        );

        // Act
        final id1 = await repository.createSystem(system1);
        final id2 = await repository.createSystem(system2);

        // Assert
        expect(id1, isNotNull);
        expect(id2, isNotNull);
        expect(id1, isNot(equals(id2)));

        final roomSystems = await repository.getSystemsByRoom(1);
        expect(roomSystems.length, greaterThanOrEqualTo(2));
      },
    );

    test(
      'createSystem() - should handle system without room assignment',
      () async {
        // Arrange - No room_id
        final system = RdwcSystem(
          name: 'Unassigned System',
          maxCapacity: 100.0,
          currentLevel: 90.0,
          bucketCount: 4,
        );

        // Act
        final id = await repository.createSystem(system);

        // Assert
        expect(id, greaterThan(0));

        final found = await repository.getSystemById(id);
        expect(found, isNotNull);
        expect(found!.roomId, isNull);
      },
    );

    test('remainingCapacity - should calculate correctly', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Capacity Test',
        maxCapacity: 100.0,
        currentLevel: 75.0,
        bucketCount: 4,
      );

      // Act
      final id = await repository.createSystem(system);
      final found = await repository.getSystemById(id);

      // Assert
      expect(found!.remainingCapacity, equals(25.0)); // 100 - 75
    });

    test('isFull - should return true when system is full', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Full System',
        maxCapacity: 100.0,
        currentLevel: 100.0,
        bucketCount: 4,
      );

      // Act
      final id = await repository.createSystem(system);
      final found = await repository.getSystemById(id);

      // Assert
      expect(found!.isFull, isTrue);
    });

    test('createSystem() - should handle empty system', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Empty System',
        maxCapacity: 100.0,
        currentLevel: 0.0,
        bucketCount: 4,
      );

      // Act
      final id = await repository.createSystem(system);
      final found = await repository.getSystemById(id);

      // Assert
      expect(found!.currentLevel, equals(0.0));
      expect(found.remainingCapacity, equals(100.0));
    });

    test(
      'getAllSystems() - should return empty list when no systems',
      () async {
        // Act
        final systems = await repository.getAllSystems();

        // Assert - Default seed data has no RDWC systems
        expect(systems, isEmpty);
      },
    );

    test('updateSystemLevel() - should update current level', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Level Test',
        maxCapacity: 100.0,
        currentLevel: 100.0,
        bucketCount: 4,
      );
      final id = await repository.createSystem(system);

      // Act - Update current level (simulating water consumption)
      await repository.updateSystemLevel(id, 90.0);

      var found = await repository.getSystemById(id);
      expect(found!.currentLevel, equals(90.0));

      await repository.updateSystemLevel(id, 80.0);

      // Assert
      found = await repository.getSystemById(id);
      expect(found!.currentLevel, equals(80.0));
    });

    test('fillPercentage - should calculate correctly', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Fill Test',
        maxCapacity: 100.0,
        currentLevel: 50.0,
        bucketCount: 4,
      );

      // Act
      final id = await repository.createSystem(system);
      final found = await repository.getSystemById(id);

      // Assert
      expect(found!.fillPercentage, equals(50.0)); // 50 / 100 * 100
    });

    test('isLowWater - should return true when below 30%', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Low Water Test',
        maxCapacity: 100.0,
        currentLevel: 25.0, // 25%
        bucketCount: 4,
      );

      // Act
      final id = await repository.createSystem(system);
      final found = await repository.getSystemById(id);

      // Assert
      expect(found!.isLowWater, isTrue);
    });

    test('isCriticallyLow - should return true when below 15%', () async {
      // Arrange
      final system = RdwcSystem(
        name: 'Critical Test',
        maxCapacity: 100.0,
        currentLevel: 10.0, // 10%
        bucketCount: 4,
      );

      // Act
      final id = await repository.createSystem(system);
      final found = await repository.getSystemById(id);

      // Assert
      expect(found!.isCriticallyLow, isTrue);
    });

    test('deleteSystem() - should detach plants from system', () async {
      // Arrange
      final systemId = await repository.createSystem(
        RdwcSystem(
          name: 'System to Delete',
          roomId: 1,
          maxCapacity: 100.0,
          currentLevel: 90.0,
          bucketCount: 4,
        ),
      );

      // Create plant attached to system
      await testDb.insert('plants', {
        'name': 'Test Plant',
        'seed_type': 'REGULAR',
        'medium': 'HYDRO',
        'phase': 'VEG',
        'grow_id': 1,
        'rdwc_system_id': systemId,
        'bucket_number': 1,
      });

      // Act
      await repository.deleteSystem(systemId);

      // Assert
      final plants = await testDb.query(
        'plants',
        where: 'name = ?',
        whereArgs: ['Test Plant'],
      );

      expect(plants, isNotEmpty);
      expect(plants.first['rdwc_system_id'], isNull);
      expect(plants.first['bucket_number'], isNull);
    });
  });
}
