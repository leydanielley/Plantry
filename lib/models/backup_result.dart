// =============================================
// GROWLOG - BackupResult Sealed Type
// Structured result for emergency-backup operations (QA-002).
//
// Previously emergency-backup methods returned `Future<String?>` (path or null)
// and callers had to branch on null OR string-match log messages to decide
// whether a backup was created. That was fragile and error-prone, especially
// in the recovery path where deleting the database without a verified backup
// causes data loss.
//
// This sealed type forces callers to pattern-match on the outcome:
//   - BackupSuccess: backup written, [path] points at the artifact
//   - BackupSkipped: backup intentionally not produced, [reason] explains why
//   - BackupFailure: backup failed, [error] / [stackTrace] preserved for logs
// =============================================

/// Sealed result type for the emergency-backup pipeline.
///
/// Usage:
/// ```dart
/// final result = await DatabaseRecovery.exportToJSON(db);
/// switch (result) {
///   case BackupSuccess(:final path):
///     // safe to proceed with destructive recovery steps
///   case BackupSkipped(:final reason):
///     // nothing to back up (e.g. empty DB) — non-fatal
///   case BackupFailure(:final error):
///     // refuse to delete data, surface error to user
/// }
/// ```
sealed class BackupResult {
  const BackupResult();

  /// Convenience: the artifact path when a backup exists, null otherwise.
  String? get pathOrNull => switch (this) {
    BackupSuccess(:final path) => path,
    _ => null,
  };

  /// Convenience: whether a usable backup artifact was produced.
  bool get isSuccess => this is BackupSuccess;
}

/// Backup completed successfully and was written to [path].
class BackupSuccess extends BackupResult {
  final String path;

  const BackupSuccess(this.path);

  @override
  String toString() => 'BackupSuccess(path: $path)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupSuccess &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// Backup intentionally skipped (e.g. empty database, nothing to export).
/// This is a non-fatal outcome — callers may proceed but must not assume a
/// backup artifact exists.
class BackupSkipped extends BackupResult {
  final String reason;

  const BackupSkipped(this.reason);

  @override
  String toString() => 'BackupSkipped(reason: $reason)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupSkipped &&
          runtimeType == other.runtimeType &&
          reason == other.reason;

  @override
  int get hashCode => reason.hashCode;
}

/// Backup attempt failed. Callers MUST treat this as fatal for any
/// downstream destructive operation (e.g. deleting the corrupted DB).
class BackupFailure extends BackupResult {
  final Object error;
  final StackTrace? stackTrace;

  const BackupFailure(this.error, [this.stackTrace]);

  @override
  String toString() => 'BackupFailure(error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupFailure &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}
