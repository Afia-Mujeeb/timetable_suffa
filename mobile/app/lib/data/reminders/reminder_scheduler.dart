import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";

abstract interface class ReminderScheduler {
  Future<ReminderPermissionStatus> getPermissionStatus();

  Future<ReminderPermissionStatus> requestPermissions();

  Future<void> replaceSchedule(List<ScheduledReminder> reminders);

  Future<void> cancelAll();
}
