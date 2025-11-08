// =============================================
// GROWLOG - All Database Migrations Registry
// =============================================

import '../migration.dart';
import 'migration_v8.dart';
import 'migration_v9.dart';
import 'migration_v10.dart';

/// All migrations in chronological order
///
/// IMPORTANT RULES:
/// 1. NEVER modify existing migrations after they've been released
/// 2. NEVER delete old migrations (users might be upgrading from old versions)
/// 3. NEVER skip version numbers (always increment by 1)
/// 4. ALWAYS add new migrations to the END of this list
/// 5. ALWAYS test migrations from ALL previous versions
///
/// How to add a new migration:
/// 1. Create a new file: lib/database/migrations/scripts/migration_v{X}.dart
/// 2. Import it at the top of this file
/// 3. Add it to the list below
/// 4. Update database version in database_helper.dart
/// 5. Test the migration thoroughly
final List<Migration> allMigrations = [
  // v8: RDWC Expert Mode - Advanced nutrient tracking & recipes
  migrationV8,

  // v9: CRITICAL FIX - Change fertilizer CASCADE → RESTRICT constraints
  migrationV9,

  // v10: Phase History System - veg_date, bloom_date, harvest_date
  migrationV10,
];

/// Get the latest migration version
///
/// Returns the highest version number in the migrations list.
/// If no migrations exist, returns 2 (the current base version).
int get latestMigrationVersion {
  if (allMigrations.isEmpty) {
    return 2; // Current base version
  }

  return allMigrations
      .map((m) => m.version)
      .reduce((a, b) => a > b ? a : b);
}

/// Get the oldest migration version
int get oldestMigrationVersion {
  if (allMigrations.isEmpty) {
    return 2;
  }

  return allMigrations
      .map((m) => m.version)
      .reduce((a, b) => a < b ? a : b);
}

/// Check if migrations exist for a specific upgrade path
bool canMigrate(int fromVersion, int toVersion) {
  if (fromVersion == toVersion) return true;
  if (fromVersion > toVersion) return false;

  final migrationsNeeded = allMigrations
      .where((m) => m.version > fromVersion && m.version <= toVersion)
      .toList();

  // Check for gaps in version numbers
  migrationsNeeded.sort((a, b) => a.version.compareTo(b.version));

  for (int i = 0; i < migrationsNeeded.length; i++) {
    final expectedVersion = fromVersion + i + 1;
    if (migrationsNeeded[i].version != expectedVersion) {
      return false; // Gap found
    }
  }

  return migrationsNeeded.isNotEmpty;
}

/// Get summary of all migrations
String getMigrationsSummary() {
  final buffer = StringBuffer();
  buffer.writeln('Database Migrations Summary');
  buffer.writeln('=' * 50);
  buffer.writeln('Base version: 2');
  buffer.writeln('Latest version: $latestMigrationVersion');
  buffer.writeln('Total migrations: ${allMigrations.length}');
  buffer.writeln('=' * 50);

  for (final migration in allMigrations) {
    buffer.writeln('v${migration.version}: ${migration.description}');
  }

  return buffer.toString();
}
