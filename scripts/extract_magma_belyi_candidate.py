#!/usr/bin/env python3
"""Extract an exact versioned Belyi candidate from a Magma pilot transcript."""

from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import re
from typing import Any

from verify_belyi_candidate import (
    M23_8A_PROBLEM,
    M23_8A_SOURCE_SHA256,
    SCHEMA_VERSION,
    TARGET,
)


MARKERS = {
    "field": "M23_EXACT_FIELD_POLYNOMIAL=",
    "numerator": "M23_EXACT_NUMERATOR=",
    "denominator": "M23_EXACT_DENOMINATOR=",
}

TOKEN = re.compile(r"\s*(?:(-?[0-9]+(?:/[1-9][0-9]*)?)|([\[\],]))")


def parse_magma_sequence(text: str) -> Any:
    """Parse the list/rational subset of Magma's Sprint output."""
    position = 0

    def token() -> tuple[str, str]:
        nonlocal position
        match = TOKEN.match(text, position)
        if match is None:
            raise ValueError(f"unsupported Magma sequence syntax at offset {position}")
        position = match.end()
        return ("number", match.group(1)) if match.group(1) else (match.group(2), match.group(2))

    def value(first: tuple[str, str] | None = None) -> Any:
        current = token() if first is None else first
        if current[0] == "number":
            return str(Fraction(current[1]))
        if current[0] != "[":
            raise ValueError("expected a Magma list or rational")
        result = []
        current = token()
        if current[0] == "]":
            return result
        while True:
            result.append(value(current))
            current = token()
            if current[0] == "]":
                return result
            if current[0] != ",":
                raise ValueError("expected ',' or ']' in Magma list")
            current = token()

    result = value()
    if text[position:].strip():
        raise ValueError("trailing text after Magma sequence")
    return result


def bracketed_marker_values(transcript: str,
                            markers: dict[str, str]) -> dict[str, str]:
    """Collect one balanced, possibly line-wrapped sequence per marker."""
    lines = transcript.splitlines()
    values: dict[str, str] = {}
    for name, prefix in markers.items():
        matches = [index for index, line in enumerate(lines)
                   if line.startswith(prefix)]
        if len(matches) != 1:
            qualifier = "missing" if not matches else "duplicate"
            raise ValueError(f"{qualifier} {prefix} marker")
        index = matches[0]
        first = lines[index][len(prefix):].strip()
        if not first.startswith("["):
            raise ValueError(f"{prefix} marker does not begin a sequence")
        chunks = [first]
        balance = first.count("[") - first.count("]")
        while balance > 0:
            index += 1
            if index >= len(lines):
                raise ValueError(f"unterminated {prefix} sequence")
            continuation = lines[index].strip()
            chunks.append(continuation)
            balance += continuation.count("[") - continuation.count("]")
        if balance < 0:
            raise ValueError(f"unbalanced {prefix} sequence")
        values[name] = "\n".join(chunks)
    return values


def marker_values(transcript: str) -> dict[str, str]:
    values = bracketed_marker_values(transcript, MARKERS)
    sanity_prefix = "M23_EXACT_SANITY="
    sanity = [line[len(sanity_prefix):].strip()
              for line in transcript.splitlines()
              if line.startswith(sanity_prefix)]
    if len(sanity) != 1:
        qualifier = "missing" if not sanity else "duplicate"
        raise ValueError(f"{qualifier} exact sanity marker")
    if sanity[0] != "true":
        raise ValueError("Magma did not report a successful exact sanity check")
    return values


def build_candidate(transcript: str, *, package_revision: str,
                    magma_version: str, configuration: dict[str, Any],
                    problem_id: str = M23_8A_PROBLEM,
                    expected_partitions: tuple[tuple[int, ...], ...] = TARGET,
                    source_description: str = (
                        "class 1 of the committed (8A,8A,2A) inner-class certificate"),
                    source_class_id: int = 1,
                    source_dataset_sha256: str = M23_8A_SOURCE_SHA256,
                    ) -> dict[str, Any]:
    values = marker_values(transcript)
    field_polynomial = parse_magma_sequence(values["field"])
    numerator = parse_magma_sequence(values["numerator"])
    denominator = parse_magma_sequence(values["denominator"])
    if not isinstance(field_polynomial, list):
        raise ValueError("field polynomial marker must be a list")
    if not isinstance(numerator, list) or not isinstance(denominator, list):
        raise ValueError("map coefficient markers must be lists")
    return {
        "schema_version": SCHEMA_VERSION,
        "problem": {
            "id": problem_id,
            "expected_partitions": [list(partition) for partition in expected_partitions],
        },
        "field": {
            "generator": None if not field_polynomial else "a",
            "defining_polynomial": field_polynomial or None,
        },
        "map": {"numerator": numerator, "denominator": denominator},
        "provenance": {
            "source": {
                "description": source_description,
                "class_id": source_class_id,
                "dataset_sha256": source_dataset_sha256,
            },
            "producer": {
                "software": f"Magma {magma_version} with michaelmusty/Belyi",
                "revision": package_revision,
                "configuration": {
                    **configuration,
                    "transcript_sha256": hashlib.sha256(transcript.encode()).hexdigest(),
                },
            },
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("transcript", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--package-revision", required=True)
    parser.add_argument("--magma-version", required=True)
    parser.add_argument("--configuration-json", default="{}")
    parser.add_argument("--problem-id", default=M23_8A_PROBLEM)
    parser.add_argument(
        "--expected-partitions-json",
        default=json.dumps([list(partition) for partition in TARGET]))
    parser.add_argument(
        "--source-description",
        default="class 1 of the committed (8A,8A,2A) inner-class certificate")
    parser.add_argument("--source-class-id", type=int, default=1)
    parser.add_argument("--source-dataset-sha256", default=M23_8A_SOURCE_SHA256)
    args = parser.parse_args()
    configuration = json.loads(args.configuration_json)
    if not isinstance(configuration, dict):
        raise SystemExit("configuration JSON must be an object")
    try:
        partitions_value = json.loads(args.expected_partitions_json)
        if (not isinstance(partitions_value, list) or len(partitions_value) != 3 or
                any(not isinstance(partition, list) for partition in partitions_value)):
            raise ValueError("expected partitions must be a JSON list of three lists")
        expected_partitions = tuple(
            tuple(int(entry) for entry in partition) for partition in partitions_value)
        candidate = build_candidate(
            args.transcript.read_text(), package_revision=args.package_revision,
            magma_version=args.magma_version, configuration=configuration,
            problem_id=args.problem_id, expected_partitions=expected_partitions,
            source_description=args.source_description,
            source_class_id=args.source_class_id,
            source_dataset_sha256=args.source_dataset_sha256)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"candidate extraction failed: {error}") from error
    args.output.write_text(json.dumps(candidate, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
