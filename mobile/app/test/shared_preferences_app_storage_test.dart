import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/core/monitoring/app_error_monitor.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

void main() {
  test("drops malformed cached payloads and reports the read failures",
      () async {
    SharedPreferences.setMockInitialValues({
      "sections_snapshot": "{not-json",
      "section_timetable_BS-CS-2A": "{still-not-json",
      "reminder_preferences": "{broken",
    });
    final preferences = await SharedPreferences.getInstance();
    final monitor = MemoryAppErrorMonitor();
    final storage = SharedPreferencesAppStorage(
      preferences,
      errorMonitor: monitor,
    );

    expect(await storage.readSectionsSnapshot(), isNull);
    expect(await storage.readSectionTimetable("BS-CS-2A"), isNull);

    final preferencesResult = await storage.readReminderPreferences();
    expect(preferencesResult.enabled, ReminderPreferences.defaults.enabled);
    expect(preferencesResult.leadTime, ReminderPreferences.defaults.leadTime);

    final events = await monitor.readRecentEvents();
    expect(events, hasLength(3));
    expect(
      events.map((event) => event.source),
      containsAll(<String>[
        "storage.sections_snapshot",
        "storage.section_timetable:BS-CS-2A",
        "storage.reminder_preferences",
      ]),
    );
  });
}
