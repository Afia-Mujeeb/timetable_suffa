# Sprint 6: Admin and Operations

## Objective

Make timetable updates safe, reviewable, and repeatable so a new semester or revised PDF can be imported and published without code changes or manual database surgery.

## Why This Sprint Exists

Without an operational workflow, the system will regress into the same fragility as the old project. The parser and backend must be wrapped in a controlled import and publish process.

## Primary Outcomes

- admin import workflow exists
- publish and rollback are explicit actions
- version history is visible
- imports are auditable

## Scope

### In Scope

- import workflow choice
- preview and validation before publish
- publish controls
- rollback path
- audit log

### Out of Scope

- enterprise-grade IAM
- complex role management
- non-CS department expansion unless it falls out naturally

## Dependencies

- Sprint 1 parser
- Sprint 2 importable backend schema
- Sprint 5 change detection rules if notifications will react to publish events

## Workflow Options

Choose one primary path in this sprint:

### Option A: CI-Driven Import

- admin adds PDF or parser output to repo or upload storage
- CI runs parser and validation
- admin reviews output
- publish step promotes the version

Advantages:

- cheap
- traceable
- works with public GitHub Actions

Tradeoffs:

- less friendly for non-technical admins

### Option B: Admin Upload Endpoint

- admin uploads PDF through a protected interface or endpoint
- backend stores artifact and runs import validation
- admin publishes after preview

Advantages:

- operationally convenient later

Tradeoffs:

- more implementation and security work

Recommendation:

- start with CI-driven import unless there is an immediate need for non-technical self-service

## Deliverables

- chosen import workflow implemented
- version preview capability
- publish command or endpoint
- rollback command or endpoint
- import audit log

## Detailed Work Breakdown

### 1. Import Run Tracking

Record:

- source file name or source id
- parser version
- import start and end timestamps
- operator or triggering identity
- success or failure
- warnings

### 2. Preview Before Publish

Support a review state where the imported version can be inspected without becoming live.

Preview should expose:

- version metadata
- section counts
- meeting counts
- warnings
- diff versus current live version

### 3. Publish Action

Publishing should:

- mark one version current
- keep previous versions retained
- optionally trigger downstream notification workflow

Publishing should not:

- destroy previous data
- skip validation

### 4. Rollback

Rollback should:

- be explicit
- repoint current version to a previous known-good one
- preserve audit trail

### 5. Auditability

Need traceability for:

- who imported
- who published
- what changed
- whether warnings were ignored

### 6. Operational Docs

Write runbooks for:

- importing a new timetable
- handling failed parse
- publishing a version
- rolling back a bad version

## Acceptance Criteria

- a new timetable can be imported without editing application code
- preview data can be reviewed before publish
- publish is explicit
- rollback to previous version works
- audit history exists for imports and publishes

## Testing Plan

Required tests:

- import state transition tests
- publish state transition tests
- rollback tests
- audit log creation tests

Manual QA:

- import a valid timetable fixture
- import a deliberately malformed fixture
- publish the valid import
- rollback after publish

## Risks

### Risk: admin flow becomes under-specified and dangerous

Mitigation:

- require preview
- require explicit publish step
- never auto-promote on import success alone

### Risk: CI-only flow becomes too technical for operators

Mitigation:

- document exact steps
- keep logs and outputs readable
- defer UI automation only if truly needed later

### Risk: rollback does not trigger cache and notification consistency

Mitigation:

- define whether rollback is just pointer movement or also downstream event emission
- test both publish and rollback paths with version metadata consumers

## Exit Criteria

- timetable updates are an operational process, not a coding event

## Definition of Done

- import workflow committed
- publish and rollback committed
- runbooks committed
- audit paths tested

## Follow-On Inputs to Sprint 7

Sprint 7 should inherit:

- realistic operator workflow
- stable lifecycle for timetable versions
