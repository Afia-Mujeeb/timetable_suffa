import "dart:convert";

import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_identifier.dart";
import "package:timetable_app/features/schedule/schedule_occurrences.dart";

class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.sectionCode,
    required this.meeting,
    required this.leadTime,
    required this.scheduledAt,
  });

  final int id;
  final String sectionCode;
  final TimetableMeeting meeting;
  final ReminderLeadTime leadTime;
  final DateTime scheduledAt;

  String get title => "${meeting.courseName} starts in ${leadTime.minutes} min";

  String get body {
    final location = meeting.online
        ? "Online"
        : (meeting.room?.isNotEmpty ?? false)
            ? meeting.room!
            : "Room TBD";

    return "$sectionCode - ${meeting.day} ${meeting.startTime} - $location";
  }

  String get payload {
    return jsonEncode({
      "sectionCode": sectionCode,
      "courseName": meeting.courseName,
      "dayKey": meeting.dayKey.name,
      "startTime": meeting.startTime,
      "endTime": meeting.endTime,
    });
  }
}

List<ScheduledReminder> buildScheduledReminders({
  required SectionTimetable timetable,
  required ReminderPreferences preferences,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final reminders = timetable.meetings
      .map(
        (meeting) => _buildScheduledReminder(
          timetable: timetable,
          meeting: meeting,
          preferences: preferences,
          now: reference,
        ),
      )
      .whereType<ScheduledReminder>()
      .toList(growable: false);

  final sortedReminders = reminders.toList()
    ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));

  return sortedReminders;
}

ScheduledReminder? _buildScheduledReminder({
  required SectionTimetable timetable,
  required TimetableMeeting meeting,
  required ReminderPreferences preferences,
  required DateTime now,
}) {
  final scheduledAt = nextReminderTime(
    meeting: meeting,
    now: now,
    leadTime: Duration(minutes: preferences.leadTimeMinutes),
  );
  if (scheduledAt == null) {
    return null;
  }

  return ScheduledReminder(
    id: buildReminderNotificationId(
      sectionCode: timetable.section.sectionCode,
      meeting: meeting,
    ),
    sectionCode: timetable.section.sectionCode,
    meeting: meeting,
    leadTime: preferences.leadTime,
    scheduledAt: scheduledAt,
  );
}
