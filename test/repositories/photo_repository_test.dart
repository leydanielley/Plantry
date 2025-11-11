// =============================================
// GROWLOG - PhotoRepository Integration Tests
// =============================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:growlog_app/repositories/photo_repository.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/photo.dart';
import 'package:path/path.dart' as path;
import '../helpers/test_database_helper.dart';

void main() {
  late Database testDb;
  late PhotoRepository repository;
  late int testPlantId;
  late int testLogId;
  late String testPhotoDir;

  setUpAll(() {
    TestDatabaseHelper.initFfi();
  });

  setUp(() async {
    testDb = await TestDatabaseHelper.createTestDatabase();
    DatabaseHelper.setTestDatabase(testDb);
    repository = PhotoRepository();
    await TestDatabaseHelper.seedTestData(testDb);

    // Create test plant and log
    testPlantId = await testDb.insert('plants', {
      'name': 'Test Plant for Photos',
      'seed_type': 'REGULAR',
      'medium': 'SOIL',
      'phase': 'VEG',
    });

    testLogId = await testDb.insert('plant_logs', {
      'plant_id': testPlantId,
      'day_number': 10,
      'log_date': DateTime.now().toIso8601String(),
      'action_type': 'WATERING',
      'phase': 'VEG',
    });

    // Create test photo directory
    testPhotoDir = path.join(Directory.systemTemp.path, 'test_photos');
    await Directory(testPhotoDir).create(recursive: true);
  });

  tearDown(() async {
    // Clean up test photo directory
    final dir = Directory(testPhotoDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    await testDb.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('PhotoRepository - CRUD Operations', () {
    test('save() - should create new photo', () async {
      // Arrange
      final testFile = File(path.join(testPhotoDir, 'test1.jpg'));
      await testFile.writeAsString('test image data');

      final photo = Photo(logId: testLogId, filePath: testFile.path);

      // Act
      final id = await repository.save(photo);

      // Assert
      expect(id, greaterThan(0));

      final found = await repository.getById(id);
      expect(found, isNotNull);
      expect(found!.logId, equals(testLogId));
      expect(found.filePath, equals(testFile.path));
    });

    test('save() - should update existing photo', () async {
      // Arrange
      final testFile1 = File(path.join(testPhotoDir, 'test1.jpg'));
      await testFile1.writeAsString('test image data 1');

      final photo = Photo(logId: testLogId, filePath: testFile1.path);
      final id = await repository.save(photo);

      // Create new file for update
      final testFile2 = File(path.join(testPhotoDir, 'test2.jpg'));
      await testFile2.writeAsString('test image data 2');

      // Act
      final updated = photo.copyWith(id: id, filePath: testFile2.path);
      final resultId = await repository.save(updated);

      // Assert
      expect(resultId, equals(id));

      final found = await repository.getById(id);
      expect(found, isNotNull);
      expect(found!.filePath, equals(testFile2.path));
    });

    test('getById() - should return photo when exists', () async {
      // Arrange
      final testFile = File(path.join(testPhotoDir, 'test.jpg'));
      await testFile.writeAsString('test image data');

      final photo = Photo(logId: testLogId, filePath: testFile.path);
      final id = await repository.save(photo);

      // Act
      final found = await repository.getById(id);

      // Assert
      expect(found, isNotNull);
      expect(found!.id, equals(id));
      expect(found.logId, equals(testLogId));
    });

    test('getById() - should return null when not exists', () async {
      // Act
      final found = await repository.getById(99999);

      // Assert
      expect(found, isNull);
    });

    test('delete() - should remove photo and file', () async {
      // Arrange
      final testFile = File(path.join(testPhotoDir, 'to_delete.jpg'));
      await testFile.writeAsString('test image data');

      final photo = Photo(logId: testLogId, filePath: testFile.path);
      final id = await repository.save(photo);

      // Act
      final deleted = await repository.delete(id);

      // Assert
      expect(deleted, equals(1));
      expect(await testFile.exists(), isFalse);

      final found = await repository.getById(id);
      expect(found, isNull);
    });

    test('delete() - should handle missing file gracefully', () async {
      // Arrange
      final testFile = File(path.join(testPhotoDir, 'missing.jpg'));
      // Don't create the file

      final photo = Photo(logId: testLogId, filePath: testFile.path);
      final id = await repository.save(photo);

      // Act
      final deleted = await repository.delete(id);

      // Assert - Should still delete DB record
      expect(deleted, equals(1));

      final found = await repository.getById(id);
      expect(found, isNull);
    });

    test('deletePhoto() - should be alias for delete()', () async {
      // Arrange
      final testFile = File(path.join(testPhotoDir, 'alias_test.jpg'));
      await testFile.writeAsString('test image data');

      final photo = Photo(logId: testLogId, filePath: testFile.path);
      final id = await repository.save(photo);

      // Act
      final deleted = await repository.deletePhoto(id);

      // Assert
      expect(deleted, equals(1));

      final found = await repository.getById(id);
      expect(found, isNull);
    });
  });

  group('PhotoRepository - Query Operations', () {
    test('getPhotosByLogId() - should return photos for a log', () async {
      // Arrange - Create 3 photos for the log
      for (int i = 1; i <= 3; i++) {
        final testFile = File(path.join(testPhotoDir, 'log_photo_$i.jpg'));
        await testFile.writeAsString('test image data $i');

        final photo = Photo(logId: testLogId, filePath: testFile.path);
        await repository.save(photo);
      }

      // Act
      final photos = await repository.getPhotosByLogId(testLogId);

      // Assert
      expect(photos, isNotEmpty);
      expect(photos.length, greaterThanOrEqualTo(3));
      for (final photo in photos) {
        expect(photo.logId, equals(testLogId));
      }
    });

    test(
      'getPhotosByLogId() - should return empty list for log without photos',
      () async {
        // Arrange - Create another log without photos
        final emptyLogId = await testDb.insert('plant_logs', {
          'plant_id': testPlantId,
          'day_number': 11,
          'log_date': DateTime.now().toIso8601String(),
          'action_type': 'WATERING',
          'phase': 'VEG',
        });

        // Act
        final photos = await repository.getPhotosByLogId(emptyLogId);

        // Assert
        expect(photos, isEmpty);
      },
    );

    test('getPhotosByLogId() - should order by created_at DESC', () async {
      // Arrange - Create photos with different timestamps
      final photo1 = Photo(
        logId: testLogId,
        filePath: path.join(testPhotoDir, 'photo1.jpg'),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final photo2 = Photo(
        logId: testLogId,
        filePath: path.join(testPhotoDir, 'photo2.jpg'),
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final photo3 = Photo(
        logId: testLogId,
        filePath: path.join(testPhotoDir, 'photo3.jpg'),
        createdAt: DateTime.now(),
      );

      await repository.save(photo1);
      await repository.save(photo2);
      await repository.save(photo3);

      // Act
      final photos = await repository.getPhotosByLogId(testLogId);

      // Assert - Should be in reverse chronological order
      expect(photos, isNotEmpty);
      expect(photos.length, greaterThanOrEqualTo(3));
      // Most recent first
      expect(
        photos.first.createdAt.isAfter(photos.last.createdAt) ||
            photos.first.createdAt.isAtSameMomentAs(photos.last.createdAt),
        isTrue,
      );
    });

    test(
      'getPhotosByPlantId() - should return all photos for a plant',
      () async {
        // Arrange - Create 2 logs with photos
        final log1 = await testDb.insert('plant_logs', {
          'plant_id': testPlantId,
          'day_number': 15,
          'log_date': DateTime.now().toIso8601String(),
          'action_type': 'WATERING',
          'phase': 'VEG',
        });

        final log2 = await testDb.insert('plant_logs', {
          'plant_id': testPlantId,
          'day_number': 52,
          'log_date': DateTime.now().toIso8601String(),
          'action_type': 'WATERING',
          'phase': 'BLOOM',
        });

        // Create photos for both logs
        for (final logId in [log1, log2]) {
          for (int i = 1; i <= 2; i++) {
            final testFile = File(
              path.join(testPhotoDir, 'plant_photo_${logId}_$i.jpg'),
            );
            await testFile.writeAsString('test image data');

            final photo = Photo(logId: logId, filePath: testFile.path);
            await repository.save(photo);
          }
        }

        // Act
        final photos = await repository.getPhotosByPlantId(testPlantId);

        // Assert - Should return photos from both logs
        expect(photos, isNotEmpty);
        expect(photos.length, greaterThanOrEqualTo(4));
      },
    );

    test('getPhotosByPlantId(limit) - should respect limit', () async {
      // Arrange - Create 5 photos
      for (int i = 1; i <= 5; i++) {
        final testFile = File(path.join(testPhotoDir, 'limit_photo_$i.jpg'));
        await testFile.writeAsString('test image data $i');

        final photo = Photo(logId: testLogId, filePath: testFile.path);
        await repository.save(photo);
      }

      // Act
      final photos = await repository.getPhotosByPlantId(testPlantId, limit: 3);

      // Assert
      expect(photos.length, equals(3));
    });

    test('getPhotosByPlantId(limit + offset) - should respect both', () async {
      // Arrange - Create 5 photos
      final photoIds = <int>[];
      for (int i = 1; i <= 5; i++) {
        final testFile = File(path.join(testPhotoDir, 'offset_photo_$i.jpg'));
        await testFile.writeAsString('test image data $i');

        final photo = Photo(logId: testLogId, filePath: testFile.path);
        final id = await repository.save(photo);
        photoIds.add(id);
      }

      // Act - Skip first 2 photos, return next 2
      final photos = await repository.getPhotosByPlantId(
        testPlantId,
        limit: 2,
        offset: 2,
      );

      // Assert
      expect(photos.length, equals(2));
    });
  });

  group('PhotoRepository - Batch Operations', () {
    test('getPhotosByLogIds() - should return photos grouped by log', () async {
      // Arrange - Create 2 logs with photos
      final log1 = await testDb.insert('plant_logs', {
        'plant_id': testPlantId,
        'day_number': 16,
        'log_date': DateTime.now().toIso8601String(),
        'action_type': 'WATERING',
        'phase': 'VEG',
      });

      final log2 = await testDb.insert('plant_logs', {
        'plant_id': testPlantId,
        'day_number': 53,
        'log_date': DateTime.now().toIso8601String(),
        'action_type': 'WATERING',
        'phase': 'BLOOM',
      });

      // Create 2 photos for log1, 3 photos for log2
      for (int i = 1; i <= 2; i++) {
        final testFile = File(path.join(testPhotoDir, 'batch_log1_$i.jpg'));
        await testFile.writeAsString('test image data');

        final photo = Photo(logId: log1, filePath: testFile.path);
        await repository.save(photo);
      }

      for (int i = 1; i <= 3; i++) {
        final testFile = File(path.join(testPhotoDir, 'batch_log2_$i.jpg'));
        await testFile.writeAsString('test image data');

        final photo = Photo(logId: log2, filePath: testFile.path);
        await repository.save(photo);
      }

      // Act
      final result = await repository.getPhotosByLogIds([log1, log2]);

      // Assert
      expect(result, isNotEmpty);
      expect(result.containsKey(log1), isTrue);
      expect(result.containsKey(log2), isTrue);
      expect(result[log1]!.length, equals(2));
      expect(result[log2]!.length, equals(3));
    });

    test(
      'getPhotosByLogIds() - should return empty map for empty list',
      () async {
        // Act
        final result = await repository.getPhotosByLogIds([]);

        // Assert
        expect(result, isEmpty);
      },
    );

    test('getPhotosByLogIds() - should handle logs without photos', () async {
      // Arrange - Create log without photos
      final emptyLog = await testDb.insert('plant_logs', {
        'plant_id': testPlantId,
        'day_number': 14,
        'log_date': DateTime.now().toIso8601String(),
        'action_type': 'WATERING',
        'phase': 'VEG',
      });

      // Act
      final result = await repository.getPhotosByLogIds([emptyLog]);

      // Assert
      expect(result, isEmpty);
    });

    test('deleteByLogId() - should delete all photos for a log', () async {
      // Arrange - Create 3 photos for the log
      for (int i = 1; i <= 3; i++) {
        final testFile = File(path.join(testPhotoDir, 'delete_batch_$i.jpg'));
        await testFile.writeAsString('test image data $i');

        final photo = Photo(logId: testLogId, filePath: testFile.path);
        await repository.save(photo);
      }

      // Act
      await repository.deleteByLogId(testLogId);

      // Assert
      final photos = await repository.getPhotosByLogId(testLogId);
      expect(photos, isEmpty);

      // Verify files are deleted
      for (int i = 1; i <= 3; i++) {
        final testFile = File(path.join(testPhotoDir, 'delete_batch_$i.jpg'));
        expect(await testFile.exists(), isFalse);
      }
    });
  });

  group('PhotoRepository - Validation', () {
    test('save() - should throw for invalid log ID', () async {
      // Act & Assert
      expect(
        () => Photo(
          logId: 0, // Invalid
          filePath: '/path/to/photo.jpg',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('save() - should throw for empty file path', () async {
      // Act & Assert
      expect(
        () => Photo(
          logId: testLogId,
          filePath: '', // Invalid
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('save() - should throw for invalid file path format', () async {
      // Arrange
      final photo = Photo(
        logId: testLogId,
        filePath: 'invalidpath', // No separators
      );

      // Act & Assert
      expect(() => repository.save(photo), throwsArgumentError);
    });
  });
}
