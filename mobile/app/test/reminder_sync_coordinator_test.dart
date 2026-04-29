import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";
import "package:timetable_app/data/reminders/reminder_sync_coordinator.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

void main() {
  test(
    "syncSelectedSection schedules reminders for the selected cached timetable",
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = SharedPreferencesAppStorage(preferences);
      final scheduler = _FakeReminderScheduler();
      final coordinator = ReminderSyncCoordinator(
        storage: storage,
        scheduler: scheduler,
      );

      await storage.writeSelectedSectionCode("BS-CS-2A");
      await storage.writeReminderPreferences(
        const ReminderPreferences(
          enabled: true,
          leadTime: ReminderLeadTime.tenMinutes,
        ),
      );
      await storage.writeSectionTimetable(_sectionTimetable);

      await coordinator.syncSelectedSection();

      expect(scheduler.cancelAllCallCount, 0);
      expect(scheduler.replaceScheduleCallCount, 1);
      expect(scheduler.lastScheduledReminders, hasLength(1));
      expect(scheduler.lastScheduledReminders.single.sectionCode, "BS-CS-2A");
    },
  );

  test("syncSelectedSection cancels reminders when preferences are disabled",
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);
    final scheduler = _FakeReminderScheduler();
    final coordinator = ReminderSyncCoordinator(
      storage: storage,
      scheduler: scheduler,
    );

    await storage.writeSelectedSectionCode("BS-CS-2A");
    await storage.writeReminderPreferences(
      const ReminderPreferences(
        enabled: false,
        leadTime: ReminderLeadTime.tenMinutes,
      ),
    );
    await storage.writeSectionTimetable(_sectionTimetable);

    await coordinator.syncSelectedSection();

    expect(scheduler.cancelAllCallCount, 1);
    expect(scheduler.replaceScheduleCallCount, 0);
  });

  test("syncForSectionTimetable ignores timetables for non-selected sections",
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);
    final scheduler = _FakeReminderScheduler();
    final coordinator = ReminderSyncCoordinator(
      storage: storage,
      scheduler: scheduler,
    );

    await storage.writeSelectedSectionCode("BS-CS-2A");
    await storage.writeReminderPreferences(
      const ReminderPreferences(
        enabled: true,
        leadTime: ReminderLeadTime.tenMinutes,
      ),
    );

    await coordinator.syncForSectionTimetable(
      sectionCode: "BS-CS-4B",
      timetable: _sectionTimetable.copyWith(
        section: const SectionDetail(
          sectionCode: "BS-CS-4B",
          displayName: "BS-CS-4B",
          active: true,
          meetingCount: 1,
          timetableVersion: _version,
        ),
      ),
    );

    expect(scheduler.cancelAllCallCount, 0);
    expect(scheduler.replaceScheduleCallCount, 0);
  });
}

class _FakeReminderScheduler implements ReminderScheduler {
  int cancelAllCallCount = 0;
  int replaceScheduleCallCount = 0;
  List<ScheduledReminder> lastScheduledReminders = const [];

  @override
  Future<void> cancelAll() async {
    cancelAllCallCount += 1;
  }

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async {
    return ReminderPermissionStatus.granted;
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {
    replaceScheduleCallCount += 1;
    lastScheduledReminders = reminders;
  }

  @override
  Future<ReminderPermissionStatus> requestPermissions() async {
    return ReminderPermissionStatus.granted;
  }
}

const _version = TimetableVersion(
  versionId: "spring-2026",
  sourceFileName: "spring-2026.json",
  generatedDate: "2026-04-26",
  publishStatus: "published",
  sectionCount: 25,
  meetingCount: 162,
  warningCount: 1,
  createdAt: "2026-04-29T00:00:00Z",
  publishedAt: "2026-04-29T00:05:00Z",
);

const _sectionTimetable = SectionTimetable(
  section: SectionDetail(
    sectionCode: "BS-CS-2A",
    displayName: "BS-CS-2A",
    active: true,
    meetingCount: 1,
    timetableVersion: _version,
  ),
  timetableVersion: _version,
  meetings: [
    TimetableMeeting(
      courseName: "Compiler Construction",
      instructor: "Dr. Khan",
      room: "Lab 2",
      day: "Monday",
      dayKey: DayKey.monday,
      startTime: "08:30",
      endTime: "09:50",
      meetingType: "lecture",
      online: false,
      sourcePage: 2,
      confidenceClass: "high",
      warnings: [],
    ),
  ],
);
