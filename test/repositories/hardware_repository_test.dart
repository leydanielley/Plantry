// =============================================
// GROWLOG - HardwareRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/hardware_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/hardware.dart';
import 'package:growlog_app/models/enums.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late HardwareRepository repository;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    repository = HardwareRepository();
    await TestDatabaseHelper.seedTestData(testDb);
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('HardwareRepository - CRUD Operations', () {
    test('findAll() - should return all hardware', () async {
      // Arrange - Create hardware
      await repository.save(
        Hardware(roomId: 1, name: 'Test Hardware', type: HardwareType.ledPanel),
      );

      // Act
      final hardware = await repository.findAll();

      // Assert
      expect(hardware, isNotEmpty);
      expect(hardware.length, greaterThanOrEqualTo(1));
    });

    test('findAll(limit) - should respect limit', () async {
      // Arrange - Create multiple hardware items
      for (int i = 1; i <= 5; i++) {
        await repository.save(
          Hardware(roomId: 1, name: 'Hardware $i', type: HardwareType.ledPanel),
        );
      }

      // Act
      final hardware = await repository.findAll(limit: 3);

      // Assert
      expect(hardware.length, equals(3));
    });

    test('findById() - should return hardware when exists', () async {
      // Arrange - Create hardware
      final created = await repository.save(
        Hardware(
          roomId: 1,
          name: 'Test LED Panel',
          type: HardwareType.ledPanel,
          wattage: 600,
        ),
      );

      // Act
      final found = await repository.findById(created.id!);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(created.id));
      expect(found.name, equals('Test LED Panel'));
      expect(found.type, equals(HardwareType.ledPanel));
      expect(found.wattage, equals(600));
    });

    test('findById() - should return null when not exists', () async {
      // Act
      final hardware = await repository.findById(99999);

      // Assert
      expect(hardware, isNull);
    });

    test('save() - should create new hardware with all properties', () async {
      // Arrange
      final hardware = Hardware(
        roomId: 1,
        name: 'Premium LED Panel',
        type: HardwareType.ledPanel,
        brand: 'TestBrand',
        model: 'TB-1000',
        wattage: 1000,
        quantity: 2,
        spectrum: 'Full Spectrum',
        dimmable: true,
      );

      // Act
      final saved = await repository.save(hardware);

      // Assert
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.name, equals('Premium LED Panel'));
      expect(found.brand, equals('TestBrand'));
      expect(found.model, equals('TB-1000'));
      expect(found.wattage, equals(1000));
      expect(found.quantity, equals(2));
      expect(found.spectrum, equals('Full Spectrum'));
      expect(found.dimmable, isTrue);
    });

    test('save() - should create hardware with minimal data', () async {
      // Arrange - Only required fields
      final hardware = Hardware(
        roomId: 1,
        name: 'Minimal Hardware',
        type: HardwareType.other,
      );

      // Act
      final saved = await repository.save(hardware);

      // Assert
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.name, equals('Minimal Hardware'));
      expect(found.quantity, equals(1)); // Default value
      expect(found.active, isTrue); // Default value
    });

    test('save() - should update existing hardware', () async {
      // Arrange
      final hardware = Hardware(
        roomId: 1,
        name: 'Original Name',
        type: HardwareType.ledPanel,
        wattage: 500,
      );
      final saved = await repository.save(hardware);

      // Act
      final updated = saved.copyWith(
        name: 'Updated Name',
        wattage: 800,
        brand: 'New Brand',
      );
      final result = await repository.save(updated);

      // Assert
      expect(result.id, equals(saved.id));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.name, equals('Updated Name'));
      expect(found.wattage, equals(800));
      expect(found.brand, equals('New Brand'));
    });

    test('delete() - should remove hardware', () async {
      // Arrange
      final hardware = Hardware(
        roomId: 1,
        name: 'To Delete',
        type: HardwareType.other,
      );
      final saved = await repository.save(hardware);

      // Act
      final deleted = await repository.delete(saved.id!);

      // Assert
      expect(deleted, equals(1));

      final found = await repository.findById(saved.id!);
      expect(found, isNull);
    });

    test('delete() - should return 0 for non-existent hardware', () async {
      // Act
      final deleted = await repository.delete(99999);

      // Assert
      expect(deleted, equals(0));
    });
  });

  group('HardwareRepository - Room Queries', () {
    test('findByRoom() - should return hardware for specific room', () async {
      // Arrange - Create hardware in different rooms
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Room 1 Hardware',
          type: HardwareType.ledPanel,
        ),
      );

      // Act
      final hardware = await repository.findByRoom(1);

      // Assert
      expect(hardware, isNotEmpty);
      for (final item in hardware) {
        expect(item.roomId, equals(1));
      }
    });

    test(
      'findByRoom() - should return empty list for room with no hardware',
      () async {
        // Act
        final hardware = await repository.findByRoom(999);

        // Assert
        expect(hardware, isEmpty);
      },
    );

    test('findActiveByRoom() - should return only active hardware', () async {
      // Arrange - Create active and inactive hardware
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Active Hardware',
          type: HardwareType.ledPanel,
          active: true,
        ),
      );

      final inactive = await repository.save(
        Hardware(
          roomId: 1,
          name: 'Inactive Hardware',
          type: HardwareType.hpsLamp,
          active: false,
        ),
      );

      // Act
      final hardware = await repository.findActiveByRoom(1);

      // Assert
      expect(hardware, isNotEmpty);
      for (final item in hardware) {
        expect(item.active, isTrue);
        expect(item.id, isNot(equals(inactive.id)));
      }
    });

    test('countByRoom() - should return correct count', () async {
      // Arrange - Create hardware
      await repository.save(
        Hardware(roomId: 1, name: 'Hardware 1', type: HardwareType.ledPanel),
      );
      await repository.save(
        Hardware(roomId: 1, name: 'Hardware 2', type: HardwareType.exhaustFan),
      );

      // Act
      final count = await repository.countByRoom(1);

      // Assert
      expect(count, greaterThanOrEqualTo(2));
    });

    test('getTotalWattageByRoom() - should calculate total wattage', () async {
      // Arrange - Create hardware with wattage
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'LED Panel',
          type: HardwareType.ledPanel,
          wattage: 600,
          quantity: 2, // 600 * 2 = 1200W
        ),
      );
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Exhaust Fan',
          type: HardwareType.exhaustFan,
          wattage: 100,
          quantity: 1, // 100 * 1 = 100W
        ),
      );
      // Total = 1300W

      // Act
      final totalWattage = await repository.getTotalWattageByRoom(1);

      // Assert
      expect(totalWattage, equals(1300));
    });

    test(
      'getTotalWattageByRoom() - should return 0 for room with no hardware',
      () async {
        // Act
        final totalWattage = await repository.getTotalWattageByRoom(999);

        // Assert
        expect(totalWattage, equals(0));
      },
    );
  });

  group('HardwareRepository - Activation Management', () {
    test('deactivate() - should mark hardware as inactive', () async {
      // Arrange
      final hardware = await repository.save(
        Hardware(
          roomId: 1,
          name: 'To Deactivate',
          type: HardwareType.ledPanel,
          active: true,
        ),
      );

      // Act
      final updated = await repository.deactivate(hardware.id!);

      // Assert
      expect(updated, equals(1));

      final found = await repository.findById(hardware.id!);
      expect(found, isNotNull);
      expect(found!.active, isFalse);
    });

    test('activate() - should mark hardware as active', () async {
      // Arrange
      final hardware = await repository.save(
        Hardware(
          roomId: 1,
          name: 'To Activate',
          type: HardwareType.ledPanel,
          active: false,
        ),
      );

      // Act
      final updated = await repository.activate(hardware.id!);

      // Assert
      expect(updated, equals(1));

      final found = await repository.findById(hardware.id!);
      expect(found, isNotNull);
      expect(found!.active, isTrue);
    });

    test('deactivate() - should return 0 for non-existent hardware', () async {
      // Act
      final updated = await repository.deactivate(99999);

      // Assert
      expect(updated, equals(0));
    });

    test('activate() - should return 0 for non-existent hardware', () async {
      // Act
      final updated = await repository.activate(99999);

      // Assert
      expect(updated, equals(0));
    });
  });

  group('HardwareRepository - Edge Cases', () {
    test('save() - should handle all hardware types', () async {
      // Test all hardware types
      final types = [
        HardwareType.ledPanel,
        HardwareType.hpsLamp,
        HardwareType.mhLamp,
        HardwareType.cflLamp,
        HardwareType.exhaustFan,
        HardwareType.circulationFan,
        HardwareType.airConditioner,
        HardwareType.other,
      ];

      for (final type in types) {
        // Arrange
        final hardware = Hardware(
          roomId: 1,
          name: 'Hardware ${type.name}',
          type: type,
        );

        // Act
        final saved = await repository.save(hardware);

        // Assert
        final found = await repository.findById(saved.id!);
        expect(found, isNotNull);
        expect(found!.type, equals(type));
      }
    });

    test('save() - should handle hardware with purchase info', () async {
      // Arrange
      final purchaseDate = DateTime(2024, 1, 15);
      final hardware = Hardware(
        roomId: 1,
        name: 'Purchased Hardware',
        type: HardwareType.ledPanel,
        purchaseDate: purchaseDate,
        purchasePrice: 599.99,
        notes: 'Bought on sale',
      );

      // Act
      final saved = await repository.save(hardware);

      // Assert
      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.purchaseDate, isNotNull);
      expect(found.purchaseDate!.year, equals(2024));
      expect(found.purchaseDate!.month, equals(1));
      expect(found.purchaseDate!.day, equals(15));
      expect(found.purchasePrice, equals(599.99));
      expect(found.notes, equals('Bought on sale'));
    });

    test('save() - should calculate total wattage correctly', () async {
      // Arrange
      final hardware = Hardware(
        roomId: 1,
        name: 'Multi LED',
        type: HardwareType.ledPanel,
        wattage: 300,
        quantity: 4,
      );

      // Act
      final saved = await repository.save(hardware);

      // Assert
      expect(saved.totalWattage, equals(1200)); // 300 * 4
    });

    test('save() - should handle hardware with specific features', () async {
      // Arrange - Exhaust Fan with specific features
      final fan = Hardware(
        roomId: 1,
        name: 'Premium Exhaust Fan',
        type: HardwareType.exhaustFan,
        wattage: 150,
        airflow: 550, // m³/h
        flangeSize: '150mm',
        controllable: true,
        dimmable: true,
      );

      // Act
      final saved = await repository.save(fan);

      // Assert
      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.airflow, equals(550));
      expect(found.flangeSize, equals('150mm'));
      expect(found.controllable, isTrue);
      expect(found.dimmable, isTrue);
    });

    test('countByRoom() - should only count active hardware', () async {
      // Arrange - Create active and inactive hardware
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Active 1',
          type: HardwareType.ledPanel,
          active: true,
        ),
      );
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Active 2',
          type: HardwareType.exhaustFan,
          active: true,
        ),
      );
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Inactive',
          type: HardwareType.hpsLamp,
          active: false,
        ),
      );

      // Act
      final count = await repository.countByRoom(1);

      // Assert
      expect(count, equals(2)); // Only active hardware
    });

    test('getTotalWattageByRoom() - should only sum active hardware', () async {
      // Arrange
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Active LED',
          type: HardwareType.ledPanel,
          wattage: 600,
          quantity: 1,
          active: true,
        ),
      );
      await repository.save(
        Hardware(
          roomId: 1,
          name: 'Inactive LED',
          type: HardwareType.ledPanel,
          wattage: 800,
          quantity: 1,
          active: false, // Should not be counted
        ),
      );

      // Act
      final totalWattage = await repository.getTotalWattageByRoom(1);

      // Assert
      expect(totalWattage, equals(600)); // Only active hardware
    });
  });
}
