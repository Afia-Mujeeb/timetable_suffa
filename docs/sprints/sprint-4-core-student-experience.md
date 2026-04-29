# Sprint 4: Core Student Experience

## Objective

Ship the minimum product a student would actually install and keep using: select a section, view the timetable, and reliably check current and upcoming classes even when connectivity is poor.

## Why This Sprint Exists

The platform is only valuable if the core timetable experience is fast, clear, and dependable. This sprint converts the new backend and app foundation into a useful student-facing product.

## Primary Outcomes

- section-first onboarding
- timetable screen with clear structure
- today/next class experience
- offline fallback for last successful sync

## Scope

### In Scope

- section selection and persistence
- timetable viewing
- daily summary and next class view
- offline cached read path
- sync and refresh affordances

### Out of Scope

- change push notifications
- admin features
- analytics-heavy experimentation
- social or friend features from the old app concept

## Dependencies

- Sprint 2 backend endpoints
- Sprint 3 mobile foundation

## Product Direction

Prefer section-based usage over email-identity-based usage.

Reasons:

- the target PDF is section-driven
- onboarding becomes faster
- backend complexity stays lower
- privacy surface stays smaller
- students usually care first about their own section timetable

If later needed, account features can be layered on top without making them the foundation.

## User Flows

### First-Run Flow

1. Open app
2. Choose section
3. Download timetable
4. Land on timetable home

### Returning User Flow

1. Open app
2. See today or next class
3. Navigate to full timetable if needed

### Offline Flow

1. Open app without connectivity
2. Load last cached timetable
3. Show stale-data indicator if version freshness is unknown

## Deliverables

- section picker screen
- timetable home screen
- full week timetable screen
- today schedule card or list
- next class indicator
- refresh and stale-state messaging

## Detailed Work Breakdown

### 1. Section Selection

Build:

- searchable section list if list size justifies it
- section persistence locally
- change-section affordance in settings or header

Validation:

- impossible to enter the main app without a selected section
- section can be changed without reinstalling

### 2. Timetable Presentation

Design around the real data:

- 40-minute slots
- multiple weekdays
- on-campus versus online indicators
- labs with longer spans

Do not force a generic calendar UI that hides timetable structure.

### 3. Today View

Show:

- all classes for today in chronological order
- current class if within active range
- next class if one exists
- no-classes state if applicable

### 4. Sync and Cache Behavior

Implement:

- last fetched timetable cache
- pull-to-refresh or explicit refresh
- current version id tracking
- stale-data marker if backend is unreachable

### 5. Error and Empty States

Cases to handle:

- no connectivity on first run
- no connectivity after cache exists
- section timetable not found
- backend returns unexpected error

### 6. UX Refinement

Make timetable reading fast:

- clearly label day and time
- visually distinguish labs and online classes
- keep dense information readable on small screens

## Acceptance Criteria

- a user can install the app and choose a section in under a minute
- the timetable loads from the backend
- the last timetable remains viewable offline
- today and next class information is accurate
- changing section updates the cached and displayed data correctly

## Testing Plan

Required tests:

- section selection persistence test
- timetable rendering test with sample schedule
- offline cache test
- today/next class calculation test

Manual QA:

- test with at least one section from each major semester group
- test empty or no-class day
- test app launch with no network and existing cache

## Risks

### Risk: timetable UI becomes visually dense and unreadable

Mitigation:

- design from real fixture data
- prefer clarity over decorative complexity
- test on smaller Android screens early

### Risk: stale cache confuses users

Mitigation:

- show last updated timestamp
- show version label when available
- distinguish refresh failure from no-data state

### Risk: time calculations drift because of local timezone assumptions

Mitigation:

- keep timetable times as local academic schedule times
- avoid unnecessary timezone conversions for fixed class schedules

## Exit Criteria

- the app is useful without any future sprint work
- a student can rely on it as a timetable viewer

## Definition of Done

- section onboarding committed
- timetable screens committed
- offline cache path committed
- tested today/next class logic committed

## Follow-On Inputs to Sprint 5

Sprint 5 should inherit:

- persisted section data
- reliable schedule model on-device
- stable notion of current timetable version
