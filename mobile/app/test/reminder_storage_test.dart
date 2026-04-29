import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

void main() {
  test("reminder preferences persist separately from clearing timetable cache",
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);

    await storage.writeReminderPreferences(
      const ReminderPreferences(
        enabled: true,
        leadTime: ReminderLeadTime.fifteenMinutes,
      ),
    );
    await storage.writeSelectedSectionCode("BS-CS-2A");
    await storage.writeLastSeenVersionId("spring-2026");

    await storage.clear();

    final reminderPreferences = await storage.readReminderPreferences();

    expect(reminderPreferences.enabled, isTrue);
    expect(reminderPreferences.leadTime, ReminderLeadTime.fifteenMinutes);
    expect(await storage.readSelectedSectionCode(), isNull);
    expect(await storage.readLastSeenVersionId(), isNull);
  });
}
