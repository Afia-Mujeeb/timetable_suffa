# Memory

Last updated: 2026-04-29

## Sprint 0 outcome

- Reinitialized `E:\timetable` as the new rewrite repo and created the planned folder structure.
- Added the root workspace baseline for TypeScript, Flutter, Python, CI, environment examples, and bootstrap automation.
- Wrote `docs/adr/0001-rewrite-decision.md` and updated Sprint 0 docs to reflect the implemented state.

## Sprint 1 outcome

- Replaced the placeholder parser in `tools/pdf_parser` with a coordinate-aware PyMuPDF pipeline that reads timetable grid lines, reconstructs meeting cells, and emits schema-validated JSON.
- Added `parse` and `validate` CLI commands, a committed JSON schema, a reviewed golden artifact at `tools/pdf_parser/fixtures/golden/spring-2026-2026-04-26.json`, and parser tests that compare live output against that fixture when the local PDF is available.
- Documented parser assumptions and manual QA under `tools/pdf_parser/docs/`, including sampled 2nd, 4th, 6th, 8th, and MISC pages.
- Parsed the April 26, 2026 timetable PDF into `25` structured pages and `162` normalized meetings with one expected validation warning for the `BS-CS-MISC 3` `Computer Networks` block missing a room line in the source PDF.

## Sprint 2 outcome

- Added a shared backend core under `backend/shared/` with the initial D1 migration, repository/service boundaries, parser-artifact import flow, publish flow, and a `sql.js`-backed D1-compatible test harness.
- Expanded `backend/worker-api` into the first production backend slice with `GET /health`, `GET /ready`, `GET /v1/versions`, `GET /v1/versions/current`, `GET /v1/sections`, `GET /v1/sections/:sectionCode`, and `GET /v1/sections/:sectionCode/timetable`, plus structured error envelopes, request IDs, request-duration logging, and cache headers on read endpoints.
- Expanded `backend/worker-admin` into the import/publish worker with `POST /v1/imports`, `POST /v1/versions/:versionId/publish`, `GET /ready`, optional `x-import-secret` protection for write routes, and a fixture import command at `backend/worker-admin/scripts/import-fixture.mjs`.
- Updated both Wrangler configs to bind the shared `TIMETABLE_DB` D1 database and point at `backend/shared/migrations`, then refreshed the OpenAPI contracts in `contracts/openapi/worker-api.openapi.yaml` and `contracts/openapi/worker-admin.openapi.yaml`.
- Added backend tests covering migration smoke, fixture import, repository hot-path timetable queries, service response assembly, route validation failures, and admin import/publish behavior.

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
- The golden parser artifact still carries one known warning: `normalized_domain/meetings/160: missing room on non-online meeting`, which corresponds to `BS-CS-MISC 3` page `25` where the source PDF does not show a room line for `Computer Networks`.
- The backend Workers now expect a real shared D1 database binding and, for protected admin writes, a real `IMPORT_SHARED_SECRET`; the committed Wrangler configs still use placeholder Cloudflare database IDs.

## Verification commands that passed

- `pnpm run check`
- `pnpm --dir backend/worker-api exec wrangler --version`
- `pnpm --dir backend/worker-admin exec wrangler --version`
- `python -m ruff check tools/pdf_parser`
- `python -m pytest tools/pdf_parser`
- `python -m pdf_parser parse --input "C:\Users\PC\Downloads\26 april sp26 CS DEPARTMENT (4days sec wise).pdf" --output "E:\timetable\tools\pdf_parser\fixtures\golden\spring-2026-2026-04-26.json"`
- `python -m pdf_parser validate --input "E:\timetable\tools\pdf_parser\fixtures\golden\spring-2026-2026-04-26.json"`
- `flutter analyze`
- `flutter test`
- `pnpm --dir backend/worker-api test`
- `pnpm --dir backend/worker-api typecheck`
- `pnpm --dir backend/worker-api lint`
- `pnpm --dir backend/worker-admin test`
- `pnpm --dir backend/worker-admin typecheck`
- `pnpm --dir backend/worker-admin lint`
