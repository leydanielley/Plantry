// =============================================
// GROWLOG - Enhanced Theme mit Glassmorphism
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class AppTheme {
  // ✅ WCAG-konforme monochrome Farbpalette für Light Mode
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFE9ECEF);
  static const Color lightBorder = Color(0xFFDEE2E6);
  static const Color lightTextPrimary = Color(0xFF212529);
  static const Color lightTextSecondary = Color(0xFF495057);
  static const Color lightTextTertiary = Color(0xFF6C757D);

  /// ==========================================
  /// CUSTOM TEXT THEME
  /// ==========================================
  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor, Color tertiaryColor) {
    const String fontFamily = 'Roboto';

    return TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, fontSize: 57, fontWeight: FontWeight.w700, color: primaryColor, height: 1.12),
      displayMedium: TextStyle(fontFamily: fontFamily, fontSize: 45, fontWeight: FontWeight.w700, color: primaryColor, height: 1.16),
      displaySmall: TextStyle(fontFamily: fontFamily, fontSize: 36, fontWeight: FontWeight.w600, color: primaryColor, height: 1.22),
      headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: primaryColor, height: 1.25),
      headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.w600, color: primaryColor, height: 1.29),
      headlineSmall: TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w600, color: primaryColor, height: 1.33),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w600, color: primaryColor, height: 1.2),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor, height: 1.2),
      titleSmall: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor, height: 1.2),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: primaryColor, height: 1.2),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: secondaryColor, height: 1.2),
      bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: tertiaryColor, height: 1.2),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: primaryColor, height: 1.2),
      labelMedium: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: secondaryColor, height: 1.2),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: tertiaryColor, height: 1.2),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color surfaceVariant,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color primaryAccent,
    required Color onPrimaryAccent,
  }) {
    final textTheme = _buildTextTheme(textPrimary, textSecondary, textTertiary);
    final bool isDarkMode = brightness == Brightness.dark;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        brightness: brightness,
        primary: primaryAccent,
        secondary: primaryAccent,
        surface: surfaceColor,
        onPrimary: onPrimaryAccent,
        onSecondary: onPrimaryAccent,
        onSurface: textPrimary,
      ),
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? backgroundColor : primaryAccent,
        foregroundColor: isDarkMode ? textPrimary : onPrimaryAccent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: isDarkMode ? textPrimary : onPrimaryAccent, fontWeight: FontWeight.bold),
      ),

      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode ? surfaceVariant : surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorder)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: onPrimaryAccent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static final glassBorder = Colors.white.withValues(alpha: 0.08);

  static ThemeData lightTheme() {
    return _buildTheme(
      brightness: Brightness.light,
      backgroundColor: lightBackground,
      surfaceColor: lightSurface,
      surfaceVariant: lightSurfaceVariant,
      borderColor: lightBorder,
      textPrimary: lightTextPrimary,
      textSecondary: lightTextSecondary,
      textTertiary: lightTextTertiary,
      primaryAccent: DT.accent,
      onPrimaryAccent: Colors.white,
    );
  }

  static ThemeData darkTheme() {
    return _buildTheme(
      brightness: Brightness.dark,
      backgroundColor: DT.canvas,
      surfaceColor: DT.surface,
      surfaceVariant: DT.elevated,
      borderColor: DT.border,
      textPrimary: DT.textPrimary,
      textSecondary: DT.textSecondary,
      textTertiary: DT.textTertiary,
      primaryAccent: DT.accent,
      onPrimaryAccent: DT.onAccent,
    );
  }
}
