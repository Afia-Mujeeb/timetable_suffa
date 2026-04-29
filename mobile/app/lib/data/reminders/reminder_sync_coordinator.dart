import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";
import "package:timetable_app/data/storage/app_storage.dart";

class ReminderSyncCoordinator {
  ReminderSyncCoordinator({
    required this.storage,
    required this.scheduler,
  });

  final AppStorage storage;
  final ReminderScheduler scheduler;

  Future<void> clearScheduledReminders() {
    return scheduler.cancelAll();
  }

  Future<void> syncForSectionTimetable({
    required String sectionCode,
    required SectionTimetable timetable,
  }) async {
    final selectedSectionCode = await storage.readSelectedSectionCode();
    if (selectedSectionCode != sectionCode) {
      return;
    }

    await _syncWithTimetable(timetable);
  }

  Future<void> syncSelectedSection() async {
    final selectedSectionCode = await storage.readSelectedSectionCode();
    if (selectedSectionCode == null || selectedSectionCode.isEmpty) {
      await scheduler.cancelAll();
      return;
    }

    final timetable = await storage.readSectionTimetable(selectedSectionCode);
    if (timetable == null) {
      await scheduler.cancelAll();
      return;
    }

    await _syncWithTimetable(timetable);
  }

  Future<void> _syncWithTimetable(SectionTimetable timetable) async {
    final preferences = await storage.readReminderPreferences();
    if (!preferences.enabled) {
      await scheduler.cancelAll();
      return;
    }

    final reminders = buildScheduledReminders(
      timetable: timetable,
      preferences: preferences,
    );

    await scheduler.replaceSchedule(reminders);
  }
}
