// =============================================
// GROWLOG - Splash Screen (OPTIMIERT - Async Loading)
// =============================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/screens/dashboard_screen.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/widgets/widgets.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/app_state_recovery.dart';
import 'package:growlog_app/utils/version_manager.dart';
import 'package:growlog_app/utils/update_cleanup.dart';
import 'package:growlog_app/utils/auto_recovery_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Wird geladen...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();

    try {
      // ✅ P0 FIX: Version tracking & update detection
      if (kDebugMode) {
        await VersionManager.logVersionInfo();
      }

      final updateInfo = await VersionManager.getUpdateInfo();
      if (updateInfo.isUpdate) {
        AppLogger.info('SplashScreen', '🆕 ${updateInfo.changeDescription}');
        setState(() {
          _status = 'Update wird vorbereitet...';
        });
      }

      // Check if migration is stuck
      final migrationStuck = await VersionManager.isMigrationInProgress();
      if (migrationStuck) {
        AppLogger.error('SplashScreen', '⚠️ Previous migration appears stuck');
        await VersionManager.clearFailedMigrations();
      }

      // ✅ P0 FIX: Check for crash recovery
      final recoveryInfo = await AppStateRecovery.checkRecovery();

      if (recoveryInfo.inCrashLoop) {
        AppLogger.error(
          'SplashScreen',
          '❌ App in crash loop! Count: ${recoveryInfo.crashCount}',
        );
        setState(() {
          _hasError = true;
          _status = 'App-Wiederherstellung läuft...';
        });

        // Give user feedback and reset
        await Future.delayed(const Duration(seconds: 2));
        await AppStateRecovery.resetCrashCount();
      } else if (recoveryInfo.wasKilled && kDebugMode) {
        AppLogger.warning('SplashScreen', '⚠️ App was killed unexpectedly');
        if (recoveryInfo.lastScreen != null) {
          AppLogger.info(
            'SplashScreen',
            'Last screen: ${recoveryInfo.lastScreen}',
          );
        }
      }

      // WICHTIG: sqflite MUSS im Main Thread laufen!
      // Isolates (compute) funktionieren NICHT mit sqflite
      if (kDebugMode) {
        AppLogger.info(
          'SplashScreen',
          '🚀 Starting database initialization...',
        );
      }

      if (updateInfo.isUpdate) {
        setState(() {
          _status = 'Datenbank wird migriert...';
        });
      }

      // ✅ FIX: Timeout nach 10 Minuten (war 30s - zu kurz für Migrationen!)
      // Migrationen können länger dauern, besonders bei großen Datenbanken
      final db = await DatabaseHelper.instance.database.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          AppLogger.error(
            'SplashScreen',
            '⏱️ Database initialization timeout after 10 minutes!',
          );
          throw TimeoutException(
            'Database initialization took too long (>10 min)',
          );
        },
      );
      final dbPath = db.path;

      if (kDebugMode) {
        AppLogger.info('SplashScreen', '✅ Database initialized: $dbPath');
        AppLogger.info(
          'SplashScreen',
          '⏱️  Initialization took: ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // Mark successful initialization
      await AppStateRecovery.resetCrashCount();

      // ✅ NEW: Check if auto-recovery is needed
      setState(() {
        _status = 'Daten werden überprüft...';
      });

      final recoveryNeeded = await _checkAutoRecovery(db);
      if (recoveryNeeded) {
        // Recovery was performed, data should be restored
        if (kDebugMode) {
          AppLogger.info('SplashScreen', '✅ Auto-recovery completed');
        }
      }

      // ✅ Post-Update Cleanup (run in background)
      if (updateInfo.isUpdate) {
        setState(() {
          _status = 'Aufräumen...';
        });
        await UpdateCleanup.performPostUpdateCleanup();
      }

      // Fix 2 Sekunden Splash
      if (stopwatch.elapsedMilliseconds < 2000) {
        await Future.delayed(
          Duration(milliseconds: 2000 - stopwatch.elapsedMilliseconds),
        );
      }

      if (mounted) {
        // OPTIMIERUNG 3: Direkt navigieren ohne weitere Delays
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  // Smooth Fade Transition
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        AppLogger.error('SplashScreen', '❌ Error initializing: $e');
        AppLogger.error('SplashScreen', 'StackTrace: $stackTrace');
      }

      setState(() {
        _hasError = true;
        _status = 'Fehler beim Laden - App wird neu gestartet...';
      });

      // Bei Fehler: kurz warten, dann trotzdem weiter
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning! 🌱';
    if (hour < 18) return 'Good Afternoon! 🌿';
    return 'Good Evening! 🌙';
  }

  /// Check if auto-recovery is needed and offer to user
  Future<bool> _checkAutoRecovery(Database db) async {
    try {
      final recoveryInfo = await AutoRecoveryHelper.shouldOfferRecovery(db);

      if (!recoveryInfo.shouldRecover) {
        // No recovery needed
        return false;
      }

      if (!mounted) return false;

      // Show recovery dialog
      final shouldRecover = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Text('Datenwiederherstellung'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Es wurde ein Problem beim Laden der Daten erkannt.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Grund: ${recoveryInfo.reasonMessage}'),
              const SizedBox(height: 12),
              if (recoveryInfo.backupAvailable) ...[
                const Text(
                  'Ein aktuelles Backup wurde gefunden. Möchten Sie Ihre Daten wiederherstellen?',
                ),
                const SizedBox(height: 8),
                const Text(
                  '⚠️ Dies überschreibt die aktuelle Datenbank!',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ] else ...[
                const Text(
                  'Leider wurde kein Backup gefunden. Sie können versuchen, ein Backup manuell in den Einstellungen wiederherzustellen.',
                ),
              ],
            ],
          ),
          actions: [
            if (!recoveryInfo.backupAvailable)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('OK'),
              )
            else ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Wiederherstellen'),
              ),
            ],
          ],
        ),
      );

      if (shouldRecover == true && recoveryInfo.backupPath != null) {
        // Show loading
        if (mounted) {
          setState(() {
            _status = 'Backup wird wiederhergestellt...';
          });
        }

        // Perform recovery
        final success = await AutoRecoveryHelper.performAutoRecovery(
          recoveryInfo.backupPath!,
        );

        if (success) {
          if (mounted) {
            setState(() {
              _status = 'Wiederherstellung erfolgreich!';
            });
          }
          await Future.delayed(const Duration(seconds: 1));
          return true;
        } else {
          if (mounted) {
            setState(() {
              _hasError = true;
              _status = 'Wiederherstellung fehlgeschlagen!';
            });
          }
          await Future.delayed(const Duration(seconds: 2));
          return false;
        }
      }

      return false;
    } catch (e, stackTrace) {
      AppLogger.error(
        'SplashScreen',
        'Auto-recovery check failed',
        e,
        stackTrace,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFF004225),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // PlantPot Icon mit Animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: PlantPotIcon(
                  size: 100,
                  leavesColor: const Color(0xFF4CAF50),
                  stemColor: const Color(0xFF6D4C41),
                  potColor: isDark
                      ? const Color(0xFF78909C)
                      : const Color(0xFF90A4AE),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Welcome Text
            const Text(
              'Welcome',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),

            // Greeting
            Text(
              _getGreeting(),
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 64),

            // Loading Indicator
            if (!_hasError)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              )
            else
              const Icon(Icons.error_outline, color: Colors.orange, size: 40),

            const SizedBox(height: 16),

            // Status Text
            Text(
              _status,
              style: TextStyle(
                fontSize: 14,
                color: _hasError ? Colors.orange[200] : Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),

            // Debug Info (nur im Debug Mode)
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DEBUG MODE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white54,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
