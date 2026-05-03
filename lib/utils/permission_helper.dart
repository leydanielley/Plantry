// =============================================
// GROWLOG - Permission Helper
// Handles runtime permissions gracefully
// =============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:growlog_app/utils/app_logger.dart';

class PermissionHelper {
  /// image_picker semantik:
  ///  - returnt null  → User hat abgebrochen (Permission ist gewährt!)
  ///  - returnt XFile → Permission gewährt + Bild gewählt
  ///  - wirft        → Permission verweigert (PlatformException) oder System-Fehler
  ///
  /// Vorher: ALLES wurde als "OK" interpretiert → Permission-Denied wurde
  /// fälschlich als "gewährt" gemeldet. Jetzt: nur ein Wurf führt zu false.
  static Future<bool> _probeImagePickerPermission(
    BuildContext context, {
    required ImageSource source,
    required String dialogTitle,
    required String dialogMessage,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      await picker.pickImage(source: source, maxWidth: 1, maxHeight: 1);
      // null (cancel) oder XFile → Permission gewährt
      return true;
    } on PlatformException catch (e) {
      // Häufige codes: 'camera_access_denied', 'photo_access_denied',
      // 'photo_access_restricted', 'invalid_image'.
      AppLogger.warning(
        'PermissionHelper',
        '$source permission denied: ${e.code} ${e.message}',
      );
      if (context.mounted) {
        _showPermissionDeniedDialog(context, dialogTitle, dialogMessage);
      }
      return false;
    } catch (e) {
      AppLogger.error('PermissionHelper', '$source permission probe error', e);
      if (context.mounted) {
        _showPermissionDeniedDialog(context, dialogTitle, dialogMessage);
      }
      return false;
    }
  }

  static Future<bool> checkCameraPermission(BuildContext context) {
    return _probeImagePickerPermission(
      context,
      source: ImageSource.camera,
      dialogTitle: 'Kamera-Zugriff',
      dialogMessage:
          'Plantry benötigt Zugriff auf die Kamera um Fotos aufzunehmen.',
    );
  }

  static Future<bool> checkPhotoPermission(BuildContext context) {
    return _probeImagePickerPermission(
      context,
      source: ImageSource.gallery,
      dialogTitle: 'Foto-Zugriff',
      dialogMessage: 'Plantry benötigt Zugriff auf deine Fotos.',
    );
  }

  /// Show permission denied dialog with instructions
  /// ✅ AUDIT NOTE: German messages are intentional - this is a German-language app
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'So aktivierst du den Zugriff:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Öffne Einstellungen'),
            const Text('2. Apps → Plantry'),
            const Text('3. Berechtigungen'),
            const Text('4. Aktiviere die benötigten Berechtigungen'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  /// Check if notification permission is granted (Android 13+)
  static Future<bool> checkNotificationPermission() async {
    try {
      // For Flutter, notification permissions are handled by the plugin
      // We'll just log and return true for now
      AppLogger.info(
        'PermissionHelper',
        'Notification permission check - handled by plugin',
      );
      return true;
    } catch (e) {
      AppLogger.error('PermissionHelper', 'Notification permission error', e);
      return false;
    }
  }

  /// Show a generic permission rationale
  static Future<bool> showPermissionRationale(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Zulassen',
    String cancelText = 'Abbrechen',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
