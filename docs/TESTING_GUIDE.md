# Testing Guide - Plantry

## Warum Tests schreiben?

**CI/CD testet NICHT automatisch deine Business-Logic!**

Git/GitHub führen nur Tests aus, die **DU schreibst**. Ohne Tests kann CI/CD keine Bugs finden.

## Aktuelle Test-Coverage

✅ **Gut getestet (114 Tests):**
- LogService (27 Tests)
- PlantRepository (28 Tests)
- GrowRepository (32 Tests)
- Fertilizer Model (5 Tests)
- User Journey (2 Tests)

❌ **KEINE Tests:**
- 10 von 13 Repositories (0 Tests!)
- RdwcRepository (CRITICAL!)
- FertilizerRepository
- HardwareRepository
- HarvestRepository
- RoomRepository
- SettingsRepository
- PhotoRepository
- NotificationRepository
- PlantLogRepository
- LogFertilizerRepository
- 45+ Screens
- 8+ Services

## Beispiel: Repository-Test schreiben

### 1. Test-Datei erstellen
```bash
# Für FertilizerRepository:
touch test/repositories/fertilizer_repository_test.dart
```

### 2. Test-Template verwenden
```dart
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

  group('FertilizerRepository - findAll()', () {
    test('should return all fertilizers', () async {
      // Act
      final fertilizers = await repository.findAll();

      // Assert
      expect(fertilizers, isNotEmpty);
      expect(fertilizers.length, greaterThan(0));
    });
  });

  group('FertilizerRepository - create()', () {
    test('should create new fertilizer and return ID', () async {
      // Arrange
      final fert = Fertilizer(
        name: 'New Fertilizer',
        brand: 'Test Brand',
        type: FertilizerType.base,
        npk: '10-10-10',
      );

      // Act
      final id = await repository.create(fert);

      // Assert
      expect(id, greaterThan(0));

      // Verify in database
      final saved = await repository.findById(id);
      expect(saved, isNotNull);
      expect(saved!.name, equals('New Fertilizer'));
    });
  });

  group('FertilizerRepository - delete()', () {
    test('should delete fertilizer', () async {
      // Arrange
      final fert = Fertilizer(name: 'To Delete', type: FertilizerType.base);
      final id = await repository.create(fert);

      // Act
      final deleted = await repository.delete(id);

      // Assert
      expect(deleted, equals(1));

      // Verify deletion
      final found = await repository.findById(id);
      expect(found, isNull);
    });
  });
}
```

### 3. Test ausführen
```bash
# Einzelner Test:
flutter test test/repositories/fertilizer_repository_test.dart

# Alle Tests:
flutter test

# Mit Coverage:
flutter test --coverage
```

## Was solltest du testen?

### ✅ IMMER testen:
- **CRUD Operationen** (Create, Read, Update, Delete)
- **Validierung** (Input-Validation, Error-Handling)
- **Business-Logic** (Berechnungen, Formeln)
- **Edge Cases** (Leere Listen, null-Werte, ungültige Inputs)
- **Kritische User-Flows** (Login, Checkout, Datenverlust)

### ❌ NICHT unbedingt testen:
- Getter/Setter ohne Logic
- Framework-Code (Flutter selbst)
- Externe Libraries

## Kritische Bereiche zuerst

**Priorisierung nach Risiko:**

### P0 (SOFORT testen):
1. **RdwcRepository** - RDWC-System kritisch für Daten
2. **FertilizerRepository** - Rezept-Daten wichtig
3. **HarvestRepository** - Ernte-Daten wertvoll

### P1 (Diese Woche):
4. **RoomRepository** - Raum-Management
5. **HardwareRepository** - Hardware-Tracking
6. **SettingsRepository** - App-Konfiguration

### P2 (Nächster Sprint):
7. **PhotoRepository** - Foto-Management
8. **PlantLogRepository** - Log-Queries
9. **NotificationRepository** - Benachrichtigungen

## Test-Driven Development (TDD)

**Best Practice für neue Features:**

```bash
# 1. Test schreiben (RED)
test('should calculate total harvest weight', () {
  final harvest = Harvest(wetWeight: 100, dryWeight: 20);
  expect(harvest.totalWeight, equals(120));
});

# 2. Code implementieren (GREEN)
class Harvest {
  final double wetWeight;
  final double dryWeight;
  double get totalWeight => wetWeight + dryWeight;
}

# 3. Test läuft durch ✅

# 4. Refactoren (REFACTOR)
# Code verbessern ohne Funktionalität zu ändern
```

## Coverage-Ziel

**Minimum:** 70% Code-Coverage

**Aktuell:** ~30-40% (geschätzt)

**Prüfen:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html  # Öffne Report im Browser
```

## Pre-Commit Hook

Der Pre-Commit Hook führt **DEINE Tests** aus:

```bash
# Vor jedem Commit automatisch:
✅ dart format
✅ flutter analyze
✅ flutter test  # ← Führt NUR existierende Tests aus!
```

**Tests überspringen (Notfall):**
```bash
NO_TEST=1 git commit -m "message"
```

## Zusammenfassung

| Tool | Was es macht | Was es NICHT macht |
|------|--------------|-------------------|
| `flutter analyze` | Findet Syntax-Fehler | Findet keine Logic-Bugs |
| `dart format` | Formatiert Code | Testet keine Funktionalität |
| `flutter test` | Führt Tests aus | Schreibt keine Tests |
| **CI/CD** | Blockiert bei Failures | Findet keine ungetesteten Bugs |

**🎯 Fazit: Du musst Tests schreiben, damit CI/CD Bugs finden kann!**
