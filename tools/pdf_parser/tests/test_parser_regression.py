from __future__ import annotations

from pathlib import Path

import pytest

from pdf_parser.parser import DEFAULT_VERSION_ID, parse_pdf
from pdf_parser.validation import load_artifact
from tests.helpers import MeetingBlockSpec, build_synthetic_timetable_pdf

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GOLDEN_ARTIFACT = PROJECT_ROOT / "fixtures" / "golden" / f"{DEFAULT_VERSION_ID}.json"


def _find_meeting(payload: dict[str, object], **filters: object) -> dict[str, object]:
    meetings = payload["normalized_domain"]["meetings"]
    assert isinstance(meetings, list)

    for meeting in meetings:
        assert isinstance(meeting, dict)
        if all(meeting.get(key) == value for key, value in filters.items()):
            return meeting

    pytest.fail(f"Meeting not found for filters: {filters}")


def _find_page(payload: dict[str, object], section_label: str) -> dict[str, object]:
    pages = payload["structured_pages"]
    assert isinstance(pages, list)

    for page in pages:
        assert isinstance(page, dict)
        if page.get("section_label") == section_label:
            return page

    pytest.fail(f"Structured page not found for section: {section_label}")


def test_golden_artifact_preserves_known_regression_markers() -> None:
    payload = load_artifact(GOLDEN_ARTIFACT)

    assert payload["source"]["page_count"] == 25
    assert len(payload["normalized_domain"]["meetings"]) == 162
    assert payload["validation"]["warnings"] == [
        "normalized_domain/meetings/160: missing room on non-online meeting"
    ]

    wrapped_title_meeting = _find_meeting(
        payload,
        section="BS-CS-4A",
        course_name="Computer Organization & Assembly Language",
    )
    assert wrapped_title_meeting["slot_start"] == 7
    assert wrapped_title_meeting["slot_end"] == 8
    assert wrapped_title_meeting["warnings"] == []

    inferred_lab_meeting = _find_meeting(
        payload,
        section="BS-CS-6E",
        course_name="Artificial Intelligence Lab",
        instructor="Zaryab",
    )
    assert inferred_lab_meeting["meeting_type"] == "lab"
    assert inferred_lab_meeting["slot_start"] == 1
    assert inferred_lab_meeting["slot_end"] == 3
    assert inferred_lab_meeting["warnings"] == ["instructor_inferred_from_last_line"]

    misc_page = _find_page(payload, "BS-CS-MISC 3")
    assert misc_page["page_class"] == "misc-page"
    assert misc_page["raw_meeting_blocks"][0]["text_lines"] == [
        "Computer Networks",
        "Ms. Urooj Waheed",
    ]
    assert misc_page["raw_meeting_blocks"][0]["warnings"] == ["missing_room"]


def test_parse_pdf_handles_wrapped_titles_long_blocks_and_wrapped_online_labels(tmp_path: Path) -> None:
    source_pdf = tmp_path / "synthetic-timetable.pdf"
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

    payload = parse_pdf(source_pdf, version_id="test-synthetic-version")

    meetings = payload["normalized_domain"]["meetings"]
    assert meetings == [
        {
            "section": "BS-CS-2Z",
            "course_name": "Advanced Applied Machine Learning Lab",
            "instructor": "Mr. Lab Instructor",
            "room": "CS LAB1",
            "day": "Mon",
            "day_key": "monday",
            "online": False,
            "meeting_type": "lab",
            "slot_start": 1,
            "slot_end": 3,
            "start_time": "08:30",
            "end_time": "10:30",
            "source_page": 1,
            "source_version": "test-synthetic-version",
            "confidence_class": "high",
            "confidence_score": 1.0,
            "warnings": [],
        },
        {
            "section": "BS-CS-2Z",
            "course_name": "Computer Organization & Assembly Language",
            "instructor": "Ms. Tahira Ansari",
            "room": "FF-101",
            "day": "Tues",
            "day_key": "tuesday",
            "online": False,
            "meeting_type": "lecture",
            "slot_start": 4,
            "slot_end": 5,
            "start_time": "10:30",
            "end_time": "11:50",
            "source_page": 1,
            "source_version": "test-synthetic-version",
            "confidence_class": "high",
            "confidence_score": 1.0,
            "warnings": [],
        },
    ]
    assert payload["structured_pages"][0]["days_detected"][4]["label"] == "Fri (online)"


def test_parse_pdf_rejects_missing_generated_date(tmp_path: Path) -> None:
    source_pdf = tmp_path / "missing-date.pdf"
    build_synthetic_timetable_pdf(source_pdf, include_generated_date=False)

    with pytest.raises(ValueError, match="Generated date not found in PDF text"):
        parse_pdf(source_pdf)


def test_parse_pdf_rejects_missing_section_label(tmp_path: Path) -> None:
    source_pdf = tmp_path / "missing-section.pdf"
    build_synthetic_timetable_pdf(source_pdf, include_section_label=False)

    with pytest.raises(ValueError, match="Section label not found on page"):
        parse_pdf(source_pdf)


def test_parse_pdf_rejects_partial_slot_header(tmp_path: Path) -> None:
    source_pdf = tmp_path / "partial-slot-header.pdf"
    build_synthetic_timetable_pdf(source_pdf, corrupt_first_slot_header=True)

    with pytest.raises(ValueError, match="Unable to read slot header for slot column 1"):
        parse_pdf(source_pdf)
