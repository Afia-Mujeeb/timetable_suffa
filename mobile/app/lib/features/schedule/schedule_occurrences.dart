import "package:timetable_app/data/models/timetable_models.dart";

class ScheduleMeetingOccurrence {
  const ScheduleMeetingOccurrence({
    required this.meeting,
    required this.startsAt,
    required this.endsAt,
  });

  final TimetableMeeting meeting;
  final DateTime startsAt;
  final DateTime endsAt;

  Duration get duration => endsAt.difference(startsAt);
}

List<ScheduleMeetingOccurrence> occurrencesForDay({
  required List<TimetableMeeting> meetings,
  required DayKey dayKey,
  required DateTime anchor,
}) {
  final dayStart = startOfDay(anchor);
  final occurrences = meetings
      .where((meeting) => meeting.dayKey == dayKey)
      .map(
        (meeting) => buildOccurrenceForAnchor(
          meeting: meeting,
          anchor: dayStart,
        ),
      )
      .whereType<ScheduleMeetingOccurrence>()
      .toList(growable: false);

  final sortedOccurrences = occurrences.toList()
    ..sort((left, right) => left.startsAt.compareTo(right.startsAt));

  return sortedOccurrences;
}

ScheduleMeetingOccurrence? nextMeetingOccurrence({
  required List<TimetableMeeting> meetings,
  required DateTime now,
}) {
  final weekStart = startOfDay(now).subtract(Duration(days: now.weekday - 1));
  ScheduleMeetingOccurrence? bestCandidate;

  for (final meeting in meetings) {
    final candidate = nextOccurrenceForMeeting(
      meeting: meeting,
      now: now,
      weekStart: weekStart,
    );
    if (candidate == null) {
      continue;
    }

    if (bestCandidate == null ||
        candidate.startsAt.isBefore(bestCandidate.startsAt)) {
      bestCandidate = candidate;
    }
  }

  return bestCandidate;
}

ScheduleMeetingOccurrence? nextOccurrenceForMeeting({
  required TimetableMeeting meeting,
  required DateTime now,
  DateTime? weekStart,
}) {
  final initialWeekStart =
      weekStart ?? startOfDay(now).subtract(Duration(days: now.weekday - 1));
  final firstAnchor =
      initialWeekStart.add(Duration(days: meeting.dayKey.index));
  final firstOccurrence = buildOccurrenceForAnchor(
    meeting: meeting,
    anchor: firstAnchor,
  );
  if (firstOccurrence == null) {
    return null;
  }

  if (firstOccurrence.startsAt.isAfter(now)) {
    return firstOccurrence;
  }

  return ScheduleMeetingOccurrence(
    meeting: meeting,
    startsAt: firstOccurrence.startsAt.add(const Duration(days: 7)),
    endsAt: firstOccurrence.endsAt.add(const Duration(days: 7)),
  );
}

DateTime? nextReminderTime({
  required TimetableMeeting meeting,
  required DateTime now,
  required Duration leadTime,
}) {
  final nextOccurrence = nextOccurrenceForMeeting(
    meeting: meeting,
    now: now,
  );
  if (nextOccurrence == null) {
    return null;
  }

  final reminderTime = nextOccurrence.startsAt.subtract(leadTime);
  if (reminderTime.isAfter(now)) {
    return reminderTime;
  }

  return reminderTime.add(const Duration(days: 7));
}

ScheduleMeetingOccurrence? buildOccurrenceForAnchor({
  required TimetableMeeting meeting,
  required DateTime anchor,
}) {
  final start = parseScheduleTime(meeting.startTime);
  final end = parseScheduleTime(meeting.endTime);
  if (start == null || end == null) {
    return null;
  }

  final startsAt = DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    start.hour,
    start.minute,
  );
  var endsAt = DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    end.hour,
    end.minute,
  );
  if (!endsAt.isAfter(startsAt)) {
    endsAt = endsAt.add(const Duration(days: 1));
  }

  return ScheduleMeetingOccurrence(
    meeting: meeting,
    startsAt: startsAt,
    endsAt: endsAt,
  );
}

DateTime startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

({int hour, int minute})? parseScheduleTime(String value) {
  final parts = value.split(":");
  if (parts.length != 2) {
    return null;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }

  return (hour: hour, minute: minute);
}

DayKey dayKeyFromWeekday(int weekday) {
  return switch (weekday) {
    DateTime.monday => DayKey.monday,
    DateTime.tuesday => DayKey.tuesday,
    DateTime.wednesday => DayKey.wednesday,
    DateTime.thursday => DayKey.thursday,
    DateTime.friday => DayKey.friday,
    DateTime.saturday => DayKey.saturday,
    _ => DayKey.monday,
  };
}
