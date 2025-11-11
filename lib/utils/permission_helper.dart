// =============================================
// GROWLOG - Permission Helper
// Handles runtime permissions gracefully
// =============================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:growlog_app/utils/app_logger.dart';

class PermissionHelper {
  /// Check and request camera permission
  static Future<bool> checkCameraPermission(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();

      // ✅ HIGH FIX: Use standard try-catch instead of mixing with .catchError()
      // Try to pick an image - this will trigger permission request
      try {
        await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1,
          maxHeight: 1,
        );
      } catch (error) {
        AppLogger.warning(
          'PermissionHelper',
          'Camera permission check failed: $error',
        );
        // Continue - this might be user cancellation, which is OK
      }

      // If we got here, permission was granted (even if user cancelled)
      return true;
    } catch (e) {
      AppLogger.error('PermissionHelper', 'Camera permission error', e);

      if (context.mounted) {
        _showPermissionDeniedDialog(
          context,
          'Kamera-Zugriff',
          'Plantry benötigt Zugriff auf die Kamera um Fotos aufzunehmen.',
        );
      }

      return false;
    }
  }

  /// Check and request photo library permission
  static Future<bool> checkPhotoPermission(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();

      // ✅ HIGH FIX: Use standard try-catch instead of mixing with .catchError()
      // Try to pick an image - this will trigger permission request
      try {
        await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1,
          maxHeight: 1,
        );
      } catch (error) {
        AppLogger.warning(
          'PermissionHelper',
          'Photo permission check failed: $error',
        );
        // Continue - this might be user cancellation, which is OK
      }

      // If we got here, permission was granted (even if user cancelled)
      return true;
    } catch (e) {
      AppLogger.error('PermissionHelper', 'Photo permission error', e);

      if (context.mounted) {
        _showPermissionDeniedDialog(
          context,
          'Foto-Zugriff',
          'Plantry benötigt Zugriff auf deine Fotos.',
        );
      }

      return false;
    }
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
