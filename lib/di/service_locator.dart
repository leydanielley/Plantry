// =============================================
// GROWLOG - Dependency Injection (Service Locator)
// =============================================

import 'package:get_it/get_it.dart';
import '../database/database_helper.dart';
import '../repositories/plant_repository.dart';
import '../repositories/grow_repository.dart';
import '../repositories/room_repository.dart';
import '../repositories/plant_log_repository.dart';
import '../repositories/fertilizer_repository.dart';
import '../repositories/log_fertilizer_repository.dart';
import '../repositories/photo_repository.dart';
import '../repositories/hardware_repository.dart';
import '../repositories/harvest_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/log_service.dart';
import '../services/backup_service.dart';
import '../utils/app_logger.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Setup all dependencies
///
/// Call this once in main() before runApp():
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await setupServiceLocator();
///   runApp(const GrowLogApp());
/// }
/// ```
Future<void> setupServiceLocator() async {
  AppLogger.info('ServiceLocator', 'Setting up dependency injection...');

  // ═══════════════════════════════════════════
  // DATABASE
  // ═══════════════════════════════════════════
  getIt.registerLazySingleton<DatabaseHelper>(
    () => DatabaseHelper.instance,
  );

  // ═══════════════════════════════════════════
  // REPOSITORIES (Singletons)
  // ═══════════════════════════════════════════
  getIt.registerLazySingleton<PlantRepository>(
    () => PlantRepository(),
  );

  getIt.registerLazySingleton<GrowRepository>(
    () => GrowRepository(),
  );

  getIt.registerLazySingleton<RoomRepository>(
    () => RoomRepository(),
  );

  getIt.registerLazySingleton<PlantLogRepository>(
    () => PlantLogRepository(),
  );

  getIt.registerLazySingleton<FertilizerRepository>(
    () => FertilizerRepository(),
  );

  getIt.registerLazySingleton<LogFertilizerRepository>(
    () => LogFertilizerRepository(),
  );

  getIt.registerLazySingleton<PhotoRepository>(
    () => PhotoRepository(),
  );

  getIt.registerLazySingleton<HardwareRepository>(
    () => HardwareRepository(),
  );

  getIt.registerLazySingleton<HarvestRepository>(
    () => HarvestRepository(),
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(),
  );

  // ═══════════════════════════════════════════
  // SERVICES (Singletons)
  // ═══════════════════════════════════════════
  getIt.registerLazySingleton<LogService>(
    () => LogService(),
  );

  getIt.registerLazySingleton<BackupService>(
    () => BackupService(),
  );

  AppLogger.info('ServiceLocator', '✅ Dependency injection setup complete');
  AppLogger.debug(
    'ServiceLocator',
    'Registered services',
    'Repositories: 10, Services: 2',
  );
}

/// Reset all dependencies (useful for testing)
Future<void> resetServiceLocator() async {
  AppLogger.warning('ServiceLocator', 'Resetting all dependencies...');
  await getIt.reset();
  AppLogger.info('ServiceLocator', '✅ Dependencies reset');
}

/// Check if a dependency is registered
bool isRegistered<T extends Object>() {
  return getIt.isRegistered<T>();
}
