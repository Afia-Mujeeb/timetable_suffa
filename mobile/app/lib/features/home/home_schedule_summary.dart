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

class HomeScheduleSummary {
  const HomeScheduleSummary({
    required this.dayKey,
    required this.todayMeetings,
    required this.currentMeeting,
    required this.nextMeeting,
  });

  final DayKey dayKey;
  final List<ScheduleMeetingOccurrence> todayMeetings;
  final ScheduleMeetingOccurrence? currentMeeting;
  final ScheduleMeetingOccurrence? nextMeeting;

  bool get hasClassesToday => todayMeetings.isNotEmpty;

  bool get isNoClassDay => !hasClassesToday;
}

HomeScheduleSummary buildHomeScheduleSummary({
  required SectionTimetable timetable,
  required DateTime now,
}) {
  final dayKey = _dayKeyFromWeekday(now.weekday);
  final todayMeetings = _occurrencesForDay(
    meetings: timetable.meetings,
    dayKey: dayKey,
    anchor: now,
  );

  ScheduleMeetingOccurrence? currentMeeting;
  for (final occurrence in todayMeetings) {
    if (!now.isBefore(occurrence.startsAt) && now.isBefore(occurrence.endsAt)) {
      currentMeeting = occurrence;
      break;
    }
  }

  final nextMeeting = _nextMeetingOccurrence(
    meetings: timetable.meetings,
    now: now,
  );

  return HomeScheduleSummary(
    dayKey: dayKey,
    todayMeetings: todayMeetings,
    currentMeeting: currentMeeting,
    nextMeeting: nextMeeting,
  );
}

List<ScheduleMeetingOccurrence> _occurrencesForDay({
  required List<TimetableMeeting> meetings,
  required DayKey dayKey,
  required DateTime anchor,
}) {
  final dayStart = _startOfDay(anchor);
  final occurrences = meetings
      .where((meeting) => meeting.dayKey == dayKey)
      .map(
        (meeting) => _buildOccurrence(
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

ScheduleMeetingOccurrence? _nextMeetingOccurrence({
  required List<TimetableMeeting> meetings,
  required DateTime now,
}) {
  final weekStart = _startOfDay(now).subtract(Duration(days: now.weekday - 1));
  ScheduleMeetingOccurrence? bestCandidate;

  for (final meeting in meetings) {
    final baseDayOffset = meeting.dayKey.index;
    final firstAnchor = weekStart.add(Duration(days: baseDayOffset));

    final firstOccurrence = _buildOccurrence(
      meeting: meeting,
      anchor: firstAnchor,
    );
    if (firstOccurrence == null) {
      continue;
    }

    final candidate = firstOccurrence.startsAt.isAfter(now)
        ? firstOccurrence
        : ScheduleMeetingOccurrence(
            meeting: meeting,
            startsAt: firstOccurrence.startsAt.add(const Duration(days: 7)),
            endsAt: firstOccurrence.endsAt.add(const Duration(days: 7)),
          );

    if (bestCandidate == null ||
        candidate.startsAt.isBefore(bestCandidate.startsAt)) {
      bestCandidate = candidate;
    }
  }

  return bestCandidate;
}

ScheduleMeetingOccurrence? _buildOccurrence({
  required TimetableMeeting meeting,
  required DateTime anchor,
}) {
  final start = _parseTimeOfDay(meeting.startTime);
  final end = _parseTimeOfDay(meeting.endTime);
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

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

({int hour, int minute})? _parseTimeOfDay(String value) {
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

DayKey _dayKeyFromWeekday(int weekday) {
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
