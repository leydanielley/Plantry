// =============================================
// GROWLOG - RoomRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/room_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late RoomRepository repository;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    repository = RoomRepository();
    await TestDatabaseHelper.seedTestData(testDb);
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('RoomRepository - CRUD Operations', () {
    test('findAll() - should return all rooms', () async {
      // Act
      final rooms = await repository.findAll();

      // Assert - Seed data has at least 1 room
      expect(rooms, isNotEmpty);
      expect(rooms.length, greaterThanOrEqualTo(1));
    });

    test('findAll(limit) - should respect limit', () async {
      // Arrange - Create multiple rooms
      await repository.save(Room(name: 'Room 1'));
      await repository.save(Room(name: 'Room 2'));
      await repository.save(Room(name: 'Room 3'));

      // Act
      final rooms = await repository.findAll(limit: 2);

      // Assert
      expect(rooms.length, equals(2));
    });

    test('findById() - should return room when exists', () async {
      // Arrange - Create a room
      final created = await repository.save(
        Room(name: 'Test Room', description: 'Test Description'),
      );

      // Act
      final found = await repository.findById(created.id!);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(created.id));
      expect(found.name, equals('Test Room'));
      expect(found.description, equals('Test Description'));
    });

    test('findById() - should return null when not exists', () async {
      // Act
      final room = await repository.findById(99999);

      // Assert
      expect(room, isNull);
    });

    test('save() - should create new room with all properties', () async {
      // Arrange
      final room = Room(
        name: 'Grow Room A',
        description: 'Indoor grow space',
        growType: GrowType.indoor,
        wateringSystem: WateringSystem.drip,
        width: 2.5,
        depth: 3.0,
        height: 2.2,
      );

      // Act
      final saved = await repository.save(room);

      // Assert
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.name, equals('Grow Room A'));
      expect(found.description, equals('Indoor grow space'));
      expect(found.growType, equals(GrowType.indoor));
      expect(found.wateringSystem, equals(WateringSystem.drip));
      expect(found.width, equals(2.5));
      expect(found.depth, equals(3.0));
      expect(found.height, equals(2.2));
    });

    test('save() - should create room with minimal data', () async {
      // Arrange - Only required field
      final room = Room(name: 'Minimal Room');

      // Act
      final saved = await repository.save(room);

      // Assert
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.name, equals('Minimal Room'));
      expect(found.description, isNull);
      expect(found.growType, isNull);
      expect(found.width, equals(0.0));
    });

    test('save() - should update existing room', () async {
      // Arrange
      final room = Room(
        name: 'Original Name',
        description: 'Original Description',
      );
      final saved = await repository.save(room);

      // Act
      final updated = saved.copyWith(
        name: 'Updated Name',
        description: 'Updated Description',
        growType: GrowType.outdoor,
        width: 5.0,
      );
      final result = await repository.save(updated);

      // Assert
      expect(result.id, equals(saved.id));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.name, equals('Updated Name'));
      expect(found.description, equals('Updated Description'));
      expect(found.growType, equals(GrowType.outdoor));
      expect(found.width, equals(5.0));
    });

    test('delete() - should remove unused room', () async {
      // Arrange
      final room = Room(name: 'To Delete');
      final saved = await repository.save(room);

      // Act
      final deleted = await repository.delete(saved.id!);

      // Assert
      expect(deleted, equals(1));

      final found = await repository.findById(saved.id!);
      expect(found, isNull);
    });

    test('delete() - should return 0 for non-existent room', () async {
      // Act
      final deleted = await repository.delete(99999);

      // Assert
      expect(deleted, equals(0));
    });

    test('count() - should return total count', () async {
      // Arrange - Get initial count
      final initialCount = await repository.count();

      // Add 2 rooms
      await repository.save(Room(name: 'Room 1'));
      await repository.save(Room(name: 'Room 2'));

      // Act
      final finalCount = await repository.count();

      // Assert
      expect(finalCount, equals(initialCount + 2));
    });
  });

  group('RoomRepository - Usage Tracking', () {
    test('isInUse() - should return false for unused room', () async {
      // Arrange
      final room = Room(name: 'Unused Room');
      final saved = await repository.save(room);

      // Act
      final inUse = await repository.isInUse(saved.id!);

      // Assert
      expect(inUse, isFalse);
    });

    test(
      'getUsageDetails() - should return zero counts for unused room',
      () async {
        // Arrange
        final room = Room(name: 'Empty Room');
        final saved = await repository.save(room);

        // Act
        final usage = await repository.getUsageDetails(saved.id!);

        // Assert
        expect(usage, isNotNull);
        expect(usage.containsKey('plants'), isTrue);
        expect(usage.containsKey('grows'), isTrue);
        expect(usage.containsKey('hardware'), isTrue);
        expect(usage.containsKey('rdwc_systems'), isTrue);
        expect(usage['plants'], equals(0));
        expect(usage['grows'], equals(0));
        expect(usage['hardware'], equals(0));
        expect(usage['rdwc_systems'], equals(0));
      },
    );

    test('getUsageDetails() - should return correct structure', () async {
      // Arrange
      final room = Room(name: 'Test Room');
      final saved = await repository.save(room);

      // Act
      final usage = await repository.getUsageDetails(saved.id!);

      // Assert - Check structure
      expect(usage, hasLength(4));
      expect(
        usage.keys,
        containsAll(['plants', 'grows', 'hardware', 'rdwc_systems']),
      );
      for (final count in usage.values) {
        expect(count, isA<int>());
        expect(count, greaterThanOrEqualTo(0));
      }
    });
  });

  group('RoomRepository - Edge Cases', () {
    test('findAll() - should return empty list when no rooms', () async {
      // Arrange - Delete all rooms
      final all = await repository.findAll();
      for (final room in all) {
        await repository.delete(room.id!);
      }

      // Act
      final rooms = await repository.findAll();

      // Assert
      expect(rooms, isEmpty);
    });

    test('count() - should return 0 when no rooms', () async {
      // Arrange - Delete all rooms
      final all = await repository.findAll();
      for (final room in all) {
        await repository.delete(room.id!);
      }

      // Act
      final count = await repository.count();

      // Assert
      expect(count, equals(0));
    });

    test('save() - should handle room with all watering systems', () async {
      // Test all watering system types
      final systems = [
        WateringSystem.manual,
        WateringSystem.drip,
        WateringSystem.autopot,
        WateringSystem.rdwc,
        WateringSystem.floodDrain,
      ];

      for (final system in systems) {
        // Arrange
        final room = Room(name: 'Room ${system.name}', wateringSystem: system);

        // Act
        final saved = await repository.save(room);

        // Assert
        final found = await repository.findById(saved.id!);
        expect(found, isNotNull);
        expect(found!.wateringSystem, equals(system));
      }
    });

    test('save() - should handle room with all grow types', () async {
      // Test all grow types
      final types = [GrowType.indoor, GrowType.outdoor, GrowType.greenhouse];

      for (final type in types) {
        // Arrange
        final room = Room(name: 'Room ${type.name}', growType: type);

        // Act
        final saved = await repository.save(room);

        // Assert
        final found = await repository.findById(saved.id!);
        expect(found, isNotNull);
        expect(found!.growType, equals(type));
      }
    });

    test('save() - should calculate volume and area correctly', () async {
      // Arrange
      final room = Room(name: 'Math Room', width: 3.0, depth: 4.0, height: 2.5);

      // Act
      final saved = await repository.save(room);
      final found = await repository.findById(saved.id!);

      // Assert
      expect(found, isNotNull);
      expect(found!.volume, equals(30.0)); // 3 * 4 * 2.5
      expect(found.area, equals(12.0)); // 3 * 4
    });

    test('save() - should preserve timestamps', () async {
      // Arrange
      final room = Room(name: 'Time Test');

      // Act
      final saved = await repository.save(room);

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 10));

      // Update
      final updated = saved.copyWith(description: 'Updated');
      final result = await repository.save(updated);

      // Assert
      expect(result.createdAt, equals(saved.createdAt));
      expect(
        result.updatedAt.isAfter(saved.updatedAt) ||
            result.updatedAt.isAtSameMomentAs(saved.updatedAt),
        isTrue,
      );
    });
  });

  group('RoomRepository - Delete Protection', () {
    test(
      'delete() - should throw RepositoryException for room in use',
      () async {
        // Arrange - Create room with a plant (simulated by seed data)
        // The seed data creates rooms with plants
        final rooms = await repository.findAll();

        // Find a room from seed data that might have plants
        Room? roomToTest;
        for (final room in rooms) {
          final inUse = await repository.isInUse(room.id!);
          if (inUse) {
            roomToTest = room;
            break;
          }
        }

        // If we found a room in use, test delete protection
        if (roomToTest != null) {
          // Act & Assert
          expect(
            () => repository.delete(roomToTest!.id!),
            throwsA(isA<RepositoryException>()),
          );
        }
      },
    );
  });
}
