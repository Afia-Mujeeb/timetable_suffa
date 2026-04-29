# Sprint 5: Notifications and Change Detection

## Objective

Restore the notifier value of the original project while keeping the new architecture cheap, maintainable, and decoupled from brittle backend behavior.

## Why This Sprint Exists

The old app's value proposition was not just viewing the timetable. It was reminding students about classes. The rewrite should preserve that value, but without building a backend that has to push every class reminder to every user.

## Primary Outcomes

- local reminders generated from on-device schedule data
- timetable diff logic between published versions
- optional push path for urgent changes only

## Scope

### In Scope

- local notification scheduling
- notification preference model
- timetable version comparison
- selective push strategy for major changes

### Out of Scope

- mass marketing notifications
- complex segmentation
- server-driven per-class reminder schedule for all users

## Dependencies

- Sprint 4 must provide cached schedule data and selected section
- Sprint 6 will later operationalize admin publishing, but version comparison logic starts here

## Design Principles

- default reminders should be local, not server-pushed
- server push should be reserved for meaningful timetable changes
- notification identifiers must be stable across refreshes
- rescheduling should be idempotent

## Reminder Model

For each meeting, derive:

- stable meeting id
- day of week
- class start time
- reminder lead time
- enabled or disabled state

Suggested defaults:

- reminder enabled by default
- lead time configurable, such as 10 or 15 minutes
- quiet-hours support optional if cheap enough

## Change Detection Model

Compare published versions at meeting level.

Detect:

- new meeting added
- meeting removed
- time changed
- room changed
- online status changed
- instructor changed if considered user-relevant

Do not notify for meaningless internal representation changes.

## Deliverables

- local notification scheduler
- notification settings model
- version diff engine
- optional FCM topic strategy design
- change summary messaging rules

## Detailed Work Breakdown

### 1. Local Notification Integration

Integrate current Flutter notification libraries that are supported on modern Flutter.

Implement:

- permission request flow
- schedule notifications from cached timetable
- cancel and rebuild schedules safely

Important:

- avoid duplicate notifications after refresh
- ensure schedule refresh updates existing reminders

### 2. Stable Meeting Identity

Construct a stable key from data such as:

- section
- course
- day
- start time
- end time
- version-independent meeting fingerprint if possible

This key is critical for both diffing and notification replacement.

### 3. Preferences

At minimum support:

- notifications enabled or disabled
- lead time selection

Optional if cheap:

- only weekdays with classes
- quiet hours
- skip labs

### 4. Diff Engine

Build a utility that compares two published timetable versions for a section.

Output should classify:

- additions
- removals
- modifications

Each change should be expressible as user-facing copy later.

### 5. Push Strategy

If push is implemented, keep it minimal:

- subscribe devices to section topics
- send pushes only when a published version materially changes a section schedule

Do not use backend push for every upcoming class. That destroys the free-tier strategy.

### 6. Rescheduling Logic

When timetable data changes:

- diff old and new schedules
- cancel obsolete notifications
- update changed ones
- preserve unchanged identifiers where possible

## Acceptance Criteria

- app can schedule class reminders from the cached timetable
- refresh does not create duplicate reminders
- toggling notifications works reliably
- version diff identifies meaningful schedule changes
- optional push path, if included, is section-scoped and low-volume

## Testing Plan

Required tests:

- diff engine unit tests
- stable identifier tests
- notification scheduling tests where feasible
- preference persistence tests

Manual QA:

- select section and enable reminders
- refresh same timetable and confirm no duplicates
- load changed timetable fixture and confirm reschedule behavior

## Risks

### Risk: notification libraries behave differently across Android versions

Mitigation:

- keep library choice current
- test on at least two Android API levels if possible
- document exact permission flows

### Risk: push becomes an infrastructure trap

Mitigation:

- make push optional and narrow
- local reminders remain the primary feature

### Risk: diff engine produces noisy alerts

Mitigation:

- define meaningful change categories
- ignore non-user-facing internal deltas

## Exit Criteria

- the app can remind students about classes without heavy backend work
- timetable changes can be detected accurately enough for selective alerts

## Definition of Done

- local scheduling path committed
- preferences committed
- diff engine committed
- change scenarios tested

## Follow-On Inputs to Sprint 6

Sprint 6 should inherit:

- definition of a material timetable change
- notification-sensitive versioning behavior
