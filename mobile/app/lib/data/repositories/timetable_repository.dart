import "dart:io";

import "package:http/http.dart" as http;
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/api/timetable_api_client.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/reminders/reminder_sync_coordinator.dart";
import "package:timetable_app/data/storage/app_storage.dart";

abstract interface class TimetableRepository {
  Future<SectionsSnapshot> fetchSections({bool forceRefresh = false});

  Future<SectionTimetable> fetchSectionTimetable(
    String sectionCode, {
    bool forceRefresh = false,
    String? latestVersionId,
  });
}

class LiveTimetableRepository implements TimetableRepository {
  LiveTimetableRepository({
    required this.apiClient,
    required this.storage,
    this.reminderSyncCoordinator,
  });

  final TimetableApiClient apiClient;
  final AppStorage storage;
  final ReminderSyncCoordinator? reminderSyncCoordinator;

  @override
  Future<SectionsSnapshot> fetchSections({bool forceRefresh = false}) async {
    final cached = await storage.readSectionsSnapshot();
    if (!forceRefresh && cached != null && !cached.isStale) {
      return cached;
    }

    try {
      final response = await apiClient.fetchSections(
        ifNoneMatch: cached?.etag,
      );
      final snapshot = response.payload;
      if (response.notModified && cached != null) {
        final refreshed = cached.copyWith(
          cachedAt: DateTime.now().toUtc().toIso8601String(),
          etag: response.etag ?? cached.etag,
          isStale: false,
        );
        await storage.writeSectionsSnapshot(refreshed);
        await storage.writeLastSeenVersionId(
          refreshed.timetableVersion.versionId,
        );
        return refreshed;
      }
      if (snapshot == null) {
        return _fetchSectionsWithoutValidator();
      }
      final freshSnapshot = snapshot.copyWith(
        etag: response.etag,
      );
      await storage.writeSectionsSnapshot(freshSnapshot);
      await storage.writeLastSeenVersionId(
        freshSnapshot.timetableVersion.versionId,
      );
      return freshSnapshot;
    } on ApiException catch (_) {
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    } on SocketException catch (_) {
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    } on http.ClientException catch (_) {
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    }
  }

  @override
  Future<SectionTimetable> fetchSectionTimetable(
    String sectionCode, {
    bool forceRefresh = false,
    String? latestVersionId,
  }) async {
    final cached = await storage.readSectionTimetable(sectionCode);
    if (_shouldUseCachedTimetable(
      cached,
      forceRefresh: forceRefresh,
      latestVersionId: latestVersionId,
    )) {
      return cached!;
    }

    try {
      final response = await apiClient.fetchSectionTimetable(
        sectionCode,
        ifNoneMatch: cached?.etag,
      );
      final timetable = response.payload;
      if (response.notModified && cached != null) {
        final refreshed = cached.copyWith(
          cachedAt: DateTime.now().toUtc().toIso8601String(),
          etag: response.etag ?? cached.etag,
          isStale: false,
        );
        await storage.writeSectionTimetable(refreshed);
        await storage.writeLastSeenVersionId(
          refreshed.timetableVersion.versionId,
        );
        await reminderSyncCoordinator?.syncForSectionTimetable(
          sectionCode: sectionCode,
          timetable: refreshed,
        );
        return refreshed;
      }
      if (timetable == null) {
        return _fetchSectionTimetableWithoutValidator(sectionCode);
      }
      final freshTimetable = timetable.copyWith(
        etag: response.etag,
      );
      await storage.writeSectionTimetable(freshTimetable);
      await storage.writeLastSeenVersionId(
        freshTimetable.timetableVersion.versionId,
      );
      await reminderSyncCoordinator?.syncForSectionTimetable(
        sectionCode: sectionCode,
        timetable: freshTimetable,
      );
      return freshTimetable;
    } on ApiException catch (_) {
      if (cached != null) {
        final staleTimetable = cached.copyWith(isStale: true);
        await reminderSyncCoordinator?.syncForSectionTimetable(
          sectionCode: sectionCode,
          timetable: staleTimetable,
        );
        return staleTimetable;
      }
      rethrow;
    } on SocketException catch (_) {
      if (cached != null) {
        final staleTimetable = cached.copyWith(isStale: true);
        await reminderSyncCoordinator?.syncForSectionTimetable(
          sectionCode: sectionCode,
          timetable: staleTimetable,
        );
        return staleTimetable;
      }
      rethrow;
    } on http.ClientException catch (_) {
      if (cached != null) {
        final staleTimetable = cached.copyWith(isStale: true);
        await reminderSyncCoordinator?.syncForSectionTimetable(
          sectionCode: sectionCode,
          timetable: staleTimetable,
        );
        return staleTimetable;
      }
      rethrow;
    }
  }

  Future<SectionsSnapshot> _fetchSectionsWithoutValidator() async {
    final response = await apiClient.fetchSections();
    final snapshot = response.payload;
    if (snapshot == null) {
      throw http.ClientException("sections payload missing");
    }

    final freshSnapshot = snapshot.copyWith(
      etag: response.etag,
    );
    await storage.writeSectionsSnapshot(freshSnapshot);
    await storage.writeLastSeenVersionId(
      freshSnapshot.timetableVersion.versionId,
    );
    return freshSnapshot;
  }

  Future<SectionTimetable> _fetchSectionTimetableWithoutValidator(
    String sectionCode,
  ) async {
    final response = await apiClient.fetchSectionTimetable(sectionCode);
    final timetable = response.payload;
    if (timetable == null) {
      throw http.ClientException("timetable payload missing");
    }

    final freshTimetable = timetable.copyWith(
      etag: response.etag,
    );
    await storage.writeSectionTimetable(freshTimetable);
    await storage.writeLastSeenVersionId(
      freshTimetable.timetableVersion.versionId,
    );
    await reminderSyncCoordinator?.syncForSectionTimetable(
      sectionCode: sectionCode,
      timetable: freshTimetable,
    );
    return freshTimetable;
  }

  bool _shouldUseCachedTimetable(
    SectionTimetable? cached, {
    required bool forceRefresh,
    required String? latestVersionId,
  }) {
    if (cached == null) {
      return false;
    }

    if (latestVersionId != null) {
      return cached.timetableVersion.versionId == latestVersionId;
    }

    if (forceRefresh) {
      return false;
    }

    return !cached.isStale;
  }
}
