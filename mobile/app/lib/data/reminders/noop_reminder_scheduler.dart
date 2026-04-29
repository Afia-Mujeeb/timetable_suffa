import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> cancelAll() async {}

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async {
    return ReminderPermissionStatus.unsupported;
  }

  @override
  Future<ReminderPermissionStatus> requestPermissions() async {
    return ReminderPermissionStatus.unsupported;
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {}
}
