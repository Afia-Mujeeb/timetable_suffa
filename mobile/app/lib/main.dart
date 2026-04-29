import "dart:async";
import "dart:ui";

import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timetable_app/app/timetable_app.dart";
import "package:timetable_app/core/bootstrap/app_bootstrap.dart";
import "package:timetable_app/core/bootstrap/app_provider_observer.dart";
import "package:timetable_app/core/providers/app_providers.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await bootstrapApplication();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      bootstrap.errorMonitor.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        source: "flutter.framework",
        fatal: true,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      bootstrap.errorMonitor.recordError(
        error,
        stackTrace,
        source: "platform.dispatcher",
        fatal: true,
      ),
    );
    return true;
  };

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          observers: [
            AppProviderObserver(bootstrap.errorMonitor),
          ],
          overrides: [
            appConfigProvider.overrideWithValue(bootstrap.config),
            appStorageProvider.overrideWithValue(bootstrap.storage),
            appErrorMonitorProvider.overrideWithValue(bootstrap.errorMonitor),
            appBootstrapStatusProvider.overrideWithValue(bootstrap.status),
          ],
          child: const TimetableApp(),
        ),
      );
    },
    (error, stackTrace) {
      unawaited(
        bootstrap.errorMonitor.recordError(
          error,
          stackTrace,
          source: "app.zone",
          fatal: true,
        ),
      );
    },
  );
}
