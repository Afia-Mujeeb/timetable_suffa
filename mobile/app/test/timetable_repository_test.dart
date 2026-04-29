import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/data/api/timetable_api_client.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/repositories/timetable_repository.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

void main() {
  test("falls back to cached sections when the network is offline", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);
    await storage.writeSectionsSnapshot(_sectionsSnapshot);

    final repository = LiveTimetableRepository(
      apiClient: TimetableApiClient(
        baseUrl: "http://localhost:8787",
        httpClient: MockClient((request) async {
          throw const SocketException("offline");
        }),
      ),
      storage: storage,
    );

    final snapshot = await repository.fetchSections();

    expect(snapshot.isStale, isTrue);
    expect(snapshot.sections.single.sectionCode, "BS-CS-2A");
    expect(snapshot.cachedAt, isNotNull);
  });

  test("falls back to cached timetable when the HTTP client cannot connect", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);
    await storage.writeSectionTimetable(_sectionTimetable);

    final repository = LiveTimetableRepository(
      apiClient: TimetableApiClient(
        baseUrl: "http://localhost:8787",
        httpClient: MockClient((request) async {
          throw http.ClientException("connection failed");
        }),
      ),
      storage: storage,
    );

    final timetable = await repository.fetchSectionTimetable("BS-CS-2A");

    expect(timetable.isStale, isTrue);
    expect(timetable.section.sectionCode, "BS-CS-2A");
    expect(timetable.meetings.single.courseName, "Compiler Construction");
    expect(timetable.cachedAt, isNotNull);
  });
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

const _sectionsSnapshot = SectionsSnapshot(
  timetableVersion: _version,
  sections: [
    SectionSummary(
      sectionCode: "BS-CS-2A",
      displayName: "BS-CS-2A",
      active: true,
      meetingCount: 2,
    ),
  ],
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
  ],
);
