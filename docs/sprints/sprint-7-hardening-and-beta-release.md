# Sprint 7: Hardening and Beta Release

## Objective

Prove the product is stable enough for real users by hardening the parser, backend, and mobile app around error handling, regression protection, and operational readiness.

## Why This Sprint Exists

Feature completeness is not enough. A timetable product fails in practice when:

- imports silently go wrong
- the app crashes on stale or partial data
- endpoints return inconsistent shapes
- releases happen without rollback confidence

This sprint is about reducing that failure surface before broad beta access.

## Primary Outcomes

- regression suite for parser and backend
- mobile stability improvements
- rate limiting and abuse guards
- release checklist and operational readiness artifacts

## Scope

### In Scope

- integration tests
- parser regression fixtures
- crash reporting setup
- API hardening
- release criteria

### Out of Scope

- new major end-user features
- department expansion
- large-scale growth optimization beyond beta needs

## Dependencies

- Sprints 1 through 6 substantially complete

## Deliverables

- integration test suite
- parser regression suite
- crash/error monitoring baseline
- rate limiting strategy
- launch checklist
- beta support runbook

## Detailed Work Breakdown

### 1. Parser Regression Protection

Add test fixtures for:

- current known-good semester PDF
- wrapped course titles
- long lab blocks
- misc pages
- malformed or partial input

Goal:

- parser changes should not unknowingly alter canonical output

### 2. Backend Integration Tests

Cover:

- import to publish flow
- current version read path
- section timetable read path
- error handling for missing sections and invalid requests

### 3. Mobile Stability Pass

Focus on:

- startup sequence
- offline startup
- refresh failure behavior
- notification reschedule behavior
- section switching edge cases

### 4. Crash and Error Monitoring

Set up a free or low-cost error reporting baseline if practical.

At minimum:

- capture unexpected mobile crashes
- capture backend error counts and types

### 5. Rate Limiting and Abuse Handling

Add lightweight safeguards for:

- repeated invalid requests
- accidental burst traffic
- noisy admin endpoints if exposed publicly

### 6. Release Readiness

Create a launch checklist covering:

- environment setup complete
- parser verified on current production timetable
- publish/rollback tested
- app version tested on target Android versions
- backend metrics visible

## Acceptance Criteria

- core flows have automated regression coverage
- known error paths are handled intentionally
- beta release checklist exists and is usable
- operational responders know how to detect and react to common failures

## Testing Plan

Required:

- parser regression tests
- backend integration tests
- mobile widget or integration coverage for core flows

Manual beta readiness checks:

- first install
- section change
- offline open
- refresh after version update
- reminder behavior

## Risks

### Risk: too much time goes into tooling instead of real failure paths

Mitigation:

- prioritize tests around import, publish, fetch, cache, and notifications
- avoid vanity coverage

### Risk: crash reporting adds maintenance cost

Mitigation:

- choose the smallest viable monitoring footprint
- only add what the team will actually monitor

### Risk: rate limits break legitimate use during beta

Mitigation:

- set conservative, observable thresholds
- log rate-limited events clearly

## Exit Criteria

- product is safe enough for 100 to 300 beta users
- common failure modes are covered by tests or runbooks

## Definition of Done

- regression suites committed
- crash/error monitoring baseline committed
- release checklist committed
- beta runbook committed

## Follow-On Inputs to Sprint 8

Sprint 8 should inherit:

- actual beta behavior data
- observed hot paths
- known operational weak points
