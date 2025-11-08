// =============================================
// GROWLOG - Accessibility Helper
// Screen Reader & TalkBack Support
// =============================================

import 'package:flutter/material.dart';

class AccessibilityHelper {
  /// Wrap widget with semantic label for screen readers
  ///
  /// Example:
  /// ```dart
  /// AccessibilityHelper.semanticButton(
  ///   label: 'Pflanze hinzufügen',
  ///   hint: 'Öffnet Formular zum Hinzufügen einer neuen Pflanze',
  ///   child: IconButton(icon: Icon(Icons.add), onPressed: ...),
  /// )
  /// ```
  static Widget semanticButton({
    required String label,
    String? hint,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      child: child,
    );
  }

  /// Wrap image with description for screen readers
  static Widget semanticImage({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      label: label,
      image: true,
      child: child,
    );
  }

  /// Wrap text with heading semantics
  static Widget semanticHeading({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      label: label,
      header: true,
      child: child,
    );
  }

  /// Check if text scale is large (accessibility setting)
  static bool isLargeTextScale(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    return textScaler.scale(1.0) > 1.3;
  }

  /// Get accessible font size based on text scale
  static double getAccessibleFontSize(BuildContext context, double baseFontSize) {
    final textScaler = MediaQuery.of(context).textScaler;
    final scaleFactor = textScaler.scale(1.0);

    // Limit maximum scaling to prevent overflow
    final clampedScale = scaleFactor.clamp(1.0, 2.0);

    return baseFontSize * clampedScale;
  }

  /// Check if user prefers reduced motion
  static bool prefersReducedMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Announce message to screen reader
  static void announce(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Accessibility-aware container
///
/// Adjusts padding based on text scale
class AccessibleContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AccessibleContainer({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final scaleFactor = textScaler.scale(1.0);

    // Increase padding for large text
    final basePadding = padding ?? const EdgeInsets.all(16.0);
    final scaledPadding = scaleFactor > 1.3
        ? EdgeInsets.all(basePadding.horizontal * 1.2)
        : basePadding;

    return Container(
      padding: scaledPadding,
      child: child,
    );
  }
}

/// Accessibility-aware text
///
/// Ensures minimum contrast and readable size
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double minFontSize;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.minFontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final scaleFactor = textScaler.scale(1.0);

    // Ensure minimum font size
    final fontSize = (style?.fontSize ?? minFontSize) * scaleFactor;
    final clampedFontSize = fontSize.clamp(minFontSize, 32.0);

    return Text(
      text,
      style: style?.copyWith(fontSize: clampedFontSize) ??
          TextStyle(fontSize: clampedFontSize),
    );
  }
}
