# Parser Assumptions

This document records the actual Sprint 1 assumptions of the implemented parser, not the earlier prototype plan.

## Source Baseline

- Default `version_id`: `spring-2026-2026-04-26`
- Expected source file name: `26 april sp26 CS DEPARTMENT (4days sec wise).pdf`
- Generated date embedded in the reviewed artifact: `2026-04-26`
- Reviewed artifact path: `fixtures/golden/spring-2026-2026-04-26.json`

The source PDF is not committed in this repository. Re-running `parse` requires a local copy of that PDF.

## Extraction Model

The parser is coordinate-aware and uses PyMuPDF for both geometry and text:

- page grid lines come from `page.get_drawings()`
- clipped cell text comes from `page.get_text("words", clip=rect)`
- meeting text is reconstructed from word coordinates rather than whole-page text order

This is the main reason Sprint 1 can recover merged cells and wrapped titles without hard-coded slot lengths.

## Page Structure Assumptions

Each timetable page is assumed to contain:

- `14` unique X grid positions
- `8` unique Y grid positions
- `6` day rows
- `12` timetable slots

If a page does not match `14 x 8`, the parser does not stop immediately. It records `unexpected_grid_shape:x=...:y=...` in that page's warnings and continues. The reviewed April 26 artifact has no page-level grid warnings.

## Section Detection

Section labels are extracted from page text using `^BS-[A-Z]{2,3}-[A-Z0-9 ]+$`.

Observed April 26 sections include:

- regular pages such as `BS-CS-2A`, `BS-CS-4A`, `BS-CS-6A`, `BS-CS-8A`
- special pages `BS-CS-MISC`, `BS-CS-MISC 1`, `BS-CS-MISC 3`
- one non-CS section page `BS-CE-2A`

Any section containing `MISC` is tagged as `page_class: "misc-page"`. All other pages are tagged as `regular-section-page`.

## Day and Time Assumptions

The parser assumes the left-most grid column contains day labels in this order:

- Monday
- Tuesday
- Wednesday
- Thursday
- Friday
- Saturday

Day labels are normalized from the short forms present in the PDF:

- `Mon`, `Tues`, `Wed`, `Thurs`, `Fri`, `Sat`
- split labels such as `Fri (onlin e)` are normalized to `Fri (online)`

Time slots are read from the header row. The parser expects each slot header to provide:

- a slot number
- a start token
- an end token with explicit `AM` or `PM`

When the start token omits `AM` or `PM`, the parser infers it from the slot end token.

## Meeting Block Assumptions

Meeting spans are derived from vertical grid lines that fully cross a given row:

- fully bounded cells become single-slot or multi-slot meetings
- merged cells are detected from missing internal vertical boundaries

Within a detected meeting block, line parsing assumes:

- first line is the room if it matches the known room vocabulary for that page
- last line is the instructor if it matches the instructor heuristic
- all remaining lines form the course title

Meeting type is inferred from the normalized course title:

- contains `lab` -> `lab`
- otherwise -> `lecture`

Online status is derived from the day label, not from room text.

## Room Assumptions

Known rooms are extracted from the page-level room inventory line near the top of each page.

Recognized room forms in Sprint 1 are:

- rooms listed in that page inventory, such as `FF-104`, `CS LAB1`, `ACL`, `FYP`, `CE LAB`
- literal `ONLINE`
- literal `UNKNOWN`

Important consequence: room detection only checks the first line of a meeting block. If a source cell omits a room line entirely, the parser keeps `room: null` and emits a warning instead of inventing a room.

## Confidence Rules

Confidence is derived strictly from meeting warnings:

- `high` / `1.0`: no meeting warnings
- `medium` / `0.75`: warning present, but no `missing_*` warning
- `low` / `0.5`: any warning starting with `missing_`

## April 26 Special Cases

The reviewed artifact shows three non-clean meeting blocks:

1. `BS-CS-2F` page `6`, `Pakistan Studies`
   The cell text ends with `Mahmood`, so the parser infers the instructor from the last line and emits `instructor_inferred_from_last_line`.
2. `BS-CS-6E` page `17`, `Artificial Intelligence Lab`
   The cell text is `CS LAB3`, `Artificial Intelligence Lab`, `Zaryab`, so the parser again emits `instructor_inferred_from_last_line`.
3. `BS-CS-MISC 3` page `25`, `Computer Networks`
   The cell contains no room line. The parser emits `missing_room`, stores `room: null`, and validation reports `normalized_domain/meetings/160: missing room on non-online meeting`.

No duplicate time-window warnings were produced in the reviewed artifact.

## Observed Behaviors Worth Preserving

- Wrapped course titles are rejoined cleanly, including titles like `Computer Organization & Assembly Language` and `CS-Elective I (Knowledge Representation and Reasoning)`.
- Online days can still preserve a physical room string if the PDF cell contains one; the parser keeps both `online: true` and the room value.
- Generated date is taken from the first page that exposes `Timetable generated:4/26/2026` and applied to the whole artifact.
- Validation is schema-first plus domain-rule checks, so the artifact can pass while still surfacing warnings.

## Artifact Locations

- main reviewed artifact: `fixtures/golden/spring-2026-2026-04-26.json`
- schema: `schema/timetable.schema.json`
- manual QA sample results: `docs/manual-qa-report.md`
