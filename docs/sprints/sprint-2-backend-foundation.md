# Sprint 2: Backend Foundation

## Objective

Build the first production-grade backend slice around the parsed timetable data: schema, import path, read API, and operational basics.

## Why This Sprint Exists

Sprint 1 proves the data can be parsed. Sprint 2 turns that proof into an actual service contract the mobile app can consume.

This sprint must avoid repeating the old backend mistakes:

- parsing inside request handlers
- mixing persistence, business logic, and HTTP logic in one file
- unsafe query construction
- no versioned contract

## Primary Outcomes

- normalized database schema exists
- timetable versions can be imported cleanly
- read endpoints are defined and documented
- responses are stable enough for the mobile app foundation

## Scope

### In Scope

- D1 schema and migrations
- backend service structure
- import pipeline from parsed JSON
- read API for section lists and section schedules
- basic observability and error handling
- OpenAPI or equivalent contract definition

### Out of Scope

- advanced auth
- admin UI
- push notification fan-out
- high-complexity personalization

## Dependencies

- Sprint 1 normalized output must exist
- parser output shape must be stable enough to model

## Service Responsibilities

The backend in this sprint is responsible for:

- serving the list of available sections
- serving timetable version metadata
- serving a timetable for a selected section
- exposing health and readiness endpoints
- loading parsed timetable versions into D1

The backend is not responsible for:

- parsing the PDF on live requests
- building personalized schedules from free-text emails
- scheduling local notifications for devices

## Proposed Modules

```text
backend/worker-api/
  src/
    routes/
    services/
    repositories/
    db/
    schemas/
    lib/
```

Recommended boundaries:

- `routes`: HTTP input/output only
- `services`: business logic
- `repositories`: D1 queries
- `schemas`: request/response validation
- `db`: migration and connection helpers

## Data Model

Minimum tables:

- `timetable_versions`
- `sections`
- `courses`
- `instructors`
- `rooms`
- `class_meetings`

Optional in this sprint if cheap:

- `meeting_tags`
- `import_runs`

### Table Intent

`timetable_versions`

- source identifier
- source date
- publish status
- checksum or file hash
- created timestamp

`sections`

- normalized section code
- display name
- active flag

`courses`

- canonical course name
- normalized slug
- optional course type

`instructors`

- display name
- normalized slug

`rooms`

- room label
- online flag

`class_meetings`

- version id
- section id
- course id
- instructor id
- room id
- day of week
- start time
- end time
- source page
- source confidence or warning marker

## API Endpoints

Minimum endpoints:

- `GET /health`
- `GET /v1/versions/current`
- `GET /v1/sections`
- `GET /v1/sections/:sectionCode/timetable`

Optional but useful:

- `GET /v1/versions`
- `GET /v1/sections/:sectionCode`

### Response Design Principles

- responses are JSON only
- stable field names
- no raw parser internals leaked unless deliberate
- include timetable version metadata in schedule responses
- return structured errors with machine-readable codes

## Import Flow

Recommended import path:

1. parser produces canonical JSON
2. import command validates the file against schema
3. import command writes a new `timetable_version`
4. import command upserts supporting entities
5. import command inserts normalized meetings
6. version remains unpublished until validation passes
7. publish step marks the new version current

This keeps release and ingestion separate.

## Detailed Work Breakdown

### 1. Worker Initialization

- scaffold Worker app
- define environment bindings
- configure local and deployed environments
- add route registration

### 2. Validation Layer

- validate route params
- validate import file shape
- validate DB-bound payloads before write

Never trust parser output blindly just because it came from an internal tool.

### 3. D1 Schema and Migrations

- create initial schema
- add indexes for expected access patterns
- document migration order

Expected hot path:

- fetch timetable by section code and current version

Index accordingly.

### 4. Repository Layer

- create section repository
- create timetable version repository
- create class meeting repository

Rules:

- no SQL string interpolation
- parameterize all queries
- centralize query logic

### 5. Service Layer

- section listing service
- current version service
- section timetable service
- import/publish service

Service layer should own:

- joining entities into API shape
- hiding internal normalization complexity from routes

### 6. Error Model

Define error categories:

- validation error
- not found
- import conflict
- internal error
- unavailable dependency

Each error response should include:

- stable code
- human-readable message
- request correlation id if available

### 7. Observability Baseline

Add:

- structured logs
- import summary logs
- request duration logs
- failure logs with context

Do not add expensive telemetry vendors in this sprint unless already free and trivial.

### 8. OpenAPI Contract

Document:

- routes
- params
- success response shape
- error response shape

This contract feeds Sprint 3 typed client work.

## Acceptance Criteria

- parsed JSON can be imported successfully
- current timetable version can be published
- section list endpoint works
- section timetable endpoint works
- route validation rejects malformed input
- API contract is documented and stable enough for client integration

## Testing Plan

Required tests:

- migration smoke test
- repository test for section timetable query
- service test for response assembly
- route test for `404` and validation failures
- import test from fixture JSON

Manual checks:

- fetch known section such as `BS-CS-2A`
- verify version metadata returned
- verify meetings are correctly ordered

## Risks

### Risk: Over-modeling before the parser fully stabilizes

Mitigation:

- keep schema normalized but not ornamental
- support additive changes later
- avoid speculative entities with no demonstrated value

### Risk: Query count per request becomes too high for D1 free limits

Mitigation:

- design schedule endpoint to execute in a small fixed number of queries
- prefer join-based reads over N+1 lookups
- precompute simple derived fields if necessary

### Risk: Import and publish become the same unsafe step

Mitigation:

- separate import from publish
- store version state explicitly
- allow rollback to previous version in a later sprint

## Exit Criteria

- backend serves real parsed timetable data
- contract is ready for mobile integration
- import path is reliable enough that the team trusts the data source

## Definition of Done

- migrations committed
- API routes committed
- import command committed
- test suite for core paths committed
- contract documentation committed

## Follow-On Inputs to Sprint 3

Sprint 3 should inherit:

- stable route list
- sample responses
- error contract
- known performance characteristics for mobile fetches
