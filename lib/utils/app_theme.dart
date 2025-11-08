// =============================================
// GROWLOG - Enhanced Theme mit Glassmorphism
// WCAG 2.1 AA/AAA konform
// =============================================

import 'package:flutter/material.dart';

class AppTheme {
  // ✅ WCAG-konforme monochrome Farbpalette für Light Mode (60-30-10 Regel)
  static const Color lightBackground = Color(0xFFF8F9FA);      // 60% - Haupthintergrund (fast weiß)
  static const Color lightSurface = Color(0xFFFFFFFF);         // 30% - Karten/Container (weiß)
  static const Color lightSurfaceVariant = Color(0xFFE9ECEF);  // 10% - Sekundäre Flächen (helles Grau)
  static const Color lightBorder = Color(0xFFDEE2E6);          // Borders/Dividers
  static const Color lightTextPrimary = Color(0xFF212529);     // Haupttext (dunkel, WCAG AAA)
  static const Color lightTextSecondary = Color(0xFF495057);   // Sekundärtext (WCAG AA)
  static const Color lightTextTertiary = Color(0xFF6C757D);    // Tertiärtext (dezent)
  
  // ✅ WCAG-konforme monochrome Farbpalette für Dark Mode
  static const Color darkBackground = Color(0xFF121212);       // Haupthintergrund
  static const Color darkSurface = Color(0xFF1E1E1E);          // Karten/Container
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);   // Sekundäre Flächen
  static const Color darkBorder = Color(0xFF3A3A3A);           // Borders/Dividers
  static const Color darkTextPrimary = Color(0xFFE9ECEF);      // Haupttext (hell, WCAG AAA)
  static const Color darkTextSecondary = Color(0xFFCED4DA);    // Sekundärtext (WCAG AA)
  static const Color darkTextTertiary = Color(0xFFADB5BD);     // Tertiärtext (dezent)
  
  // ✅ Grün nur als Akzentfarbe (WCAG AA konform)
  static final Color primaryGreen = Colors.green[700] ?? const Color(0xFF388E3C);        // #388E3C - Header & wichtige CTAs
  static final Color primaryGreenLight = Colors.green[400] ?? const Color(0xFF66BB6A);   // Dark Mode Akzent
  static final Color primaryGreenDark = Colors.green[800] ?? const Color(0xFF2E7D32);    // Hover/Active States

  // 🎨 Custom Color Palette - Additional Colors
  static const Color successColor = Color(0xFF28A745);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFDC3545);
  static const Color infoColor = Color(0xFF17A2B8);

  /// ==========================================
  /// CUSTOM TEXT THEME - 100% OFFLINE
  /// ==========================================

  /// Uses Roboto font (built-in with Material Design, no network required)
  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor, Color tertiaryColor) {
    // Using Roboto font family (available offline in Android/iOS)
    const String fontFamily = 'Roboto';

    return TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, fontSize: 57, fontWeight: FontWeight.w700, color: primaryColor, letterSpacing: -0.25, height: 1.12),
      displayMedium: TextStyle(fontFamily: fontFamily, fontSize: 45, fontWeight: FontWeight.w700, color: primaryColor, letterSpacing: 0, height: 1.16),
      displaySmall: TextStyle(fontFamily: fontFamily, fontSize: 36, fontWeight: FontWeight.w600, color: primaryColor, letterSpacing: 0, height: 1.22),
      headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: primaryColor, letterSpacing: -0.5, height: 1.25),
      headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.w600, color: primaryColor, letterSpacing: 0, height: 1.29),
      headlineSmall: TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w600, color: primaryColor, letterSpacing: 0, height: 1.33),
      titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w600, color: primaryColor, letterSpacing: 0, height: 1.27),
      titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor, letterSpacing: 0.15, height: 1.5),
      titleSmall: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor, letterSpacing: 0.1, height: 1.43),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: primaryColor, letterSpacing: 0.5, height: 1.5),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: secondaryColor, letterSpacing: 0.25, height: 1.43),
      bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: tertiaryColor, letterSpacing: 0.4, height: 1.33),
      labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: primaryColor, letterSpacing: 0.1, height: 1.43),
      labelMedium: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: secondaryColor, letterSpacing: 0.5, height: 1.33),
      labelSmall: TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: tertiaryColor, letterSpacing: 0.5, height: 1.45),
    );
  }

  /// ==========================================
  /// LIGHT THEME
  /// ==========================================
  static ThemeData lightTheme() {
    final textTheme = _buildTextTheme(lightTextPrimary, lightTextSecondary, lightTextTertiary);
    
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.light,
        primary: primaryGreen,
        secondary: primaryGreen,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        error: errorColor,
      ),
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      textTheme: textTheme,
      
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      cardTheme: CardThemeData(
        elevation: 2,
        color: lightSurface.withValues(alpha: 0.95),
        shadowColor: lightTextTertiary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: lightBorder.withValues(alpha: 0.5), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        tileColor: lightSurface,
        selectedTileColor: primaryGreen.withValues(alpha: 0.1),
        iconColor: lightTextSecondary,
        textColor: lightTextPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface.withValues(alpha: 0.8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightBorder.withValues(alpha: 0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightBorder.withValues(alpha: 0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: errorColor, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: errorColor, width: 2)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: lightTextSecondary),
        hintStyle: textTheme.bodySmall?.copyWith(color: lightTextTertiary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: primaryGreen),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: primaryGreen.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: BorderSide(color: lightBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface.withValues(alpha: 0.98),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: lightTextPrimary),
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: lightTextSecondary),
      ),
      
      dividerTheme: DividerThemeData(color: lightBorder.withValues(alpha: 0.5), thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: lightTextSecondary, size: 24),
      
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceVariant,
        selectedColor: primaryGreen,
        labelStyle: textTheme.labelMedium?.copyWith(color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryGreen,
        unselectedItemColor: lightTextTertiary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : lightTextTertiary),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primaryGreen : lightBorder),
      ),
      
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primaryGreen : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: lightBorder, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primaryGreen : lightTextTertiary),
      ),
    );
  }

  /// ==========================================
  /// DARK THEME
  /// ==========================================
  static ThemeData darkTheme() {
    final textTheme = _buildTextTheme(darkTextPrimary, darkTextSecondary, darkTextTertiary);
    
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreenLight,
        brightness: Brightness.dark,
        primary: primaryGreenLight,
        secondary: primaryGreenLight,
        surface: darkSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: darkTextPrimary,
        error: errorColor,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme,
      
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: darkTextPrimary),
        iconTheme: const IconThemeData(color: darkTextPrimary),
      ),
      
      cardTheme: CardThemeData(
        elevation: 3,
        color: darkSurface.withValues(alpha: 0.95),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkBorder.withValues(alpha: 0.5), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        tileColor: darkSurface,
        selectedTileColor: primaryGreenLight.withValues(alpha: 0.15),
        iconColor: darkTextSecondary,
        textColor: darkTextPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant.withValues(alpha: 0.8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkBorder.withValues(alpha: 0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkBorder.withValues(alpha: 0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreenLight, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: errorColor, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: errorColor, width: 2)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        hintStyle: textTheme.bodySmall?.copyWith(color: darkTextTertiary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: primaryGreenLight),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreenLight,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: primaryGreenLight.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreenLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: BorderSide(color: darkBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryGreenLight,
        foregroundColor: Colors.black,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceVariant.withValues(alpha: 0.98),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: darkBorder)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: darkTextPrimary),
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: darkTextSecondary),
      ),
      
      dividerTheme: DividerThemeData(color: darkBorder.withValues(alpha: 0.5), thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: darkTextSecondary, size: 24),
      
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceVariant,
        selectedColor: primaryGreenLight,
        labelStyle: textTheme.labelMedium?.copyWith(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryGreenLight,
        unselectedItemColor: darkTextTertiary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceVariant,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.black : darkTextTertiary),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primaryGreenLight : darkBorder),
      ),
      
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primaryGreenLight : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: BorderSide(color: darkBorder, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primaryGreenLight : darkTextTertiary),
      ),
    );
  }

  /// ==========================================
  /// HELPER METHODS
  /// ==========================================
  
  static Color getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  static double getOpacity(BuildContext context, double lightOpacity, double darkOpacity) {
    return Theme.of(context).brightness == Brightness.dark ? darkOpacity : lightOpacity;
  }
  
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  static Color getGlassColor(BuildContext context, {double opacity = 0.1}) {
    return isDark(context)
        ? Colors.white.withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity + 0.1);
  }
  
  static Color getBorderColor(BuildContext context, {double opacity = 1.0}) {
    return isDark(context)
        ? darkBorder.withValues(alpha: opacity)
        : lightBorder.withValues(alpha: opacity);
  }
}