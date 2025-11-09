# Integration Tests for Plant Repository, Grow Repository, and Log Service

## Problem: DatabaseHelper Singleton Pattern

The current implementation uses `DatabaseHelper.instance` as a singleton with a private `_database` field. This makes it impossible to directly inject a test database for integration testing without modifying the production code.

## Solution Options

### Option 1: Modify Production Code (Recommended)
Add a test-friendly method to DatabaseHelper:

```dart
// In database_helper.dart
@visibleForTesting
static void setTestDatabase(Database? db) {
  _database = db;
}
```

### Option 2: Use Test Database Files
Instead of in-memory databases, use actual database files that are deleted between tests.

### Option 3: Repository Constructor Injection
Modify repositories to accept DatabaseHelper as a constructor parameter:

```dart
class PlantRepository {
  final DatabaseHelper _dbHelper;
  
  PlantRepository({DatabaseHelper? dbHelper}) 
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;
}
```

### Option 4: Test at Database Level
Write tests that directly use SQL queries instead of repository methods.

## Current Status

The integration test files have been created with comprehensive test cases, but they cannot run without one of the above modifications. The test files are:

1. `test/repositories/plant_repository_integration_test.dart` - 300+ lines, 40+ test cases
2. `test/services/log_service_integration_test.dart` - 850+ lines, 30+ test cases  
3. `test/repositories/grow_repository_integration_test.dart` - 550+ lines, 35+ test cases

All tests follow the AAA pattern (Arrange, Act, Assert) and include:
- Success cases
- Edge cases
- Error handling
- Data validation
- Transaction testing
- Cascade delete verification

## Required Setup

1. Install sqlite3 library:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install libsqlite3-dev
   
   # macOS
   brew install sqlite3
   ```

2. Choose and implement one of the solution options above

3. Run tests:
   ```bash
   flutter test test/repositories/plant_repository_integration_test.dart
   flutter test test/services/log_service_integration_test.dart
   flutter test test/repositories/grow_repository_integration_test.dart
   ```

## Test Database Schema

The `TestDatabaseHelper` creates an in-memory database with the complete schema matching production database v10, including:
- All tables (plants, grows, rooms, logs, fertilizers, etc.)
- Foreign key constraints
- Indexes
- Default values
- Seed data for common test scenarios

