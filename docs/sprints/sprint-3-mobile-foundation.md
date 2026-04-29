# Sprint 3: Mobile Foundation

## Objective

Replace the obsolete Flutter client with a modern, maintainable Flutter 3 app that can consume the new backend contract and support later student features cleanly.

## Why This Sprint Exists

The legacy app is not a safe foundation:

- obsolete dependencies
- old notification APIs
- direct storage and network logic mixed into UI files
- backend contract tied to legacy PHP

This sprint creates a real mobile foundation instead of patching around old code.

## Primary Outcomes

- modern Flutter app scaffold
- navigation, state management, and API client baseline
- typed models for backend responses
- clean loading, error, and offline-aware foundation

## Scope

### In Scope

- Flutter 3 app setup
- project structure
- navigation setup
- state management choice
- theming system
- network client
- storage abstraction
- baseline tests

### Out of Scope

- final student UX polish
- timetable feature completeness
- push scheduling logic
- admin features

## Dependencies

- Sprint 2 backend routes and response shapes
- finalized enough API contract to generate or hand-maintain models

## Architectural Goals

- UI code should not know HTTP details.
- screens should not know secure storage details directly.
- API models should be separate from view models where useful.
- offline caching should be possible without restructuring the app later.

## State Management

Pick one and lock it:

- Riverpod is a pragmatic choice for clear dependency wiring and testability.
- Bloc is acceptable if the team already prefers it and will stay disciplined.

Do not spend a sprint debating this after kickoff.

## Proposed App Structure

```text
mobile/app/lib/
  app/
  core/
  features/
    sections/
    timetable/
    settings/
  data/
    api/
    storage/
    models/
  routing/
```

Suggested meanings:

- `app/`: app bootstrap
- `core/`: theme, constants, utilities
- `features/`: screen-oriented modules
- `data/`: repositories, API clients, DTOs
- `routing/`: route config and guards

## Deliverables

- Flutter app scaffold in `mobile/app`
- app theme and design tokens
- navigation system
- API client
- local cache abstraction
- environment configuration approach
- test skeletons

## Detailed Work Breakdown

### 1. Project Bootstrap

- create Flutter 3 project
- enable null safety
- configure lint rules
- add flavor or environment strategy if needed

### 2. App Shell

- app entrypoint
- root widget
- route config
- loading splash behavior appropriate for current data model

Avoid rebuilding the legacy splash/login flow. The new app is section-first.

### 3. Theme System

Build a consistent theme:

- color tokens
- typography
- spacing
- reusable components for cards, chips, and states

The UI should fit timetable-heavy information display instead of generic template styling.

### 4. Network Layer

Add:

- base API client
- JSON decoding
- typed response mapping
- error normalization
- retry policy only where justified

Rules:

- no raw HTTP calls inside widgets
- no scattered endpoint strings across screens

### 5. Local Storage Layer

Plan for:

- selected section
- last fetched timetable
- last seen version id
- notification preferences later

Storage API should be abstracted so local reminder work in Sprint 5 does not require UI rewrites.

### 6. State Management Wiring

Wire:

- selected section state
- section list state
- current timetable state
- loading/error states

### 7. API Contract Consumption

Either:

- generate models from OpenAPI if that flow is stable enough
- or write hand-maintained DTOs with strict tests and clear mapping

Do not add generation just for novelty if it becomes a time sink.

### 8. Test Baseline

Minimum tests:

- app boot smoke test
- one provider or state test
- one API client decoding test
- one screen rendering test with fake data

## UX Standards for This Sprint

- app opens without crashes
- loading states are explicit
- empty states are intentional
- network errors are understandable
- first-run setup path is shorter than the old email-driven flow

## Acceptance Criteria

- app builds on the chosen Flutter version
- app can fetch section list from the backend
- app can fetch a section timetable using the new contract
- local cache abstractions exist
- there is a clean code path for future offline and notification features

## Risks

### Risk: Team copies old UI architecture by habit

Mitigation:

- keep screen, data, and storage layers separate
- reject utility dumping grounds like the old `functions.dart`

### Risk: Generated models create churn

Mitigation:

- only use generation if the backend contract is already stable enough
- otherwise hand-write DTOs and revisit later

### Risk: State management choice delays feature work

Mitigation:

- choose once
- document why
- move on

## Exit Criteria

- mobile app foundation is ready for actual timetable screens
- the app integrates with the real backend, not hardcoded mock flows

## Definition of Done

- project scaffold committed
- state management pattern committed
- API client committed
- cache abstraction committed
- test baseline committed

## Follow-On Inputs to Sprint 4

Sprint 4 should inherit:

- reliable section selection state
- timetable fetch path
- reusable UI shell and theming
