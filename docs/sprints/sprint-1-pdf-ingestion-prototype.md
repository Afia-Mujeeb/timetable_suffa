# Sprint 1: PDF Ingestion Prototype

## Objective

Prove that the target PDF timetable can be parsed into a reliable, normalized, versioned data structure that the rest of the system can trust.

## Why This Sprint Exists

The old system relied on spreadsheet parsing and fragile assumptions. The new system targets a PDF that was verified locally to contain:

- 25 pages
- section labels including `BS-CS-2A` through `BS-CS-8E`
- additional pages `BS-CE-2A`, `BS-CS-MISC`, `BS-CS-MISC 1`, and `BS-CS-MISC 3`
- generated date `4/26/2026`

If parsing is wrong, the backend contract will be wrong, the mobile app will be wrong, and notifications will be wrong. This sprint is the main schema-risk reduction sprint.

## Primary Outcomes

- One command turns the PDF into structured JSON.
- The JSON reflects real timetable entities, not presentation fragments.
- Parser failures are explicit and reviewable.
- Manual validation proves the output is trustworthy enough to continue.

## Scope

### In Scope

- PDF text extraction
- page classification
- section detection
- normalization into structured entities
- parser confidence and validation rules
- sample outputs and fixtures

### Out of Scope

- production backend API
- production database writes
- mobile UI
- push notifications

## Dependencies

- Sprint 0 completed or waived with equivalent setup in place
- Working Python environment
- PDF available locally and committed to test fixture strategy if policy allows

## Parsing Goal

Convert a source page like `BS-CS-2A` into structured meetings with these minimum fields:

- section
- course name
- instructor
- room or online status
- day of week
- start time
- end time
- meeting type if distinguishable, such as lecture or lab
- source page
- source timetable version

## Key Parsing Constraints

- The PDF is formatted for humans, not machines.
- Text extraction order may not match visual order.
- Some course titles wrap across multiple lines.
- Room labels and online markers are mixed with schedule text.
- Labs may span multiple time slots.
- Miscellaneous pages may not follow the same density or section structure.

## Deliverables

- `tools/pdf_parser/` parser prototype
- JSON schema for parsed output
- one or more golden fixture files
- validation script
- parser assumptions document
- manual QA checklist with sampled sections

## Canonical Output Shape

Recommended output layers:

### Raw Extraction Layer

Stores minimally transformed text and page metadata:

- page number
- extracted lines
- parser warnings

### Structured Page Layer

Stores page-level interpretation:

- section label
- source rooms detected
- time grid detected
- days detected
- raw meeting blocks

### Normalized Domain Layer

Stores system-ready entities:

- section
- course
- instructor
- room
- day
- start/end time
- online flag
- source version

The normalized domain layer is what later sprints should consume.

## Detailed Work Breakdown

### 1. Fixture and Version Setup

- create a parser workspace under `tools/pdf_parser`
- create a sample input directory
- create an output directory ignored by version control where appropriate
- assign a version id for the April 26, 2026 file

### 2. Extraction Strategy

Start with text extraction using Python libraries that can be installed cheaply.

Minimum tasks:

- extract all page text
- preserve page boundaries
- inspect line ordering consistency
- detect whether some pages require special handling

If text extraction proves insufficient, be ready to spike coordinate-aware extraction next, but do not over-engineer before confirming the failure mode.

### 3. Section Identification

Detect the page-to-section mapping.

Observed examples already include:

- `BS-CS-2A`
- `BS-CS-2B`
- `BS-CS-4A`
- `BS-CS-6A`
- `BS-CS-8A`
- `BS-CS-MISC`

Rules:

- section label should be extracted from page footer or final lines
- page must fail validation if no section label is found
- special labels like `MISC` must be tagged, not discarded

### 4. Time Grid and Day Detection

Detect:

- day names
- on-campus versus online markers
- slot numbering
- start and end time boundaries

Expected challenges:

- multi-line day labels like `Fri (onlin e)`
- split lines such as `08:30` and `09:10AM`
- need to reconstruct 40-minute slots accurately

### 5. Course Block Reconstruction

Need to stitch multi-line fields into coherent blocks:

- course title lines
- instructor line
- room line

Examples from the PDF show that course names such as `Object Oriented Programming` and `Computer Organization & Assembly Language Lab` are split across lines.

The parser should:

- join wrapped titles
- detect instructor-like lines
- detect room identifiers from a known room vocabulary plus fallback rules

### 6. Meeting Placement

Once the page structure is understood, map course blocks to:

- day
- start slot
- end slot

Labs and long sessions:

- should not rely on legacy hard-coded assumptions
- should infer length from the PDF layout where possible
- may carry a confidence warning if the span cannot be proven cleanly

### 7. Validation Rules

Add rules such as:

- every meeting must have a section
- every meeting must have a course title
- every meeting must map to a valid day
- start time must be earlier than end time
- room values must be either recognized or explicitly marked `unknown`
- duplicate meetings on the same section/day/time should be flagged

### 8. Confidence and Review Support

Not every parse will be fully certain. Add:

- warnings
- confidence score or confidence class
- human-review report for suspicious pages

Examples of suspicious conditions:

- missing section label
- unexpected line count
- time slot count not equal to expected range
- course title without room
- room detected but no instructor

## Manual QA Plan

Manually inspect at least:

- one `2nd semester` page
- one `4th semester` page
- one `6th semester` page
- one `8th semester` page
- one `MISC` page

For each, verify:

- section label
- number of meetings
- at least one lab
- at least one lecture
- one course with wrapped title
- one online-marked day

## Acceptance Criteria

- The parser runs from a documented command.
- The target PDF produces structured JSON for all 25 pages.
- The output passes validation.
- Manual sampling confirms correctness for representative pages.
- Warnings are produced for ambiguous cases instead of silently producing false certainty.

## Non-Functional Requirements

- parser should be deterministic
- parser should be rerunnable without manual edits
- output should be versioned by source file or source date
- tests should run without cloud dependencies

## Risks

### Risk: PDF text order is insufficient

Mitigation:

- isolate extraction from normalization
- add an alternate extractor or coordinate-aware pass only if needed
- preserve raw page text for debugging

### Risk: Misc pages break general rules

Mitigation:

- support page classes such as `regular-section-page` and `misc-page`
- do not force one parsing path if the layout differs materially

### Risk: Lab duration inference is wrong

Mitigation:

- base duration on detected occupied slots
- add warnings for uncertain spans
- include manual QA around labs before approving the sprint

## Exit Criteria

- parser output is good enough to define the backend schema
- ambiguous cases are known and documented
- the team can point to a canonical JSON example and say "this is the contract seed"

## Definition of Done

- parser prototype committed
- fixtures committed
- validation script committed
- assumptions documented
- at least one reviewed output artifact produced and accepted

## Follow-On Inputs to Sprint 2

Sprint 2 should inherit:

- normalized entity shape
- list of parser assumptions
- known special-case sections or pages
- versioning rules for timetable imports
