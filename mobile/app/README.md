# Timetable Mobile App

Flutter 3 client foundation for the timetable rewrite.

## What Sprint 3 Added

- a full Flutter multi-platform scaffold under `mobile/app`
- Riverpod-based dependency wiring and selected-section state
- GoRouter app shell with timetable and settings routes
- typed Worker API client for Sprint 2 section and timetable endpoints
- `SharedPreferences` storage for selected section, last seen version, and cached payloads
- cache-backed repository behavior so the UI can fall back to stale data when the latest fetch fails

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
flutter build web --release
```
