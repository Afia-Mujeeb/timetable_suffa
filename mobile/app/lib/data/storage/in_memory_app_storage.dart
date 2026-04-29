import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/storage/app_storage.dart";

class InMemoryAppStorage implements AppStorage {
  String? _selectedSectionCode;
  String? _lastSeenVersionId;
  SectionsSnapshot? _sectionsSnapshot;
  final Map<String, SectionTimetable> _timetables =
      <String, SectionTimetable>{};
  ReminderPreferences _reminderPreferences = ReminderPreferences.defaults;

  @override
  Future<void> clear() async {
    _selectedSectionCode = null;
    _lastSeenVersionId = null;
    _sectionsSnapshot = null;
    _timetables.clear();
  }

  @override
  Future<String?> readLastSeenVersionId() async {
    return _lastSeenVersionId;
  }

  @override
  Future<ReminderPreferences> readReminderPreferences() async {
    return _reminderPreferences;
  }

  @override
  Future<String?> readSelectedSectionCode() async {
    return _selectedSectionCode;
  }

  @override
  Future<SectionsSnapshot?> readSectionsSnapshot() async {
    return _sectionsSnapshot;
  }

  @override
  Future<SectionTimetable?> readSectionTimetable(String sectionCode) async {
    return _timetables[sectionCode];
  }

  @override
  Future<void> writeLastSeenVersionId(String? versionId) async {
    _lastSeenVersionId = versionId;
  }

  @override
  Future<void> writeReminderPreferences(ReminderPreferences preferences) async {
    _reminderPreferences = preferences;
  }

  @override
  Future<void> writeSectionsSnapshot(SectionsSnapshot snapshot) async {
    _sectionsSnapshot = snapshot.copyWith(
      isStale: false,
      cachedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> writeSectionTimetable(SectionTimetable timetable) async {
    _timetables[timetable.section.sectionCode] = timetable.copyWith(
      isStale: false,
      cachedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> writeSelectedSectionCode(String? sectionCode) async {
    _selectedSectionCode = sectionCode;
  }
}
