# Worker Admin Operator Runbook

This runbook covers Sprint 6 and Sprint 7 operator tasks for the timetable admin API exposed by `backend/worker-admin`.

## Prerequisites

- Admin worker base URL, usually local dev `http://127.0.0.1:8788` or the deployed admin host
- Parser artifact JSON file from the parser pipeline
- Shared secret if the worker is configured with `IMPORT_SHARED_SECRET`
- Operator identity for auditability

The CLI lives at `backend/worker-admin/scripts/import-fixture.mjs` and is exposed through package scripts.
Examples below assume commands are run from the repo root `e:\timetable`.

Common environment variables:

```powershell
$env:TIMETABLE_ADMIN_URL="http://127.0.0.1:8788"
$env:TIMETABLE_ADMIN_SECRET="replace-me-if-configured"
$env:TIMETABLE_ADMIN_OPERATOR_ID="ops@example.com"
```

Optional per-request correlation:

```powershell
$requestId = "worker-admin-$(Get-Date -Format yyyyMMddHHmmss)"
```

The CLI prints the raw response JSON to stdout and exits non-zero for HTTP failures, which makes it safe to use in CI jobs.

## Metrics And Abuse Signals

The admin worker exposes `GET /metrics` for a lightweight operational snapshot.
Review it during and after release windows to confirm:

- request totals by final response status
- error totals by error code and type
- rate-limited traffic totals by rule

If operators see repeated `429` responses from admin endpoints, stop retrying blindly and inspect `/metrics` plus the worker logs before continuing.

## Import A New Artifact

Preferred wrapper import:

```powershell
npm --prefix backend/worker-admin run admin:import -- `
  --file .\tools\pdf_parser\fixtures\golden\spring-2026-2026-04-26.json `
  --source-id spring-2026-2026-04-26 `
  --parser-version parser@<commit> `
  --note "Initial Spring 2026 import" `
  --request-id $requestId
```

Use `--raw` when the parser output should be sent directly as the request body with no wrapper object:

```powershell
npm --prefix backend/worker-admin run admin:import -- `
  --file .\artifact.json `
  --raw `
  --request-id $requestId
```

Expected response shape:

- `requestId`
- `import`
- `importRun`
- `version`

Record `version.versionId` from the response. That is the draft to preview and later publish.

## Handle A Failed Import

When the import command exits non-zero:

1. Read `error.code`, `error.message`, and `error.requestId` from the CLI output.
2. If the error is `validation_error`, fix the parser artifact or wrapper fields and rerun the import.
3. If the error indicates the secret is missing or invalid, refresh `TIMETABLE_ADMIN_SECRET` or pass `--secret`.
4. If the server returns `internal_error`, keep the `requestId`, inspect worker logs for the same request, and do not retry blindly until the cause is understood.
5. Review the import history to confirm whether a partial or older run already exists:

```powershell
npm --prefix backend/worker-admin run admin:import-runs -- --request-id $requestId
```

Use `admin:audit-events` if the incident needs publish or rollback history during triage:

```powershell
npm --prefix backend/worker-admin run admin:audit-events -- --request-id $requestId
```

## Review The Preview Before Publish

Fetch the preview for the imported draft:

```powershell
npm --prefix backend/worker-admin run admin:preview -- <versionId> --request-id $requestId
```

Review these fields in the response before publishing:

- `version`
- `currentVersion`
- `importRun`
- `warnings`
- `sections`
- `changes`
- `pushPreview`
- `publishable`

Do not publish until the preview is acceptable. If `publishable` is `false`, stop and resolve the warnings or data issue first. Only use `--ignore-warnings` when the warning set has been explicitly reviewed and accepted.

To see the broader release history while reviewing:

```powershell
npm --prefix backend/worker-admin run admin:versions -- --request-id $requestId
```

## Publish A Reviewed Draft

Standard publish:

```powershell
npm --prefix backend/worker-admin run admin:publish -- `
  <versionId> `
  --note "Publish reviewed Spring 2026 timetable" `
  --request-id $requestId
```

If the preview is acceptable but warnings are intentionally being overridden:

```powershell
npm --prefix backend/worker-admin run admin:publish -- `
  <versionId> `
  --ignore-warnings `
  --note "Approved publish with reviewed warnings" `
  --request-id $requestId
```

Expected response shape:

- `requestId`
- `version`
- `previousVersion`
- `changes`
- `pushPreview`
- `auditEvent`

Confirm that the returned `version` is now the published version and store the `auditEvent.auditEventId` in the change record.

## Roll Back A Published Version

Roll back to a previously known-good version when a publish causes bad data or an unacceptable downstream change:

```powershell
npm --prefix backend/worker-admin run admin:rollback -- `
  <versionId> `
  --note "Rollback after regression review" `
  --request-id $requestId
```

If the rollback must proceed despite acknowledged warnings:

```powershell
npm --prefix backend/worker-admin run admin:rollback -- `
  <versionId> `
  --ignore-warnings `
  --note "Rollback with reviewed warnings" `
  --request-id $requestId
```

Verify the rollback by checking:

- `version`
- `previousVersion`
- `changes`
- `pushPreview`
- `auditEvent`

Then confirm the overall state with:

```powershell
npm --prefix backend/worker-admin run admin:versions -- --request-id $requestId
npm --prefix backend/worker-admin run admin:audit-events -- --request-id $requestId
```

## Command Reference

All commands accept `--base-url`, `--secret`, `--operator-id`, `--request-id`, and `--output pretty|json`.

```powershell
npm --prefix backend/worker-admin run admin -- --help
```

Available commands:

- `import`
- `versions`
- `preview <versionId>`
- `publish <versionId>`
- `rollback <versionId>`
- `import-runs`
- `audit-events`
