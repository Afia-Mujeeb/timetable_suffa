# Beta Support Runbook

This runbook covers common Sprint 7 beta failures for the parser, backend, and mobile app.

## Required Inputs During Triage

- exact time of incident
- environment
- request ID or correlation ID when available
- affected section code and timetable version
- whether the issue is isolated or widespread
- whether the problem started after a publish or rollback

## First Response Rules

1. Preserve the current published version ID before making changes.
2. Do not re-import or re-publish blindly.
3. Prefer evidence from metrics, logs, preview output, and cached mobile state over guesswork.
4. If a publish likely caused the issue, prepare rollback data immediately while triage continues.

## Incident: Import Fails

Check:

- admin CLI output
- `requestId`
- latest `import-runs`
- latest `audit-events`

Actions:

1. If the error is parser or payload validation, fix the artifact and re-run the import.
2. If the error is duplicate version or checksum conflict, verify whether the intended artifact was already imported.
3. If the error is backend `internal_error`, inspect Worker logs with the matching `requestId` before retrying.
4. If the import partially failed, confirm the failed run is visible in `import-runs` before taking the next step.

## Incident: Publish Looks Wrong In Preview

Check:

- `warnings`
- `changes.summary`
- section-level changes
- `pushPreview`

Actions:

1. Stop the release if warnings or diffs are not understood.
2. Compare the candidate artifact against the last known-good version.
3. Re-run parser validation if the preview suggests structural drift.
4. Do not use `--ignore-warnings` unless the warning set is understood and documented.

## Incident: Users See Stale Or Missing Data

Check:

- `GET /v1/versions/current`
- `GET /v1/sections`
- one affected `GET /v1/sections/{sectionCode}/timetable`
- Worker metrics for `5xx`, `4xx`, and `429`

Actions:

1. Confirm the intended version is still published.
2. If the public API is healthy but data is wrong, compare the live section output with the publish preview.
3. If the public API is returning dependency failures, inspect database binding health before changing versions.
4. If the issue began immediately after publish and the data is wrong, roll back to the previous known-good version.

## Incident: Elevated `429` Rate Limits

Check:

- Worker metrics for rate-limited paths
- request patterns by path
- whether traffic is user-driven, scripted, or malformed

Actions:

1. Confirm whether the traffic is legitimate beta usage or abuse/noise.
2. If abuse is isolated, keep the current limits and continue observing.
3. If legitimate traffic is being blocked, raise thresholds conservatively and keep logging enabled.
4. If only invalid requests are spiking, inspect clients for malformed section codes or repeated bad paths.

## Incident: Mobile App Crash Or Startup Failure

Check:

- crash-reporting output captured by the app
- affected platform and OS version
- whether the issue happens on first install, offline startup, refresh, or section change

Actions:

1. Separate startup crashes from handled network failures.
2. If the crash is tied to a new release, pause rollout and gather the last successful app build and backend version.
3. If the crash happens only on first run, reproduce with clean local storage.
4. If the crash happens after data refresh, compare the returned timetable payload with a working cached payload.

## Incident: Reminder Or Notification Drift

Check:

- selected section code
- latest cached timetable version
- current reminder preferences
- whether reminders were rescheduled after refresh or section change

Actions:

1. Reproduce with one selected section and a known timetable payload.
2. Confirm the stale-cache path does not duplicate reminders.
3. If reminder drift follows a publish, compare old and new timetable meetings for changed slots.
4. If the device state is corrupted, clear the selected section and reselect it to force a clean resync.

## Rollback Decision

Roll back when:

- published data is incorrect for real users
- backend error rates stay elevated after initial investigation
- the mobile app is crashing on normal beta flows
- operators cannot complete a safe forward fix inside the release window

Do not roll back when:

- the issue is isolated to one malformed request
- metrics show noise without user impact
- the issue is confirmed to be local device state with a safe workaround

## After Action

1. Record version IDs, request IDs, timestamps, and operator actions.
2. Add a regression test or runbook update for the failure mode before the next beta release.
3. Update `memory.md` after the fix so the current operational state stays accurate.
