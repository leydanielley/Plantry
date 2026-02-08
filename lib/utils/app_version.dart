// =============================================
// GROWLOG - App Version
// AUTO-GENERATED - DO NOT EDIT MANUALLY
// =============================================

/// Current app version
///
/// ⚠️ WICHTIG: Diese Datei wird automatisch generiert
/// Bei Version-Update: `flutter pub run build_runner build` ausführen
///
/// Alternativ: Version wird zur Runtime aus package_info_plus gelesen
class AppVersion {
  /// Version aus pubspec.yaml
  ///
  /// Format: "major.minor.patch+build"
  /// Beispiel: "1.0.0+49"
  /// ⚠️ WICHTIG: Bei jedem Release MUSS diese Zeile MIT pubspec.yaml synchron sein!
  static const String version = '1.0.0+49';

  /// Extrahiert Major Version
  /// Beispiel: "0.8.7+12" → 0
  static int get major {
    final parts = version.split('+')[0].split('.');
    return int.tryParse(parts[0]) ?? 0;
  }

  /// Extrahiert Minor Version
  /// Beispiel: "0.8.7+12" → 8
  static int get minor {
    final parts = version.split('+')[0].split('.');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }

  /// Extrahiert Patch Version
  /// Beispiel: "0.8.7+12" → 7
  static int get patch {
    final parts = version.split('+')[0].split('.');
    return parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
  }

  /// Extrahiert Build Number
  /// Beispiel: "0.8.7+12" → 12
  static int get buildNumber {
    final parts = version.split('+');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }

  /// Version ohne Build Number
  /// Beispiel: "0.8.7+12" → "0.8.7"
  static String get versionWithoutBuild {
    return version.split('+')[0];
  }

  /// Vergleicht mit anderer Version
  ///
  /// Returns:
  /// - 1 wenn diese Version neuer ist
  /// - 0 wenn Versionen gleich sind
  /// - -1 wenn andere Version neuer ist
  static int compareTo(String otherVersion) {
    // ✅ CRITICAL FIX: Use tryParse to prevent crash on malformed version strings
    final thisParts = version
        .split('+')[0]
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final otherParts = otherVersion
        .split('+')[0]
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    for (int i = 0; i < 3; i++) {
      final thisValue = i < thisParts.length ? thisParts[i] : 0;
      final otherValue = i < otherParts.length ? otherParts[i] : 0;

      if (thisValue > otherValue) return 1;
      if (thisValue < otherValue) return -1;
    }

    return 0;
  }
}
