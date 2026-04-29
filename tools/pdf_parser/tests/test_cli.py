from pathlib import Path

from pdf_parser.cli import build_placeholder_payload, main


def test_build_placeholder_payload_uses_input_path(tmp_path: Path) -> None:
    input_path = tmp_path / "sample.pdf"
    input_path.write_bytes(b"%PDF-1.4\n")

    payload = build_placeholder_payload(input_path)

    assert payload["status"] == "placeholder"
    assert payload["source"] == str(input_path.resolve())


def test_main_writes_output_file(tmp_path: Path) -> None:
    input_path = tmp_path / "sample.pdf"
    output_path = tmp_path / "artifacts" / "parsed.json"
    input_path.write_bytes(b"%PDF-1.4\n")

    exit_code = main(["parse", "--input", str(input_path), "--output", str(output_path)])

    assert exit_code == 0
    assert output_path.exists()
