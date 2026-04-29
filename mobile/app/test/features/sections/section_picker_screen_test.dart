import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/core/theme/app_theme.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";
import "package:timetable_app/features/sections/section_picker_screen.dart";

void main() {
  testWidgets("filters sections and confirms the drafted selection", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({
      "selected_section_code": "BS-CS-1A",
    });
    final preferences = await SharedPreferences.getInstance();

    String? confirmedSectionCode;

    await tester.pumpWidget(
      _buildHarness(
        storage: SharedPreferencesAppStorage(preferences),
        onConfirmed: (sectionCode) {
          confirmedSectionCode = sectionCode;
        },
        sectionOverride: sectionsProvider.overrideWith(
          (ref) async => SectionsSnapshot(
            timetableVersion: _version,
            sections: _sections,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Search sections"), findsOneWidget);
    expect(find.text("Selected: BS-CS-1A"), findsOneWidget);

    await tester.enterText(find.byType(TextField), "AI-2B");
    await tester.pumpAndSettle();

    expect(find.text("BS-AI-2B"), findsWidgets);
    expect(find.text("Computer Science 1B"), findsNothing);

    final optionFinder = find.byKey(const ValueKey("section-option-BS-AI-2B"));
    await tester.scrollUntilVisible(
      optionFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();

    expect(find.text("Selected: BS-AI-2B"), findsOneWidget);
    expect(
        find.widgetWithText(FilledButton, "Use this section"), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, "Use this section"));
    await tester.pumpAndSettle();

    expect(confirmedSectionCode, "BS-AI-2B");
    expect(
      await SharedPreferencesAppStorage(preferences).readSelectedSectionCode(),
      "BS-AI-2B",
    );
  });

  testWidgets("shows cached offline messaging and allows continuing", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      "selected_section_code": "BS-CS-2A",
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _buildHarness(
        storage: SharedPreferencesAppStorage(preferences),
        sectionOverride: sectionsProvider.overrideWith(
          (ref) async => SectionsSnapshot(
            timetableVersion: _version,
            sections: _sections,
            isStale: true,
            cachedAt: "2026-04-29T08:00:00Z",
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Offline mode"), findsOneWidget);
    expect(
      find.textContaining("2026-04-29T08:00:00Z"),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, "Continue"), findsOneWidget);
  });

  testWidgets("shows a dedicated first-run offline state", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _buildHarness(
        storage: SharedPreferencesAppStorage(preferences),
        sectionOverride: sectionsProvider.overrideWith(
          (ref) => Future<SectionsSnapshot>.error(
            const SocketException("offline"),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("First run needs a connection"), findsOneWidget);
    expect(
      find.textContaining("Connect once so the list can be cached"),
      findsOneWidget,
    );

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "Continue"),
    );
    expect(continueButton.onPressed, isNull);
  });
}

Widget _buildHarness({
  required SharedPreferencesAppStorage storage,
  required Override sectionOverride,
  ValueChanged<String>? onConfirmed,
}) {
  return ProviderScope(
    overrides: [
      appStorageProvider.overrideWithValue(storage),
      sectionOverride,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: SectionPickerScreen(
        onConfirmed: onConfirmed,
      ),
    ),
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

const _sections = [
  SectionSummary(
    sectionCode: "BS-CS-1A",
    displayName: "Computer Science 1A",
    active: true,
    meetingCount: 23,
  ),
  SectionSummary(
    sectionCode: "BS-CS-1B",
    displayName: "Computer Science 1B",
    active: true,
    meetingCount: 22,
  ),
  SectionSummary(
    sectionCode: "BS-CS-2A",
    displayName: "Computer Science 2A",
    active: true,
    meetingCount: 25,
  ),
  SectionSummary(
    sectionCode: "BS-AI-2B",
    displayName: "Artificial Intelligence 2B",
    active: true,
    meetingCount: 24,
  ),
  SectionSummary(
    sectionCode: "BS-SE-3A",
    displayName: "Software Engineering 3A",
    active: true,
    meetingCount: 21,
  ),
  SectionSummary(
    sectionCode: "BBA-1A",
    displayName: "Business Administration 1A",
    active: true,
    meetingCount: 19,
  ),
  SectionSummary(
    sectionCode: "BBA-2B",
    displayName: "Business Administration 2B",
    active: false,
    meetingCount: 18,
  ),
  SectionSummary(
    sectionCode: "DPT-1A",
    displayName: "Physical Therapy 1A",
    active: true,
    meetingCount: 20,
  ),
];
