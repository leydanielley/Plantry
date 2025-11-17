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
import 'package:growlog_app/utils/backup_progress_notifier.dart';
import 'package:growlog_app/screens/manual_recovery_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Wird geladen...';
  bool _hasError = false;
  BackupProgressEvent? _backupProgress;
  StreamSubscription<BackupProgressEvent>? _progressSubscription;
  int _initAttempts = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _setupProgressListener();
    _initializeApp();
  }

  /// Setup listener for backup progress
  void _setupProgressListener() {
    _progressSubscription = BackupProgressNotifier.instance.stream.listen((
      event,
    ) {
      if (mounted) {
        setState(() {
          _backupProgress = event;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    _initAttempts++;

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

      // ✅ NEW: Check if migration crashed/stuck - show recovery screen immediately
      final migrationStuck = await VersionManager.isMigrationInProgress();
      if (migrationStuck) {
        AppLogger.error('SplashScreen', '⚠️ Previous migration appears stuck or crashed');

        if (mounted) {
          // Navigate to Manual Recovery Screen - user MUST make a choice
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ManualRecoveryScreen(
                errorMessage:
                    'Die letzte Datenbank-Migration ist fehlgeschlagen oder wurde unterbrochen. '
                    'Bitte wählen Sie eine der folgenden Optionen:\n\n'
                    '1. Backup wiederherstellen (empfohlen)\n'
                    '2. Neue Datenbank erstellen (alle Daten gehen verloren)',
                allowSkip: false, // Force user to make a choice
              ),
            ),
          );
          return; // Stop splash screen initialization
        }
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

      // Clear backup progress
      BackupProgressNotifier.instance.clear();

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

      // Clear backup progress on error
      BackupProgressNotifier.instance.clear();

      // ✅ CRITICAL FIX: DON'T navigate to Dashboard on DB error!
      // Instead, stay on splash screen and show error state
      setState(() {
        _hasError = true;
        _status = 'Kritischer Fehler beim Laden der Datenbank';
      });

      // Show error dialog with options
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _showDatabaseErrorDialog(e.toString());
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning! 🌱';
    if (hour < 18) return 'Good Afternoon! 🌿';
    return 'Good Evening! 🌙';
  }

  /// Show critical database error dialog
  Future<void> _showDatabaseErrorDialog(String errorMessage) async {
    // If too many retries, offer alternative options
    final tooManyRetries = _initAttempts >= _maxRetries;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              tooManyRetries ? Icons.error : Icons.error_outline,
              color: tooManyRetries ? Colors.red : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text('Datenbankfehler'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tooManyRetries
                    ? 'Die Datenbank konnte nach $_initAttempts Versuchen nicht geladen werden.'
                    : 'Die Datenbank konnte nicht geladen werden.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (tooManyRetries) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Kritischer Fehler',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Bitte verwenden Sie die manuelle Wiederherstellung, um Ihre Daten zu retten.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Mögliche Ursachen:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• Migration fehlgeschlagen'),
              const Text('• Datenbank beschädigt'),
              const Text('• Nicht genug Speicherplatz'),
              const Text('• App-Berechtigungen fehlen'),
              const SizedBox(height: 16),
              Text(
                tooManyRetries ? 'Empfohlene Aktion:' : 'Sie können:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (!tooManyRetries) ...[
                const Text('1. Nochmal versuchen'),
                const Text('2. Manuelle Wiederherstellung starten'),
                const Text('3. Support kontaktieren'),
              ] else ...[
                const Text('→ Manuelle Wiederherstellung öffnen'),
                const Text('   (Daten aus Backup wiederherstellen)'),
              ],
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                const Text(
                  'Debug Info:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!tooManyRetries)
            TextButton(
              onPressed: () => Navigator.of(context).pop('close'),
              child: const Text('App schließen'),
            ),
          if (!tooManyRetries)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop('retry'),
              icon: const Icon(Icons.refresh),
              label: const Text('Nochmal versuchen'),
            ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop('manual_recovery'),
            icon: const Icon(Icons.build),
            label: Text(
              tooManyRetries ? 'Wiederherstellung öffnen' : 'Manuelle Wiederherstellung',
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    switch (result) {
      case 'retry':
        // Retry initialization
        setState(() {
          _hasError = false;
          _status = 'Wird geladen...';
        });
        _initializeApp();
        break;

      case 'manual_recovery':
        // Navigate to manual recovery screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ManualRecoveryScreen(
              errorMessage: errorMessage,
              allowSkip: false, // Don't allow skip if we're in error state
            ),
          ),
        );
        break;

      case 'close':
      default:
        // Close app - do nothing, user will use system back button
        break;
    }
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

            // Backup Progress
            if (_backupProgress != null && _backupProgress!.total > 0) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            _backupProgress!.current / _backupProgress!.total,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Progress Text
                    Text(
                      _backupProgress!.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

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
