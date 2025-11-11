// =============================================
// GROWLOG - Empty State Widget
// =============================================
// ✅ PHASE 3 FIX: Extracted shared empty state pattern

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_constants.dart';

/// Reusable empty state widget
///
/// Shows a centered icon with title and subtitle text.
/// Used across list screens when no data is available.
///
/// **Usage:**
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.eco,
///   title: 'No Plants',
///   subtitle: 'Create your first plant',
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// Icon to display (required)
  final IconData icon;

  /// Main title text (required)
  final String title;

  /// Subtitle/description text (required)
  final String subtitle;

  /// Icon size (defaults to AppConstants.emptyStateIconSize = 64)
  final double? iconSize;

  /// Icon color (defaults to grey based on theme)
  final Color? iconColor;

  /// Title font size (defaults to AppConstants.emptyStateTitleFontSize = 20)
  final double? titleFontSize;

  /// Title color (defaults to grey based on theme)
  final Color? titleColor;

  /// Subtitle font size (defaults to AppConstants.emptyStateSubtitleFontSize = 16)
  final double? subtitleFontSize;

  /// Subtitle color (defaults to grey based on theme)
  final Color? subtitleColor;

  /// Optional action button at the bottom
  final Widget? action;

  /// Custom icon widget (if you need more than just IconData)
  final Widget? customIcon;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconSize,
    this.iconColor,
    this.titleFontSize,
    this.titleColor,
    this.subtitleFontSize,
    this.subtitleColor,
    this.action,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Default colors based on theme
    final defaultIconColor = isDark ? Colors.grey[700] : Colors.grey[400];
    final defaultTitleColor = isDark ? Colors.grey[600] : Colors.grey[600];
    final defaultSubtitleColor = isDark ? Colors.grey[700] : Colors.grey[600];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon or custom icon widget
            if (customIcon != null)
              customIcon!
            else
              Icon(
                icon,
                size: iconSize ?? AppConstants.emptyStateIconSize,
                color: iconColor ?? defaultIconColor,
              ),

            const SizedBox(height: AppConstants.emptyStateSpacingTop),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize ?? AppConstants.emptyStateTitleFontSize,
                color: titleColor ?? defaultTitleColor,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppConstants.emptyStateSpacingMiddle),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: subtitleFontSize ?? AppConstants.emptyStateSubtitleFontSize,
                color: subtitleColor ?? defaultSubtitleColor,
              ),
            ),

            // Optional action button
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state with custom icon widget (for complex icons)
class EmptyStateWidgetWithCustomIcon extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyStateWidgetWithCustomIcon({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.help_outline, // Dummy icon (won't be shown)
      title: title,
      subtitle: subtitle,
      customIcon: icon,
      action: action,
    );
  }
}
