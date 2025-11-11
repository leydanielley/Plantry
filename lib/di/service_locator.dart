// =============================================
// GROWLOG - Dependency Injection (Service Locator)
// =============================================

import 'package:get_it/get_it.dart';
import 'package:growlog_app/database/database_helper.dart';

// Repository Interfaces
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_log_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_photo_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_hardware_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_notification_repository.dart';

// Repository Implementations
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/grow_repository.dart';
import 'package:growlog_app/repositories/room_repository.dart';
import 'package:growlog_app/repositories/plant_log_repository.dart';
import 'package:growlog_app/repositories/fertilizer_repository.dart';
import 'package:growlog_app/repositories/log_fertilizer_repository.dart';
import 'package:growlog_app/repositories/photo_repository.dart';
import 'package:growlog_app/repositories/hardware_repository.dart';
import 'package:growlog_app/repositories/harvest_repository.dart';
import 'package:growlog_app/repositories/settings_repository.dart';
import 'package:growlog_app/repositories/rdwc_repository.dart';
import 'package:growlog_app/repositories/notification_repository.dart';

// Service Interfaces
import 'package:growlog_app/services/interfaces/i_log_service.dart';
import 'package:growlog_app/services/interfaces/i_backup_service.dart';
import 'package:growlog_app/services/interfaces/i_health_score_service.dart';
import 'package:growlog_app/services/interfaces/i_warning_service.dart';
import 'package:growlog_app/services/interfaces/i_harvest_service.dart';
import 'package:growlog_app/services/interfaces/i_notification_service.dart';

// Service Implementations
import 'package:growlog_app/services/log_service.dart';
import 'package:growlog_app/services/backup_service.dart';
import 'package:growlog_app/services/health_score_service.dart';
import 'package:growlog_app/services/warning_service.dart';
import 'package:growlog_app/services/harvest_service.dart';
import 'package:growlog_app/services/notification_service.dart';

import 'package:growlog_app/utils/app_logger.dart';

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
  getIt.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper.instance);

  // ═══════════════════════════════════════════
  // REPOSITORIES (Interface-based Singletons)
  // ═══════════════════════════════════════════
  getIt.registerLazySingleton<IPlantRepository>(() => PlantRepository());

  getIt.registerLazySingleton<IGrowRepository>(() => GrowRepository());

  getIt.registerLazySingleton<IRoomRepository>(() => RoomRepository());

  getIt.registerLazySingleton<IPlantLogRepository>(() => PlantLogRepository());

  getIt.registerLazySingleton<IFertilizerRepository>(
    () => FertilizerRepository(),
  );

  getIt.registerLazySingleton<ILogFertilizerRepository>(
    () => LogFertilizerRepository(),
  );

  getIt.registerLazySingleton<IPhotoRepository>(() => PhotoRepository());

  getIt.registerLazySingleton<IHardwareRepository>(() => HardwareRepository());

  getIt.registerLazySingleton<IHarvestRepository>(() => HarvestRepository());

  getIt.registerLazySingleton<ISettingsRepository>(() => SettingsRepository());

  getIt.registerLazySingleton<IRdwcRepository>(() => RdwcRepository());

  getIt.registerLazySingleton<INotificationRepository>(
    () => NotificationRepository(),
  );

  // ═══════════════════════════════════════════
  // SERVICES (Interface-based Singletons)
  // ═══════════════════════════════════════════
  getIt.registerLazySingleton<ILogService>(
    () => LogService(getIt<DatabaseHelper>(), getIt<IPlantRepository>()),
  );

  getIt.registerLazySingleton<IBackupService>(() => BackupService());

  getIt.registerLazySingleton<IHealthScoreService>(
    () => HealthScoreService(
      getIt<IPlantLogRepository>(),
      getIt<IPhotoRepository>(),
    ),
  );

  getIt.registerLazySingleton<IWarningService>(
    () =>
        WarningService(getIt<IPlantLogRepository>(), getIt<IPhotoRepository>()),
  );

  getIt.registerLazySingleton<IHarvestService>(
    () => HarvestService(getIt<IHarvestRepository>()),
  );

  getIt.registerLazySingleton<INotificationService>(
    () => NotificationService(),
  );

  AppLogger.info('ServiceLocator', '✅ Dependency injection setup complete');
  AppLogger.debug(
    'ServiceLocator',
    'Registered services',
    'Repositories: 12, Services: 6',
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
