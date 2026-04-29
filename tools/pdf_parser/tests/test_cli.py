from __future__ import annotations

from pathlib import Path

import pytest

from pdf_parser.cli import main
from pdf_parser.parser import DEFAULT_VERSION_ID, parse_pdf
from pdf_parser.validation import load_artifact, validate_payload

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GOLDEN_ARTIFACT = PROJECT_ROOT / "fixtures" / "golden" / f"{DEFAULT_VERSION_ID}.json"
SOURCE_PDF = Path(r"C:\Users\PC\Downloads\26 april sp26 CS DEPARTMENT (4days sec wise).pdf")


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


def test_parse_pdf_matches_golden_fixture_when_source_available() -> None:
    if not SOURCE_PDF.exists():
        pytest.skip("Local timetable PDF is not available on this machine.")

    payload = parse_pdf(SOURCE_PDF, version_id=DEFAULT_VERSION_ID)
    expected = load_artifact(GOLDEN_ARTIFACT)

    assert payload == expected


def test_parse_command_writes_output_file_when_source_available(tmp_path: Path) -> None:
    if not SOURCE_PDF.exists():
        pytest.skip("Local timetable PDF is not available on this machine.")

    output_path = tmp_path / "parsed.json"

    exit_code = main(
        [
            "parse",
            "--input",
            str(SOURCE_PDF),
            "--output",
            str(output_path),
            "--version-id",
            DEFAULT_VERSION_ID,
        ]
    )

    assert exit_code == 0
    assert output_path.exists()
    assert load_artifact(output_path) == load_artifact(GOLDEN_ARTIFACT)
