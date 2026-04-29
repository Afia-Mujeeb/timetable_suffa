import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/app/timetable_app.dart";
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

void main() {
  testWidgets("starts into the offline cached experience for a saved section",
      (tester) async {
    SharedPreferences.setMockInitialValues({
      "selected_section_code": "BS-CS-2A",
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: "http://localhost:8787",
              appFlavor: "test",
            ),
          ),
          appStorageProvider.overrideWithValue(
            SharedPreferencesAppStorage(preferences),
          ),
          sectionsProvider.overrideWith(
            (ref) async => const SectionsSnapshot(
              timetableVersion: _version,
              sections: [
                SectionSummary(
                  sectionCode: "BS-CS-2A",
                  displayName: "BS-CS-2A",
                  active: true,
                  meetingCount: 2,
                ),
              ],
              isStale: true,
              cachedAt: "2026-04-29T08:00:00Z",
            ),
          ),
          selectedSectionTimetableProvider.overrideWith(
            (ref) async => const SectionTimetable(
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
              isStale: true,
              cachedAt: "2026-04-29T08:05:00Z",
            ),
          ),
        ],
        child: const TimetableApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Today"), findsWidgets);
    expect(
      find.textContaining("Showing the last successful timetable sync"),
      findsOneWidget,
    );
    expect(find.text("BS-CS-2A"), findsWidgets);
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
