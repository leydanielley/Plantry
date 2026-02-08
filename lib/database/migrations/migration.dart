// =============================================
// GROWLOG - Database Migration Model
// =============================================

import 'package:sqflite/sqflite.dart';

/// Represents a single database migration
///
/// Each migration represents a change to the database schema.
/// Migrations are run sequentially to upgrade the database from
/// one version to another.
///
/// Example:
/// ```dart
/// final migrationV14 = Migration(
///   version: 14,
///   description: 'Add color column to plants',
///   up: (db) async {
///     await db.execute('ALTER TABLE plants ADD COLUMN color TEXT DEFAULT "green"');
///   },
///   down: (db) async {
///     // Optional: Rollback logic
///   },
/// );
/// ```
class Migration {
  /// The target database version for this migration
  final int version;

  /// Human-readable description of what this migration does
  final String description;

  /// Function to apply the migration (upgrade)
  ///
  /// This is called when upgrading the database.
  /// Should contain all SQL commands needed to apply the schema changes.
  ///
  /// Note: The parameter can be either Database or Transaction (both implement DatabaseExecutor)
  final Future<void> Function(DatabaseExecutor db) up;

  /// Optional function to rollback the migration (downgrade)
  ///
  /// This is called if a migration fails and needs to be rolled back.
  /// Not required for all migrations.
  final Future<void> Function(DatabaseExecutor db)? down;

  const Migration({
    required this.version,
    required this.description,
    required this.up,
    this.down,
  });

  @override
  String toString() => 'Migration v$version: $description';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Migration &&
          runtimeType == other.runtimeType &&
          version == other.version;

  @override
  int get hashCode => version.hashCode;
}
