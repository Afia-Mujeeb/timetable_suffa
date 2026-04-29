import "package:flutter_test/flutter_test.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/features/home/home_schedule_summary.dart";

void main() {
  test("returns today's meetings in chronological order", () {
    final summary = buildHomeScheduleSummary(
      timetable: _timetable([
        _meeting(
          courseName: "Operating Systems",
          dayKey: DayKey.monday,
          startTime: "13:00",
          endTime: "14:20",
        ),
        _meeting(
          courseName: "Compiler Construction",
          dayKey: DayKey.monday,
          startTime: "08:30",
          endTime: "09:50",
        ),
      ]),
      now: DateTime(2026, 4, 27, 7, 45),
    );

    expect(summary.dayKey, DayKey.monday);
    expect(summary.hasClassesToday, isTrue);
    expect(
      summary.todayMeetings.map((item) => item.meeting.courseName),
      ["Compiler Construction", "Operating Systems"],
    );
    expect(summary.currentMeeting, isNull);
    expect(summary.nextMeeting?.meeting.courseName, "Compiler Construction");
    expect(summary.nextMeeting?.startsAt, DateTime(2026, 4, 27, 8, 30));
  });

  test("resolves the current class within its active time range", () {
    final summary = buildHomeScheduleSummary(
      timetable: _timetable([
        _meeting(
          courseName: "Database Systems",
          dayKey: DayKey.tuesday,
          startTime: "10:00",
          endTime: "11:20",
        ),
        _meeting(
          courseName: "Software Engineering",
          dayKey: DayKey.tuesday,
          startTime: "12:00",
          endTime: "13:20",
        ),
      ]),
      now: DateTime(2026, 4, 28, 10, 35),
    );

    expect(summary.currentMeeting?.meeting.courseName, "Database Systems");
    expect(summary.currentMeeting?.startsAt, DateTime(2026, 4, 28, 10, 0));
    expect(summary.currentMeeting?.endsAt, DateTime(2026, 4, 28, 11, 20));
    expect(summary.nextMeeting?.meeting.courseName, "Software Engineering");
    expect(summary.nextMeeting?.startsAt, DateTime(2026, 4, 28, 12, 0));
  });

  test("resolves the next recurring class on a no-class day", () {
    final summary = buildHomeScheduleSummary(
      timetable: _timetable([
        _meeting(
          courseName: "Physics",
          dayKey: DayKey.monday,
          startTime: "08:30",
          endTime: "09:50",
        ),
        _meeting(
          courseName: "Mobile Application Development",
          dayKey: DayKey.friday,
          startTime: "14:00",
          endTime: "15:20",
        ),
      ]),
      now: DateTime(2026, 4, 29, 9, 0),
    );

    expect(summary.dayKey, DayKey.wednesday);
    expect(summary.todayMeetings, isEmpty);
    expect(summary.isNoClassDay, isTrue);
    expect(summary.currentMeeting, isNull);
    expect(
      summary.nextMeeting?.meeting.courseName,
      "Mobile Application Development",
    );
    expect(summary.nextMeeting?.startsAt, DateTime(2026, 5, 1, 14, 0));
  });

  test("wraps next class lookup into the next academic week", () {
    final summary = buildHomeScheduleSummary(
      timetable: _timetable([
        _meeting(
          courseName: "Linear Algebra",
          dayKey: DayKey.monday,
          startTime: "08:30",
          endTime: "09:50",
        ),
      ]),
      now: DateTime(2026, 5, 2, 16, 0),
    );

    expect(summary.dayKey, DayKey.saturday);
    expect(summary.nextMeeting?.meeting.courseName, "Linear Algebra");
    expect(summary.nextMeeting?.startsAt, DateTime(2026, 5, 4, 8, 30));
  });
}

SectionTimetable _timetable(List<TimetableMeeting> meetings) {
  return SectionTimetable(
    section: const SectionDetail(
      sectionCode: "BS-CS-2A",
      displayName: "BS-CS-2A",
      active: true,
      meetingCount: 0,
      timetableVersion: _version,
    ),
    timetableVersion: _version,
    meetings: meetings,
  );
}

TimetableMeeting _meeting({
  required String courseName,
  required DayKey dayKey,
  required String startTime,
  required String endTime,
}) {
  return TimetableMeeting(
    courseName: courseName,
    instructor: "Faculty",
    room: "Room 101",
    day: dayKey.label,
    dayKey: dayKey,
    startTime: startTime,
    endTime: endTime,
    meetingType: "lecture",
    online: false,
    sourcePage: 1,
    confidenceClass: "high",
    warnings: const [],
  );
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
