import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:timetable_app/data/api/timetable_api_client.dart";
import "package:timetable_app/data/models/timetable_models.dart";

void main() {
  test("decodes the section list response shape", () async {
    final client = TimetableApiClient(
      baseUrl: "http://localhost:8787",
      httpClient: MockClient((request) async {
        expect(request.url.path, "/v1/sections");
        return http.Response(
          """
          {
            "timetableVersion": {
              "versionId": "spring-2026",
              "sourceFileName": "spring-2026.json",
              "generatedDate": "2026-04-26",
              "publishStatus": "published",
              "sectionCount": 25,
              "meetingCount": 162,
              "warningCount": 1,
              "createdAt": "2026-04-29T00:00:00Z",
              "publishedAt": "2026-04-29T00:05:00Z"
            },
            "sections": [
              {
                "sectionCode": "BS-CS-2A",
                "displayName": "BS-CS-2A",
                "active": true,
                "meetingCount": 6
              }
            ]
          }
          """,
          200,
          headers: const {"content-type": "application/json"},
        );
      }),
    );

    final response = await client.fetchSections();

    expect(response.timetableVersion.versionId, "spring-2026");
    expect(response.sections.single.sectionCode, "BS-CS-2A");
  });

  test("decodes the section timetable response shape", () async {
    final client = TimetableApiClient(
      baseUrl: "http://localhost:8787",
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          "/v1/sections/BS-CS-2A/timetable",
        );
        return http.Response(
          """
          {
            "section": {
              "sectionCode": "BS-CS-2A",
              "displayName": "BS-CS-2A",
              "active": true,
              "meetingCount": 2,
              "timetableVersion": {
                "versionId": "spring-2026",
                "sourceFileName": "spring-2026.json",
                "generatedDate": "2026-04-26",
                "publishStatus": "published",
                "sectionCount": 25,
                "meetingCount": 162,
                "warningCount": 1,
                "createdAt": "2026-04-29T00:00:00Z",
                "publishedAt": "2026-04-29T00:05:00Z"
              }
            },
            "timetableVersion": {
              "versionId": "spring-2026",
              "sourceFileName": "spring-2026.json",
              "generatedDate": "2026-04-26",
              "publishStatus": "published",
              "sectionCount": 25,
              "meetingCount": 162,
              "warningCount": 1,
              "createdAt": "2026-04-29T00:00:00Z",
              "publishedAt": "2026-04-29T00:05:00Z"
            },
            "meetings": [
              {
                "courseName": "Compiler Construction",
                "instructor": "Dr. Khan",
                "room": "Lab 2",
                "day": "Monday",
                "dayKey": "monday",
                "startTime": "08:30",
                "endTime": "09:50",
                "meetingType": "lecture",
                "online": false,
                "sourcePage": 2,
                "confidenceClass": "high",
                "warnings": []
              }
            ]
          }
          """,
          200,
          headers: const {"content-type": "application/json"},
        );
      }),
    );

    final response = await client.fetchSectionTimetable("BS-CS-2A");

    expect(response.section.sectionCode, "BS-CS-2A");
    expect(response.meetings.single.courseName, "Compiler Construction");
    expect(response.meetings.single.dayKey, DayKey.monday);
  });
}
