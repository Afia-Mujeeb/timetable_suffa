import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/core/monitoring/app_error_monitor.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

void main() {
  test("persists the selected section code", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);
    final scheduler = _FakeReminderScheduler();

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: "http://localhost:8787",
            appFlavor: "test",
          ),
        ),
        appStorageProvider.overrideWithValue(storage),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedSectionCodeControllerProvider.future);
    await container
        .read(selectedSectionCodeControllerProvider.notifier)
        .selectSection("BS-CS-2A");

    expect(
      await storage.readSelectedSectionCode(),
      "BS-CS-2A",
    );
    expect(
      container.read(selectedSectionCodeControllerProvider).valueOrNull,
      "BS-CS-2A",
    );
  });

  test(
    "reschedules reminders from cached timetable when the selected section changes",
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = SharedPreferencesAppStorage(preferences);
      final scheduler = _FakeReminderScheduler();

      await storage.writeReminderPreferences(
        const ReminderPreferences(
          enabled: true,
          leadTime: ReminderLeadTime.tenMinutes,
        ),
      );
      await storage.writeSectionTimetable(_sectionTimetable);

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: "http://localhost:8787",
              appFlavor: "test",
            ),
          ),
          appStorageProvider.overrideWithValue(storage),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);

      await container.read(selectedSectionCodeControllerProvider.future);
      await container
          .read(selectedSectionCodeControllerProvider.notifier)
          .selectSection("BS-CS-2A");

      expect(scheduler.replaceScheduleCallCount, 1);
      expect(scheduler.lastScheduledReminders.single.sectionCode, "BS-CS-2A");
    },
  );

  test("keeps the section change when reminder rescheduling fails", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);
    final scheduler = _ThrowingReminderScheduler();
    final monitor = MemoryAppErrorMonitor();

    await storage.writeReminderPreferences(
      const ReminderPreferences(
        enabled: true,
        leadTime: ReminderLeadTime.tenMinutes,
      ),
    );
    await storage.writeSectionTimetable(_sectionTimetable);

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: "http://localhost:8787",
            appFlavor: "test",
          ),
        ),
        appStorageProvider.overrideWithValue(storage),
        appErrorMonitorProvider.overrideWithValue(monitor),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedSectionCodeControllerProvider.future);
    await container
        .read(selectedSectionCodeControllerProvider.notifier)
        .selectSection("BS-CS-2A");

    expect(await storage.readSelectedSectionCode(), "BS-CS-2A");
    final events = await monitor.readRecentEvents();
    expect(events, hasLength(1));
    expect(events.single.source, "reminders.replace_schedule");
  });
}

class _FakeReminderScheduler implements ReminderScheduler {
  int replaceScheduleCallCount = 0;
  List<ScheduledReminder> lastScheduledReminders = const [];

  @override
  Future<void> cancelAll() async {}

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

class _ThrowingReminderScheduler implements ReminderScheduler {
  @override
  Future<void> cancelAll() async {}

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async {
    return ReminderPermissionStatus.granted;
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {
    throw StateError("scheduler failed");
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
