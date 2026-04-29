import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;
import "package:timetable_app/core/bootstrap/app_bootstrap.dart";
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/core/monitoring/app_error_event.dart";
import "package:timetable_app/core/monitoring/app_error_monitor.dart";
import "package:timetable_app/data/api/timetable_api_client.dart";
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/flutter_local_notifications_reminder_scheduler.dart";
import "package:timetable_app/data/reminders/noop_reminder_scheduler.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";
import "package:timetable_app/data/reminders/reminder_sync_coordinator.dart";
import "package:timetable_app/data/repositories/timetable_repository.dart";
import "package:timetable_app/data/storage/app_storage.dart";

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError("appConfigProvider must be overridden."),
);

final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError("appStorageProvider must be overridden."),
);

final _defaultAppErrorMonitor = MemoryAppErrorMonitor();

final appErrorMonitorProvider = Provider<AppErrorMonitor>(
  (ref) => _defaultAppErrorMonitor,
);

final appBootstrapStatusProvider = Provider<AppBootstrapStatus>(
  (ref) => AppBootstrapStatus.healthy,
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

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  if (kIsWeb) {
    return const NoopReminderScheduler();
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS =>
      FlutterLocalNotificationsReminderScheduler(),
    _ => const NoopReminderScheduler(),
  };
});

final reminderSyncCoordinatorProvider =
    Provider<ReminderSyncCoordinator>((ref) {
  return ReminderSyncCoordinator(
    storage: ref.watch(appStorageProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
    errorMonitor: ref.watch(appErrorMonitorProvider),
  );
});

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  return LiveTimetableRepository(
    apiClient: ref.watch(timetableApiClientProvider),
    storage: ref.watch(appStorageProvider),
    reminderSyncCoordinator: ref.watch(reminderSyncCoordinatorProvider),
  );
});

final sectionsProvider = FutureProvider<SectionsSnapshot>((ref) async {
  return ref.watch(timetableRepositoryProvider).fetchSections();
});

final selectedSectionCodeControllerProvider =
    AsyncNotifierProvider<SelectedSectionCodeController, String?>(
  SelectedSectionCodeController.new,
);

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

final reminderPermissionStatusProvider =
    FutureProvider<ReminderPermissionStatus>((ref) {
  return ref.watch(reminderSchedulerProvider).getPermissionStatus();
});

final recentAppErrorsProvider = FutureProvider<List<AppErrorEvent>>((ref) {
  return ref.watch(appErrorMonitorProvider).readRecentEvents();
});

final reminderPreferencesControllerProvider =
    AsyncNotifierProvider<ReminderPreferencesController, ReminderPreferences>(
  ReminderPreferencesController.new,
);

class SelectedSectionCodeController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.watch(appStorageProvider).readSelectedSectionCode();
  }

  Future<void> selectSection(String? sectionCode) async {
    state = AsyncValue.data(sectionCode);
    await ref.read(appStorageProvider).writeSelectedSectionCode(sectionCode);
    await ref.read(reminderSyncCoordinatorProvider).syncSelectedSection();
  }
}

class ReminderPreferencesController extends AsyncNotifier<ReminderPreferences> {
  @override
  Future<ReminderPreferences> build() {
    return ref.watch(appStorageProvider).readReminderPreferences();
  }

  Future<ReminderPermissionStatus> requestPermissions() async {
    final status =
        await ref.read(reminderSchedulerProvider).requestPermissions();
    ref.invalidate(reminderPermissionStatusProvider);
    await ref.read(reminderSyncCoordinatorProvider).syncSelectedSection();
    return status;
  }

  Future<void> setLeadTime(ReminderLeadTime leadTime) async {
    final preferences = (state.valueOrNull ?? await future).copyWith(
      leadTime: leadTime,
    );

    await _persistPreferences(preferences);
  }

  Future<ReminderPermissionStatus> setRemindersEnabled(bool enabled) async {
    final preferences = (state.valueOrNull ?? await future).copyWith(
      enabled: enabled,
    );
    await _persistPreferences(preferences);

    var permissionStatus =
        await ref.read(reminderSchedulerProvider).getPermissionStatus();
    if (enabled && permissionStatus != ReminderPermissionStatus.granted) {
      permissionStatus =
          await ref.read(reminderSchedulerProvider).requestPermissions();
    }

    ref.invalidate(reminderPermissionStatusProvider);
    await ref.read(reminderSyncCoordinatorProvider).syncSelectedSection();
    return permissionStatus;
  }

  Future<void> _persistPreferences(ReminderPreferences preferences) async {
    state = AsyncValue.data(preferences);
    await ref.read(appStorageProvider).writeReminderPreferences(preferences);
    await ref.read(reminderSyncCoordinatorProvider).syncSelectedSection();
  }
}
