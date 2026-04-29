# Timetable Overhaul Roadmap

## Scope and Inputs

- Reference backend/codebase: `Afia-Mujeeb/timetable` (`master`)
- Reference mobile app: `Afia-Mujeeb/timetable_notifier` (`master`)
- Target source document: `C:\Users\PC\Downloads\26 april sp26 CS DEPARTMENT (4days sec wise).pdf`
- PDF facts verified locally on April 29, 2026:
  - 25 pages
  - Sections include `BS-CS-2A` through `BS-CS-8E`, plus `BS-CE-2A`, `BS-CS-MISC`, `BS-CS-MISC 1`, `BS-CS-MISC 3`
  - Page footer indicates `DEPARTMENT OF COMPUTER SCIENCE (SPRING 2026 TIMETABLE)`
  - PDF timestamp line shows `Timetable generated: 4/26/2026`

## Detailed Sprint Docs

- [Sprint dossier index](E:/timetable/docs/sprints/README.md)
- [Sprint 0](E:/timetable/docs/sprints/sprint-0-environment-and-repo-reset.md)
- [Sprint 1](E:/timetable/docs/sprints/sprint-1-pdf-ingestion-prototype.md)
- [Sprint 2](E:/timetable/docs/sprints/sprint-2-backend-foundation.md)
- [Sprint 3](E:/timetable/docs/sprints/sprint-3-mobile-foundation.md)
- [Sprint 4](E:/timetable/docs/sprints/sprint-4-core-student-experience.md)
- [Sprint 5](E:/timetable/docs/sprints/sprint-5-notifications-and-change-detection.md)
- [Sprint 6](E:/timetable/docs/sprints/sprint-6-admin-and-operations.md)
- [Sprint 7](E:/timetable/docs/sprints/sprint-7-hardening-and-beta-release.md)
- [Sprint 8](E:/timetable/docs/sprints/sprint-8-scale-to-2000-users.md)

## Current-State Audit

### Old backend repo

- The current backend is not a realistic base for modernization.
- `README.md` explicitly says it is an example of how not to build it.
- `api/fetch.php` loads a spreadsheet directly inside the request path and builds the response from raw cell scanning.
- `api/fetch.php` interpolates `email` into SQL unsafely and mixes DB access, parsing, business rules, and HTTP response code in one file.
- The parser logic is hard-coded around an older spreadsheet layout and lab timing assumptions.
- `composer.json` is minimal and there is no visible testing, deployment, or environment automation.
- `getUpdatedTT.py` is a brittle page scraper for a 2018 Google Sites page and is no longer an acceptable ingestion strategy.

### Old mobile repo

- The Flutter app is from an obsolete Flutter generation.
- `pubspec.yaml` uses very old packages like `http 0.11`, `firebase_messaging 1.0.5`, and `flutter_local_notifications 0.3.7`.
- `lib/main.dart` is a thin launcher into old imperative screens.
- `lib/functions.dart` mixes storage, networking, validation, and notification scheduling in one file.
- The app fetches a legacy PHP endpoint and stores the entire payload locally, which means the current client contract is tied to the old backend shape.

### Local environment

- Present: `python`, `py`, `java`, `javac`, `winget`
- Missing: `git`, `node`, `npm`, `pnpm`, `flutter`, `dart`, `php`, `composer`, `docker`, `docker-compose`, `gradle`
- Added during audit: `pypdf` in the user Python environment to inspect the target PDF

## Recommendation

Build a new codebase. Keep only product intent and timetable semantics from the old repos.

Do not attempt a line-by-line refactor of the PHP backend or the old Flutter app. The technical debt is structural:

- no usable architecture boundaries
- obsolete mobile dependencies
- unsafe backend patterns
- parser logic coupled to one old file format
- no repeatable environment/bootstrap path

## Target Architecture

### Product shape

- Mobile app for students
- Admin/import flow for new timetable PDFs
- Lightweight backend API
- Change detection and notification pipeline

### Technology choice

- Mobile: Flutter 3.x
- Backend API: TypeScript on Cloudflare Workers with Hono
- Database: Cloudflare D1
- Blob storage for uploaded source PDFs and parsed artifacts: Cloudflare R2 only if needed
- Parser/import worker: Python script plus CI job, or a dedicated import endpoint if you want browser upload later
- Push notifications: Firebase Cloud Messaging

### Why this stack

- Flutter keeps the mobile target cross-platform and is a cleaner continuation than reviving the old app.
- Cloudflare Workers + D1 is the strongest free deployment path for this scale if request volume stays modest and heavy parsing is moved out of user-facing requests.
- PDF ingestion is infrequent, so it should run offline during admin import, not on every student request.
- Students can receive most reminders as device-local notifications generated from downloaded timetable data, which keeps backend cost near zero.

## Proposed Repository Layout

```text
/
  docs/
  mobile/
    app/
  backend/
    worker-api/
    worker-admin/
  tools/
    pdf_parser/
  contracts/
    openapi/
  .github/
    workflows/
```

## Data Model Direction

Core entities:

- `timetable_versions`
- `sections`
- `courses`
- `instructors`
- `rooms`
- `timeslots`
- `class_meetings`
- `student_preferences`
- `device_registrations`

Important rule: store normalized meetings, not raw page text blobs as your serving model.

Each class meeting should resolve to:

- section
- course name
- instructor
- room or online marker
- day of week
- start time
- end time
- source version

## Free Deployment Fit

This plan is realistic for 2,000 users if the product is mostly read-heavy and notifications are mostly local.

Verified current limits from official docs:

- Cloudflare Workers Free: `100,000 requests/day`, `10 ms` CPU per HTTP request, `5` cron triggers, `128 MB` memory
- Cloudflare D1 Free: `10` databases, `500 MB` per database, `5 GB` total account storage, `50` queries per Worker invocation
- GitHub Actions: standard hosted runners are free for public repositories
- Firebase Cloud Messaging: listed as no-cost on Firebase pricing

Practical implication:

- Do not parse PDFs inside the public request path.
- Do not model the app as a chatty backend per screen.
- Cache aggressively and serve section timetables in a few queries.
- Generate on-device reminders whenever possible.

## Sprint Breakdown

Assume 1-week sprints. These are intentionally separable so you can run them one by one.

### Sprint 0: Environment and Repo Reset

Goal:

- make the team able to build, run, lint, test, and deploy from a clean Windows machine

Deliverables:

- new repository scaffold
- bootstrap script for Windows
- pinned tool versions
- `.editorconfig`, formatter, linter, CI skeleton
- local `.env.example` files

Tasks:

- install `git`, `node` LTS, `pnpm`, `flutter`, Android toolchain, optional Docker
- decide whether the repo stays public to keep GitHub Actions free
- initialize folders for `mobile`, `backend`, `tools`, `contracts`, `docs`
- add ADR documenting why this is a rewrite

Exit criteria:

- a fresh machine can run setup and build the empty app/backend shells

### Sprint 1: PDF Ingestion Prototype

Goal:

- prove we can turn the April 26, 2026 PDF into normalized structured data

Deliverables:

- parser spike in Python
- versioned JSON output for all 25 pages
- parser test fixtures from the target PDF
- documented assumptions for room names, online days, and lab durations

Tasks:

- extract per-page section labels
- define parsing rules for day columns, 40-minute slots, merged blocks, and labs
- produce a canonical JSON schema for parsed timetable versions
- detect parser confidence failures instead of silently guessing

Exit criteria:

- one command converts the target PDF into validated structured JSON with manual spot checks passing

### Sprint 2: Backend Foundation

Goal:

- build a clean API and storage layer around the parsed timetable

Deliverables:

- D1 schema and migrations
- Worker API with OpenAPI contract
- timetable version loader/import command
- healthcheck and structured error model

Tasks:

- model normalized tables
- create endpoints for sections, timetable version, and section schedule
- add basic caching headers
- add request logging and error correlation ids

Exit criteria:

- mobile can fetch section lists and a section schedule from the new backend

### Sprint 3: Mobile Foundation

Goal:

- replace the legacy Flutter shell with a modern, maintainable client

Deliverables:

- Flutter 3 app scaffold
- app theme, navigation, state management, network layer
- typed models generated or maintained from the API contract
- baseline test setup

Tasks:

- choose Riverpod or Bloc and keep the decision documented
- build app bootstrap, routing, and error/loading states
- add remote config and notification permission handling hooks

Exit criteria:

- clean install opens a working app shell and can fetch demo data from the backend

### Sprint 4: Core Student Experience

Goal:

- ship the minimum product students will actually use

Deliverables:

- section selection flow
- section timetable screen
- today/next class view
- offline cache for last successful timetable download

Tasks:

- support section-based usage first
- keep account creation optional until there is a strong reason to require it
- design around the real schedule shape from the PDF, not a generic calendar template

Exit criteria:

- a student can install the app, choose a section, and reliably view their timetable offline

### Sprint 5: Notifications and Change Detection

Goal:

- restore the original notifier value without recreating the old coupling

Deliverables:

- local class reminders from downloaded schedule
- timetable diff engine between versions
- optional push for urgent timetable changes

Tasks:

- schedule local reminders on-device
- generate stable identifiers per class meeting
- push only when a version changes materially
- add quiet hours and per-user notification preferences

Exit criteria:

- reminders work without the backend sending per-class pushes

### Sprint 6: Admin and Operations

Goal:

- make timetable updates operationally safe

Deliverables:

- admin upload/import flow or CI-driven import workflow
- version history
- rollback path to previous timetable version
- audit log for imports

Tasks:

- choose between manual admin upload and GitHub-based import trigger
- validate parsed output before promoting it live
- support preview before publish

Exit criteria:

- a new semester PDF can be imported and published without code edits

### Sprint 7: Hardening and Beta Release

Goal:

- prove the platform is stable enough for real users

Deliverables:

- integration tests
- parser regression suite
- crash reporting
- rate limiting
- launch checklist

Tasks:

- test section retrieval and caching under realistic usage
- test parser against malformed or changed layouts
- verify app startup, offline behavior, and notification edge cases

Exit criteria:

- beta release is ready for 100 to 300 users

### Sprint 8: Scale to 2,000 Users

Goal:

- tighten cost and reliability before broad rollout

Deliverables:

- usage dashboards
- cache tuning
- hot path query optimization
- incident/runbook docs

Tasks:

- estimate worst-case daily requests per active user
- reduce request fan-out per screen
- validate D1 query counts stay well under per-invocation limits
- define upgrade trigger for moving off free tier

Exit criteria:

- projected daily traffic fits free-tier limits with headroom

## Parallel Workstreams

Once Sprint 1 is underway, these can move partly in parallel:

- parser/data modeling
- backend contract and schema
- mobile shell and UI system
- CI/CD and environment automation

Avoid parallelizing before the parser schema is stable. That is the main contract risk.

## Immediate Build Order

1. Finish Sprint 0 first.
2. Do Sprint 1 before writing serious backend or mobile feature code.
3. Lock the API contract in Sprint 2.
4. Build the app around section-first usage, not account-first usage.
5. Add pushes only after local reminders and timetable diffing work.

## Concrete Environment Bootstrap Targets

Minimum local tools to standardize:

- `Git`
- `Node.js LTS`
- `pnpm`
- `Flutter`
- `Android Studio` plus Android SDK
- `Python 3.12+` or one team-approved version
- `Firebase CLI`
- `Wrangler`

Windows installation can be scripted with `winget`, but exact package ids should be verified during Sprint 0 on the target machines before automation is committed.

## Recommended First Milestone

The first milestone should not be "build the whole app".

It should be:

- parse the April 26, 2026 PDF
- publish one normalized timetable version
- fetch and display one section in a new Flutter app

If that milestone is weak, everything else will inherit the wrong contract.
