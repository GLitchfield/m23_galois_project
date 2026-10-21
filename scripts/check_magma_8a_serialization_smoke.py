#!/usr/bin/env python3
"""Check the fast Magma number-field serialization smoke transcript."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from extract_magma_belyi_candidate import (
    bracketed_marker_values,
    parse_magma_sequence,
)


MARKERS = {
    "field": "M23_SMOKE_FIELD_POLYNOMIAL=",
    "numerator": "M23_SMOKE_NUMERATOR=",
    "denominator": "M23_SMOKE_DENOMINATOR=",
}
EXPECTED = {
    "field": ["-2", "0", "1"],
    "numerator": [["2", "1"], ["0", "0"], ["3", "-1"]],
    "denominator": [["1", "0"], ["0", "1"]],
}


def check_transcript(transcript: str) -> dict[str, object]:
    lines = transcript.splitlines()
    values = bracketed_marker_values(transcript, MARKERS)
    for name, expected in EXPECTED.items():
        actual = parse_magma_sequence(values[name])
        if actual != expected:
            raise ValueError(f"unexpected {MARKERS[name]} value: {actual!r}")
    if lines.count("M23_SMOKE_COMPLETE=true") != 1:
        raise ValueError("missing or duplicate smoke completion marker")
    return {
        "coefficient_order": "low-to-high",
        "field_degree": 2,
        "status": "verified",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("transcript", type=Path)
    args = parser.parse_args()
    try:
        result = check_transcript(args.transcript.read_text())
    except (OSError, ValueError) as error:
        raise SystemExit(f"smoke verification failed: {error}") from error
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
