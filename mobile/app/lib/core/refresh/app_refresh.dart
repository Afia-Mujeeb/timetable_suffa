import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/models/timetable_models.dart";

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
  SectionsSnapshot? refreshedSections;
  SectionTimetable? refreshedTimetable;
  final repository = ref.read(timetableRepositoryProvider);

  try {
    refreshedSections = await repository.fetchSections(forceRefresh: true);
  } catch (error, stackTrace) {
    sectionsFailed = true;
    await ref.read(appErrorMonitorProvider).recordError(
          error,
          stackTrace,
          source: "refresh.sections",
          fatal: false,
        );
  }

  final selectedSectionCode =
      await ref.read(selectedSectionCodeControllerProvider.future);
  if (selectedSectionCode != null && selectedSectionCode.isNotEmpty) {
    try {
      refreshedTimetable = await repository.fetchSectionTimetable(
        selectedSectionCode,
        forceRefresh: true,
        latestVersionId: refreshedSections?.timetableVersion.versionId,
      );
    } catch (error, stackTrace) {
      timetableFailed = true;
      await ref.read(appErrorMonitorProvider).recordError(
            error,
            stackTrace,
            source: "refresh.selected_timetable",
            fatal: false,
          );
    }
  }

  ref.invalidate(sectionsProvider);
  ref.invalidate(selectedSectionTimetableProvider);

  return AppRefreshResult(
    sectionsFailed: sectionsFailed,
    timetableFailed: timetableFailed,
    usedCachedSections: refreshedSections?.isStale == true,
    usedCachedTimetable: refreshedTimetable?.isStale == true,
  );
}

Future<AppRefreshResult> refreshSectionsData(WidgetRef ref) async {
  var sectionsFailed = false;
  SectionsSnapshot? refreshedSections;

  try {
    refreshedSections = await ref
        .read(timetableRepositoryProvider)
        .fetchSections(forceRefresh: true);
  } catch (error, stackTrace) {
    sectionsFailed = true;
    await ref.read(appErrorMonitorProvider).recordError(
          error,
          stackTrace,
          source: "refresh.sections",
          fatal: false,
        );
  }

  ref.invalidate(sectionsProvider);

  return AppRefreshResult(
    sectionsFailed: sectionsFailed,
    timetableFailed: false,
    usedCachedSections: refreshedSections?.isStale == true,
    usedCachedTimetable: false,
  );
}
