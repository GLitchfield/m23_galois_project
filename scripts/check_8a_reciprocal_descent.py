#!/usr/bin/env python3
"""Check the exact reciprocal descent-datum artifact for the 8A map."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from barth_wenz_preprocess import Permutation  # noqa: E402
from check_8a_cover_monodromy import (  # noqa: E402
    gap_group,
    matching_classes,
)


REVISION = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_result(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    properties = {row["property"]: row["value"] for row in rows}
    if len(properties) != len(rows):
        raise RuntimeError("duplicate reciprocal-descent properties")
    return metadata, properties


def check_source(
    metadata: dict[str, str], path_key: str, hash_key: str
) -> Path:
    if not SHA256.fullmatch(metadata.get(hash_key, "")):
        raise RuntimeError(f"invalid source hash: {hash_key}")
    source = (ROOT / metadata[path_key]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError(f"descent source is unavailable: {path_key}")
    if sha256(source) != metadata[hash_key]:
        raise RuntimeError(f"descent source hash mismatch: {path_key}")
    return source


def read_monodromy(path: Path) -> dict[str, Permutation]:
    data_lines = [
        line for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("# ")
    ]
    rows = {
        row["loop"]: row
        for row in csv.DictReader(data_lines, delimiter="\t")
    }
    return {
        label: Permutation(tuple(
            int(value) - 1 for value in rows[label]["images"].split(",")
        ))
        for label in ("zero", "one", "infinity")
    }


def check(path: Path) -> None:
    metadata, properties = read_result(path)
    expected_metadata = {
        "format": "m23_8a_reciprocal_descent_v2",
        "sage_version": "10.9",
        "coefficient_involution": "t->t^-1",
        "target_mobius": "z->1-z",
        "interpretation":
            "exact reciprocal color-swap descent and split degree-14 cover",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected reciprocal metadata: {key}")
    if not REVISION.fullmatch(metadata.get("code_revision", "")):
        raise RuntimeError("invalid reciprocal producer revision")
    check_source(metadata, "candidate", "candidate_sha256")
    monodromy_path = check_source(
        metadata, "monodromy", "monodromy_sha256"
    )
    check_source(metadata, "class_ledger", "class_ledger_sha256")

    expected_properties = {
        "source_class_id": "1",
        "reciprocal_class_id": "19",
        "ordered_belyi_equivalent": "false",
        "color_swap_equivalent": "true",
        "source_mobius_maps_multiplicities": "1->1,4->4,2->2",
        "source_mobius_matrix_sha256":
            "2badeb3022b0e3995bbdc2a2ef3ab3c38167d09f2134eec5e4c39cf27967ada6",
        "source_mobius_cocycle": "true",
        "target_mobius_cocycle": "true",
        "source_cocycle_scalar_is_relative_norm": "true",
        "hilbert90_source_trivialization": "true",
        "hilbert90_source_matrix_sha256":
            "90d710d83f1b2b10516f9bb80c5ce5d8424417ebfb937f15add411c434264967",
        "target_twist_split": "true",
        "swapped_group_order": "10200960",
        "swapped_group_structure": "M23",
        "swapped_group_centralizer_order": "1",
        "swapped_class_conjugator":
            "9,22,6,13,23,14,7,18,16,11,21,17,12,10,20,1,2,19,15,3,5,4,8",
        "ordered_descent_to_fixed_field": "false",
        "color_swap_descent_datum": "true",
        "source_twist_split": "true",
        "descended_cover_degree": "23",
        "descended_coefficient_field_degree": "14",
        "descended_map_sha256":
            "b79065595fbe8c355494b5dc9631d16fbeda6427265b98e998ee21c3eed935ae",
        "descended_finite_branch_polynomial": "W^2-(y^2-4)/4",
        "descended_branch_points_individually_fixed": "false",
    }
    if properties != expected_properties:
        missing = set(expected_properties) - set(properties)
        extra = set(properties) - set(expected_properties)
        wrong = {
            key for key in set(properties) & set(expected_properties)
            if properties[key] != expected_properties[key]
        }
        raise RuntimeError(
            "reciprocal-descent properties changed: "
            f"missing={missing}, extra={extra}, wrong={wrong}"
        )

    permutations = read_monodromy(monodromy_path)
    matches = matching_classes(
        permutations["one"], permutations["zero"]
    )
    if len(matches) != 1 or matches[0][0] != 19:
        raise RuntimeError(f"swapped class does not reproduce: {matches}")
    group = gap_group(permutations["one"], permutations["zero"])
    if group != (10_200_960, "M23", 1):
        raise RuntimeError(f"swapped monodromy group changed: {group}")


def main() -> None:
    if len(sys.argv) not in {2, 3}:
        raise SystemExit(
            f"usage: {sys.argv[0]} RECIPROCAL_DESCENT.tsv "
            "[DESCENDED_COVER.json]"
        )
    check(Path(sys.argv[1]))
    if len(sys.argv) == 3:
        cover = json.loads(
            Path(sys.argv[2]).read_text(encoding="utf-8")
        )
        encoded = json.dumps(
            {
                "numerator": cover["map"]["numerator"],
                "denominator": cover["map"]["denominator"],
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        map_hash = hashlib.sha256(encoded).hexdigest()
        _, properties = read_result(Path(sys.argv[1]))
        if map_hash != properties["descended_map_sha256"]:
            raise RuntimeError("descended-cover map hash mismatch")
    print(
        "verified reciprocal class 1->19, exact color swap, "
        "and source Möbius cocycle"
    )


if __name__ == "__main__":
    main()
