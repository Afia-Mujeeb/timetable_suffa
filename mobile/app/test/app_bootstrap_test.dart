import "package:flutter_test/flutter_test.dart";
import "package:timetable_app/core/bootstrap/app_bootstrap.dart";
import "package:timetable_app/data/storage/in_memory_app_storage.dart";

void main() {
  test("falls back to in-memory storage when preferences bootstrap fails",
      () async {
    final result = await bootstrapApplication(
      loadPreferences: () async {
        throw StateError("preferences unavailable");
      },
    );

    expect(result.status.isDegraded, isTrue);
    expect(result.storage, isA<InMemoryAppStorage>());
    expect(result.errorMonitor.isPersistent, isFalse);

    final events = await result.errorMonitor.readRecentEvents();
    expect(events, hasLength(1));
    expect(events.single.source, "bootstrap.shared_preferences");
  });
}
