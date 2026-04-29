import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

void main() {
  test("persists the selected section code", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesAppStorage(preferences);

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: "http://localhost:8787",
            appFlavor: "test",
          ),
        ),
        appStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedSectionCodeControllerProvider.future);
    await container
        .read(selectedSectionCodeControllerProvider.notifier)
        .selectSection("BS-CS-2A");

    expect(
      await storage.readSelectedSectionCode(),
      "BS-CS-2A",
    );
    expect(
      container.read(selectedSectionCodeControllerProvider).valueOrNull,
      "BS-CS-2A",
    );
  });
}
