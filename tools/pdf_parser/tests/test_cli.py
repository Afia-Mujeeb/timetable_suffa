from __future__ import annotations

from pathlib import Path

import pytest

from pdf_parser.cli import main
from pdf_parser.parser import DEFAULT_VERSION_ID, parse_pdf
from pdf_parser.validation import load_artifact, validate_payload
from tests.helpers import MeetingBlockSpec, build_synthetic_timetable_pdf

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GOLDEN_ARTIFACT = PROJECT_ROOT / "fixtures" / "golden" / f"{DEFAULT_VERSION_ID}.json"


def test_golden_artifact_passes_validation() -> None:
    payload = load_artifact(GOLDEN_ARTIFACT)

    errors, warnings = validate_payload(payload)

    assert errors == []
    assert payload["validation"]["status"] == "passed"
    assert payload["source"]["page_count"] == 25
    assert len(payload["structured_pages"]) == 25
    assert len(payload["normalized_domain"]["meetings"]) == 162
    assert warnings == ["normalized_domain/meetings/160: missing room on non-online meeting"]


def test_validate_command_accepts_golden_artifact(capsys: pytest.CaptureFixture[str]) -> None:
    exit_code = main(["validate", "--input", str(GOLDEN_ARTIFACT)])

    stdout = capsys.readouterr().out
    assert exit_code == 0
    assert "Validation passed." in stdout


def test_parse_command_writes_output_file_for_synthetic_pdf(tmp_path: Path) -> None:
    source_pdf = tmp_path / "synthetic-timetable.pdf"
    output_path = tmp_path / "parsed.json"
    build_synthetic_timetable_pdf(
        source_pdf,
        meeting_blocks=[
            MeetingBlockSpec(
                day_index=0,
                slot_start=1,
                slot_end=3,
                lines=("CS LAB1", "Advanced Applied Machine", "Learning Lab", "Mr. Lab Instructor"),
            ),
            MeetingBlockSpec(
                day_index=1,
                slot_start=4,
                slot_end=5,
                lines=("FF-101", "Computer Organization &", "Assembly Language", "Ms. Tahira Ansari"),
            ),
        ],
    )

    exit_code = main(
        [
            "parse",
            "--input",
            str(source_pdf),
            "--output",
            str(output_path),
            "--version-id=test-synthetic-version",
        ]
    )

    assert exit_code == 0
    assert output_path.exists()
    assert load_artifact(output_path) == parse_pdf(source_pdf, version_id="test-synthetic-version")
