// =============================================
// GROWLOG - Error Handling Mixin
// Reusable Error Handling Logic
// =============================================

import 'package:flutter/material.dart';

/// Mixin for standardized error handling in all screens
/// Benefits:
/// - Prevents code duplication
/// - Better UX with user feedback
/// - Race Condition Protection (mounted checks)
/// - Retry mechanism
mixin ErrorHandlingMixin<T extends StatefulWidget> on State<T> {
  
  /// Executes an async operation with error handling
  /// 
  /// Features:
  /// - Loading State Management
  /// - Mounted Checks (Race Condition Protection)
  /// - User Feedback (Snackbars)
  /// - Retry Mechanism
  /// - Custom Success Callback
  Future<bool> executeWithErrorHandling({
    required Future<void> Function() operation,
    String? successMessage,
    String? errorPrefix,
    Future<void> Function()? onRetry,
    VoidCallback? onSuccess,
    bool showLoadingIndicator = false,
  }) async {
    try {
      // Execute operation
      await operation();
      
      // Success Feedback (with mounted check!)
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Success Callback (with mounted check!)
      if (mounted && onSuccess != null) {
        onSuccess();
      }
      
      return true;
    } catch (e) {
      // Error Handling (with mounted check!)
      if (mounted) {
        final errorMessage = errorPrefix != null 
            ? '$errorPrefix: $e' 
            : 'Error: $e';
        
        // Show Error with Retry Option
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: onRetry != null
                ? SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () {
                      // Retry with mounted check!
                      if (mounted) {
                        executeWithErrorHandling(
                          operation: onRetry,
                          successMessage: successMessage,
                          errorPrefix: errorPrefix,
                          onRetry: onRetry,
                          onSuccess: onSuccess,
                        );
                      }
                    },
                  )
                : null,
          ),
        );
      }
      
      return false;
    }
  }
  
  /// Shows an error dialog (with mounted check!)
  Future<void> showErrorDialog({
    required String title,
    required String message,
    String? details,
  }) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                details,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Shows a confirm dialog (with mounted check!)
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
    Color? confirmColor,
  }) async {
    if (!mounted) return false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop(false);
              }
            },
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            },
            style: confirmColor != null
                ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Shows a loading dialog (PopScope instead of deprecated WillPopScope)
  void showLoadingDialog({String message = 'Please wait...'}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Closes the loading dialog (with mounted check!)
  void hideLoadingDialog() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  /// Shows a success snackbar (with mounted check!)
  void showSuccessMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// Shows an error snackbar (with mounted check!)
  void showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  /// Shows a warning snackbar (with mounted check!)
  void showWarningMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Shows an info snackbar (with mounted check!)
  void showInfoMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
