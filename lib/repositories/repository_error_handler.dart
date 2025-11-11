// =============================================
// GROWLOG - Repository Error Handler
// =============================================
// ✅ PHASE 2 FIX: Standardized error handling for all repositories

import 'package:growlog_app/utils/app_logger.dart';

/// Mixin providing standardized error handling for repositories
///
/// Error Handling Strategy:
/// - **Query operations** (findAll, findById, count): Return safe defaults on error
///   to prevent app crashes. Logs error but doesn't throw.
/// - **Mutation operations** (create, update, delete, save): Rethrow exceptions
///   so UI can display proper error messages to users.
///
/// This ensures:
/// 1. Read-heavy operations are fault-tolerant (graceful degradation)
/// 2. Write operations provide clear feedback on failures
/// 3. All errors are logged for debugging
mixin RepositoryErrorHandler {
  // Repository name for logging (override in implementing class)
  String get repositoryName;

  /// Wraps a query operation with safe error handling
  /// Returns [defaultValue] on error and logs the exception
  ///
  /// Use for: findAll, findById, count, search operations
  ///
  /// Example:
  /// ```dart
  /// Future<List<Plant>> findAll() async {
  ///   return handleQuery(
  ///     operation: () async {
  ///       final db = await _dbHelper.database;
  ///       final maps = await db.query('plants');
  ///       return maps.map((m) => Plant.fromMap(m)).toList();
  ///     },
  ///     operationName: 'findAll',
  ///     defaultValue: [],
  ///   );
  /// }
  /// ```
  Future<T> handleQuery<T>({
    required Future<T> Function() operation,
    required String operationName,
    required T defaultValue,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      final contextStr = context != null ? ', context: $context' : '';
      AppLogger.error(
        repositoryName,
        'Query operation failed: $operationName$contextStr',
        e,
        stackTrace,
      );
      return defaultValue;
    }
  }

  /// Wraps a mutation operation with error handling and rethrowing
  /// Logs the error and rethrows for UI to handle
  ///
  /// Use for: create, update, delete, save operations
  ///
  /// Example:
  /// ```dart
  /// Future<int> create(Plant plant) async {
  ///   return handleMutation(
  ///     operation: () async {
  ///       final db = await _dbHelper.database;
  ///       return await db.insert('plants', plant.toMap());
  ///     },
  ///     operationName: 'create',
  ///     context: {'plantName': plant.name},
  ///   );
  /// }
  /// ```
  Future<T> handleMutation<T>({
    required Future<T> Function() operation,
    required String operationName,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      final contextStr = context != null ? ', context: $context' : '';
      AppLogger.error(
        repositoryName,
        'Mutation operation failed: $operationName$contextStr',
        e,
        stackTrace,
      );
      rethrow; // Let UI handle the error
    }
  }

  /// Wraps a transaction operation with error handling
  /// Transactions automatically rollback on error
  ///
  /// Use for: multi-step database operations that must be atomic
  ///
  /// Example:
  /// ```dart
  /// Future<void> cascadeDelete(int plantId) async {
  ///   return handleTransaction(
  ///     operation: (txn) async {
  ///       await txn.delete('plant_logs', where: 'plant_id = ?', whereArgs: [plantId]);
  ///       await txn.delete('plants', where: 'id = ?', whereArgs: [plantId]);
  ///     },
  ///     operationName: 'cascadeDelete',
  ///     context: {'plantId': plantId},
  ///   );
  /// }
  /// ```
  Future<T> handleTransaction<T>({
    required Future<T> Function() operation,
    required String operationName,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      final contextStr = context != null ? ', context: $context' : '';
      AppLogger.error(
        repositoryName,
        'Transaction failed (auto-rollback): $operationName$contextStr',
        e,
        stackTrace,
      );
      rethrow; // Transaction already rolled back, inform UI
    }
  }
}

/// Repository error types for better error classification
enum RepositoryErrorType {
  databaseError,      // SQLite/database errors
  validationError,    // Data validation failures
  notFound,           // Entity not found
  conflict,           // Unique constraint violations
  timeout,            // Operation timeout
  unknown,            // Unclassified errors
}

/// Custom exception for repository operations
class RepositoryException implements Exception {
  final RepositoryErrorType type;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  RepositoryException({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'RepositoryException: $message (type: $type)';

  /// Factory constructors for common error types
  factory RepositoryException.notFound(String entity, dynamic id) {
    return RepositoryException(
      type: RepositoryErrorType.notFound,
      message: '$entity with id $id not found',
    );
  }

  factory RepositoryException.conflict(String message) {
    return RepositoryException(
      type: RepositoryErrorType.conflict,
      message: message,
    );
  }

  factory RepositoryException.validation(String message) {
    return RepositoryException(
      type: RepositoryErrorType.validationError,
      message: message,
    );
  }
}
