import "dart:io";

import "package:http/http.dart" as http;
import "package:timetable_app/data/api/api_exception.dart";
import "package:timetable_app/data/api/timetable_api_client.dart";
import "package:timetable_app/data/models/timetable_models.dart";
import "package:timetable_app/data/storage/app_storage.dart";

abstract interface class TimetableRepository {
  Future<SectionsSnapshot> fetchSections();

  Future<SectionTimetable> fetchSectionTimetable(String sectionCode);
}

class LiveTimetableRepository implements TimetableRepository {
  LiveTimetableRepository({
    required this.apiClient,
    required this.storage,
  });

  final TimetableApiClient apiClient;
  final AppStorage storage;

  @override
  Future<SectionsSnapshot> fetchSections() async {
    try {
      final snapshot = await apiClient.fetchSections();
      await storage.writeSectionsSnapshot(snapshot);
      await storage.writeLastSeenVersionId(snapshot.timetableVersion.versionId);
      return snapshot;
    } on ApiException catch (_) {
      final cached = await storage.readSectionsSnapshot();
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    } on SocketException catch (_) {
      final cached = await storage.readSectionsSnapshot();
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    } on http.ClientException catch (_) {
      final cached = await storage.readSectionsSnapshot();
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    }
  }

  @override
  Future<SectionTimetable> fetchSectionTimetable(String sectionCode) async {
    try {
      final timetable = await apiClient.fetchSectionTimetable(sectionCode);
      await storage.writeSectionTimetable(timetable);
      await storage.writeLastSeenVersionId(
        timetable.timetableVersion.versionId,
      );
      return timetable;
    } on ApiException catch (_) {
      final cached = await storage.readSectionTimetable(sectionCode);
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    } on SocketException catch (_) {
      final cached = await storage.readSectionTimetable(sectionCode);
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    } on http.ClientException catch (_) {
      final cached = await storage.readSectionTimetable(sectionCode);
      if (cached != null) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    }
  }
}
