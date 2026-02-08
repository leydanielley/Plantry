// =============================================
// GROWLOG - Delete Validation Tests
// Tests for Fix #3: canDeleteRoom() and canDeleteGrow()
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/hardware.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/room_repository.dart';
import 'package:growlog_app/repositories/grow_repository.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/hardware_repository.dart';
import 'package:growlog_app/repositories/repository_error_handler.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database db;
  late RoomRepository roomRepo;
  late GrowRepository growRepo;
  late PlantRepository plantRepo;
  late HardwareRepository hardwareRepo;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    db = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(db);

    // Initialize repositories
    roomRepo = RoomRepository();
    growRepo = GrowRepository();
    plantRepo = PlantRepository();
    hardwareRepo = HardwareRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('Fix #3: Room Delete Validation', () {
    test('canDeleteRoom() returns true for unused room', () async {
      // Arrange: Create empty room
      final room = await roomRepo.save(Room(
        name: 'Empty Room',
        growType: GrowType.indoor,
      ));

      // Act
      final canDelete = await roomRepo.canDeleteRoom(room.id!);

      // Assert
      expect(canDelete, true, reason: 'Empty room should be deletable');
    });

    test('canDeleteRoom() returns false for room with plants', () async {
      // Arrange: Create room with plant
      final room = await roomRepo.save(Room(
        name: 'Room with Plants',
        growType: GrowType.indoor,
      ));

      await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        roomId: room.id,
      ));

      // Act
      final canDelete = await roomRepo.canDeleteRoom(room.id!);

      // Assert
      expect(canDelete, false, reason: 'Room with plants should not be deletable');
    });

    test('canDeleteRoom() returns false for room with hardware', () async {
      // Arrange: Create room with hardware
      final room = await roomRepo.save(Room(
        name: 'Room with Hardware',
        growType: GrowType.indoor,
      ));

      await hardwareRepo.save(Hardware(
        roomId: room.id!,
        name: 'LED Light',
        type: HardwareType.light,
      ));

      // Act
      final canDelete = await roomRepo.canDeleteRoom(room.id!);

      // Assert
      expect(canDelete, false, reason: 'Room with hardware should not be deletable');
    });

    test('delete() successfully archives unused room', () async {
      // Arrange: Create empty room
      final room = await roomRepo.save(Room(
        name: 'Room to Delete',
        growType: GrowType.indoor,
      ));

      // Act
      final result = await roomRepo.delete(room.id!);

      // Assert
      expect(result, 1, reason: 'Should archive 1 room');

      // Verify room is archived (not returned by default findAll)
      final rooms = await roomRepo.findAll();
      expect(rooms.where((r) => r.id == room.id), isEmpty,
          reason: 'Archived room should not be in default findAll');

      // Verify room still exists in DB with archived=1
      final archivedRooms = await roomRepo.findArchived();
      expect(archivedRooms.where((r) => r.id == room.id), isNotEmpty,
          reason: 'Room should be in archived list');
    });

    test('delete() throws RepositoryException for room with plants', () async {
      // Arrange: Create room with plant
      final room = await roomRepo.save(Room(
        name: 'Room with Plant',
        growType: GrowType.indoor,
      ));

      await plantRepo.save(Plant(
        name: 'Blocking Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        roomId: room.id,
      ));

      // Act & Assert
      expect(
        () => roomRepo.delete(room.id!),
        throwsA(isA<RepositoryException>().having(
          (e) => e.type,
          'type',
          RepositoryErrorType.conflict,
        )),
        reason: 'Should throw conflict exception',
      );
    });

    test('delete() error message includes plant count in German', () async {
      // Arrange: Create room with 2 plants
      final room = await roomRepo.save(Room(
        name: 'Room with 2 Plants',
        growType: GrowType.indoor,
      ));

      await plantRepo.save(Plant(
        name: 'Plant 1',
        seedType: SeedType.photo,
        medium: Medium.erde,
        roomId: room.id,
      ));

      await plantRepo.save(Plant(
        name: 'Plant 2',
        seedType: SeedType.auto,
        medium: Medium.coco,
        roomId: room.id,
      ));

      // Act & Assert
      try {
        await roomRepo.delete(room.id!);
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<RepositoryException>());
        final exception = e as RepositoryException;
        expect(exception.message, contains('2 Pflanzen'),
            reason: 'Error should mention 2 plants in German');
        expect(exception.message, contains('kann nicht gelöscht werden'),
            reason: 'Error should be in German');
      }
    });

    test('delete() error message includes hardware count in German', () async {
      // Arrange: Create room with hardware
      final room = await roomRepo.save(Room(
        name: 'Room with Hardware',
        growType: GrowType.indoor,
      ));

      await hardwareRepo.save(Hardware(
        roomId: room.id!,
        name: 'LED Panel',
        type: HardwareType.light,
      ));

      // Act & Assert
      try {
        await roomRepo.delete(room.id!);
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<RepositoryException>());
        final exception = e as RepositoryException;
        expect(exception.message, contains('Hardware-Gerät'),
            reason: 'Error should mention hardware in German');
      }
    });

    test('delete() error message handles multiple dependency types', () async {
      // Arrange: Create room with plant AND hardware
      final room = await roomRepo.save(Room(
        name: 'Busy Room',
        growType: GrowType.indoor,
      ));

      await plantRepo.save(Plant(
        name: 'Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        roomId: room.id,
      ));

      await hardwareRepo.save(Hardware(
        roomId: room.id!,
        name: 'Light',
        type: HardwareType.light,
      ));

      // Act & Assert
      try {
        await roomRepo.delete(room.id!);
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<RepositoryException>());
        final exception = e as RepositoryException;
        expect(exception.message, contains('Pflanze'),
            reason: 'Error should mention plant');
        expect(exception.message, contains('Hardware-Gerät'),
            reason: 'Error should mention hardware');
      }
    });
  });

  group('Fix #3: Grow Delete Validation', () {
    test('canDeleteGrow() returns true for grow without plants', () async {
      // Arrange: Create empty grow
      final growId = await growRepo.create(Grow(
        name: 'Empty Grow',
        startDate: DateTime(2025, 1, 1),
      ));

      // Act
      final canDelete = await growRepo.canDeleteGrow(growId);

      // Assert
      expect(canDelete, true, reason: 'Empty grow should be deletable');
    });

    test('canDeleteGrow() returns false for grow with plants', () async {
      // Arrange: Create grow with plant
      final growId = await growRepo.create(Grow(
        name: 'Grow with Plants',
        startDate: DateTime(2025, 1, 1),
      ));

      await plantRepo.save(Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        growId: growId,
      ));

      // Act
      final canDelete = await growRepo.canDeleteGrow(growId);

      // Assert
      expect(canDelete, false, reason: 'Grow with plants should not be deletable');
    });

    test('delete() successfully deletes grow without plants', () async {
      // Arrange: Create empty grow
      final growId = await growRepo.create(Grow(
        name: 'Grow to Delete',
        startDate: DateTime(2025, 1, 1),
      ));

      // Act
      final result = await growRepo.delete(growId);

      // Assert
      expect(result, 1, reason: 'Should delete 1 grow');

      // Verify grow is deleted
      final grows = await growRepo.getAll();
      expect(grows.where((g) => g.id == growId), isEmpty,
          reason: 'Grow should be deleted');
    });

    test('delete() throws RepositoryException for grow with plants', () async {
      // Arrange: Create grow with plant
      final growId = await growRepo.create(Grow(
        name: 'Grow with Plant',
        startDate: DateTime(2025, 1, 1),
      ));

      await plantRepo.save(Plant(
        name: 'Blocking Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        growId: growId,
      ));

      // Act & Assert
      expect(
        () => growRepo.delete(growId),
        throwsA(isA<RepositoryException>().having(
          (e) => e.type,
          'type',
          RepositoryErrorType.conflict,
        )),
        reason: 'Should throw conflict exception',
      );
    });

    test('delete() error message includes plant count in German', () async {
      // Arrange: Create grow with 3 plants
      final growId = await growRepo.create(Grow(
        name: 'Grow with 3 Plants',
        startDate: DateTime(2025, 1, 1),
      ));

      for (int i = 1; i <= 3; i++) {
        await plantRepo.save(Plant(
          name: 'Plant $i',
          seedType: SeedType.photo,
          medium: Medium.erde,
          growId: growId,
        ));
      }

      // Act & Assert
      try {
        await growRepo.delete(growId);
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<RepositoryException>());
        final exception = e as RepositoryException;
        expect(exception.message, contains('3 Pflanzen'),
            reason: 'Error should mention 3 plants in German');
        expect(exception.message, contains('kann nicht gelöscht werden'),
            reason: 'Error should be in German');
        expect(exception.message, contains('archivieren'),
            reason: 'Error should suggest archiving');
      }
    });

    test('delete() error uses singular "Pflanze" for one plant', () async {
      // Arrange: Create grow with 1 plant
      final growId = await growRepo.create(Grow(
        name: 'Grow with 1 Plant',
        startDate: DateTime(2025, 1, 1),
      ));

      await plantRepo.save(Plant(
        name: 'Single Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        growId: growId,
      ));

      // Act & Assert
      try {
        await growRepo.delete(growId);
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<RepositoryException>());
        final exception = e as RepositoryException;
        // Should use singular form "1 Pflanze" not "1 Pflanzen"
        expect(exception.message, contains('1 Pflanze'),
            reason: 'Should use singular form for 1 plant');
        expect(exception.message, isNot(contains('1 Pflanzen')),
            reason: 'Should NOT use plural form for 1 plant');
      }
    });

    test('archive() works as alternative to delete()', () async {
      // Arrange: Create grow with plant
      final growId = await growRepo.create(Grow(
        name: 'Grow to Archive',
        startDate: DateTime(2025, 1, 1),
      ));

      await plantRepo.save(Plant(
        name: 'Plant',
        seedType: SeedType.photo,
        medium: Medium.erde,
        growId: growId,
      ));

      // Act: Archive instead of delete
      final result = await growRepo.archive(growId);

      // Assert
      expect(result, 1, reason: 'Should archive 1 grow');

      // Verify grow is archived
      final activeGrows = await growRepo.getAll(includeArchived: false);
      expect(activeGrows.where((g) => g.id == growId), isEmpty,
          reason: 'Archived grow should not be in active list');

      final allGrows = await growRepo.getAll(includeArchived: true);
      final archivedGrow = allGrows.firstWhere((g) => g.id == growId);
      expect(archivedGrow.archived, true,
          reason: 'Grow should be marked as archived');
    });
  });
}
