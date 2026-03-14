import 'package:flutter/material.dart';

/// Plantry Design Tokens — Premium Technical System (Bitget Style)
class DT {
  DT._();

  // ── Base Backgrounds (Deep HUD Style) ──
  static const canvas = Color(0xFF050505);    // Fast Schwarz
  static const surface = Color(0xFF0E0E0E);   // Karten-Basis
  static const elevated = Color(0xFF161616);  // Buttons/Inputs

  // ── Cyber Colors (Neon Akzente) ──
  static const accent = Color(0xFF00FFBB);    // Cyber-Mint
  static const onAccent = Color(0xFF000000);
  static const secondary = Color(0xFF00CCFF); // Electric Blue
  static const warning = Color(0xFFFFBB00);   // Vivid Orange
  static const error = Color(0xFFFF3366);     // Neon Pink
  static const success = Color(0xFF00FFBB);   // Alias für accent
  static const info = Color(0xFF8833FF);      // Purple

  // ── Text ──
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9E9E9E);
  static const textTertiary = Color(0xFF505050);

  // ── Borders & Glass ──
  static const border = Color(0xFF1A1A1A);
  static final glassBackground = Colors.white.withValues(alpha: 0.03);
  static final glassBorder = Colors.white.withValues(alpha: 0.08);

  // ── Radien ──
  static const radiusCard = 16.0;
  static const radiusButton = 12.0;
  static const radiusInput = 12.0;
  static const radiusChip = 10.0;

  // ── Compatibility Deco (Phase 3 Fallbacks) ──
  static BoxDecoration cardDeco({double radius = radiusCard}) => glassDeco(radius: radius);
  static BoxDecoration cardDecoFlat({double radius = radiusCard}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: elevated,
    border: Border.all(color: glassBorder, width: 0.5),
  );

  static BoxDecoration glassDeco({double radius = radiusCard}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: glassBackground,
    border: Border.all(color: glassBorder, width: 0.5),
  );

  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1),
  ];

  static TextStyle mono({double size = 14, Color color = textPrimary, FontWeight weight = FontWeight.normal}) {
    return TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontFamily: 'monospace',
      letterSpacing: -0.5,
    );
  }
}
