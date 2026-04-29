from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence


def build_placeholder_payload(input_path: Path) -> dict[str, object]:
    return {
        "source": str(input_path.resolve()),
        "status": "placeholder",
        "notes": [
            "Sprint 0 scaffold only.",
            "Replace this payload with real extraction logic in Sprint 1.",
        ],
    }


def parse_command(input_path: Path, output_path: Path | None) -> int:
    if not input_path.exists():
        raise FileNotFoundError(f"Input PDF not found: {input_path}")

    payload = build_placeholder_payload(input_path)
    serialized = json.dumps(payload, indent=2) + "\n"

    if output_path is None:
        print(serialized, end="")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(serialized, encoding="utf-8")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Timetable PDF parser workspace.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    parse_parser = subparsers.add_parser("parse", help="Emit placeholder parser output.")
    parse_parser.add_argument("--input", required=True, type=Path, help="Path to the source PDF.")
    parse_parser.add_argument(
        "--output",
        type=Path,
        help="Optional JSON output path. Writes to stdout when omitted.",
    )

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "parse":
        return parse_command(args.input, args.output)

    parser.error(f"Unsupported command: {args.command}")
    return 1
