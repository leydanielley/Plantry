// =============================================
// GROWLOG - Splash Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:growlog_app/screens/dashboard_screen.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/app_state_recovery.dart';
import 'package:growlog_app/utils/version_manager.dart';
import 'package:growlog_app/utils/update_cleanup.dart';
import 'package:growlog_app/utils/auto_recovery_helper.dart';
import 'package:growlog_app/utils/backup_progress_notifier.dart';
import 'package:growlog_app/screens/manual_recovery_screen.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

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

      // Check if migration crashed/stuck - show recovery screen immediately
      final migrationStuck = await VersionManager.isMigrationInProgress();
      if (migrationStuck) {
        AppLogger.error(
          'SplashScreen',
          '⚠️ Previous migration appears stuck or crashed',
        );

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

      // Timeout of 10 minutes — migrations can take longer with large databases
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

      if (updateInfo.isUpdate) {
        setState(() {
          _status = 'Aufräumen...';
        });
        await UpdateCleanup.performPostUpdateCleanup();
      }

      // Clear backup progress
      BackupProgressNotifier.instance.clear();

      if (mounted) {
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

      // Stay on splash screen and show error state — do NOT navigate to Dashboard
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

  /// Show critical database error dialog
  Future<void> _showDatabaseErrorDialog(String errorMessage) async {
    // If too many retries, offer alternative options
    final tooManyRetries = _initAttempts >= _maxRetries;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final t = AppTranslations(Localizations.localeOf(context).languageCode);
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                tooManyRetries ? Icons.error : Icons.error_outline,
                color: tooManyRetries ? Colors.red : Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(t['splash_error_db_title']),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tooManyRetries
                      ? '${t['splash_error_db_retries']} ($_initAttempts)'
                      : t['splash_error_db_retries'],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t['splash_error_critical'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t['splash_error_manual_recovery'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  t['splash_error_causes'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• Migration fehlgeschlagen'),
                const Text('• Datenbank beschädigt'),
                const Text('• Nicht genug Speicherplatz'),
                const Text('• App-Berechtigungen fehlen'),
                const SizedBox(height: 16),
                Text(
                  tooManyRetries ? t['splash_error_action'] : 'Sie können:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (!tooManyRetries) ...[
                  Text('1. ${t['splash_btn_retry']}'),
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
                      style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
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
                child: Text(t['splash_btn_close']),
              ),
            if (!tooManyRetries)
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop('retry'),
                icon: const Icon(Icons.refresh),
                label: Text(t['splash_btn_retry']),
              ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop('manual_recovery'),
              icon: const Icon(Icons.build),
              label: Text(t['splash_btn_recovery']),
            ),
          ],
        );
      },
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
    return Scaffold(
      backgroundColor: DT.canvas,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo mit Animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'PLANTRY',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: DT.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: DT.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'PLANT HEALTH TRACKER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: DT.accent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 64),

            // Loading Indicator
            if (!_hasError)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(DT.accent),
                  strokeWidth: 2.5,
                ),
              )
            else
              const Icon(Icons.error_outline, color: DT.error, size: 40),

            const SizedBox(height: 16),

            // Status Text
            Text(
              _status,
              style: TextStyle(
                fontSize: 13,
                color: _hasError ? DT.error : DT.textSecondary,
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            _backupProgress!.current / _backupProgress!.total,
                        minHeight: 6,
                        backgroundColor: DT.elevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          DT.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _backupProgress!.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DT.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            // Debug Info
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: DT.elevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DEBUG MODE',
                  style: TextStyle(
                    fontSize: 10,
                    color: DT.textTertiary,
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
