// =============================================
// GROWLOG - FertilizerRepository Integration Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/fertilizer_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/fertilizer.dart';
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late FertilizerRepository repository;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    repository = FertilizerRepository();
    await TestDatabaseHelper.seedTestData(testDb);
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('FertilizerRepository - CRUD Operations', () {
    test('findAll() - should return all fertilizers', () async {
      // Act
      final fertilizers = await repository.findAll();

      // Assert - Seed data has 2 fertilizers
      expect(fertilizers.length, greaterThanOrEqualTo(2));
    });

    test('findAll(limit) - should respect limit', () async {
      // Act
      final fertilizers = await repository.findAll(limit: 1);

      // Assert
      expect(fertilizers.length, equals(1));
    });

    test('findById() - should return fertilizer when exists', () async {
      // Arrange - ID 1 from seed data
      // Act
      final fertilizer = await repository.findById(1);

      // Assert
      expect(fertilizer, isNotNull);
      expect(fertilizer!.name, equals('Test Fertilizer A'));
    });

    test('findById() - should return null when not exists', () async {
      // Act
      final fertilizer = await repository.findById(99999);

      // Assert
      expect(fertilizer, isNull);
    });

    test('save() - should create new fertilizer', () async {
      // Arrange
      final fertilizer = Fertilizer(
        name: 'New Fertilizer',
        brand: 'Test Brand',
        type: 'base',
        npk: '10-5-5',
      );

      // Act
      final saved = await repository.save(fertilizer);

      // Assert
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final found = await repository.findById(saved.id!);
      expect(found, isNotNull);
      expect(found!.name, equals('New Fertilizer'));
      expect(found.npk, equals('10-5-5'));
    });

    test('save() - should update existing fertilizer', () async {
      // Arrange
      final fertilizer = Fertilizer(name: 'To Update', type: 'base');
      final saved = await repository.save(fertilizer);

      // Act
      final updated = saved.copyWith(name: 'Updated Name', brand: 'New Brand');
      final result = await repository.save(updated);

      // Assert
      expect(result.id, equals(saved.id));

      final found = await repository.findById(saved.id!);
      expect(found!.name, equals('Updated Name'));
      expect(found.brand, equals('New Brand'));
    });

    test('delete() - should remove fertilizer', () async {
      // Arrange
      final fertilizer = Fertilizer(name: 'To Delete', type: 'base');
      final saved = await repository.save(fertilizer);

      // Act
      final deleted = await repository.delete(saved.id!);

      // Assert
      expect(deleted, equals(1));

      final found = await repository.findById(saved.id!);
      expect(found, isNull);
    });

    test('count() - should return total count', () async {
      // Act
      final count = await repository.count();

      // Assert - Seed data has 2 fertilizers
      expect(count, greaterThanOrEqualTo(2));
    });
  });

  group('FertilizerRepository - Usage Tracking', () {
    test('isInUse() - should return false for unused fertilizer', () async {
      // Arrange
      final fertilizer = Fertilizer(name: 'Unused', type: 'base');
      final saved = await repository.save(fertilizer);

      // Act
      final inUse = await repository.isInUse(saved.id!);

      // Assert
      expect(inUse, isFalse);
    });

    test('getUsageDetails() - should return usage counts', () async {
      // Arrange
      final fertilizer = Fertilizer(name: 'Usage Test', type: 'base');
      final saved = await repository.save(fertilizer);

      // Act
      final usage = await repository.getUsageDetails(saved.id!);

      // Assert
      expect(usage, isNotNull);
      expect(usage.containsKey('plantLogs'), isTrue);
      expect(usage.containsKey('rdwcLogs'), isTrue);
      expect(usage.containsKey('templates'), isTrue);
      expect(usage['plantLogs'], equals(0));
    });
  });

  group('FertilizerRepository - Edge Cases', () {
    test('save() - should handle minimal fertilizer', () async {
      // Arrange - Only required fields
      final fertilizer = Fertilizer(name: 'Minimal', type: 'base');

      // Act
      final saved = await repository.save(fertilizer);

      // Assert
      expect(saved.id, greaterThan(0));
      expect(saved.name, equals('Minimal'));
    });

    test('findAll() - should return empty list when no fertilizers', () async {
      // Arrange - Delete all fertilizers
      final all = await repository.findAll();
      for (final fert in all) {
        await repository.delete(fert.id!);
      }

      // Act
      final fertilizers = await repository.findAll();

      // Assert
      expect(fertilizers, isEmpty);
    });

    test('delete() - should return 0 for non-existent fertilizer', () async {
      // Act
      final deleted = await repository.delete(99999);

      // Assert
      expect(deleted, equals(0));
    });
  });
}
