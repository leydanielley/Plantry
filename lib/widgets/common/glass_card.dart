import 'dart:ui';
import 'package:flutter/material.dart';

/// 🎨 Glassmorphism Card Widget - OPTIMIZED VERSION
/// 
/// Modern glass effect WITHOUT BackdropFilter for better performance
/// Uses gradients and borders for clean look on all devices
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final bool useBlur; // Toggle blur on/off

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 10,
    this.opacity = 0.1,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderWidth = 1,
    this.boxShadow,
    this.useBlur = false, // Default: no blur for better quality
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorderColor = isDark 
        ? Colors.white.withValues(alpha: 0.08) 
        : Colors.white.withValues(alpha: 0.2);

    // Clean version without BackdropFilter (better quality)
    if (!useBlur) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow ?? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: opacity * 0.5)
                : Colors.white.withValues(alpha: opacity * 1.5),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? defaultBorderColor,
              width: borderWidth,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.03),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.5),
                      Colors.white.withValues(alpha: 0.2),
                    ],
            ),
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );
    }

    // Blur version (original - may look pixelated on some devices)
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: opacity)
                  : Colors.white.withValues(alpha: opacity + 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? defaultBorderColor,
                width: borderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.1),
                      ],
              ),
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 🎨 Simplified Glass Card - NO BLUR, CLEAN LOOK
class SimpleGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;

  const SimpleGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: backgroundColor ?? (isDark 
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.8)),
        border: Border.all(
          color: borderColor ?? (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// 🎨 Glassmorphism Card mit Farbverlauf
class GlassGradientCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool useBlur;

  const GlassGradientCard({
    super.key,
    required this.child,
    required this.gradientColors,
    this.borderRadius = 16,
    this.blur = 10,
    this.padding,
    this.margin,
    this.useBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!useBlur) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors
                .map((color) => color.withValues(alpha: 0.15))
                .toList(),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors
                    .map((color) => color.withValues(alpha: 0.3))
                    .toList(),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
