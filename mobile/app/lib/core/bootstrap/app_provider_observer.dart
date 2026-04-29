import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timetable_app/core/monitoring/app_error_monitor.dart";

class AppProviderObserver extends ProviderObserver {
  AppProviderObserver(this._errorMonitor);

  final AppErrorMonitor _errorMonitor;

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    unawaited(
      _errorMonitor.recordError(
        error,
        stackTrace,
        source: "provider:${provider.name ?? provider.runtimeType}",
        fatal: false,
      ),
    );
  }
}
