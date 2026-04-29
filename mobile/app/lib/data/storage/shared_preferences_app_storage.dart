import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/storage/app_storage.dart";

class SharedPreferencesAppStorage implements AppStorage {
  SharedPreferencesAppStorage(this._preferences);

  static const String _selectedSectionCodeKey = "selected_section_code";
  static const String _lastSeenVersionIdKey = "last_seen_version_id";
  static const String _sectionsSnapshotKey = "sections_snapshot";
  static const String _timetablePrefix = "section_timetable_";

  final SharedPreferences _preferences;

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

    return SectionsSnapshot.fromCacheJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  @override
  Future<SectionTimetable?> readSectionTimetable(String sectionCode) async {
    final value = _preferences.getString(_timetableKey(sectionCode));
    if (value == null || value.isEmpty) {
      return null;
    }

    return SectionTimetable.fromCacheJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
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
}
