import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timetable_app/app/timetable_app.dart";
import "package:timetable_app/core/config/app_config.dart";
import "package:timetable_app/core/providers/app_providers.dart";
import "package:timetable_app/data/storage/shared_preferences_app_storage.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final config = AppConfig.fromEnvironment();
  final storage = SharedPreferencesAppStorage(preferences);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appStorageProvider.overrideWithValue(storage),
      ],
      child: const TimetableApp(),
    ),
  );
}
