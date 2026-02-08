// =============================================
// GROWLOG - Edge-to-Edge Safe Scaffold
// Android 15+ Edge-to-Edge Display Support
// =============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Edge-to-Edge compatible Scaffold wrapper
///
/// Automatically handles System UI Insets for Android 15+
/// Use this instead of regular Scaffold for new screens
///
/// Example:
/// ```dart
/// EdgeToEdgeScaffold(
///   appBar: AppBar(title: Text('My Screen')),
///   body: MyContent(),
/// )
/// ```
class EdgeToEdgeScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const EdgeToEdgeScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _getSystemUiOverlayStyle(context),
      child: Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        drawer: drawer,
        backgroundColor: backgroundColor,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
      ),
    );
  }

  SystemUiOverlayStyle _getSystemUiOverlayStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return SystemUiOverlayStyle(
      // Status Bar (top)
      statusBarColor: Colors.transparent, // Transparent for edge-to-edge
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,

      // Navigation Bar (bottom)
      systemNavigationBarColor:
          Colors.transparent, // Transparent for edge-to-edge
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,

      // System Gestures (Android 10+)
      systemNavigationBarContrastEnforced: false,
    );
  }
}

/// Helper to wrap content with safe area padding
///
/// Use this for content that should not be overlapped by system UI
///
/// Example:
/// ```dart
/// EdgeToEdgeSafeArea(
///   child: ListView(children: [...]),
/// )
/// ```
class EdgeToEdgeSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  const EdgeToEdgeSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: child,
    );
  }
}
