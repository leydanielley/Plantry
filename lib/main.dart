import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'models/app_settings.dart';
import 'repositories/settings_repository.dart';
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

class GrowLogAppState extends State<GrowLogApp> {
  final SettingsRepository _settingsRepo = getIt<SettingsRepository>();
  late AppSettings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
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