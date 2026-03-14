import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import für den Fix
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/screens/splash_screen.dart';
import 'package:growlog_app/screens/privacy_policy_screen.dart';
import 'package:growlog_app/utils/app_theme.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/providers/plant_provider.dart';
import 'package:growlog_app/providers/grow_provider.dart';
import 'package:growlog_app/providers/room_provider.dart';
import 'package:growlog_app/providers/log_provider.dart';

// Import sqflite_ffi for Desktop platforms
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===================== RECOVERY CODE =====================
  // Dieser Block löscht den fehlerhaften Migrations-Status.
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('migration_status') == 'in_progress') {
      await prefs.remove('migration_status');
      await prefs.remove('migration_start_time');
      AppLogger.warning('main.dart', 'FORCE-CLEARED stuck migration flag.');
    }
  } catch (e) {
    AppLogger.error('main.dart', 'Failed to clear migration flag', e);
  }
  // ================= END RECOVERY CODE =================

  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await setupServiceLocator();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error('Flutter', 'Error: ${details.exception}', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('AsyncError', 'Uncaught', error, stack);
    return true;
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlantProvider(getIt())),
        ChangeNotifierProvider(create: (_) => GrowProvider(getIt())),
        ChangeNotifierProvider(create: (_) => RoomProvider(getIt())),
        ChangeNotifierProvider(create: (_) => LogProvider(getIt())),
      ],
      child: const GrowLogApp(),
    ),
  );
}

class GrowLogApp extends StatefulWidget {
  const GrowLogApp({super.key});

  static GrowLogAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<GrowLogAppState>();

  @override
  State<GrowLogApp> createState() => GrowLogAppState();
}

class GrowLogAppState extends State<GrowLogApp> with WidgetsBindingObserver {
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  
  late AppSettings _settings = AppSettings(
    language: 'de',
    isDarkMode: true,
    isExpertMode: false,
    nutrientUnit: NutrientUnit.ec,
    ppmScale: PpmScale.scale700,
    temperatureUnit: TemperatureUnit.celsius,
    lengthUnit: LengthUnit.cm,
    volumeUnit: VolumeUnit.liter,
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      unawaited(_settingsRepo.saveSettings(_settings));
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepo.getSettings().timeout(const Duration(seconds: 5));
      if (mounted) setState(() { _settings = settings; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void updateSettings(AppSettings newSettings) {
    setState(() => _settings = newSettings);
  }

  AppSettings get settings => _settings;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const MaterialApp(home: Scaffold(backgroundColor: Color(0xFF050505), body: Center(child: CircularProgressIndicator(color: Color(0xFF00FFBB)))));

    return MaterialApp(
      title: 'Plantry',
      debugShowCheckedModeBanner: false,
      themeMode: _settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: const SplashScreen(),
      routes: {'/privacy-policy': (context) => const PrivacyPolicyScreen()},
    );
  }
}
