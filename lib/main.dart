import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'models/app_settings.dart';
import 'repositories/interfaces/i_settings_repository.dart';
import 'screens/splash_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'utils/app_theme.dart';
import 'utils/app_logger.dart';
import 'di/service_locator.dart';
import 'providers/plant_provider.dart';
import 'providers/grow_provider.dart';
import 'providers/room_provider.dart';
import 'providers/log_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await setupServiceLocator();
  AppLogger.info('Main', 'Service locator initialized');

  // Global Error Handler für Flutter Errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Flutter',
      'Flutter Error: ${details.exception}',
      details.exception,
      details.stack,
    );
  };

  // Global Error Handler für Async Errors (außerhalb Flutter Framework)
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('AsyncError', 'Uncaught Error', error, stack);
    return true; // Error handled
  };

  // Wrap app with multiple providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlantProvider(getIt()),
        ),
        ChangeNotifierProvider(
          create: (_) => GrowProvider(getIt()),
        ),
        ChangeNotifierProvider(
          create: (_) => RoomProvider(getIt()),
        ),
        ChangeNotifierProvider(
          create: (_) => LogProvider(getIt()),
        ),
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
  // ✅ FIX: Initialize with defaults to prevent LateInitializationError
  late AppSettings _settings = AppSettings(
    language: 'de',
    isDarkMode: false,
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

    AppLogger.info('AppLifecycle', 'State changed: ${state.name}');

    switch (state) {
      case AppLifecycleState.resumed:
        AppLogger.info('AppLifecycle', '✅ App resumed');
        break;
      case AppLifecycleState.inactive:
        // Foldable is folding or app switching
        AppLogger.info('AppLifecycle', '⚠️ App inactive (possibly folding)');
        break;
      case AppLifecycleState.paused:
        AppLogger.info('AppLifecycle', '⏸️ App paused');
        _handleAppPause();
        break;
      case AppLifecycleState.detached:
        AppLogger.info('AppLifecycle', '🔌 App detached');
        break;
      case AppLifecycleState.hidden:
        AppLogger.info('AppLifecycle', '👁️ App hidden');
        break;
    }
  }

  /// Handle app pause - save critical state
  Future<void> _handleAppPause() async {
    try {
      // Save current settings to prevent loss
      await _settingsRepo.saveSettings(_settings);
      AppLogger.info('AppLifecycle', 'Settings saved on pause');
    } catch (e) {
      AppLogger.error('AppLifecycle', 'Failed to save settings on pause', e);
    }
  }

  Future<void> _loadSettings() async {
    try {
      // Timeout claudenach 10 Sekunden - verhindert unendliches Hängen
      final settings = await _settingsRepo.getSettings().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('Main', 'Settings loading timeout - using defaults');
          // Fallback auf Default-Settings
          return AppSettings(
            language: 'de',
            isDarkMode: false,
            isExpertMode: false,
            nutrientUnit: NutrientUnit.ec,
            ppmScale: PpmScale.scale700,
            temperatureUnit: TemperatureUnit.celsius,
            lengthUnit: LengthUnit.cm,
            volumeUnit: VolumeUnit.liter,
          );
        },
      );

      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Main', 'Error loading settings', e, stackTrace);

      // Fallback auf Default-Settings bei Fehler
      if (mounted) {
        setState(() {
          _settings = AppSettings(
            language: 'de',
            isDarkMode: false,
            isExpertMode: false,
            nutrientUnit: NutrientUnit.ec,
            ppmScale: PpmScale.scale700,
            temperatureUnit: TemperatureUnit.celsius,
            lengthUnit: LengthUnit.cm,
            volumeUnit: VolumeUnit.liter,
          );
          _isLoading = false;
        });
      }
    }
  }

  void updateSettings(AppSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
  }

  // Getter to access current settings
  AppSettings get settings => _settings;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.green[700],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Plantry',
      debugShowCheckedModeBanner: false,
      themeMode: _settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),

      home: const SplashScreen(),

      // Named routes for deep linking
      routes: {
        '/privacy-policy': (context) => const PrivacyPolicyScreen(),
      },
    );
  }
}