import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/testing.dart";
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/storage/in_memory_app_storage.dart";

void main() {
  test(
    "selected timetable provider serves the local cache without extra API calls",
    () async {
      final storage = InMemoryAppStorage();
      await storage.writeSelectedSectionCode("BS-CS-2A");
      await storage.writeSectionsSnapshot(_sectionsSnapshot);
      await storage.writeSectionTimetable(_sectionTimetable);
      final client = MockClient((request) async {
        throw StateError("unexpected request: ${request.url.path}");
      });

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: "http://localhost:8787",
              appFlavor: "test",
            ),
          ),
          appStorageProvider.overrideWithValue(storage),
          httpClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(() {
        client.close();
        container.dispose();
      });

      final timetable = await container.read(
        selectedSectionTimetableProvider.future,
      );

      expect(timetable, isNotNull);
      expect(timetable!.timetableVersion.versionId, _version.versionId);
      expect(timetable.cachedAt, isNotNull);
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
