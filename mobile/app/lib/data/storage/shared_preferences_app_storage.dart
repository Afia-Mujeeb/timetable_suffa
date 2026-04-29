import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/core/monitoring/app_error_monitor.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/storage/app_storage.dart";

class SharedPreferencesAppStorage implements AppStorage {
  SharedPreferencesAppStorage(
    this._preferences, {
    AppErrorMonitor? errorMonitor,
  }) : _errorMonitor = errorMonitor;

  static const String _selectedSectionCodeKey = "selected_section_code";
  static const String _lastSeenVersionIdKey = "last_seen_version_id";
  static const String _sectionsSnapshotKey = "sections_snapshot";
  static const String _timetablePrefix = "section_timetable_";
  static const String _reminderPreferencesKey = "reminder_preferences";

  final SharedPreferences _preferences;
  final AppErrorMonitor? _errorMonitor;

  @override
  Future<void> clear() async {
    final keys = _preferences.getKeys();
    for (final key in keys) {
      if (key == _selectedSectionCodeKey ||
          key == _lastSeenVersionIdKey ||
          key == _sectionsSnapshotKey ||
          key.startsWith(_timetablePrefix)) {
        await _preferences.remove(key);
      }
    }
  }

  @override
  Future<String?> readLastSeenVersionId() async {
    return _preferences.getString(_lastSeenVersionIdKey);
  }

  @override
  Future<String?> readSelectedSectionCode() async {
    return _preferences.getString(_selectedSectionCodeKey);
  }

  @override
  Future<SectionsSnapshot?> readSectionsSnapshot() async {
    final value = _preferences.getString(_sectionsSnapshotKey);
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return SectionsSnapshot.fromCacheJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      await _preferences.remove(_sectionsSnapshotKey);
      await _reportReadFailure(
        error,
        stackTrace,
        source: "storage.sections_snapshot",
      );
      return null;
    }
  }

  @override
  Future<SectionTimetable?> readSectionTimetable(String sectionCode) async {
    final value = _preferences.getString(_timetableKey(sectionCode));
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return SectionTimetable.fromCacheJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      await _preferences.remove(_timetableKey(sectionCode));
      await _reportReadFailure(
        error,
        stackTrace,
        source: "storage.section_timetable:$sectionCode",
      );
      return null;
    }
  }

  @override
  Future<ReminderPreferences> readReminderPreferences() async {
    final value = _preferences.getString(_reminderPreferencesKey);
    if (value == null || value.isEmpty) {
      return ReminderPreferences.defaults;
    }

    try {
      return ReminderPreferences.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      await _preferences.remove(_reminderPreferencesKey);
      await _reportReadFailure(
        error,
        stackTrace,
        source: "storage.reminder_preferences",
      );
      return ReminderPreferences.defaults;
    }
  }

  @override
  Future<void> writeLastSeenVersionId(String? versionId) async {
    if (versionId == null || versionId.isEmpty) {
      await _preferences.remove(_lastSeenVersionIdKey);
      return;
    }

    await _preferences.setString(_lastSeenVersionIdKey, versionId);
  }

  @override
  Future<void> writeSectionTimetable(SectionTimetable timetable) async {
    final payload = timetable.copyWith(
      isStale: false,
      cachedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _preferences.setString(
      _timetableKey(timetable.section.sectionCode),
      jsonEncode(payload.toJson()),
    );
  }

  @override
  Future<void> writeSectionsSnapshot(SectionsSnapshot snapshot) async {
    final payload = snapshot.copyWith(
      isStale: false,
      cachedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _preferences.setString(
      _sectionsSnapshotKey,
      jsonEncode(payload.toJson()),
    );
  }

  @override
  Future<void> writeReminderPreferences(ReminderPreferences preferences) async {
    await _preferences.setString(
      _reminderPreferencesKey,
      jsonEncode(preferences.toJson()),
    );
  }

  @override
  Future<void> writeSelectedSectionCode(String? sectionCode) async {
    if (sectionCode == null || sectionCode.isEmpty) {
      await _preferences.remove(_selectedSectionCodeKey);
      return;
    }

    await _preferences.setString(_selectedSectionCodeKey, sectionCode);
  }

  String _timetableKey(String sectionCode) {
    return "$_timetablePrefix$sectionCode";
  }

  Future<void> _reportReadFailure(
    Object error,
    StackTrace stackTrace, {
    required String source,
  }) async {
    await _errorMonitor?.recordError(
      error,
      stackTrace,
      source: source,
      fatal: false,
    );
  }
}
