import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:timetable_app/data/api/timetable_api_client.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";
import "package:timetable_app/data/reminders/reminder_sync_coordinator.dart";
import "package:timetable_app/data/repositories/timetable_repository.dart";
import "package:timetable_app/data/storage/in_memory_app_storage.dart";

void main() {
  test("returns fresh cached sections without calling the API", () async {
    final storage = InMemoryAppStorage();
    await storage.writeSectionsSnapshot(_sectionsSnapshot);

    final repository = LiveTimetableRepository(
      apiClient: TimetableApiClient(
        baseUrl: "http://localhost:8787",
        httpClient: MockClient((request) async {
          throw StateError("unexpected sections request");
        }),
      ),
      storage: storage,
    );

    final snapshot = await repository.fetchSections();

    expect(snapshot.isStale, isFalse);
    expect(snapshot.sections.single.sectionCode, "BS-CS-2A");
    expect(snapshot.cachedAt, isNotNull);
  });

  test("force refresh bypasses a fresh cached section snapshot", () async {
    final storage = InMemoryAppStorage();
    await storage.writeSectionsSnapshot(_sectionsSnapshot);
    var requestCount = 0;

    final repository = LiveTimetableRepository(
      apiClient: TimetableApiClient(
        baseUrl: "http://localhost:8787",
        httpClient: MockClient((request) async {
          requestCount += 1;
          return http.Response(
            jsonEncode({
              "timetableVersion": _version.toJson(),
              "sections": _sectionsSnapshot.sections
                  .map((section) => section.toJson())
                  .toList(growable: false),
            }),
            200,
            headers: {"content-type": "application/json"},
          );
        }),
      ),
      storage: storage,
    );

    await repository.fetchSections(forceRefresh: true);

    expect(requestCount, 1);
  });

  test("falls back to cached sections when the network is offline", () async {
    final storage = InMemoryAppStorage();
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

    final snapshot = await repository.fetchSections(forceRefresh: true);

    expect(snapshot.isStale, isTrue);
    expect(snapshot.sections.single.sectionCode, "BS-CS-2A");
    expect(snapshot.cachedAt, isNotNull);
  });

  test("returns fresh cached timetable without calling the API", () async {
    final storage = InMemoryAppStorage();
    await storage.writeSectionTimetable(_sectionTimetable);

    final repository = LiveTimetableRepository(
      apiClient: TimetableApiClient(
        baseUrl: "http://localhost:8787",
        httpClient: MockClient((request) async {
          throw StateError("unexpected timetable request");
        }),
      ),
      storage: storage,
    );

    final timetable = await repository.fetchSectionTimetable(
      "BS-CS-2A",
    );

    expect(timetable.isStale, isFalse);
    expect(timetable.section.sectionCode, "BS-CS-2A");
    expect(timetable.cachedAt, isNotNull);
  });

  test("falls back to cached timetable when the HTTP client cannot connect",
      () async {
    final storage = InMemoryAppStorage();
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

    final timetable = await repository.fetchSectionTimetable(
      "BS-CS-2A",
      forceRefresh: true,
    );

    expect(timetable.isStale, isTrue);
    expect(timetable.section.sectionCode, "BS-CS-2A");
    expect(timetable.meetings.single.courseName, "Compiler Construction");
    expect(timetable.cachedAt, isNotNull);
  });

  test(
    "reuses the cached timetable when section metadata shows the version is unchanged",
    () async {
      final storage = InMemoryAppStorage();
      await storage.writeSectionTimetable(_sectionTimetable);

      final repository = LiveTimetableRepository(
        apiClient: TimetableApiClient(
          baseUrl: "http://localhost:8787",
          httpClient: MockClient((request) async {
            throw StateError("unexpected timetable request");
          }),
        ),
        storage: storage,
      );

      final timetable = await repository.fetchSectionTimetable(
        "BS-CS-2A",
        latestVersionId: _version.versionId,
      );

      expect(timetable.isStale, isFalse);
      expect(timetable.timetableVersion.versionId, _version.versionId);
      expect(timetable.cachedAt, isNotNull);
    },
  );

  test("reuses cached sections on a 304 validator response", () async {
    final storage = InMemoryAppStorage();
    await storage.writeSectionsSnapshot(
      _sectionsSnapshot.copyWith(
        etag: 'W/"sections:spring-2026"',
      ),
    );

    final repository = LiveTimetableRepository(
      apiClient: TimetableApiClient(
        baseUrl: "http://localhost:8787",
        httpClient: MockClient((request) async {
          expect(request.headers["if-none-match"], 'W/"sections:spring-2026"');
          return http.Response(
            "",
            304,
            headers: const {
              "etag": 'W/"sections:spring-2026"',
            },
          );
        }),
      ),
      storage: storage,
    );

    final snapshot = await repository.fetchSections(forceRefresh: true);

    expect(snapshot.isStale, isFalse);
    expect(snapshot.etag, 'W/"sections:spring-2026"');
    expect(snapshot.sections.single.sectionCode, "BS-CS-2A");
    expect(snapshot.cachedAt, isNotNull);
  });

  test("reuses cached timetable on a 304 validator response", () async {
    final storage = InMemoryAppStorage();
    await storage.writeSectionTimetable(
      _sectionTimetable.copyWith(
        etag: 'W/"section-timetable:spring-2026:BS-CS-2A"',
      ),
    );

    final repository = LiveTimetableRepository(
      apiClient: TimetableApiClient(
        baseUrl: "http://localhost:8787",
        httpClient: MockClient((request) async {
          expect(
            request.headers["if-none-match"],
            'W/"section-timetable:spring-2026:BS-CS-2A"',
          );
          return http.Response(
            "",
            304,
            headers: const {
              "etag": 'W/"section-timetable:spring-2026:BS-CS-2A"',
            },
          );
        }),
      ),
      storage: storage,
    );

    final timetable = await repository.fetchSectionTimetable(
      "BS-CS-2A",
      forceRefresh: true,
    );

    expect(timetable.isStale, isFalse);
    expect(timetable.etag, 'W/"section-timetable:spring-2026:BS-CS-2A"');
    expect(timetable.section.sectionCode, "BS-CS-2A");
    expect(timetable.cachedAt, isNotNull);
  });

  test(
    "fetches the timetable again when section metadata reports a newer version",
    () async {
      final storage = InMemoryAppStorage();
      await storage.writeSectionTimetable(_sectionTimetable);
      var requestCount = 0;
      const nextVersion = TimetableVersion(
        versionId: "spring-2026-rev-2",
        sourceFileName: "spring-2026-rev-2.json",
        generatedDate: "2026-04-27",
        publishStatus: "published",
        sectionCount: 25,
        meetingCount: 163,
        warningCount: 1,
        createdAt: "2026-04-29T01:00:00Z",
        publishedAt: "2026-04-29T01:05:00Z",
      );
      const refreshedTimetable = SectionTimetable(
        section: SectionDetail(
          sectionCode: "BS-CS-2A",
          displayName: "BS-CS-2A",
          active: true,
          meetingCount: 2,
          timetableVersion: nextVersion,
        ),
        timetableVersion: nextVersion,
        meetings: [
          TimetableMeeting(
            courseName: "Advanced Algorithms",
            instructor: "Dr. Khan",
            room: "Lab 4",
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

      final repository = LiveTimetableRepository(
        apiClient: TimetableApiClient(
          baseUrl: "http://localhost:8787",
          httpClient: MockClient((request) async {
            requestCount += 1;
            return http.Response(
              jsonEncode({
                "section": refreshedTimetable.section.toJson(),
                "timetableVersion": nextVersion.toJson(),
                "meetings": refreshedTimetable.meetings
                    .map((meeting) => meeting.toJson())
                    .toList(growable: false),
              }),
              200,
              headers: {"content-type": "application/json"},
            );
          }),
        ),
        storage: storage,
      );

      final timetable = await repository.fetchSectionTimetable(
        "BS-CS-2A",
        latestVersionId: nextVersion.versionId,
      );

      expect(requestCount, 1);
      expect(timetable.timetableVersion.versionId, nextVersion.versionId);
      expect(timetable.meetings.single.courseName, "Advanced Algorithms");
    },
  );

  test(
    "reschedules reminders with stable ids when the timetable is explicitly refreshed",
    () async {
      final storage = InMemoryAppStorage();
      final scheduler = _FakeReminderScheduler();

      await storage.writeSelectedSectionCode("BS-CS-2A");
      await storage.writeReminderPreferences(
        const ReminderPreferences(
          enabled: true,
          leadTime: ReminderLeadTime.tenMinutes,
        ),
      );

      final repository = LiveTimetableRepository(
        apiClient: TimetableApiClient(
          baseUrl: "http://localhost:8787",
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                "section": _sectionTimetable.section.toJson(),
                "timetableVersion": _sectionTimetable.timetableVersion.toJson(),
                "meetings": _sectionTimetable.meetings
                    .map((meeting) => meeting.toJson())
                    .toList(growable: false),
              }),
              200,
              headers: {"content-type": "application/json"},
            );
          }),
        ),
        storage: storage,
        reminderSyncCoordinator: ReminderSyncCoordinator(
          storage: storage,
          scheduler: scheduler,
        ),
      );

      await repository.fetchSectionTimetable(
        "BS-CS-2A",
        forceRefresh: true,
      );
      final firstReminderIds = scheduler.lastScheduledReminders
          .map((reminder) => reminder.id)
          .toList(growable: false);

      await repository.fetchSectionTimetable(
        "BS-CS-2A",
        forceRefresh: true,
      );

      expect(scheduler.replaceScheduleCallCount, 2);
      expect(scheduler.lastScheduledReminders, hasLength(1));
      expect(
        scheduler.lastScheduledReminders
            .map((reminder) => reminder.id)
            .toList(growable: false),
        firstReminderIds,
      );
    },
  );
}

class _FakeReminderScheduler implements ReminderScheduler {
  int replaceScheduleCallCount = 0;
  List<ScheduledReminder> lastScheduledReminders = const [];

  @override
  Future<void> cancelAll() async {}

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async {
    return ReminderPermissionStatus.granted;
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {
    replaceScheduleCallCount += 1;
    lastScheduledReminders = reminders;
  }

  @override
  Future<ReminderPermissionStatus> requestPermissions() async {
    return ReminderPermissionStatus.granted;
  }
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
