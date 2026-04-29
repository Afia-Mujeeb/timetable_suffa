import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timetable_app/core/providers/app_providers.dart";

class AppRefreshResult {
  const AppRefreshResult({
    required this.sectionsFailed,
    required this.timetableFailed,
    required this.usedCachedSections,
    required this.usedCachedTimetable,
  });

  final bool sectionsFailed;
  final bool timetableFailed;
  final bool usedCachedSections;
  final bool usedCachedTimetable;

  bool get hadFailures => sectionsFailed || timetableFailed;

  bool get usedCachedData => usedCachedSections || usedCachedTimetable;
}

Future<AppRefreshResult> refreshSelectedSectionData(WidgetRef ref) async {
  var sectionsFailed = false;
  var timetableFailed = false;

  ref.invalidate(sectionsProvider);
  ref.invalidate(selectedSectionTimetableProvider);

  try {
    await ref.read(sectionsProvider.future);
  } catch (error, stackTrace) {
    sectionsFailed = true;
    await ref.read(appErrorMonitorProvider).recordError(
          error,
          stackTrace,
          source: "refresh.sections",
          fatal: false,
        );
  }

  try {
    await ref.read(selectedSectionTimetableProvider.future);
  } catch (error, stackTrace) {
    timetableFailed = true;
    await ref.read(appErrorMonitorProvider).recordError(
          error,
          stackTrace,
          source: "refresh.selected_timetable",
          fatal: false,
        );
  }

  final refreshedSections = ref.read(sectionsProvider).valueOrNull;
  final refreshedTimetable =
      ref.read(selectedSectionTimetableProvider).valueOrNull;

  return AppRefreshResult(
    sectionsFailed: sectionsFailed,
    timetableFailed: timetableFailed,
    usedCachedSections: refreshedSections?.isStale == true,
    usedCachedTimetable: refreshedTimetable?.isStale == true,
  );
}

Future<AppRefreshResult> refreshSectionsData(WidgetRef ref) async {
  var sectionsFailed = false;

  ref.invalidate(sectionsProvider);

  try {
    await ref.read(sectionsProvider.future);
  } catch (error, stackTrace) {
    sectionsFailed = true;
    await ref.read(appErrorMonitorProvider).recordError(
          error,
          stackTrace,
          source: "refresh.sections",
          fatal: false,
        );
  }

  final refreshedSections = ref.read(sectionsProvider).valueOrNull;

  return AppRefreshResult(
    sectionsFailed: sectionsFailed,
    timetableFailed: false,
    usedCachedSections: refreshedSections?.isStale == true,
    usedCachedTimetable: false,
  );
}
