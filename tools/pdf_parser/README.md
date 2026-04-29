# PDF Parser

This workspace hosts the offline parser/import pipeline. Sprint 0 only provides the package shell, test harness, and CLI entrypoint so later parser work lands in an isolated Python environment.

## Commands

```bash
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e .[dev]
ruff check .
pytest
python -m pdf_parser parse --input path/to/timetable.pdf
```
