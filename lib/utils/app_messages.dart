// =============================================
// GROWLOG - AppMessages (Unified Messages)
// =============================================

import 'package:flutter/material.dart';

/// Central class for all app messages
/// Provides unified SnackBar messages with icons and colors
class AppMessages {
  // Private constructor - static methods only
  AppMessages._();

  /// Base method for SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  // ============================================
  // SUCCESS MESSAGES
  // ============================================

  /// General success message
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.green[700]!,
      icon: Icons.check_circle,
    );
  }

  /// Successfully saved
  static void savedSuccessfully(BuildContext context, String itemName) {
    showSuccess(context, '$itemName saved! ✅');
  }

  /// Successfully updated
  static void updatedSuccessfully(BuildContext context, String itemName) {
    showSuccess(context, '$itemName updated! ✅');
  }

  /// Successfully deleted
  static void deletedSuccessfully(BuildContext context, String itemName) {
    showSuccess(context, '$itemName deleted! 🗑️');
  }

  /// Successfully archived
  static void archivedSuccessfully(BuildContext context, String itemName) {
    showSuccess(context, '$itemName archived! 📦');
  }

  /// Successfully restored
  static void restoredSuccessfully(BuildContext context, String itemName) {
    showSuccess(context, '$itemName restored! ♻️');
  }

  /// Grow created
  static void growCreated(BuildContext context) {
    showSuccess(context, 'Grow created! 🌱');
  }

  /// Harvest recorded
  static void harvestCreated(BuildContext context) {
    showSuccess(context, 'Harvest recorded! 🌾');
  }

  /// Plant(s) created
  static void plantCreated(BuildContext context, int quantity) {
    if (quantity == 1) {
      showSuccess(context, 'Plant created! 🌱');
    } else {
      showSuccess(context, '$quantity plants created! 🌱');
    }
  }

  /// Log copied
  static void logCopied(BuildContext context) {
    showSuccess(context, 'Log data copied! 📋');
  }

  /// No previous log
  static void noPreviousLog(BuildContext context) {
    showInfo(context, 'No previous log entry found');
  }

  /// Photo(s) saved
  static void photoSaved(BuildContext context, int count) {
    if (count == 1) {
      showSuccess(context, 'Photo saved! 📸');
    } else {
      showSuccess(context, '$count photos saved! 📸');
    }
  }

  /// Photo saving - partially failed
  static void photoSavingPartialError(BuildContext context, int saved, int failed) {
    showWarning(context, '$saved photo(s) saved, $failed failed ⚠️');
  }

  /// Photo saving - error
  static void photoSavingError(BuildContext context, String error) {
    showError(context, 'Error saving photos: $error');
  }

  /// Validation error
  static void validationError(BuildContext context, String fieldName) {
    showError(context, 'Please select $fieldName');
  }

  // ============================================
  // ERROR MESSAGES
  // ============================================

  /// General error message
  static void showError(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.red[700]!,
      icon: Icons.error,
    );
  }

  /// Error while saving
  static void savingError(BuildContext context, String error) {
    showError(context, 'Error while saving: $error');
  }

  /// Error while deleting
  static void deletingError(BuildContext context, String error) {
    showError(context, 'Error while deleting: $error');
  }

  /// Error while loading with retry button
  static void loadingError(
    BuildContext context,
    String itemName, {
    VoidCallback? onRetry,
  }) {
    _showSnackBar(
      context,
      message: 'Error loading $itemName',
      backgroundColor: Colors.red[700]!,
      icon: Icons.error,
      onRetry: onRetry,
    );
  }

  // ============================================
  // INFO MESSAGES
  // ============================================

  /// General info message
  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.blue[700]!,
      icon: Icons.info,
    );
  }

  /// Warning message
  static void showWarning(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.orange[700]!,
      icon: Icons.warning,
    );
  }
}
