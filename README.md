# Timetable

Sprint 0 scaffold for the timetable rewrite. This repository is split into small, isolated workspaces so backend, mobile, and parser work can move in parallel without inheriting the legacy codebase shape.

## Repository layout

```text
backend/
  worker-api/     Public Cloudflare Worker API
  worker-admin/   Admin/import Cloudflare Worker
contracts/
  openapi/        Shared HTTP contracts
mobile/
  app/            Flutter application package
scripts/          Local bootstrap and helper scripts
tools/
  pdf_parser/     Python parser workspace
docs/             Roadmap and sprint planning
```

## Baseline toolchain

- Node.js `24.x`
- pnpm `10.x`
- Python `3.12`
- Flutter `stable` channel, `3.x`
- Cloudflare Wrangler `4.x`

## Quick start

PowerShell note: prefer `npm.cmd`, `pnpm.cmd`, and `firebase.cmd` if execution policy blocks the default PowerShell shims.

### Backend

```bash
pnpm install
pnpm run check
pnpm --dir backend/worker-api dev
pnpm --dir backend/worker-admin dev
```

### Mobile

```bash
cd mobile/app
flutter pub get
flutter analyze
flutter test
```

### Parser

```bash
cd tools/pdf_parser
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e .[dev]
pytest
python -m pdf_parser parse --input path/to/timetable.pdf
```

## Verification

- Machine: `git --version`, `node --version`, `npm.cmd --version`, `pnpm.cmd --version`, `firebase.cmd --version`, `flutter --version`, `flutter doctor`
- Repo: `pnpm run check`, `flutter analyze`, `flutter test`, `python -m ruff check tools/pdf_parser`, `python -m pytest tools/pdf_parser`

## Environment files

- Root defaults live in `.env.example`.
- Worker local development values live in each backend app's `.dev.vars.example`.
- Mobile runtime placeholders live in `mobile/app/.env.example`.
- Parser-specific placeholders live in `tools/pdf_parser/.env.example`.

## Ownership notes

- `backend/` owns API and admin worker runtime code.
- `mobile/app/` owns the Flutter client shell.
- `tools/pdf_parser/` owns offline ingestion tooling.
- `contracts/openapi/` owns HTTP contract drafts shared across clients.
- `docs/` remains planning and architecture history and was intentionally left untouched in this slice.

## Operations

- Beta release readiness: `docs/operations/beta-release-checklist.md`
- Beta support triage: `docs/operations/beta-support-runbook.md`
- Admin import/publish workflow: `docs/operations/worker-admin-runbook.md`
