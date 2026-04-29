import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/core/monitoring/app_error_monitor.dart";
import "package:timetable_app/core/monitoring/shared_preferences_app_error_monitor.dart";
import "package:timetable_app/data/storage/app_storage.dart";
import "package:timetable_app/data/storage/in_memory_app_storage.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

class AppBootstrapStatus {
  const AppBootstrapStatus({
    required this.isDegraded,
    this.message,
  });

  static const healthy = AppBootstrapStatus(isDegraded: false);

  final bool isDegraded;
  final String? message;
}

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.config,
    required this.storage,
    required this.errorMonitor,
    required this.status,
  });

  final AppConfig config;
  final AppStorage storage;
  final AppErrorMonitor errorMonitor;
  final AppBootstrapStatus status;
}

Future<AppBootstrapResult> bootstrapApplication({
  SharedPreferencesLoader loadPreferences = SharedPreferences.getInstance,
}) async {
  final config = AppConfig.fromEnvironment();

  try {
    final preferences = await loadPreferences();
    final errorMonitor = SharedPreferencesAppErrorMonitor(preferences);
    final storage = SharedPreferencesAppStorage(
      preferences,
      errorMonitor: errorMonitor,
    );

    return AppBootstrapResult(
      config: config,
      storage: storage,
      errorMonitor: errorMonitor,
      status: AppBootstrapStatus.healthy,
    );
  } catch (error, stackTrace) {
    final errorMonitor = MemoryAppErrorMonitor();
    await errorMonitor.recordError(
      error,
      stackTrace,
      source: "bootstrap.shared_preferences",
      fatal: false,
    );

    return AppBootstrapResult(
      config: config,
      storage: InMemoryAppStorage(),
      errorMonitor: errorMonitor,
      status: const AppBootstrapStatus(
        isDegraded: true,
        message:
            "Local storage could not be restored, so the app is running in temporary memory-only mode until restart.",
      ),
    );
  }
}
