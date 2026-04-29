import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/features/schedule/schedule_occurrences.dart";

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
  final dayKey = dayKeyFromWeekday(now.weekday);
  final todayMeetings = occurrencesForDay(
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

  return HomeScheduleSummary(
    dayKey: dayKey,
    todayMeetings: todayMeetings,
    currentMeeting: currentMeeting,
    nextMeeting: nextMeetingOccurrence(
      meetings: timetable.meetings,
      now: now,
    ),
  );
}
