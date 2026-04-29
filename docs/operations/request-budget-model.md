# Request Budget Model

This document captures the Sprint 8 traffic model for a timetable product that targets roughly `2,000` users while staying inside the Cloudflare Workers free-tier request budget for as long as practical.

## Current Runtime Assumptions

- Workers Free daily request budget: `100,000`
- Public home-screen hot path: one selected-section timetable read at most, not a section-list plus timetable pair
- Local cache TTL: `30` minutes for section metadata and selected timetable payloads
- Public read routes now emit `ETag` and support `If-None-Match`
- Manual home refresh first revalidates sections, then only re-fetches the timetable if the published version changed
- Firebase push delivery still is not live, so version-change traffic is driven by foreground opens and manual refreshes only

## Request Cost Per User Flow

### First install

- Open section picker: `1` request to `GET /v1/sections`
- Confirm section: `1` request to `GET /v1/sections/:sectionCode/timetable`
- Total: `2` requests

### Normal home open

- If the selected timetable cache is younger than `30` minutes: `0` requests
- If the cache is older than `30` minutes and the published version is unchanged: `1` request that should usually end as `304 Not Modified`
- If the cache is older than `30` minutes and the published version changed: `1` request returning the new timetable payload

### Section picker open

- If the cached section list is younger than `30` minutes: `0` requests
- If the cache is older than `30` minutes and the published version is unchanged: `1` conditional request, usually `304`
- If the version changed: `1` request returning the refreshed section list

### Manual refresh from the home screen

- Section metadata revalidation: `1` request
- Timetable request when the refreshed section metadata still points at the same version: `0` additional requests
- Timetable request when the version changed: `1` additional request
- Total: `1` request in the common unchanged case, `2` in the changed-version case

## Daily Traffic Model

The model below is intentionally conservative for a student timetable app:

- registered users: `2,000`
- daily active users: `1,200` typical, `2,000` stress case
- home opens per active user per day: `3`
- section picker opens per active user per day: `0.2`
- manual refreshes per active user per day: `0.3`
- publish days where a refreshed timetable actually changed: `10%` of manual refreshes

## Projected Request Volume

### Typical steady state

For `1,200` daily active users:

- home opens: `1,200 * 3 = 3,600` requests max once caches age out
- section picker opens: `1,200 * 0.2 = 240`
- manual refreshes: `1,200 * 0.3 = 360` section revalidations
- changed-version timetable follow-up on refresh: `360 * 0.1 = 36`
- total: about `4,236` requests/day

### Full 2,000-user stress case

For `2,000` daily active users:

- home opens: `6,000`
- section picker opens: `400`
- manual refreshes: `600`
- changed-version timetable follow-up on refresh: `60`
- total: about `7,060` requests/day

### Deliberately pessimistic case

If all `2,000` users force `6` stale-cache home opens, `1` section-list revalidation, and `1` manual refresh daily:

- home opens: `12,000`
- section list revalidations: `2,000`
- manual refresh section checks: `2,000`
- changed-version timetable follow-up on every refresh: `2,000`
- total: `18,000` requests/day

That is still materially below the `100,000` request/day free-tier limit.

## What Would Break The Budget

The current design stops being free-tier friendly if the client becomes chatty again. Examples:

- Home open performs both section-list and timetable reads every time
- Auto-refresh runs on every foreground transition with no cache TTL
- Manual refresh always re-fetches the full timetable even when the version is unchanged
- Background polling is introduced for timetable changes

At `2,000` users, a `12` to `15` request/day average per active user starts pushing the service toward `24,000` to `30,000` daily requests. That is still below the hard limit, but it removes the safety margin for bursts, release days, and operator activity. The target is to keep the steady-state average below roughly `8` public requests per active user per day.

## Practical Guardrails

- Keep the home screen on the selected-timetable-only hot path.
- Keep section-list refreshes scoped to onboarding, section switching, and explicit manual refresh.
- Treat `304 Not Modified` responses as the normal healthy outcome for unchanged payloads.
- Avoid adding background polling before push delivery exists.
- Use `/metrics` budget projections plus cache `not_modified` counters to confirm the real client behavior matches this model.
