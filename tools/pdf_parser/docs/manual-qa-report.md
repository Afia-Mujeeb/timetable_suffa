# Manual QA Report

Sprint 1 manual QA was performed against `fixtures/golden/spring-2026-2026-04-26.json`, the checked-in parse artifact for `26 april sp26 CS DEPARTMENT (4days sec wise).pdf`.

## Command Checks

Verified from `tools/pdf_parser`:

```powershell
python -m pip install -e .[dev]
python -m pytest
python -m ruff check .
python -m pdf_parser validate --input fixtures/golden/spring-2026-2026-04-26.json
```

Observed results:

- `pytest`: `4 passed`
- `ruff`: `All checks passed!`
- `validate`: `Validation passed.` with one warning for a missing room on page `25`

## Sampled Pages

| Semester bucket | Source page | Section        | What was checked                                                                                                                                          | Result                     |
| --------------- | ----------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| 2nd             | 1           | `BS-CS-2A`     | Section label, `8` meetings, lecture blocks, lab blocks, online day labels, wrapped title reconstruction (`Object Oriented Programming Lab`)              | Pass                       |
| 4th             | 8           | `BS-CS-4A`     | Section label, `9` meetings, multiple labs, lecture blocks, wrapped title reconstruction (`Computer Organization & Assembly Language`), online day labels | Pass                       |
| 6th             | 13          | `BS-CS-6A`     | Section label, `7` meetings, lab and lecture blocks, wrapped elective titles, Thursday online row                                                         | Pass                       |
| 8th             | 18          | `BS-CS-8A`     | Section label, `4` meetings, wrapped title reconstruction (`University Elective IV (Entrepreneurship)`), Thursday and Friday online meetings              | Pass                       |
| MISC            | 25          | `BS-CS-MISC 3` | Section label, `2` meetings, `misc-page` handling, missing-room warning propagation on `Computer Networks`                                                | Pass with expected warning |

## Notes Per Sample

### `BS-CS-2A` (`page 1`)

- Meetings extracted on `Mon`, `Tues`, and `Wed` only, which matches the artifact's non-empty cells.
- Both labs were preserved with correct spans:
  - `Object Oriented Programming Lab`, slots `10-12`
  - `Digital Logic Design Lab`, slots `1-3`
- Day labels were normalized to include `Thurs (online)` and `Fri (online)` even though those rows were empty.

### `BS-CS-4A` (`page 8`)

- The parser preserved five lecture blocks and four lab blocks.
- Wrapped titles were reconstructed correctly for both lecture and lab variants of `Computer Organization & Assembly Language`.
- Lab rooms remained intact across multiple room types: `CE LAB`, `CS LAB1`, and `CS LAB3`.

### `BS-CS-6A` (`page 13`)

- The page mixes labs, lectures, and long wrapped elective names without warnings.
- `CS-Elective I (Knowledge Representation and Reasoning)` and `Data Communication and Computer Networks Lab` were reconstructed cleanly.
- The Thursday online row produced `Technical and Business Writing` with `online: true`.

### `BS-CS-8A` (`page 18`)

- This sampled 8th-semester page contains lectures only; no missing lab was inferred.
- `Islamic Studies` on Thursday and `University Elective IV (Entrepreneurship)` on Friday were correctly marked `online: true`.
- All four meetings were `high` confidence with no per-meeting warnings.

### `BS-CS-MISC 3` (`page 25`)

- `page_class` is `misc-page`, but the same grid parser still extracted both meetings correctly.
- `Computer Networks` contains only course title and instructor text, so the parser left `room: null`, assigned `low` confidence, and preserved `missing_room`.
- `Data Structures` parsed cleanly on Saturday with `FF-111` and `high` confidence.

## QA Conclusion

The checked-in Sprint 1 artifact is consistent with the current coordinate-aware parser:

- all `25` pages parsed
- all sampled semester buckets parsed with correct section labels and meeting counts
- wrapped titles and multi-slot spans were preserved in the sampled pages
- the only artifact-level validation warning is the expected missing-room case on `BS-CS-MISC 3` page `25`
