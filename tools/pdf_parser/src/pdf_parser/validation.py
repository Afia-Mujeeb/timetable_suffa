from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

SCHEMA_PATH = Path(__file__).resolve().parents[2] / "schema" / "timetable.schema.json"
KNOWN_DAY_KEYS = {"monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}


def load_artifact(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_schema() -> dict[str, Any]:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def validate_schema(payload: dict[str, Any]) -> list[str]:
    validator = Draft202012Validator(load_schema())
    return [
        f"{'/'.join(str(part) for part in error.absolute_path) or '$'}: {error.message}"
        for error in sorted(validator.iter_errors(payload), key=lambda error: list(error.absolute_path))
    ]


def validate_domain_rules(payload: dict[str, Any]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    source = payload.get("source", {})
    version_id = source.get("version_id")
    meetings = payload.get("normalized_domain", {}).get("meetings", [])
    known_sections = set(source.get("sections", []))

    seen_windows: set[tuple[str, str, int, int]] = set()
    for index, meeting in enumerate(meetings):
        prefix = f"normalized_domain/meetings/{index}"
        section = meeting.get("section")
        if not section:
            errors.append(f"{prefix}: missing section")
        elif section not in known_sections:
            errors.append(f"{prefix}: section {section} not found in source.sections")

        course_name = meeting.get("course_name")
        if not course_name:
            errors.append(f"{prefix}: missing course_name")

        day_key = meeting.get("day_key")
        if day_key not in KNOWN_DAY_KEYS:
            errors.append(f"{prefix}: invalid day_key {day_key}")

        slot_start = meeting.get("slot_start")
        slot_end = meeting.get("slot_end")
        if not isinstance(slot_start, int) or not isinstance(slot_end, int) or slot_start > slot_end:
            errors.append(f"{prefix}: invalid slot range {slot_start}-{slot_end}")

        start_time = meeting.get("start_time")
        end_time = meeting.get("end_time")
        if isinstance(start_time, str) and isinstance(end_time, str) and start_time >= end_time:
            errors.append(f"{prefix}: start_time must be earlier than end_time")

        room = meeting.get("room")
        online = bool(meeting.get("online"))
        if room is None and not online:
            warnings.append(f"{prefix}: missing room on non-online meeting")

        if meeting.get("source_version") != version_id:
            errors.append(f"{prefix}: source_version does not match source.version_id")

        key = (str(section), str(day_key), int(slot_start), int(slot_end))
        if key in seen_windows:
            warnings.append(
                f"{prefix}: duplicate meeting window detected for {section}/{day_key}/{slot_start}-{slot_end}"
            )
        seen_windows.add(key)

    return errors, warnings


def validate_payload(payload: dict[str, Any]) -> tuple[list[str], list[str]]:
    schema_errors = validate_schema(payload)
    domain_errors, domain_warnings = validate_domain_rules(payload)
    errors = schema_errors + domain_errors
    return errors, domain_warnings
