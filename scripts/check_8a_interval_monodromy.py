#!/usr/bin/env python3
"""Check the rigorous interval certificate for the exact 8A cover monodromy."""

from __future__ import annotations

import csv
from decimal import Decimal
import hashlib
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


EXPECTED_CYCLES = {
    "zero": (8, 8, 4, 2, 1),
    "one": (8, 8, 4, 2, 1),
    "infinity": (2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1),
}
REVISION = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_result(
    path: Path,
) -> tuple[dict[str, str], dict[str, dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    by_loop = {row["loop"]: row for row in rows}
    if len(rows) != 3 or set(by_loop) != set(EXPECTED_CYCLES):
        raise RuntimeError("interval result must contain exactly three loops")
    return metadata, by_loop


def permutation(row: dict[str, str]) -> Permutation:
    images = tuple(int(value) - 1 for value in row["images"].split(","))
    if len(images) != 23 or set(images) != set(range(23)):
        raise RuntimeError("row is not a degree-23 permutation")
    return Permutation(images)


def inverse_product(left: Permutation, right: Permutation) -> Permutation:
    return left.then(right).inverse()


def check_source(
    metadata: dict[str, str], path_key: str, hash_key: str
) -> None:
    if not SHA256.fullmatch(metadata.get(hash_key, "")):
        raise RuntimeError(f"invalid source hash: {hash_key}")
    source = (ROOT / metadata[path_key]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError(f"certificate source is unavailable: {path_key}")
    if sha256(source) != metadata[hash_key]:
        raise RuntimeError(f"certificate source hash mismatch: {path_key}")


def check(path: Path) -> tuple[int, tuple[int, ...]]:
    metadata, rows = read_result(path)
    expected_metadata = {
        "format": "m23_8a_interval_monodromy_v1",
        "precision_bits": "512",
        "steps_per_loop": "8192",
        "sage_version": "10.9",
        "basepoint": "0.5",
        "parameter_enclosure":
            "trig interval enclosure of each complete arc",
        "root_model":
            "affine predictor plus complex interval error box",
        "proof_condition":
            "strict self-map and contraction bound below one",
        "all_segments_certified": "true",
        "segment_root_tubes_pairwise_disjoint": "true",
        "adjacent_endpoint_matching_bijective": "true",
        "interpretation":
            "trig-and-coefficient interval certificate for exact cover monodromy",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected interval metadata: {key}")
    if not REVISION.fullmatch(metadata.get("code_revision", "")):
        raise RuntimeError("invalid interval producer revision")
    check_source(metadata, "candidate", "candidate_sha256")
    check_source(metadata, "recovery", "recovery_sha256")
    check_source(
        metadata, "embedding_source", "embedding_source_sha256"
    )

    permutations = {
        label: permutation(row) for label, row in rows.items()
    }
    for label, expected in EXPECTED_CYCLES.items():
        recorded = tuple(
            int(value) for value in rows[label]["cycle_lengths"].split(",")
        )
        actual = tuple(sorted(
            (len(cycle) for cycle in permutations[label].cycles()),
            reverse=True,
        ))
        if recorded != expected or actual != expected:
            raise RuntimeError(f"{label} cycle partition mismatch")
    if inverse_product(
        permutations["zero"], permutations["one"]
    ) != permutations["infinity"]:
        raise RuntimeError("interval monodromy permutations violate product one")

    steps = int(metadata["steps_per_loop"])
    for label in ("zero", "one"):
        row = rows[label]
        if int(row["segment_count"]) != steps:
            raise RuntimeError(f"incomplete interval loop: {label}")
        contraction = Decimal(row["maximum_contraction_bound"])
        if not contraction.is_finite() or not 0 <= contraction < 1:
            raise RuntimeError(f"invalid contraction bound: {label}")
        diameter = Decimal(row["maximum_tube_diameter"])
        if not diameter.is_finite() or not 0 < diameter < Decimal("0.01"):
            raise RuntimeError(f"invalid root-tube diameter: {label}")

    size, structure, centralizer_size = gap_group(
        permutations["zero"], permutations["one"]
    )
    if (size, structure, centralizer_size) != (10_200_960, "M23", 1):
        raise RuntimeError(
            "unexpected interval monodromy group: "
            f"{size}, {structure}, centralizer {centralizer_size}"
        )
    matches = matching_classes(
        permutations["zero"], permutations["one"]
    )
    if len(matches) != 1 or matches[0][0] != 1:
        raise RuntimeError(f"unexpected M23 inner-class matches: {matches}")
    return matches[0]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} INTERVAL_MONODROMY.tsv")
    class_id, conjugator = check(Path(sys.argv[1]))
    print(
        f"verified rigorous exact-cover monodromy, M23, and inner class "
        f"{class_id}; conjugator="
        + ",".join(str(value + 1) for value in conjugator)
    )


if __name__ == "__main__":
    main()
