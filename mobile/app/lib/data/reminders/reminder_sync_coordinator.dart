import "package:timetable_app/core/monitoring/app_error_monitor.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";
import "package:timetable_app/data/storage/app_storage.dart";

class ReminderSyncCoordinator {
  ReminderSyncCoordinator({
    required this.storage,
    required this.scheduler,
    this.errorMonitor,
  });

  final AppStorage storage;
  final ReminderScheduler scheduler;
  final AppErrorMonitor? errorMonitor;

  Future<void> clearScheduledReminders() async {
    await _guardSchedulerCall(
      () => scheduler.cancelAll(),
      source: "reminders.clear_all",
    );
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
      await _guardSchedulerCall(
        () => scheduler.cancelAll(),
        source: "reminders.cancel_without_selection",
      );
      return;
    }

    final timetable = await storage.readSectionTimetable(selectedSectionCode);
    if (timetable == null) {
      await _guardSchedulerCall(
        () => scheduler.cancelAll(),
        source: "reminders.cancel_without_cached_timetable",
      );
      return;
    }

    await _syncWithTimetable(timetable);
  }

  Future<void> _syncWithTimetable(SectionTimetable timetable) async {
    final preferences = await storage.readReminderPreferences();
    if (!preferences.enabled) {
      await _guardSchedulerCall(
        () => scheduler.cancelAll(),
        source: "reminders.cancel_disabled_preferences",
      );
      return;
    }

    final reminders = buildScheduledReminders(
      timetable: timetable,
      preferences: preferences,
    );

    await _guardSchedulerCall(
      () => scheduler.replaceSchedule(reminders),
      source: "reminders.replace_schedule",
    );
  }

  Future<void> _guardSchedulerCall(
    Future<void> Function() run, {
    required String source,
  }) async {
    try {
      await run();
    } catch (error, stackTrace) {
      await errorMonitor?.recordError(
        error,
        stackTrace,
        source: source,
        fatal: false,
      );
    }
  }
}
