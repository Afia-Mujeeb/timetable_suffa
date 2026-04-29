# Memory

Last updated: 2026-04-29

## Sprint 0 outcome

- Reinitialized `E:\timetable` as the new rewrite repo and created the planned folder structure.
- Added the root workspace baseline for TypeScript, Flutter, Python, CI, environment examples, and bootstrap automation.
- Wrote `docs/adr/0001-rewrite-decision.md` and updated Sprint 0 docs to reflect the implemented state.

## Verified toolchain on this machine

- Git `2.54.0.windows.1`
- Node `v24.15.0`
- npm `11.12.1`
- pnpm repo version `10.0.0`
- Python `3.14.3`
- Firebase CLI `15.15.0`
- Puro `1.5.0`
- Flutter stable `3.41.8`
- Android Studio `2025.3.4.6`

## Remaining gap

- Android Studio is installed, but Android SDK setup and license acceptance still need to be completed before `flutter doctor` is fully green for Android.

## Verification commands that passed

- `pnpm run check`
- `pnpm --dir backend/worker-api exec wrangler --version`
- `pnpm --dir backend/worker-admin exec wrangler --version`
- `python -m ruff check tools/pdf_parser`
- `python -m pytest tools/pdf_parser`
- `flutter analyze`
- `flutter test`
