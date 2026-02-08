# How to Run Integration Tests

## Step 1: Apply Database Helper Patch

The integration tests require a small modification to `DatabaseHelper` to allow test database injection.

Apply the patch:

```bash
cd /home/danielworkstation/Programme/ide/Github/Plantry/Plantry
patch -p1 < test/database_helper_test_support.patch
```

Or manually add this method to `lib/database/database_helper.dart`:

```dart
import 'package:flutter/foundation.dart'; // Add this import at the top

// Add this method after DatabaseHelper._init():
/// Allows test database injection (only for testing!)
/// This method should only be called from test code
@visibleForTesting
static void setTestDatabase(Database? db) {
  _database = db;
}
```

## Step 2: Ensure SQLite3 is Installed

```bash
# Ubuntu/Debian
sudo apt-get install libsqlite3-dev

# macOS
brew install sqlite3

# Arch Linux
sudo pacman -S sqlite
```

## Step 3: Run the Tests

```bash
# Run all integration tests
flutter test test/repositories/ test/services/

# Run individual test files
flutter test test/repositories/plant_repository_integration_test.dart
flutter test test/services/log_service_integration_test.dart
flutter test test/repositories/grow_repository_integration_test.dart

# Run specific test group
flutter test test/repositories/plant_repository_integration_test.dart --name="save()"

# Run with verbose output
flutter test test/repositories/plant_repository_integration_test.dart --reporter expanded
```

## Test Coverage

### Plant Repository Tests (40+ test cases)
- Creating and updating plants
- Finding plants by ID, room, RDWC system
- Deleting and archiving plants
- Day number recalculation when seed dates change
- Phase day number recalculation
- Pagination support
- Error handling

### Log Service Tests (30+ test cases)
- Creating single logs with fertilizers
- Creating bulk logs for multiple plants
- Updating existing logs
- Copying logs
- Deleting logs
- Input validation (pH, EC, temperature, humidity, etc.)
- Transaction handling
- Plant phase updates
- Container size tracking

### Grow Repository Tests (35+ test cases)
- Creating and updating grows
- Finding grows by ID
- Archiving and unarchiving grows
- Plant count tracking
- Batch plant count queries
- Phase updates for all plants in a grow
- Cascade operations
- Error handling

## Test Structure

All tests follow the AAA pattern:
- **Arrange**: Set up test data and prerequisites
- **Act**: Execute the method being tested
- **Assert**: Verify the results with expect() statements

Example:
```dart
test('Creating new plant - should insert and return plant with ID', () async {
  // Arrange
  final plant = Plant(name: 'Test', seedType: SeedType.photo, medium: Medium.erde);
  
  // Act
  final savedPlant = await repository.save(plant);
  
  // Assert
  expect(savedPlant.id, isNotNull);
  expect(savedPlant.name, equals('Test'));
});
```

## Troubleshooting

### Error: "Failed to load dynamic library 'libsqlite3.so'"
- Install libsqlite3-dev package (see Step 2)

### Error: "setTestDatabase is not defined"
- Apply the database helper patch (see Step 1)

### Tests are failing unexpectedly
- Ensure database schema in TestDatabaseHelper matches production schema
- Check that setUp() and tearDown() are properly cleaning up between tests
- Verify seed data in TestDatabaseHelper

### Tests run but database changes persist between tests
- Check that tearDown() is calling DatabaseHelper.setTestDatabase(null)
- Verify that each test gets a fresh database instance

## Maintaining Tests

When adding new fields to models:
1. Update the schema in `test/helpers/test_database_helper.dart`
2. Update test cases to include new fields
3. Add validation tests if the field has constraints

When adding new repository methods:
1. Add corresponding test cases
2. Test both success and failure scenarios
3. Test edge cases (null values, empty lists, etc.)
