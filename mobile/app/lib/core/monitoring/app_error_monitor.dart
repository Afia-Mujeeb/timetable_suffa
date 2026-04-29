import "package:flutter/foundation.dart";
import "package:timetable_app/core/monitoring/app_error_event.dart";

abstract interface class AppErrorMonitor {
  bool get isPersistent;

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required String source,
    bool fatal = false,
  });

  Future<List<AppErrorEvent>> readRecentEvents();
}

class MemoryAppErrorMonitor implements AppErrorMonitor {
  MemoryAppErrorMonitor({
    this.capacity = 20,
  });

  final int capacity;
  final List<AppErrorEvent> _events = <AppErrorEvent>[];

  @override
  bool get isPersistent => false;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required String source,
    bool fatal = false,
  }) async {
    final event = _buildEvent(
      error,
      stackTrace,
      source: source,
      fatal: fatal,
    );

    _events.insert(0, event);
    if (_events.length > capacity) {
      _events.removeRange(capacity, _events.length);
    }

    debugPrint(
      "[app-error][$source] ${event.exceptionType}: ${event.message}\n${event.stackTrace ?? ""}",
    );
  }

  @override
  Future<List<AppErrorEvent>> readRecentEvents() async {
    return List<AppErrorEvent>.unmodifiable(_events);
  }
}

AppErrorEvent buildAppErrorEvent(
  Object error,
  StackTrace stackTrace, {
  required String source,
  required bool fatal,
}) {
  return _buildEvent(
    error,
    stackTrace,
    source: source,
    fatal: fatal,
  );
}

AppErrorEvent _buildEvent(
  Object error,
  StackTrace stackTrace, {
  required String source,
  required bool fatal,
}) {
  return AppErrorEvent(
    timestamp: DateTime.now().toUtc().toIso8601String(),
    source: source,
    message: error.toString(),
    exceptionType: error.runtimeType.toString(),
    fatal: fatal,
    stackTrace: stackTrace.toString(),
  );
}
