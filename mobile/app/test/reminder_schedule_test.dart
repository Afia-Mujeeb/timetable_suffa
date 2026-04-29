import "package:flutter_test/flutter_test.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";

void main() {
  test(
    "buildScheduledReminders keeps identifiers stable and rolls past-due reminders to next week",
    () {
      const preferences = ReminderPreferences(
        enabled: true,
        leadTime: ReminderLeadTime.fifteenMinutes,
      );

      final now = DateTime(2026, 4, 27, 8, 20);
      final reminders = buildScheduledReminders(
        timetable: _sectionTimetable,
        preferences: preferences,
        now: now,
      );

      final repeatedBuild = buildScheduledReminders(
        timetable: _sectionTimetable,
        preferences: preferences,
        now: now,
      );

      expect(reminders, hasLength(2));
      expect(reminders.map((reminder) => reminder.id).toSet(), hasLength(2));
      expect(
        reminders.map((reminder) => reminder.id).toList(growable: false),
        repeatedBuild.map((reminder) => reminder.id).toList(growable: false),
      );
      expect(reminders.first.meeting.courseName, "Operating Systems");
      expect(reminders.first.scheduledAt, DateTime(2026, 4, 29, 9, 45));
      expect(reminders.last.scheduledAt, DateTime(2026, 5, 4, 8, 15));
    },
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

const _sectionTimetable = SectionTimetable(
  section: SectionDetail(
    sectionCode: "BS-CS-2A",
    displayName: "BS-CS-2A",
    active: true,
    meetingCount: 2,
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
    TimetableMeeting(
      courseName: "Operating Systems",
      instructor: "Prof. Ali",
      room: "Room 12",
      day: "Wednesday",
      dayKey: DayKey.wednesday,
      startTime: "10:00",
      endTime: "11:20",
      meetingType: "lecture",
      online: false,
      sourcePage: 3,
      confidenceClass: "high",
      warnings: [],
    ),
  ],
);
