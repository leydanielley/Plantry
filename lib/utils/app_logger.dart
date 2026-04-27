// =============================================
// GROWLOG - Structured Logging Utility
// =============================================

import 'package:flutter/foundation.dart';

/// Log severity levels
enum LogLevel {
  debug(0, '🔍'),
  info(1, 'ℹ️'),
  warning(2, '⚠️'),
  error(3, '❌');

  const LogLevel(this.priority, this.emoji);
  final int priority;
  final String emoji;
}

/// Structured application logger with tag-based filtering
///
/// Usage:
/// ```dart
/// AppLogger.debug('PlantRepo', 'Loading plant', plantId);
/// AppLogger.info('Backup', 'Export started');
/// AppLogger.warning('Validation', 'Invalid pH value', value);
/// AppLogger.error('Database', 'Failed to save', error, stackTrace);
/// ```
class AppLogger {
  /// Enable/disable all logging (automatically disabled in release builds)
  static const bool _enabled = kDebugMode;

  /// Minimum log level to display (change to filter logs)
  static LogLevel _minLevel = LogLevel.debug;

  /// Set minimum log level at runtime
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Log debug message (lowest priority)
  /// Use for detailed tracing and development information
  static void debug(String tag, String message, [Object? data]) {
    _log(LogLevel.debug, tag, message, data);
  }

  /// Log info message
  /// Use for general information about app flow
  static void info(String tag, String message, [Object? data]) {
    _log(LogLevel.info, tag, message, data);
  }

  /// Log warning message
  /// Use for recoverable errors or unusual situations
  static void warning(String tag, String message, [Object? data]) {
    _log(LogLevel.warning, tag, message, data);
  }

  /// Log error message with optional error object and stack trace
  /// Use for exceptions and critical errors
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_enabled) return;
    if (_minLevel.priority > LogLevel.error.priority) return;

    final buffer = StringBuffer();
    buffer.write('${LogLevel.error.emoji} [$tag] $message');

    if (error != null) {
      buffer.write('\n  Error: $error');
    }

    if (stackTrace != null) {
      buffer.write('\n  Stack Trace:\n${stackTrace.toString()}');
    }

    debugPrint(buffer.toString());
  }

  /// Internal logging implementation
  static void _log(LogLevel level, String tag, String message, [Object? data]) {
    if (!_enabled) return;
    if (_minLevel.priority > level.priority) return;

    final buffer = StringBuffer();
    buffer.write('${level.emoji} [$tag] $message');

    if (data != null) {
      final dataStr = data.toString();
      final truncated = dataStr.length > 200
          ? '${dataStr.substring(0, 200)}…'
          : dataStr;
      buffer.write('\n  Data: $truncated');
    }

    debugPrint(buffer.toString());
  }

  /// Log a separator line for visual clarity
  static void separator([String title = '']) {
    if (!_enabled) return;
    if (title.isEmpty) {
      debugPrint('═' * 60);
    } else {
      final titlePadded = ' $title ';
      final padding = (60 - titlePadded.length) ~/ 2;
      final line = '═' * padding + titlePadded + '═' * padding;
      debugPrint(line);
    }
  }
}
