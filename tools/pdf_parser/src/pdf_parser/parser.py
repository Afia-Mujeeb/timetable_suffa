from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import fitz

from .validation import validate_payload

DEFAULT_VERSION_ID = "spring-2026-2026-04-26"

DAY_KEYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday")
DAY_NAMES = {
    "monday": "Mon",
    "tuesday": "Tues",
    "wednesday": "Wed",
    "thursday": "Thurs",
    "friday": "Fri",
    "saturday": "Sat",
}
DAY_ORDER = tuple(DAY_NAMES.values())
EXPECTED_GRID_X_COUNT = 14
EXPECTED_GRID_Y_COUNT = 8
FLOAT_TOLERANCE = 1.5
TEXT_TOLERANCE = 3.5
INSTRUCTOR_PREFIXES = ("Mr", "Ms", "Dr", "Mrs", "Miss", "Prof", "Professor")
SECTION_PATTERN = re.compile(r"^BS-[A-Z]{2,3}-[A-Z0-9 ]+$")
TIME_PATTERN = re.compile(r"^(?P<hour>\d{1,2}):(?P<minute>\d{2})(?P<meridiem>AM|PM)?$")


@dataclass(frozen=True)
class RectWord:
    x0: float
    y0: float
    x1: float
    y1: float
    text: str

    @property
    def center_y(self) -> float:
        return (self.y0 + self.y1) / 2


def normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalize_inline_label(value: str) -> str:
    return normalize_whitespace(value).replace("onlin e", "online")


def round_point(value: float) -> float:
    return round(value, 2)


def parse_time_token(raw_value: str, fallback_meridiem: str | None = None) -> str:
    match = TIME_PATTERN.match(raw_value)
    if match is None:
        raise ValueError(f"Unsupported time token: {raw_value}")

    hour = int(match.group("hour"))
    minute = int(match.group("minute"))
    meridiem = match.group("meridiem") or fallback_meridiem

    if meridiem is None:
        raise ValueError(f"Time token requires meridiem inference: {raw_value}")

    if meridiem == "AM":
        normalized_hour = 0 if hour == 12 else hour
    else:
        normalized_hour = 12 if hour == 12 else hour + 12

    return f"{normalized_hour:02d}:{minute:02d}"


def to_rect_word(word: tuple[float, float, float, float, str, int, int, int]) -> RectWord:
    x0, y0, x1, y1, text, *_ = word
    return RectWord(x0=x0, y0=y0, x1=x1, y1=y1, text=text)


def sort_words(words: Iterable[RectWord]) -> list[RectWord]:
    return sorted(words, key=lambda word: (round(word.center_y / 2), word.x0, word.y0))


def group_words_into_lines(words: Iterable[RectWord]) -> list[str]:
    ordered_words = sort_words(words)
    lines: list[dict[str, object]] = []

    for word in ordered_words:
        if not lines:
            lines.append({"center_y": word.center_y, "words": [word]})
            continue

        current_line = lines[-1]
        center_y = current_line["center_y"]
        assert isinstance(center_y, float)
        if abs(word.center_y - center_y) <= TEXT_TOLERANCE:
            current_words = current_line["words"]
            assert isinstance(current_words, list)
            current_words.append(word)
            current_line["center_y"] = (center_y + word.center_y) / 2
            continue

        lines.append({"center_y": word.center_y, "words": [word]})

    result: list[str] = []
    for line in lines:
        line_words = line["words"]
        assert isinstance(line_words, list)
        ordered_line_words = sorted(line_words, key=lambda word: word.x0)
        line_text = normalize_whitespace(" ".join(word.text for word in ordered_line_words))
        if line_text:
            result.append(line_text)

    return result


def clip_words(page: fitz.Page, rect: fitz.Rect) -> list[RectWord]:
    clipped = page.get_text("words", clip=rect)
    return [to_rect_word(word) for word in clipped if normalize_whitespace(word[4])]


def extract_grid_axes(page: fitz.Page) -> tuple[list[float], list[float], list[tuple[float, float, float, float]]]:
    x_values: set[float] = set()
    y_values: set[float] = set()
    line_segments: list[tuple[float, float, float, float]] = []

    for drawing in page.get_drawings():
        for item in drawing["items"]:
            if item[0] != "l":
                continue

            _, point_a, point_b = item
            x0 = round_point(point_a.x)
            y0 = round_point(point_a.y)
            x1 = round_point(point_b.x)
            y1 = round_point(point_b.y)
            line_segments.append((x0, y0, x1, y1))
            x_values.update({x0, x1})
            y_values.update({y0, y1})

    grid_x = sorted(x_values)
    grid_y = sorted(y_values)
    return grid_x, grid_y, line_segments


def line_spans_row(
    segment: tuple[float, float, float, float],
    x_position: float,
    row_top: float,
    row_bottom: float,
) -> bool:
    x0, y0, x1, y1 = segment
    if abs(x0 - x1) > FLOAT_TOLERANCE:
        return False
    if abs(x0 - x_position) > FLOAT_TOLERANCE:
        return False
    return abs(y0 - row_top) <= FLOAT_TOLERANCE and abs(y1 - row_bottom) <= FLOAT_TOLERANCE


def canonical_day_key(label_text: str) -> str:
    normalized = normalize_inline_label(label_text).lower()
    for day_key, short_name in DAY_NAMES.items():
        if normalized.startswith(short_name.lower()):
            return day_key
    raise ValueError(f"Unable to derive day key from label: {label_text}")


def extract_day_rows(page: fitz.Page, grid_x: list[float], grid_y: list[float]) -> list[dict[str, object]]:
    label_left = grid_x[0]
    label_right = grid_x[1]
    body_top = grid_y[1]
    body_bottom = grid_y[-1]
    label_rect = fitz.Rect(label_left, body_top, label_right, body_bottom)
    label_words = clip_words(page, label_rect)

    rows: list[dict[str, object]] = []
    for index in range(len(grid_y) - 2):
        row_top = grid_y[index + 1]
        row_bottom = grid_y[index + 2]
        row_rect = fitz.Rect(label_left, row_top, label_right, row_bottom)
        row_words = [word for word in label_words if row_rect.intersects(fitz.Rect(word.x0, word.y0, word.x1, word.y1))]
        label_lines = group_words_into_lines(row_words)
        label_text = normalize_inline_label(" ".join(label_lines))
        day_key = canonical_day_key(label_text)
        rows.append(
            {
                "day": DAY_NAMES[day_key],
                "day_key": day_key,
                "label": label_text,
                "online": "online" in label_text.lower(),
                "row_top": row_top,
                "row_bottom": row_bottom,
            }
        )

    return rows


def extract_time_slots(page: fitz.Page, grid_x: list[float], grid_y: list[float]) -> list[dict[str, object]]:
    header_top = grid_y[0]
    header_bottom = grid_y[1]
    slots: list[dict[str, object]] = []

    for index in range(1, len(grid_x) - 1):
        slot_left = grid_x[index]
        slot_right = grid_x[index + 1]
        slot_rect = fitz.Rect(slot_left, header_top, slot_right, header_bottom)
        slot_words = clip_words(page, slot_rect)
        tokens = [word.text for word in sort_words(slot_words)]
        if len(tokens) < 3:
            raise ValueError(f"Unable to read slot header for slot column {index}")

        slot_number = int(tokens[0])
        start_raw = tokens[1]
        end_raw = tokens[2]
        end_match = TIME_PATTERN.match(end_raw)
        if end_match is None or end_match.group("meridiem") is None:
            raise ValueError(f"Slot end time missing meridiem: {end_raw}")
        fallback_meridiem = end_match.group("meridiem")
        slots.append(
            {
                "slot": slot_number,
                "start_time": parse_time_token(start_raw, fallback_meridiem=fallback_meridiem),
                "end_time": parse_time_token(end_raw, fallback_meridiem=fallback_meridiem),
                "raw": {
                    "slot": slot_number,
                    "start": start_raw,
                    "end": end_raw,
                },
                "left": slot_left,
                "right": slot_right,
            }
        )

    return slots


def extract_room_vocabulary(text_lines: list[str]) -> list[str]:
    room_line = next((line for line in text_lines if "," in line and "FF-" in line), "")
    rooms = [normalize_whitespace(part) for part in room_line.split(",") if normalize_whitespace(part)]
    return rooms


def find_section_label(text_lines: list[str]) -> str:
    for line in text_lines:
        if SECTION_PATTERN.match(line):
            return line
    raise ValueError("Section label not found on page")


def find_generated_date(text_lines: list[str]) -> str:
    date_match = next(
        (
            re.search(r"Timetable generated:(?P<date>\d{1,2}/\d{1,2}/\d{4})", line)
            for line in text_lines
            if "Timetable generated:" in line
        ),
        None,
    )
    if date_match is None:
        raise ValueError("Generated date not found in PDF text")

    month, day, year = date_match.group("date").split("/")
    return f"{year}-{int(month):02d}-{int(day):02d}"


def normalize_room(line_text: str, known_rooms: list[str]) -> str | None:
    normalized = normalize_whitespace(line_text)
    room_map = {room.upper(): room for room in known_rooms}
    if normalized.upper() in room_map:
        return room_map[normalized.upper()]
    if normalized.upper() in {"ONLINE", "UNKNOWN"}:
        return normalized.lower()
    return None


def looks_like_instructor(line_text: str) -> bool:
    normalized = normalize_whitespace(line_text)
    if not normalized:
        return False
    if normalized.startswith(INSTRUCTOR_PREFIXES):
        return True
    return bool(re.match(r"^[A-Z][A-Za-z]+(?: [A-Z][A-Za-z.&'-]+){1,5}$", normalized))


def derive_confidence(warnings: list[str]) -> tuple[str, float]:
    if any(warning.startswith("missing_") for warning in warnings):
        return "low", 0.5
    if warnings:
        return "medium", 0.75
    return "high", 1.0


def parse_meeting_lines(
    lines: list[str],
    *,
    known_rooms: list[str],
    is_online_day: bool,
) -> tuple[dict[str, object], list[str]]:
    remaining = [normalize_whitespace(line) for line in lines if normalize_whitespace(line)]
    warnings: list[str] = []
    room: str | None = None

    if remaining:
        candidate_room = normalize_room(remaining[0], known_rooms)
        if candidate_room and candidate_room != "unknown":
            room = candidate_room
            remaining = remaining[1:]

    instructor: str | None = None
    if remaining:
        if looks_like_instructor(remaining[-1]):
            instructor = remaining[-1]
            remaining = remaining[:-1]
        elif len(remaining) > 1:
            instructor = remaining[-1]
            remaining = remaining[:-1]
            warnings.append("instructor_inferred_from_last_line")

    course_title = normalize_whitespace(" ".join(remaining))
    if not course_title:
        warnings.append("missing_course_title")
    if instructor is None:
        warnings.append("missing_instructor")

    online = is_online_day
    if room is None and online:
        warnings.append("room_missing_on_online_day")
    if room is None and not online:
        warnings.append("missing_room")

    meeting_type = "lab" if "lab" in course_title.lower() else "lecture"
    confidence_class, confidence_score = derive_confidence(warnings)
    return (
        {
            "course_name": course_title,
            "instructor": instructor,
            "room": room,
            "online": online,
            "meeting_type": meeting_type,
            "confidence_class": confidence_class,
            "confidence_score": confidence_score,
        },
        warnings,
    )


def extract_meeting_blocks(
    page: fitz.Page,
    *,
    grid_x: list[float],
    rows: list[dict[str, object]],
    slots: list[dict[str, object]],
    line_segments: list[tuple[float, float, float, float]],
    known_rooms: list[str],
    section: str,
    version_id: str,
    page_number: int,
) -> tuple[list[dict[str, object]], list[dict[str, object]], list[str]]:
    normalized_meetings: list[dict[str, object]] = []
    raw_blocks: list[dict[str, object]] = []
    warnings: list[str] = []

    slot_boundary_positions = grid_x[1:]
    boundary_to_slot_index = {round_point(boundary): index for index, boundary in enumerate(slot_boundary_positions)}

    for row in rows:
        row_top = row["row_top"]
        row_bottom = row["row_bottom"]
        assert isinstance(row_top, float)
        assert isinstance(row_bottom, float)

        row_boundaries = {round_point(grid_x[1]), round_point(grid_x[-1])}
        for x_position in slot_boundary_positions:
            if any(line_spans_row(segment, x_position, row_top, row_bottom) for segment in line_segments):
                row_boundaries.add(round_point(x_position))

        sorted_boundaries = sorted(row_boundaries)
        for left, right in zip(sorted_boundaries, sorted_boundaries[1:]):
            slot_rect = fitz.Rect(left + 1, row_top + 1, right - 1, row_bottom - 1)
            cell_words = clip_words(page, slot_rect)
            if not cell_words:
                continue

            cell_lines = group_words_into_lines(cell_words)
            parsed_meeting, cell_warnings = parse_meeting_lines(
                cell_lines,
                known_rooms=known_rooms,
                is_online_day=bool(row["online"]),
            )

            slot_start_index = boundary_to_slot_index[round_point(left)] + 1
            slot_end_index = boundary_to_slot_index[round_point(right)]
            start_slot = slots[slot_start_index - 1]
            end_slot = slots[slot_end_index - 1]

            day_key = row["day_key"]
            assert isinstance(day_key, str)
            raw_block = {
                "day": row["day"],
                "day_key": day_key,
                "slot_start": slot_start_index,
                "slot_end": slot_end_index,
                "bounds": {
                    "x0": round_point(left),
                    "y0": round_point(row_top),
                    "x1": round_point(right),
                    "y1": round_point(row_bottom),
                },
                "text_lines": cell_lines,
                "warnings": cell_warnings,
            }
            raw_blocks.append(raw_block)

            normalized_meetings.append(
                {
                    "section": section,
                    "course_name": parsed_meeting["course_name"],
                    "instructor": parsed_meeting["instructor"],
                    "room": parsed_meeting["room"],
                    "day": row["day"],
                    "day_key": day_key,
                    "online": parsed_meeting["online"],
                    "meeting_type": parsed_meeting["meeting_type"],
                    "slot_start": slot_start_index,
                    "slot_end": slot_end_index,
                    "start_time": start_slot["start_time"],
                    "end_time": end_slot["end_time"],
                    "source_page": page_number,
                    "source_version": version_id,
                    "confidence_class": parsed_meeting["confidence_class"],
                    "confidence_score": parsed_meeting["confidence_score"],
                    "warnings": cell_warnings,
                }
            )

        seen_time_windows = Counter(
            (meeting["day_key"], meeting["slot_start"], meeting["slot_end"])
            for meeting in normalized_meetings
            if meeting["section"] == section and meeting["source_page"] == page_number
        )
        duplicate_windows = [
            f"{day_key}:{slot_start}-{slot_end}"
            for (day_key, slot_start, slot_end), count in seen_time_windows.items()
            if count > 1
        ]
        if duplicate_windows:
            warnings.append(
                f"duplicate_time_windows_detected:{section}:{','.join(sorted(duplicate_windows))}"
            )

    return normalized_meetings, raw_blocks, warnings


def page_class_for_section(section: str) -> str:
    return "misc-page" if "MISC" in section else "regular-section-page"


def parse_pdf(input_path: Path, version_id: str = DEFAULT_VERSION_ID) -> dict[str, object]:
    document = fitz.open(input_path)
    raw_pages: list[dict[str, object]] = []
    structured_pages: list[dict[str, object]] = []
    normalized_meetings: list[dict[str, object]] = []

    generated_date: str | None = None
    parser_warnings: list[str] = []

    for page_index, page in enumerate(document):
        text_lines = [normalize_whitespace(line) for line in page.get_text("text").splitlines() if line.strip()]
        page_number = page_index + 1
        page_warnings: list[str] = []

        if generated_date is None:
            generated_date = find_generated_date(text_lines)

        section = find_section_label(text_lines)
        known_rooms = extract_room_vocabulary(text_lines)
        grid_x, grid_y, line_segments = extract_grid_axes(page)

        if len(grid_x) != EXPECTED_GRID_X_COUNT or len(grid_y) != EXPECTED_GRID_Y_COUNT:
            page_warnings.append(
                f"unexpected_grid_shape:x={len(grid_x)}:y={len(grid_y)}"
            )

        rows = extract_day_rows(page, grid_x, grid_y)
        slots = extract_time_slots(page, grid_x, grid_y)
        meetings, raw_blocks, block_warnings = extract_meeting_blocks(
            page,
            grid_x=grid_x,
            rows=rows,
            slots=slots,
            line_segments=line_segments,
            known_rooms=known_rooms,
            section=section,
            version_id=version_id,
            page_number=page_number,
        )
        page_warnings.extend(block_warnings)
        parser_warnings.extend(f"page_{page_number}:{warning}" for warning in page_warnings)

        raw_pages.append(
            {
                "page_number": page_number,
                "extracted_lines": text_lines,
                "parser_warnings": page_warnings,
            }
        )
        structured_pages.append(
            {
                "page_number": page_number,
                "section_label": section,
                "page_class": page_class_for_section(section),
                "source_rooms_detected": known_rooms,
                "time_grid_detected": [
                    {
                        "slot": slot["slot"],
                        "start_time": slot["start_time"],
                        "end_time": slot["end_time"],
                    }
                    for slot in slots
                ],
                "days_detected": [
                    {
                        "day": row["day"],
                        "day_key": row["day_key"],
                        "label": row["label"],
                        "online": row["online"],
                    }
                    for row in rows
                ],
                "raw_meeting_blocks": raw_blocks,
                "warnings": page_warnings,
            }
        )
        normalized_meetings.extend(meetings)

    if generated_date is None:
        raise ValueError("Generated date was not found in the source document")

    sections = [page["section_label"] for page in structured_pages]
    artifact = {
        "source": {
            "version_id": version_id,
            "source_file_name": input_path.name,
            "generated_date": generated_date,
            "page_count": len(document),
            "sections": sections,
        },
        "raw_extraction": {
            "pages": raw_pages,
        },
        "structured_pages": structured_pages,
        "normalized_domain": {
            "sections": sorted(set(sections)),
            "meetings": sorted(
                normalized_meetings,
                key=lambda meeting: (
                    meeting["section"],
                    meeting["source_page"],
                    DAY_KEYS.index(meeting["day_key"]),
                    meeting["slot_start"],
                    meeting["slot_end"],
                    meeting["course_name"],
                ),
            ),
        },
        "validation": {
            "status": "passed",
            "errors": [],
            "warnings": [],
        },
    }

    errors, warnings = validate_payload(artifact)
    artifact["validation"] = {
        "status": "passed" if not errors else "failed",
        "errors": errors,
        "warnings": sorted(set(parser_warnings + warnings)),
    }
    return artifact
