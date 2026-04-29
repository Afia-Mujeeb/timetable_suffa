import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/models/reminder_models.dart";

abstract interface class AppStorage {
  Future<String?> readSelectedSectionCode();

  Future<void> writeSelectedSectionCode(String? sectionCode);

  Future<String?> readLastSeenVersionId();

  Future<void> writeLastSeenVersionId(String? versionId);

  Future<SectionsSnapshot?> readSectionsSnapshot();

  Future<void> writeSectionsSnapshot(SectionsSnapshot snapshot);

  Future<SectionTimetable?> readSectionTimetable(String sectionCode);

  Future<void> writeSectionTimetable(SectionTimetable timetable);

  Future<ReminderPreferences> readReminderPreferences();

  Future<void> writeReminderPreferences(ReminderPreferences preferences);

  Future<void> clear();
}
