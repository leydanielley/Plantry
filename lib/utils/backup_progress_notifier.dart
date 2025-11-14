// =============================================
// GROWLOG - Backup Progress Notifier
// =============================================

import 'dart:async';

/// Progress event for backup operations
class BackupProgressEvent {
  final int current;
  final int total;
  final String message;

  BackupProgressEvent({
    required this.current,
    required this.total,
    required this.message,
  });

  /// Calculate percentage (0-100)
  int get percentage {
    if (total == 0) return 0;
    return ((current / total) * 100).round().clamp(0, 100);
  }

  @override
  String toString() => '$message ($current/$total - $percentage%)';
}

/// Singleton notifier for backup progress
///
/// Usage:
/// ```dart
/// // In BackupService:
/// BackupProgressNotifier.instance.notify(10, 100, 'Copying photos...');
///
/// // In UI (Splash Screen):
/// BackupProgressNotifier.instance.stream.listen((event) {
///   setState(() {
///     _backupProgress = event;
///   });
/// });
/// ```
class BackupProgressNotifier {
  static final BackupProgressNotifier _instance =
      BackupProgressNotifier._internal();

  static BackupProgressNotifier get instance => _instance;

  BackupProgressNotifier._internal();

  final StreamController<BackupProgressEvent> _controller =
      StreamController<BackupProgressEvent>.broadcast();

  /// Stream of backup progress events
  Stream<BackupProgressEvent> get stream => _controller.stream;

  /// Notify listeners of progress update
  void notify(int current, int total, String message) {
    if (!_controller.isClosed) {
      _controller.add(
        BackupProgressEvent(current: current, total: total, message: message),
      );
    }
  }

  /// Clear progress (reset to initial state)
  void clear() {
    if (!_controller.isClosed) {
      _controller.add(BackupProgressEvent(current: 0, total: 0, message: ''));
    }
  }

  /// Close the stream controller
  /// Should only be called when app is shutting down
  void dispose() {
    _controller.close();
  }
}
