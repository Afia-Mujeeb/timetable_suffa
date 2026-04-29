from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from .parser import DEFAULT_VERSION_ID, parse_pdf
from .validation import load_artifact, validate_payload


def parse_command(input_path: Path, output_path: Path | None, version_id: str) -> int:
    if not input_path.exists():
        raise FileNotFoundError(f"Input PDF not found: {input_path}")

    payload = parse_pdf(input_path=input_path, version_id=version_id)
    serialized = json.dumps(payload, indent=2) + "\n"

    if output_path is None:
        print(serialized, end="")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(serialized, encoding="utf-8")
    return 0


def validate_command(input_path: Path) -> int:
    payload = load_artifact(input_path)
    errors, warnings = validate_payload(payload)

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        for warning in warnings:
            print(f"WARNING: {warning}")
        return 1

    print("Validation passed.")
    for warning in warnings:
        print(f"WARNING: {warning}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Timetable PDF parser.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    parse_parser = subparsers.add_parser(
        "parse",
        help="Parse the timetable PDF into a versioned JSON artifact.",
    )
    parse_parser.add_argument("--input", required=True, type=Path, help="Path to the source PDF.")
    parse_parser.add_argument(
        "--output",
        type=Path,
        help="Optional JSON output path. Writes to stdout when omitted.",
    )
    parse_parser.add_argument(
        "--version-id",
        default=DEFAULT_VERSION_ID,
        help=f"Version id to embed in the artifact. Defaults to {DEFAULT_VERSION_ID}.",
    )

    validate_parser = subparsers.add_parser(
        "validate",
        help="Validate a parsed JSON artifact against schema and parser rules.",
    )
    validate_parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Path to the parsed JSON artifact.",
    )

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "parse":
        return parse_command(args.input, args.output, args.version_id)

    if args.command == "validate":
        return validate_command(args.input)

    parser.error(f"Unsupported command: {args.command}")
    return 1
