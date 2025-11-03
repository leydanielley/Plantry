// =============================================
// GROWLOG - Splash Screen (OPTIMIERT - Async Loading)
// =============================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dashboard_screen.dart';
import '../database/database_helper.dart';
import '../widgets/widgets.dart';
import '../utils/app_logger.dart';

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
      // WICHTIG: sqflite MUSS im Main Thread laufen!
      // Isolates (compute) funktionieren NICHT mit sqflite
      if (kDebugMode) {
        AppLogger.info('SplashScreen', '🚀 Starting database initialization...');
      }

      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path;

      if (kDebugMode) {
        AppLogger.info('SplashScreen', '✅ Database initialized: $dbPath');
        AppLogger.info('SplashScreen', '⏱️  Initialization took: ${stopwatch.elapsedMilliseconds}ms');
      }
      
      // Fix 2 Sekunden Splash
      if (stopwatch.elapsedMilliseconds < 2000) {
        await Future.delayed(Duration(milliseconds: 2000 - stopwatch.elapsedMilliseconds));
      }
      
      if (mounted) {
        // OPTIMIERUNG 3: Direkt navigieren ohne weitere Delays
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        _status = 'Fehler beim Laden';
      });
      
      // Bei Fehler: kurz warten, dann trotzdem weiter
      await Future.delayed(const Duration(seconds: 1));
      
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFF004225),
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
                return Transform.scale(
                  scale: value,
                  child: child,
                );
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
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
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
              const Icon(
                Icons.error_outline,
                color: Colors.orange,
                size: 40,
              ),
            
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
