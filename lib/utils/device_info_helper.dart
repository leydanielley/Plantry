// =============================================
// GROWLOG - Device Info Helper
// Detects device-specific issues (Samsung, etc.)
// =============================================

import 'dart:io';
import 'app_logger.dart';

class DeviceInfoHelper {
  /// Check if device is Samsung
  static bool isSamsungDevice() {
    if (Platform.isAndroid) {
      // Check manufacturer from Build info
      // This is a simple heuristic - in production you'd use device_info_plus
      return false; // Placeholder - would need device_info_plus package
    }
    return false;
  }

  /// Check if device is a foldable
  static bool isFoldableDevice() {
    // This would require checking screen size changes
    // For now, return false as placeholder
    return false;
  }

  /// Get device recommendations based on manufacturer
  /// ✅ AUDIT NOTE: German messages are intentional - this is a German-language app
  static List<String> getDeviceSpecificRecommendations() {
    final recommendations = <String>[];

    if (Platform.isAndroid) {
      // Generic Android recommendations
      recommendations.addAll([
        '• Erlaube Plantry im Hintergrund zu laufen',
        '• Deaktiviere Akku-Optimierung für Plantry',
        '• Aktiviere "Autostart" für Plantry',
      ]);

      // Samsung-specific (heuristic based on common patterns)
      // In production, use device_info_plus to detect manufacturer
      recommendations.addAll([
        '',
        'Samsung-Geräte:',
        '• Einstellungen → Apps → Plantry',
        '• Akku → Hintergrundnutzung auf "Uneingeschränkt"',
        '• Speicher → Daten nicht löschen',
      ]);
    }

    return recommendations;
  }

  /// Show battery optimization warning if needed
  static bool shouldShowBatteryWarning(int crashCount) {
    // Show warning if app has crashed multiple times
    return crashCount >= 2;
  }

  /// Get storage recommendations
  static List<String> getStorageRecommendations(int availableMB) {
    if (availableMB < 100) {
      return [
        'Kritisch wenig Speicherplatz!',
        '',
        'Empfehlungen:',
        '• Alte Fotos sichern und löschen',
        '• Backup exportieren',
        '• Thumbnails in Einstellungen löschen',
        '• Andere Apps deinstallieren',
      ];
    } else if (availableMB < 500) {
      return [
        'Speicherplatz wird knapp',
        '',
        'Tipp:',
        '• Regelmäßig Backups exportieren',
        '• Alte Fotos archivieren',
      ];
    }

    return [];
  }

  /// Log device information for debugging
  static void logDeviceInfo() {
    AppLogger.info('DeviceInfo', 'Platform: ${Platform.operatingSystem}');
    AppLogger.info('DeviceInfo', 'Version: ${Platform.operatingSystemVersion}');
    AppLogger.info('DeviceInfo', 'Locale: ${Platform.localeName}');
  }
}
