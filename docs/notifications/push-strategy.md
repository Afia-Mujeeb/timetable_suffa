# Sprint 5 Push Strategy

## Goal

Keep notifications cheap and section-scoped.

Local reminders remain the default path. Backend push should only be used for meaningful timetable changes after a publish event.

## Topic Model

- One FCM topic per normalized section code, for example `section.bs-cs-2a`.
- Devices subscribe only to the currently selected section.
- Section changes should unsubscribe the old topic before subscribing to the new one.

## Publish Trigger

The admin publish flow now returns a `changes` payload built from the shared backend diff engine.

Push should only be considered when all of the following are true:

- there is a previous published version
- the section appears in `changes.sections`
- the section has at least one material change

## Material Changes

Treat these change kinds as push-worthy:

- `added`
- `removed`
- `day_changed`
- `time_changed`
- `room_changed`
- `online_changed`
- `instructor_changed`
- `meeting_type_changed`

If notification volume becomes noisy in practice, the first candidate to downgrade is `instructor_changed`.

## Message Rules

Use one short summary per affected section:

- Added meeting: `New class added for BS-CS-2A: Operating Systems on Wednesday 10:00-11:20.`
- Removed meeting: `Class removed for BS-CS-2A: Compiler Construction on Monday 08:30-09:50.`
- Updated meeting: `BS-CS-2A changed: Databases moved from Tuesday 09:30-10:20 to Tuesday 10:30-11:20.`

If multiple changes hit the same section in one publish:

- prefer one combined push per section
- use the first one or two high-signal messages in the body
- direct the user back into the app for the full timetable

## Delivery Guardrails

- Never send per-class upcoming reminders from the backend.
- Never broadcast to all users for a single-section change.
- Skip push entirely when `previousVersion` is `null`; the first publish is a bootstrap event, not a student-facing alert.
- Reuse the backend diff summary rather than rebuilding ad hoc comparison logic in the notification worker.

## Sprint 6 Follow-On

Sprint 6 should operationalize:

- topic subscribe/unsubscribe during section changes
- publish-time fan-out from admin diff results
- preview UI showing which sections would receive a push before publish
