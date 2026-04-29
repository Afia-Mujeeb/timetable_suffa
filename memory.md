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

## Sprint 3 outcome

- Recreated `mobile/app` as a full Flutter 3 multi-platform project with Android, iOS, web, Windows, Linux, and macOS scaffolds, then replaced the placeholder shell with the new section-first mobile foundation.
- Added a Riverpod- and GoRouter-based app shell with a custom theme, timetable and settings routes, explicit loading/error/empty states, and a first timetable-focused UI that consumes the new backend contract instead of any legacy PHP flow.
- Added a typed mobile data layer for the actual Sprint 2 Worker response shapes, including the HTTP client, DTO/domain models, selected-section state, `SharedPreferences` storage abstraction, and cache-backed repository fallbacks for section lists and timetables.
- Added mobile tests covering app boot rendering, selected-section persistence, and Worker response decoding, plus project-specific run/build notes in `mobile/app/README.md`.

## Sprint 4 outcome

- Reworked `mobile/app` around an explicit section-first onboarding flow with a dedicated searchable picker screen, local selection persistence, and route gating so the main timetable experience is not entered until a section is chosen.
- Replaced the Sprint 3 placeholder home experience with a student-facing `Today` screen that surfaces current class, next class, no-class-day states, stale-cache messaging, and refresh affordances, then added a separate `Week` screen for the full timetable grid by weekday.
- Added reusable schedule-summary logic in `mobile/app/lib/features/home/home_schedule_summary.dart` so current/next class calculations are derived from the actual timetable slot times without timezone conversion hacks.
- Expanded mobile tests with section-picker widget coverage, schedule-summary unit coverage, offline repository fallback coverage, and an updated app-shell widget test aligned to the new Sprint 4 flow.
- Updated `mobile/app/README.md` to document the shipped Sprint 4 experience and current architecture boundaries.

## Sprint 5 outcome

- Added a shared backend version diff engine under `backend/shared/src/timetable/diff.ts` that compares per-version meeting snapshots, classifies added/removed/updated section changes, and emits publish-time change summaries with user-facing change messages.
- Expanded the admin publish flow so `POST /v1/versions/:versionId/publish` now returns the previously published version plus a structured `changes` payload for first-publish bootstrap events and later section-scoped timetable diffs.
- Added local reminder scheduling to `mobile/app` with reminder preferences, stable reminder identifiers, shared schedule-occurrence helpers, and a `flutter_local_notifications`-backed scheduler that resyncs on section changes and timetable refreshes.
- Updated mobile platform wiring for reminder delivery, including Android notification permission and boot receivers, Android desugaring support, iOS notification delegate registration, and generated plugin registrants for desktop/mobile builds.
- Added reminder-focused tests covering stable identifiers, coordinator resync behavior, repository-triggered rescheduling, cache-clear preference persistence, and the updated section-picker flow.
- Added `docs/notifications/push-strategy.md` to document the low-volume section-topic FCM design and change-summary messaging rules that Sprint 6 can operationalize.

## Sprint 6 outcome

- Added `backend/shared/migrations/0002_admin_operations.sql` plus shared repository/service support for durable `import_runs` and `audit_events`, backfilled existing published history, and updated the shared test harness to apply every migration in lexical order.
- Reworked the admin backend into an explicit CI-driven operations flow: `POST /v1/imports` now tracks import start/success/failure, `GET /v1/versions` and `GET /v1/versions/:versionId/preview` expose version history and pre-publish review data, `POST /v1/versions/:versionId/publish` requires explicit warning acknowledgement when needed, `POST /v1/versions/:versionId/rollback` makes rollback first-class, and `GET /v1/import-runs` plus `GET /v1/audit-events` expose the audit trail behind the shared-secret boundary.
- Added version preview and publish-time notification planning data via `pushPreview`, so operators can see which changed sections would qualify for section-scoped pushes before publishing even though real Firebase delivery is still not wired.
- Replaced the fixture-only admin helper with a general operator CLI at `backend/worker-admin/scripts/import-fixture.mjs`, added package scripts for import/preview/publish/rollback/history actions, wrote `docs/operations/worker-admin-runbook.md`, and refreshed `contracts/openapi/worker-admin.openapi.yaml` to match the current Sprint 6 runtime contract.
- Expanded backend tests to cover migration smoke with the new tables, tracked imports, failed-import audit creation, preview-before-publish, warning-gated publish, rollback state transitions, and audit/history endpoints.

## Sprint 7 outcome

- Added deterministic parser regression protection under `tools/pdf_parser/tests/`, including synthetic PyMuPDF-built fixtures for wrapped course titles, merged long lab blocks, wrapped online-day labels, and malformed or partial PDF inputs, plus a CLI parse test that no longer depends on the uncommitted Downloads PDF.
- Hardened both backend Workers with lightweight in-memory beta abuse guards and operational metrics: `GET /metrics` now exposes request totals, final error totals by code/type, and rate-limit counts by rule, while public API and admin routes now return structured `429 rate_limited` responses for burst traffic and repeated invalid requests.
- Expanded backend API coverage to exercise the new rate-limit and metrics behavior alongside the existing import, publish, rollback, and read-path integration tests.
- Reworked the mobile app boot and refresh paths around guarded bootstrap and local diagnostics: app startup now falls back to in-memory storage if `SharedPreferences` initialization fails, malformed cached payloads are dropped and reported instead of crashing the app, refresh flows degrade to cached/offline states with explicit user feedback, and reminder reschedule failures are recorded without breaking section selection or normal app use.
- Added mobile diagnostics surfaces and tests for bootstrap fallback, offline startup, malformed cache recovery, reminder failure containment, refresh hardening, and the section-picker edge case where a previously saved section is no longer present.
- Added Sprint 7 beta-readiness docs at `docs/operations/beta-release-checklist.md` and `docs/operations/beta-support-runbook.md`, then refreshed the admin runbook so operators know to inspect `GET /metrics` and react intentionally to `429` responses during release windows.

## Sprint 8 outcome

- Added validator-aware public read caching in `backend/worker-api`: `GET /v1/versions/current`, `GET /v1/sections`, `GET /v1/sections/:sectionCode`, and `GET /v1/sections/:sectionCode/timetable` now emit `ETag`, `Vary: If-None-Match`, and `x-timetable-version`, and they return `304 Not Modified` when the client already has the current published version payload.
- Tightened the public timetable hot path so section detail lookup and published-version lookup are resolved together before timetable meetings are fetched, which keeps the common section timetable miss path query-cheap while letting validator hits stop after the metadata check.
- Expanded shared Worker metrics with per-route request counts, p50/p95/p99 latency summaries, projected daily request-budget utilization, and named domain-event counters; the admin worker now records import, publish, rollback, and planned notification-section events, while the public worker records validator `not_modified` hits per route.
- Reworked `mobile/app` caching around Sprint 8 scale assumptions: the selected timetable provider no longer drags the section list into every home-screen open, repository reads now use cache TTL plus HTTP `ETag` revalidation, and explicit refreshes still revalidate sections first so unchanged versions can skip the timetable fetch entirely.
- Added Sprint 8 scale docs at `docs/operations/request-budget-model.md` and `docs/operations/scale-runbook.md`, then refreshed `docs/operations/worker-admin-runbook.md` so operators know which request-budget, latency, import-success, and notification-planning counters to inspect.
- Expanded backend and Flutter tests to cover the new `ETag`/`304` behavior, mobile cache-validator reuse, and the updated home-screen request shape.

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
- The new Worker rate limiting and metrics are intentionally lightweight and in-memory per Worker instance; they are good enough for beta detection and throttling, but they are not a durable cross-instance quota system.
- The mobile app defaults to `http://127.0.0.1:8787`; real runs still need the correct `API_BASE_URL` via `--dart-define`, and Android emulator runs should use `10.0.2.2` for a local Worker.
- The mobile app now records recent crash and runtime diagnostics locally, but there is still no remote crash-reporting SaaS wired in; beta monitoring currently depends on local diagnostics plus operator reproduction and backend logs/metrics.
- Section-scoped push planning is now exposed through admin `pushPreview` responses, but actual Firebase device-topic subscription in `mobile/app` and outbound publish-time fan-out from the admin Worker are still not implemented because this repo still lacks the required Firebase client/runtime wiring and delivery credentials.
- The current reminder implementation is intentionally active on Android and iOS only; non-mobile platforms fall back to a no-op reminder scheduler.
- The new Sprint 8 request-budget and latency metrics are still per-Worker-instance in-memory approximations; they are good enough for free-tier trend detection, but they are not a durable multi-instance analytics system.
- The mobile cache TTL is intentionally `30` minutes for both section metadata and selected timetable payloads, so passive users can continue seeing a previously validated timetable until the TTL expires or they trigger an explicit refresh.

## Verification commands that passed

- `pnpm run check`
- `pnpm --dir backend/worker-api exec wrangler --version`
- `pnpm --dir backend/worker-admin exec wrangler --version`
- `python -m ruff check tools/pdf_parser`
- `python -m pytest tools/pdf_parser`
- `python -m pytest tools/pdf_parser/tests`
- `python -m pdf_parser parse --input "C:\Users\PC\Downloads\26 april sp26 CS DEPARTMENT (4days sec wise).pdf" --output "E:\timetable\tools\pdf_parser\fixtures\golden\spring-2026-2026-04-26.json"`
- `python -m pdf_parser validate --input "E:\timetable\tools\pdf_parser\fixtures\golden\spring-2026-2026-04-26.json"`
- `cd mobile/app && flutter analyze`
- `cd mobile/app && flutter test`
- `cd mobile/app && flutter build web --release`
- `cd mobile/app && $env:PATH='C:\Program Files\Git\cmd;' + $env:PATH; & 'C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat' analyze`
- `cd mobile/app && $env:PATH='C:\Program Files\Git\cmd;' + $env:PATH; & 'C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat' test`
- `pnpm --dir backend/worker-api test`
- `pnpm --dir backend/worker-api typecheck`
- `pnpm --dir backend/worker-api lint`
- `pnpm --dir backend/worker-admin test`
- `pnpm --dir backend/worker-admin typecheck`
- `pnpm --dir backend/worker-admin lint`
- `pnpm run lint:backend`
- `pnpm run typecheck:backend`
- `pnpm run test:backend`
- `$env:PATH='C:\Program Files\nodejs;' + $env:PATH; & 'C:\Program Files\nodejs\corepack.cmd' pnpm --dir backend/worker-api lint`
- `$env:PATH='C:\Program Files\nodejs;' + $env:PATH; & 'C:\Program Files\nodejs\corepack.cmd' pnpm --dir backend/worker-api typecheck`
- `$env:PATH='C:\Program Files\nodejs;' + $env:PATH; & 'C:\Program Files\nodejs\corepack.cmd' pnpm --dir backend/worker-api test`
- `$env:PATH='C:\Program Files\nodejs;' + $env:PATH; & 'C:\Program Files\nodejs\corepack.cmd' pnpm --dir backend/worker-admin lint`
- `$env:PATH='C:\Program Files\nodejs;' + $env:PATH; & 'C:\Program Files\nodejs\corepack.cmd' pnpm --dir backend/worker-admin typecheck`
- `$env:PATH='C:\Program Files\nodejs;' + $env:PATH; & 'C:\Program Files\nodejs\corepack.cmd' pnpm --dir backend/worker-admin test`
- `& 'C:\Program Files\nodejs\node.exe' backend\worker-admin\scripts\import-fixture.mjs --help`
