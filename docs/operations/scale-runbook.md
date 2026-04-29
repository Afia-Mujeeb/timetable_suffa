# Scale Runbook

This runbook covers the Sprint 8 free-tier scaling posture for the public Worker API and the admin Worker.

## Primary Checks

Public API:

- `GET /metrics`
- worker logs for `request.completed`, `request.failed`, and `request.rate_limited`

Admin API:

- `GET /metrics`
- worker logs for `import.completed`, `publish.completed`, and `rollback.completed`

## What To Watch

Public Worker `/metrics` now exposes:

- `requests.total`
- `requests.byRoute`
- `requests.latencyMs.p50`
- `requests.latencyMs.p95`
- `requests.latencyMs.p99`
- `errors.total`
- `rateLimits.total`
- `budget.projectedRequestsPerDay`
- `budget.utilizationPercent`
- `budget.workersFreeTierState`
- `domainEvents.byName.cache.not_modified.*`

Admin Worker `/metrics` now exposes:

- the same request, error, rate-limit, and budget fields
- `domainEvents.byName.import.succeeded`
- `domainEvents.byName.import.failed`
- `domainEvents.byName.publish.succeeded`
- `domainEvents.byName.publish.notifications_planned`
- `domainEvents.byName.publish.notification_sections`
- `domainEvents.byName.rollback.succeeded`
- `domainEvents.byName.rollback.notifications_planned`
- `domainEvents.byName.rollback.notification_sections`

## Normal Healthy Shape

- `budget.workersFreeTierState` stays `ok`
- public `requests.byRoute` is dominated by `GET /v1/sections/:sectionCode/timetable`
- `cache.not_modified.section_timetable` grows steadily after a stable publish
- p95 stays comfortably below `250 ms`
- p99 stays comfortably below `500 ms`
- public `429` responses are rare and mostly abuse-driven, not normal student traffic
- admin import success count rises only when operators intentionally publish new artifacts

## Thresholds

Treat these as explicit escalation points:

- `budget.utilizationPercent >= 70`: investigate within the same day
- `budget.utilizationPercent >= 80`: prepare to move off free-tier assumptions
- public p95 above `250 ms` for `15` minutes: inspect D1/query pressure
- public p99 above `500 ms` for `15` minutes: inspect logs and recent publish activity
- cache `not_modified` counters unexpectedly flat after a stable release: check whether clients stopped sending validators
- sustained public `429` increase on read routes: inspect for abusive clients or accidental refresh loops

## Fast Triage Steps

### If request budget is climbing too fast

1. Check whether `GET /v1/sections` volume rose unexpectedly.
2. Check whether `GET /v1/sections/:sectionCode/timetable` volume rose without matching `cache.not_modified.section_timetable`.
3. Confirm the current mobile build still ships with the Sprint 8 cache behavior.
4. Ask beta operators to pause manual test churn and section-switch loops.
5. If needed, reduce beta admissions until the cause is understood.

### If latency jumps after a publish

1. Check whether a release window triggered unusual student refresh activity.
2. Confirm the public Worker still returns `ETag` on read routes.
3. Confirm the admin Worker completed the publish cleanly and did not leave operators retrying commands.
4. Sample a few section timetable reads directly and verify they still serve the current version cleanly.

### If admin metrics show import failures or unexpected notification planning spikes

1. Review `GET /v1/import-runs` and `GET /v1/audit-events`.
2. Confirm the operator is not repeatedly retrying a broken artifact.
3. Inspect the publish preview `pushPreview` result before any further publish or rollback action.

## Temporary Traffic Reduction Options

- Pause new beta cohort invites.
- Ask testers to avoid repeated manual refreshes while the issue is open.
- Keep users on the selected timetable screen instead of repeated section switching.
- Delay non-essential publish tests until metrics stabilize.

## Upgrade Trigger

Move beyond the free-tier-first operating model when one of these becomes true:

- `budget.utilizationPercent` stays above `80` for multiple days
- real usage requires background polling or other always-on traffic
- D1 latency remains elevated after client behavior is confirmed healthy
- operator workflows need more scheduled or repeated automation than the current free setup comfortably supports
