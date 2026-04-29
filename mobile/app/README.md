# Timetable Mobile App

Flutter 3 client for the timetable rewrite.

## What Sprint 4 Delivers

- explicit section-first onboarding with searchable selection and local persistence
- a gated app flow that keeps students out of the main timetable experience until a section is chosen
- a `Today` screen with current class, next class, no-class-day handling, and stale-cache messaging
- a dedicated `Week` screen that preserves the timetable’s day/slot structure instead of forcing a generic calendar
- cache-backed Worker API reads so previously fetched sections and timetables still load when connectivity is poor
- settings actions for changing section and clearing local cache

## Architecture Notes

- Riverpod owns runtime config, storage, API client, and selected-section state
- GoRouter splits onboarding from the selected-section shell
- `SharedPreferences` stores the selected section, last seen version, cached section list, and cached section timetables
- schedule summary logic for today/current/next calculations lives in `lib/features/home/home_schedule_summary.dart`

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

## Verification

```powershell
flutter pub get
flutter analyze
flutter test
```
