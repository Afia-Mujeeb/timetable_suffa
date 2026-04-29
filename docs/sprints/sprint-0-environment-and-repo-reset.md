# Sprint 0: Environment and Repo Reset

## Status

- Last verified: April 29, 2026
- Overall state: mostly implemented
- Remaining gap: Android SDK setup still needs to be completed inside Android Studio

## Objective

Create a clean, repeatable development environment and a new repository structure so later sprints can build, test, and deploy without inheriting hidden state from the legacy codebases.

## What changed in Sprint 0

### Repository baseline

The new repo layout now exists at `E:\timetable`:

```text
/
  .github/
    workflows/
  backend/
    worker-api/
    worker-admin/
  contracts/
    openapi/
  docs/
    adr/
    setup/
    sprints/
  mobile/
    app/
  scripts/
  tools/
    pdf_parser/
```

Implemented deliverables:

- root `README.md`
- `docs/adr/0001-rewrite-decision.md`
- `docs/setup/windows-bootstrap.md`
- `scripts/bootstrap-windows.ps1`
- `.editorconfig`
- `.gitignore`
- root workspace configs for TypeScript, ESLint, Prettier, and pnpm
- Worker placeholders for `backend/worker-api` and `backend/worker-admin`
- Flutter shell under `mobile/app`
- Python parser workspace under `tools/pdf_parser`
- `.env.example` files and `.dev.vars.example` files
- CI workflow skeleton in `.github/workflows/ci.yml`

### Machine baseline

Installed and verified on this workstation:

| Tool           | Status                 | Version / note                             |
| -------------- | ---------------------- | ------------------------------------------ |
| `git`          | installed              | `2.54.0.windows.1`                         |
| `node`         | installed              | `v24.15.0`                                 |
| `npm.cmd`      | installed              | `11.12.1`                                  |
| `pnpm.cmd`     | installed              | repo uses `pnpm` `10.0.0`                  |
| `python`       | installed              | `Python 3.14.3`                            |
| `firebase.cmd` | installed              | `15.15.0`                                  |
| `flutter`      | installed through Puro | `3.41.8`                                   |
| `puro`         | installed              | `1.5.0`                                    |
| Android Studio | installed              | `2025.3.4.6`                               |
| Android SDK    | pending                | `flutter doctor` still reports SDK missing |

### Chosen baseline versions

| Area                  | Baseline                                  |
| --------------------- | ----------------------------------------- |
| Version control       | Git `2.54.0`                              |
| JavaScript runtime    | Node.js LTS `24.15.0`                     |
| Package manager       | `pnpm` `10.0.0` pinned in the repo        |
| Mobile SDK manager    | Puro `1.5.0`                              |
| Flutter SDK           | stable `3.41.8`                           |
| Android IDE           | Android Studio `2025.3.4.6`               |
| Parser runtime policy | Python `3.12+`, verified here on `3.14.3` |
| Firebase CLI          | `15.15.0`                                 |
| Wrangler              | local project dependency via `pnpm`       |

## Verification results

### Passed

- `git --version`
- `node --version`
- `npm.cmd --version`
- `pnpm.cmd --version`
- `firebase.cmd --version`
- `C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat --version`
- `C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat doctor`
  - Flutter itself is healthy
  - Android SDK is still missing
- `pnpm.cmd run check`
- `pnpm.cmd --dir backend/worker-api exec wrangler --version`
- `pnpm.cmd --dir backend/worker-admin exec wrangler --version`
- `python -m ruff check tools/pdf_parser`
- `python -m pytest tools/pdf_parser`
- `flutter analyze`
- `flutter test`

### Remaining failure or manual follow-up

- Android SDK installation and license acceptance still need to be completed from Android Studio before Android-targeted `flutter doctor` is fully clean.

## Scope delivered

### In scope and completed

- Windows bootstrap path
- repository initialization and folder structure
- toolchain version policy
- formatter, linter, and placeholder test baseline
- CI workflow skeleton
- environment example files and secrets policy
- rewrite ADR

### Out of scope and still deferred

- timetable parsing logic
- backend business logic
- mobile feature implementation
- admin workflows
- production deployment

## Quality baseline

### Backend

- TypeScript strict mode
- ESLint and Prettier
- Vitest placeholder coverage
- Wrangler config per Worker

### Mobile

- Flutter lints enabled
- analyzer config present
- widget test skeleton present

### Parser

- isolated `pyproject.toml`
- Ruff for linting
- Pytest for tests
- placeholder CLI for Sprint 1 handoff

## CI baseline

The CI workflow now runs:

- backend formatting
- backend lint
- backend typecheck
- backend tests
- mobile `flutter analyze`
- mobile `flutter test`
- parser Ruff
- parser Pytest

## Risks

### Android setup is not completely closed

Android Studio is installed, but Android SDK provisioning still depends on the post-install IDE flow. This is the only notable Sprint 0 machine-level gap left.

### Python is newer than the minimum policy

The repo is verified on Python `3.14.3`, while the documented compatibility floor remains `3.12+`. Sprint 1 should keep dependencies compatible with that floor unless the team explicitly changes policy.

## Exit criteria assessment

- Bootstrap instructions exist: yes
- Repo scaffold exists: yes
- Baseline lint, test, and analyze commands exist: yes
- CI skeleton exists: yes
- All local tooling is complete: almost; Android SDK still pending

## Definition of done

Sprint 0 is functionally complete for repo work and for most machine setup. It becomes fully complete once Android SDK setup is finished and `flutter doctor` is clean for the Android toolchain.
