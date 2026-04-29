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
- the home-screen hot path now prefers the selected timetable cache and does not fetch the full section list on every open
- normal app reads prefer the last successful local section list and selected timetable cache instead of re-fetching on every screen load
- selected timetable refreshes are version-aware: after an explicit section metadata refresh, the app skips the timetable API call when the cached section timetable already matches the latest published version
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

## Cache Notes

- normal home opens are a single selected-timetable read path instead of a section-list plus timetable pair
- manual refresh still forces a section metadata revalidation and uses the cached `ETag` when available
- the selected timetable is only re-fetched during refresh when the selected section has no cached timetable, the refreshed section metadata reports a different timetable version, or the API validator says the cached payload is stale
- when the backend is unreachable, the app still falls back to stale cached payloads and shows the existing offline/stale-state messaging

## Verification

```powershell
flutter pub get
flutter analyze
flutter test
```
