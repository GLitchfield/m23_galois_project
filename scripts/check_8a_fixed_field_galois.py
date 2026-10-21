#!/usr/bin/env python3
"""Check the committed independent Galois-group certificates for the 8A field."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
REVISION = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_POLYNOMIAL = (
    768, -1344, -1308, 4496, -1512, -5352, 7292, -3360,
    -276, 872, -248, -60, 52, -12, 1,
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_tsv(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    return metadata, list(csv.DictReader(data_lines, delimiter="\t"))


def check_frobenius(path: Path) -> tuple[str, tuple[str, ...]]:
    metadata, rows = read_tsv(path)
    expected_metadata = {
        "format": "m23_8a_fixed_field_frobenius_v1",
        "sage_version": "10.9",
        "method":
            "exact factorization of a monic irreducible polynomial at unramified primes",
        "theorem":
            "Dedekind-Frobenius cycle type from squarefree modular factorization",
        "interpretation":
            "independent cycle-type constraints on the degree-14 arithmetic Galois group",
        "polynomial_low_to_high": ",".join(map(str, EXPECTED_POLYNOMIAL)),
        "polynomial_irreducible_over_Q": "true",
        "polynomial_discriminant":
            "1136318978052477567951657541049247395217408",
        "polynomial_discriminant_factorization":
            "2^71*3^17*11^2*23^3*37^2*43^2",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected Frobenius metadata: {key}")
    revision = metadata.get("code_revision", "")
    if not REVISION.fullmatch(revision):
        raise RuntimeError("invalid Frobenius producer revision")
    if not SHA256.fullmatch(metadata.get("source_sha256", "")):
        raise RuntimeError("invalid Frobenius source hash")
    source = (ROOT / metadata["source"]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError("Frobenius source is unavailable")
    if sha256(source) != metadata["source_sha256"]:
        raise RuntimeError("Frobenius source hash mismatch")

    expected_rows = [
        {
            "prime": "7",
            "discriminant_mod_prime": "6",
            "squarefree": "true",
            "factor_degrees": "14",
            "frobenius_cycle_shape": "14",
        },
        {
            "prime": "127",
            "discriminant_mod_prime": "74",
            "squarefree": "true",
            "factor_degrees": "13,1",
            "frobenius_cycle_shape": "13,1",
        },
        {
            "prime": "53",
            "discriminant_mod_prime": "48",
            "squarefree": "true",
            "factor_degrees": "11,2,1",
            "frobenius_cycle_shape": "11,2,1",
        },
    ]
    if rows != expected_rows:
        raise RuntimeError("unexpected exact Frobenius rows")
    return revision, tuple(row["frobenius_cycle_shape"] for row in rows)


def check_groups(
    path: Path, revision: str, shapes: tuple[str, ...]
) -> None:
    metadata, rows = read_tsv(path)
    expected_metadata = {
        "format": "m23_degree14_transitive_group_audit_v1",
        "code_revision": revision,
        "gap_version": "4.12.1",
        "transgrp_version": "3.6.5",
        "degree": "14",
        "transitive_group_count": "63",
        "required_cycle_shapes": ";".join(shapes),
        "method":
            "exhaustive conjugacy-class audit of GAP TransitiveGroup(14,i)",
        "interpretation":
            "groups compatible with all exact Frobenius cycle types",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected group-audit metadata: {key}")
    if len(rows) != 63:
        raise RuntimeError("group audit does not contain all 63 groups")
    if [int(row["transitive_group_id"]) for row in rows] != list(range(1, 64)):
        raise RuntimeError("group audit IDs are incomplete or out of order")
    survivors = [row for row in rows if row["survives"] == "true"]
    if survivors != [{
        "transitive_group_id": "63",
        "order": "87178291200",
        "structure": "S14",
        "has_14": "true",
        "has_13_1": "true",
        "has_11_2_1": "true",
        "survives": "true",
    }]:
        raise RuntimeError("Frobenius constraints do not uniquely select S14")
    boolean_columns = ("has_14", "has_13_1", "has_11_2_1", "survives")
    if any(row[column] not in {"true", "false"}
           for row in rows for column in boolean_columns):
        raise RuntimeError("invalid Boolean in transitive-group audit")


def main() -> None:
    if len(sys.argv) not in {1, 3}:
        raise SystemExit(
            "usage: check_8a_fixed_field_galois.py [frobenius.tsv groups.tsv]"
        )
    if len(sys.argv) == 3:
        frobenius_path, groups_path = map(Path, sys.argv[1:])
    else:
        frobenius_path = (
            ROOT / "data/derived/m23_8a_fixed_field_frobenius.tsv"
        )
        groups_path = (
            ROOT / "data/derived/m23_degree14_transitive_group_audit.tsv"
        )
    revision, shapes = check_frobenius(frobenius_path)
    check_groups(groups_path, revision, shapes)
    print(
        "verified exact Frobenius constraints and the unique "
        "degree-14 survivor 14T63 = S14"
    )


if __name__ == "__main__":
    main()
