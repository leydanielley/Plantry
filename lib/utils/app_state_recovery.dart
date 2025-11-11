// =============================================
// GROWLOG - App State Recovery
// Handles recovery from background kills
// =============================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:growlog_app/utils/app_logger.dart';

class AppStateRecovery {
  // ✅ AUDIT FIX: Extracted timeout and threshold constants
  static const String _keyLastActiveTimestamp = 'last_active_timestamp';
  static const String _keyLastActiveScreen = 'last_active_screen';
  static const String _keyHasUnsavedChanges = 'has_unsaved_changes';
  static const String _keyUnsavedDataJson = 'unsaved_data_json';
  static const String _keyCrashCount = 'crash_count';

  // Timeout constants
  static const int _recentActivityMinutes = 5; // Consider app recently active if within 5 minutes
  static const int _crashLoopThreshold = 3; // 3+ crashes = crash loop

  /// Save current app state
  static Future<void> saveState({
    required String currentScreen,
    bool hasUnsavedChanges = false,
    String? unsavedDataJson,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(_keyLastActiveTimestamp, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_keyLastActiveScreen, currentScreen);
      await prefs.setBool(_keyHasUnsavedChanges, hasUnsavedChanges);

      if (unsavedDataJson != null) {
        await prefs.setString(_keyUnsavedDataJson, unsavedDataJson);
      }

      AppLogger.debug('AppStateRecovery', 'State saved: $currentScreen');
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Failed to save state', e);
    }
  }

  /// Check if app was killed unexpectedly
  static Future<bool> wasKilledUnexpectedly() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lastActiveTimestamp = prefs.getInt(_keyLastActiveTimestamp);
      final hasUnsavedChanges = prefs.getBool(_keyHasUnsavedChanges) ?? false;

      if (lastActiveTimestamp == null) {
        return false; // First launch
      }

      final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveTimestamp);
      final timeSinceActive = DateTime.now().difference(lastActive);

      // If app was active within last N minutes and had unsaved changes, likely killed
      final wasRecentlyActive = timeSinceActive.inMinutes < _recentActivityMinutes;

      if (wasRecentlyActive && hasUnsavedChanges) {
        AppLogger.warning('AppStateRecovery', 'App may have been killed unexpectedly');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error checking kill state', e);
      return false;
    }
  }

  /// Get last active screen
  static Future<String?> getLastActiveScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastActiveScreen);
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error getting last screen', e);
      return null;
    }
  }

  /// Get unsaved data
  static Future<String?> getUnsavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUnsavedDataJson);
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error getting unsaved data', e);
      return null;
    }
  }

  /// Clear unsaved state (called after successful recovery or user dismissal)
  static Future<void> clearUnsavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyHasUnsavedChanges, false);
      await prefs.remove(_keyUnsavedDataJson);

      AppLogger.info('AppStateRecovery', 'Unsaved state cleared');
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error clearing unsaved state', e);
    }
  }

  /// Mark app as cleanly closed
  static Future<void> markCleanExit() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyHasUnsavedChanges, false);
      await prefs.setInt(_keyLastActiveTimestamp, DateTime.now().millisecondsSinceEpoch);

      AppLogger.debug('AppStateRecovery', 'Clean exit marked');
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error marking clean exit', e);
    }
  }

  /// Increment crash counter
  static Future<int> incrementCrashCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_keyCrashCount) ?? 0) + 1;

      await prefs.setInt(_keyCrashCount, count);

      AppLogger.warning('AppStateRecovery', 'Crash count: $count');
      return count;
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error incrementing crash count', e);
      return 0;
    }
  }

  /// Reset crash counter
  static Future<void> resetCrashCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCrashCount, 0);

      AppLogger.info('AppStateRecovery', 'Crash count reset');
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error resetting crash count', e);
    }
  }

  /// Get crash count
  static Future<int> getCrashCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyCrashCount) ?? 0;
    } catch (e) {
      AppLogger.error('AppStateRecovery', 'Error getting crash count', e);
      return 0;
    }
  }

  /// Check if app is in crash loop (3+ crashes in short time)
  static Future<bool> isInCrashLoop() async {
    final count = await getCrashCount();
    return count >= _crashLoopThreshold;
  }

  /// Perform recovery check on app start
  static Future<RecoveryInfo> checkRecovery() async {
    final wasKilled = await wasKilledUnexpectedly();
    final lastScreen = await getLastActiveScreen();
    final unsavedData = await getUnsavedData();
    final crashCount = await getCrashCount();
    final inCrashLoop = crashCount >= _crashLoopThreshold;

    if (wasKilled) {
      await incrementCrashCount();
    } else {
      await resetCrashCount();
    }

    return RecoveryInfo(
      wasKilled: wasKilled,
      lastScreen: lastScreen,
      unsavedData: unsavedData,
      crashCount: crashCount,
      inCrashLoop: inCrashLoop,
    );
  }
}

/// Recovery information
class RecoveryInfo {
  final bool wasKilled;
  final String? lastScreen;
  final String? unsavedData;
  final int crashCount;
  final bool inCrashLoop;

  const RecoveryInfo({
    required this.wasKilled,
    this.lastScreen,
    this.unsavedData,
    required this.crashCount,
    required this.inCrashLoop,
  });

  bool get hasRecoverableData => wasKilled && (lastScreen != null || unsavedData != null);
}
