# ADR 0001: Rewrite Instead of Refactor

- Status: Accepted
- Date: 2026-04-29
- Deciders: project planning baseline in `docs/`

## Context

The replacement timetable system needs a stable base for:

- PDF-based timetable ingestion
- a modern mobile client
- a low-cost backend that can serve roughly 2,000 users
- repeatable CI and local setup

The legacy implementation does not provide that base.

Observed issues from the project audit:

- the backend mixes parsing, SQL, HTTP response handling, and business rules in tightly coupled PHP files
- the backend contains unsafe query construction
- the mobile app depends on obsolete Flutter-era packages and a legacy API contract
- parser logic is coupled to older timetable formats
- there is no clean bootstrap path or current repo baseline for modern development

## Decision

Build a new codebase and treat the existing systems as reference implementations only.

Specifically:

- do not carry the legacy PHP backend into the new runtime path
- do not attempt a line-by-line Flutter app upgrade from the old mobile app
- preserve product intent, timetable semantics, and migration knowledge through documentation and planned contracts
- start from a new repository structure with explicit boundaries for mobile, backend, parser, contracts, and docs

## Rationale

### Why rewrite

- Architecture debt is structural, not cosmetic.
- Security issues in the old backend are not isolated enough to fix cheaply while keeping behavior trustworthy.
- The mobile app dependency graph is too old to be a safe base for incremental modernization.
- The new parser contract should be driven by the current PDF source, not by legacy spreadsheet assumptions.
- A clean repo and CI baseline are required before parallel workstreams can move safely.

### Why not refactor in place

- Refactoring in place would preserve the old runtime boundaries and hidden coupling.
- The team would spend early sprints untangling obsolete code instead of proving the PDF ingestion and serving model.
- It would make it harder to reason about what is legacy compatibility code versus new product code.

## Consequences

### Positive

- clear subsystem boundaries from the start
- modern toolchains and CI can be introduced without compatibility baggage
- backend and mobile contracts can be designed around the new normalized timetable model
- legacy systems remain available for reference during migration planning

### Negative

- some legacy behavior must be re-discovered and explicitly re-specified
- initial scaffolding cost is higher than making tactical edits to the old repos
- migration requires discipline so useful domain knowledge is not lost

## Guardrails

- use the old repos for reference, not as shared runtime dependencies
- document intentional compatibility decisions as ADRs or sprint notes
- keep Sprint 1 focused on proving the PDF-to-structured-data path before heavy backend or UI implementation

## Follow-Up

- complete Sprint 0 repo scaffolding and bootstrap tooling
- define the normalized parser output in Sprint 1
- create further ADRs only when they materially unblock implementation
