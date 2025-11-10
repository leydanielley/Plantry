// =============================================
// GROWLOG - Mounted State Mixin
// =============================================
// ✅ FIX: Reusable mixin to prevent setState after dispose

import 'package:flutter/material.dart';

/// Mixin that provides safe setState wrapper
/// Prevents calling setState on unmounted widgets
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with MountedStateMixin {
///   void someAsyncMethod() async {
///     final result = await someOperation();
///     safeSetState(() {
///       _data = result;
///     });
///   }
/// }
/// ```
mixin MountedStateMixin<T extends StatefulWidget> on State<T> {
  /// Safe setState wrapper that checks if widget is still mounted
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }
}
