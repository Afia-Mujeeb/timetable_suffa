# Timetable Mobile App

Flutter 3 client for the timetable rewrite.

## What Sprint 5 Delivers

- explicit section-first onboarding with searchable selection and local persistence
- `Today` and `Week` timetable views backed by cached Worker API reads
- local class reminders derived from the selected section timetable instead of backend per-class pushes
- reminder preferences for enable/disable and lead-time selection in Settings
- stable reminder identifiers so repeated refreshes reschedule cleanly without duplicating notifications
- permission-aware scheduling backed by `flutter_local_notifications`

## Architecture Notes

- Riverpod owns runtime config, storage, API client, selected-section state, and reminder preferences
- GoRouter splits onboarding from the selected-section shell
- `SharedPreferences` stores the selected section, last seen version, cached section list, cached section timetables, and reminder preferences
- reminder coordination lives under `lib/data/reminders/` so repository refreshes and section changes can resync reminders without widget-local side effects
- shared schedule occurrence helpers live in `lib/features/schedule/schedule_occurrences.dart`

## Runtime Configuration

The app reads configuration from `dart-define` values:

- `API_BASE_URL`
- `APP_FLAVOR`

Examples:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8787 --dart-define=APP_FLAVOR=local
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com --dart-define=APP_FLAVOR=production
```

For Android emulators, replace `127.0.0.1` with `10.0.2.2` when targeting a locally running Worker.

## Reminder Notes

- Android scheduling now relies on `flutter_local_notifications` `21.0.0`, `flutter_timezone` `5.0.2`, and `timezone` `0.11.0`.
- Android manifest and Gradle configuration include the notification permission, reboot receiver wiring, and Java 17 desugaring required by the scheduling plugin.
- Reminder preferences survive the "Clear local cache" action; cached timetable payloads and section selection do not.

## Verification

```powershell
flutter pub get
flutter analyze
flutter test
```
