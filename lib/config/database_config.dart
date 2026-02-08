// =============================================
// GROWLOG - Database Configuration
// Central configuration for database operations
// =============================================

/// Database operation timeouts and limits
class DatabaseConfig {
  DatabaseConfig._();

  // ==========================================
  // TRANSACTION TIMEOUTS
  // ==========================================

  /// Standard timeout for simple transactions (CRUD operations)
  /// Covers: insert, update, delete, simple queries
  static const Duration standardTransactionTimeout = Duration(seconds: 30);

  /// Extended timeout for complex transactions
  /// Covers: batch operations, multiple table updates
  static const Duration complexTransactionTimeout = Duration(minutes: 2);

  /// Heavy operation timeout
  /// Covers: migrations, bulk imports, recalculations
  static const Duration heavyOperationTimeout = Duration(minutes: 5);

  /// Critical timeout for backup operations
  /// Covers: full database export/import
  static const Duration backupTimeout = Duration(minutes: 10);

  // ==========================================
  // QUERY LIMITS
  // ==========================================

  /// Default limit for findAll() queries to prevent memory overflow
  static const int defaultQueryLimit = 1000;

  /// Maximum records per batch operation
  static const int maxBatchSize = 500;

  /// Maximum concurrent database connections
  static const int maxConnections = 1;

  // ==========================================
  // RETRY CONFIGURATION
  // ==========================================

  /// Number of retries for failed database operations
  static const int maxRetries = 3;

  /// Delay between retries (exponential backoff)
  static Duration retryDelay(int attempt) {
    return Duration(milliseconds: 100 * (1 << attempt)); // 100ms, 200ms, 400ms
  }

  // ==========================================
  // LOGGING
  // ==========================================

  /// Log slow queries that exceed this threshold
  static const Duration slowQueryThreshold = Duration(seconds: 5);

  /// Log very slow queries separately
  static const Duration verySlowQueryThreshold = Duration(seconds: 10);
}
