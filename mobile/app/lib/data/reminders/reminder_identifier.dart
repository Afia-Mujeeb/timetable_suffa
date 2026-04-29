import "package:timetable_app/data/models/timetable_models.dart";

int buildReminderNotificationId({
  required String sectionCode,
  required TimetableMeeting meeting,
}) {
  final seed = [
    sectionCode.trim().toUpperCase(),
    meeting.courseName.trim().toLowerCase(),
    meeting.dayKey.name,
    meeting.startTime,
    meeting.endTime,
  ].join("|");

  var hash = 0x811C9DC5;
  for (final codeUnit in seed.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }

  return hash == 0 ? 1 : hash;
}
