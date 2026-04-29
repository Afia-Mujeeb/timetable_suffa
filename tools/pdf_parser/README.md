# PDF Parser

Sprint 1 delivers a coordinate-aware parser for the Spring 2026 CS department timetable PDF generated on `2026-04-26`.

The parser reads timetable grid geometry from the PDF, clips text per cell, and emits a versioned JSON artifact with:

- `raw_extraction.pages`
- `structured_pages`
- `normalized_domain.meetings`
- `validation`

The current default source version is `spring-2026-2026-04-26`.

## Commands

Run all commands from `tools/pdf_parser`.

```powershell
python -m pip install -e .[dev]
python -m ruff check .
python -m pytest
python -m pdf_parser parse --input "C:\Users\PC\Downloads\26 april sp26 CS DEPARTMENT (4days sec wise).pdf" --output fixtures/golden/spring-2026-2026-04-26.json
python -m pdf_parser validate --input fixtures/golden/spring-2026-2026-04-26.json
```

Notes:

- Use `python -m pdf_parser ...` instead of `pdf-parser ...` unless your user scripts directory is on `PATH`.
- The April 26 source PDF is not committed in this repository. `parse` requires a local copy of `26 april sp26 CS DEPARTMENT (4days sec wise).pdf`.
- The locally verified source PDF path is also documented in `sample_inputs/README.md`.
- Omitting `--output` writes the artifact JSON to stdout.

## Reference Artifact

The reviewed Sprint 1 artifact is `fixtures/golden/spring-2026-2026-04-26.json`.

It was produced from:

- source file: `26 april sp26 CS DEPARTMENT (4days sec wise).pdf`
- generated date: `2026-04-26`
- page count: `25`
- section count: `25`
- normalized meetings: `162`
- validation status: `passed`
- validation warnings: `1` (`normalized_domain/meetings/160: missing room on non-online meeting`)

## Artifact and Doc Locations

- sample input notes: `sample_inputs/README.md`
- golden artifact: `fixtures/golden/spring-2026-2026-04-26.json`
- schema: `schema/timetable.schema.json`
- parser assumptions: `docs/parser-assumptions.md`
- manual QA report: `docs/manual-qa-report.md`

## What Sprint 1 Assumes

The parser currently assumes the April 26 source keeps the same overall page template:

- one section per page
- a six-row day grid from Monday through Saturday
- twelve timetable slots in the header row
- drawable vertical boundaries that define merged multi-slot cells
- a recognizable section label such as `BS-CS-2A` or `BS-CS-MISC 3`

Source-specific details and edge cases are documented in `docs/parser-assumptions.md`.
