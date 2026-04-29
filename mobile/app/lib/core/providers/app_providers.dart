import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/data/api/timetable_api_client.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/repositories/timetable_repository.dart";
import "package:timetable_app/data/storage/app_storage.dart";

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError("appConfigProvider must be overridden."),
);

final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError("appStorageProvider must be overridden."),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final timetableApiClientProvider = Provider<TimetableApiClient>((ref) {
  return TimetableApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    httpClient: ref.watch(httpClientProvider),
  );
});

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  return LiveTimetableRepository(
    apiClient: ref.watch(timetableApiClientProvider),
    storage: ref.watch(appStorageProvider),
  );
});

final sectionsProvider = FutureProvider<SectionsSnapshot>((ref) async {
  return ref.watch(timetableRepositoryProvider).fetchSections();
});

final selectedSectionCodeControllerProvider =
    AsyncNotifierProvider<SelectedSectionCodeController, String?>(
      SelectedSectionCodeController.new,
    );

final selectedSectionBootstrapProvider = FutureProvider<void>((ref) async {
  final sections = await ref.watch(sectionsProvider.future);
  final selectedSectionCode = await ref.watch(
    selectedSectionCodeControllerProvider.future,
  );

  if (sections.sections.isEmpty) {
    return;
  }

  final hasSelection = selectedSectionCode != null &&
      sections.sections.any(
        (section) => section.sectionCode == selectedSectionCode,
      );

  if (!hasSelection) {
    await ref
        .read(selectedSectionCodeControllerProvider.notifier)
        .selectSection(sections.sections.first.sectionCode);
  }
});

final selectedSectionSummaryProvider =
    Provider<AsyncValue<SectionSummary?>>((ref) {
      final sectionsAsync = ref.watch(sectionsProvider);
      final selectedSectionCodeAsync = ref.watch(
        selectedSectionCodeControllerProvider,
      );

      return sectionsAsync.whenData((snapshot) {
        final selectedSectionCode = selectedSectionCodeAsync.valueOrNull;
        if (selectedSectionCode == null) {
          return null;
        }

        for (final section in snapshot.sections) {
          if (section.sectionCode == selectedSectionCode) {
            return section;
          }
        }

        return null;
      });
    });

final selectedSectionTimetableProvider =
    FutureProvider<SectionTimetable?>((ref) async {
      await ref.watch(selectedSectionBootstrapProvider.future);
      final selectedSectionCode = await ref.watch(
        selectedSectionCodeControllerProvider.future,
      );

      if (selectedSectionCode == null || selectedSectionCode.isEmpty) {
        return null;
      }

      return ref
          .watch(timetableRepositoryProvider)
          .fetchSectionTimetable(selectedSectionCode);
    });

final lastSeenVersionIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(appStorageProvider).readLastSeenVersionId();
});

class SelectedSectionCodeController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.watch(appStorageProvider).readSelectedSectionCode();
  }

  Future<void> selectSection(String? sectionCode) async {
    state = AsyncValue.data(sectionCode);
    await ref.watch(appStorageProvider).writeSelectedSectionCode(sectionCode);
    ref.invalidate(selectedSectionTimetableProvider);
  }
}
