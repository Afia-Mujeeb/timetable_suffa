from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import fitz

GRID_X = [50.0, 170.0] + [170.0 + 60.0 * index for index in range(1, 13)]
GRID_Y = [110.0 + 50.0 * index for index in range(8)]
ROOM_LINE = "FF-101, CS LAB1, UNKNOWN"
DAY_LABELS = (
    ("Mon", "(on campus)"),
    ("Tues", "(on campus)"),
    ("Wed", "(on campus)"),
    ("Thurs", "(online)"),
    ("Fri (onlin", "e)"),
    ("Sat", "(on campus)"),
)
SLOT_START_TOKENS = (
    "08:30",
    "09:10",
    "09:50",
    "10:30",
    "11:10",
    "11:50AM",
    "12:30",
    "01:10",
    "01:50",
    "02:30",
    "03:10",
    "03:50",
)
SLOT_END_TOKENS = (
    "09:10AM",
    "09:50AM",
    "10:30AM",
    "11:10AM",
    "11:50AM",
    "12:30PM",
    "01:10PM",
    "01:50PM",
    "02:30PM",
    "03:10PM",
    "03:50PM",
    "04:30PM",
)


@dataclass(frozen=True)
class MeetingBlockSpec:
    day_index: int
    slot_start: int
    slot_end: int
    lines: tuple[str, ...]


def _draw_text_lines(
    page: fitz.Page,
    left: float,
    top: float,
    lines: Iterable[str],
    *,
    font_size: float = 7.0,
    line_step: float = 8.0,
) -> None:
    for index, line in enumerate(lines):
        page.insert_text((left, top + index * line_step), line, fontsize=font_size)


def build_synthetic_timetable_pdf(
    output_path: Path,
    *,
    section_label: str = "BS-CS-2Z",
    meeting_blocks: Iterable[MeetingBlockSpec] = (),
    include_generated_date: bool = True,
    include_section_label: bool = True,
    corrupt_first_slot_header: bool = False,
) -> None:
    document = fitz.open()
    page = document.new_page(width=980, height=620)

    page_header_lines = [ROOM_LINE]
    if include_generated_date:
        page_header_lines.append("Timetable generated:4/26/2026")
    page_header_lines.append("DEPARTMENT OF COMPUTER SCIENCE (SPRING 2026 TIMETABLE)")
    if include_section_label:
        page_header_lines.append(section_label)
    _draw_text_lines(page, 55.0, 35.0, page_header_lines, font_size=8.0, line_step=10.0)

    for y_position in GRID_Y:
        page.draw_line((GRID_X[0], y_position), (GRID_X[-1], y_position))

    for x_position in GRID_X:
        page.draw_line((x_position, GRID_Y[0]), (x_position, GRID_Y[1]))

    skipped_boundaries_by_row: dict[int, set[float]] = {}
    for block in meeting_blocks:
        boundaries = skipped_boundaries_by_row.setdefault(block.day_index, set())
        for boundary_index in range(block.slot_start + 1, block.slot_end + 1):
            boundaries.add(GRID_X[boundary_index])

    for row_index in range(len(GRID_Y) - 2):
        row_top = GRID_Y[row_index + 1]
        row_bottom = GRID_Y[row_index + 2]
        skipped_boundaries = skipped_boundaries_by_row.get(row_index, set())
        for x_position in GRID_X:
            if x_position in skipped_boundaries:
                continue
            page.draw_line((x_position, row_top), (x_position, row_bottom))

    for row_index, day_label_lines in enumerate(DAY_LABELS):
        _draw_text_lines(page, GRID_X[0] + 5.0, GRID_Y[row_index + 1] + 15.0, day_label_lines)

    for slot_index, (start_token, end_token) in enumerate(zip(SLOT_START_TOKENS, SLOT_END_TOKENS, strict=True), start=1):
        lines = [str(slot_index), start_token, end_token]
        if corrupt_first_slot_header and slot_index == 1:
            lines = [str(slot_index), start_token]
        _draw_text_lines(page, GRID_X[slot_index] + 4.0, GRID_Y[0] + 15.0, lines)

    for block in meeting_blocks:
        _draw_text_lines(
            page,
            GRID_X[block.slot_start] + 6.0,
            GRID_Y[block.day_index + 1] + 16.0,
            block.lines,
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    document.save(output_path)
    document.close()
