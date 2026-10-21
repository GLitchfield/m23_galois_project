#!/usr/bin/env python3
from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RESULT = ROOT / "data/derived/m23_6a_6a_2a_2a_sharded_orbit.tsv"
DEFAULT_CERTIFICATE = ROOT / "data/derived/m23_6a_6a_2a_2a_sharded_certificate.tsv"


def read_one(path: Path) -> dict[str, str]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    assert len(rows) == 1
    return rows[0]


def read_rows(path: Path) -> list[dict[str, str]]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    return list(csv.DictReader(lines, delimiter="\t"))


def cycle_degree(shape: str) -> int:
    return sum(int(length) * int(count) for length, count in
               (piece.split("^") for piece in shape.split()))


def main() -> None:
    result_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_RESULT
    certificate_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_CERTIFICATE
    result = read_one(result_path)
    certificate = read_one(certificate_path)

    assert int(result["class_order"]) == 6
    assert int(result["shard_count"]) == 32
    assert int(result["centralizer_orbit_count"]) == 345
    assert int(result["assigned_third_count"]) == 3_795
    assert int(result["product_one_fixed_first_tuples"]) == 1_221_743
    assert int(result["product_one_inner_classes"]) == 102_465
    assert int(result["generating_inner_nielsen_classes"]) == 72_528
    assert int(result["pure_braid_orbit_count"]) == 1
    assert result["pure_braid_orbit_sizes"] == "72528"
    assert result["pure_braid_orbit_genera"] == "15125"
    assert int(result["symmetric_orbit_count"]) == 1
    assert result["symmetric_orbit_sizes"] == "72528"
    assert result["symmetric_orbit_genera"] == "6065"
    for name in ("beta12_cycle_shape", "beta13_cycle_shape", "beta14_cycle_shape",
                 "beta4_cycle_shape", "eta34_cycle_shape"):
        assert cycle_degree(result[name]) == 72_528

    assert certificate["deep_verified"] == "true"
    assert int(certificate["class_order"]) == 6
    assert int(certificate["shard_count"]) == 32
    assert int(certificate["generating_inner_class_count"]) == 72_528
    assert int(certificate["verified_representative_count"]) == 72_528

    class_vectors = read_rows(ROOT / "data/reference/hafner_2022_class_vectors.tsv")
    published_count = next(row for row in class_vectors
                           if row["class_vector"] == "6A,6A,2A,2A")
    assert int(published_count["published_inner_nielsen_count"]) == 72_528
    orbits = read_rows(ROOT / "data/reference/hafner_2022_braid_orbits.tsv")
    published = {(row["action"], int(row["orbit_size"])): int(row["genus"])
                 for row in orbits if row["class_vector"] == "6A,6A,2A,2A"}
    assert published == {("B4", 72_528): 15_125, ("symmetric", 72_528): 6_065}
    print("verified certified 6A bridge result against Hafner's 2022 preprint")


if __name__ == "__main__":
    main()
