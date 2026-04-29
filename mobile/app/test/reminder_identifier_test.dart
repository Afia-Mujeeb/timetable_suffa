import "package:flutter_test/flutter_test.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_identifier.dart";

void main() {
  test("keeps the same reminder id when room and instructor metadata change",
      () {
    const baseMeeting = TimetableMeeting(
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
    );
    const movedMetadataMeeting = TimetableMeeting(
      courseName: "Compiler Construction",
      instructor: "Dr. Sana",
      room: "Lab 4",
      day: "Monday",
      dayKey: DayKey.monday,
      startTime: "08:30",
      endTime: "09:50",
      meetingType: "lecture",
      online: true,
      sourcePage: 7,
      confidenceClass: "high",
      warnings: [],
    );

    expect(
      buildReminderNotificationId(
        sectionCode: "BS-CS-2A",
        meeting: baseMeeting,
      ),
      buildReminderNotificationId(
        sectionCode: "BS-CS-2A",
        meeting: movedMetadataMeeting,
      ),
    );
  });

  test("changes the reminder id when the meeting time changes", () {
    const firstMeeting = TimetableMeeting(
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
    );
    const movedMeeting = TimetableMeeting(
      courseName: "Compiler Construction",
      instructor: "Dr. Khan",
      room: "Lab 2",
      day: "Monday",
      dayKey: DayKey.monday,
      startTime: "10:00",
      endTime: "11:20",
      meetingType: "lecture",
      online: false,
      sourcePage: 2,
      confidenceClass: "high",
      warnings: [],
    );

    expect(
      buildReminderNotificationId(
        sectionCode: "BS-CS-2A",
        meeting: firstMeeting,
      ),
      isNot(
        buildReminderNotificationId(
          sectionCode: "BS-CS-2A",
          meeting: movedMeeting,
        ),
      ),
    );
  });
}
