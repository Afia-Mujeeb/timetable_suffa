import "dart:convert";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/core/monitoring/app_error_event.dart";
import "package:timetable_app/core/monitoring/app_error_monitor.dart";

class SharedPreferencesAppErrorMonitor implements AppErrorMonitor {
  SharedPreferencesAppErrorMonitor(
    this._preferences, {
    this.capacity = 20,
  });

  static const String _eventsKey = "app_error_events";

  final SharedPreferences _preferences;
  final int capacity;

  @override
  bool get isPersistent => true;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required String source,
    bool fatal = false,
  }) async {
    final event = buildAppErrorEvent(
      error,
      stackTrace,
      source: source,
      fatal: fatal,
    );

    debugPrint(
      "[app-error][$source] ${event.exceptionType}: ${event.message}\n${event.stackTrace ?? ""}",
    );

    try {
      final events = await readRecentEvents();
      final updated = <AppErrorEvent>[event, ...events];
      if (updated.length > capacity) {
        updated.removeRange(capacity, updated.length);
      }
      await _preferences.setString(
        _eventsKey,
        jsonEncode(
          updated.map((item) => item.toJson()).toList(growable: false),
        ),
      );
    } catch (storageError, storageStackTrace) {
      debugPrint(
        "[app-error][monitor.storage] $storageError\n$storageStackTrace",
      );
    }
  }

  @override
  Future<List<AppErrorEvent>> readRecentEvents() async {
    try {
      final raw = _preferences.getString(_eventsKey);
      if (raw == null || raw.isEmpty) {
        return const <AppErrorEvent>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        await _preferences.remove(_eventsKey);
        return const <AppErrorEvent>[];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AppErrorEvent.fromJson)
          .toList(growable: false);
    } catch (_) {
      await _preferences.remove(_eventsKey);
      return const <AppErrorEvent>[];
    }
  }
}
