#!/usr/bin/env python3
from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RESULT = ROOT / "data/derived/m23_8a_8a_2a_2a_sharded_orbit.tsv"
DEFAULT_CERTIFICATE = ROOT / "data/derived/m23_8a_8a_2a_2a_sharded_certificate.tsv"


def read_one(path: Path) -> dict[str, str]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    assert len(rows) == 1
    return rows[0]


def read_rows(path: Path) -> list[dict[str, str]]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    return list(csv.DictReader(lines, delimiter="\t"))


def cycle_data(shape: str) -> tuple[int, int]:
    pieces = [tuple(map(int, piece.split("^"))) for piece in shape.split()]
    return (sum(length * count for length, count in pieces),
            sum(count for _, count in pieces))


def main() -> None:
    result_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_RESULT
    certificate_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_CERTIFICATE
    result = read_one(result_path)
    certificate = read_one(certificate_path)

    degree = 198_488
    assert int(result["class_order"]) == 8
    assert int(result["shard_count"]) == 64
    assert int(result["centralizer_orbit_count"]) == 489
    assert int(result["assigned_third_count"]) == 3_795
    assert int(result["product_one_fixed_first_tuples"]) == 1_827_193
    assert int(result["product_one_inner_classes"]) == 228_589
    assert int(result["generating_inner_nielsen_classes"]) == degree
    assert int(result["pure_braid_orbit_count"]) == 1
    assert result["pure_braid_orbit_sizes"] == str(degree)
    assert int(result["symmetric_orbit_count"]) == 1
    assert result["symmetric_orbit_sizes"] == str(degree)

    cycle_counts: dict[str, int] = {}
    for name in ("beta12_cycle_shape", "beta13_cycle_shape",
                 "beta14_cycle_shape", "beta4_cycle_shape", "eta34_cycle_shape"):
        cycle_degree, cycle_count = cycle_data(result[name])
        assert cycle_degree == degree
        cycle_counts[name] = cycle_count
    pure_genus = 1 + (degree - sum(cycle_counts[name] for name in
        ("beta12_cycle_shape", "beta13_cycle_shape", "beta14_cycle_shape"))) // 2
    symmetric_genus = 1 + (degree - sum(cycle_counts[name] for name in
        ("beta13_cycle_shape", "beta4_cycle_shape", "eta34_cycle_shape"))) // 2
    assert pure_genus == int(result["pure_braid_orbit_genera"]) == 41_277
    assert symmetric_genus == int(result["symmetric_orbit_genera"]) == 16_617

    expected_certificate = {
        "deep_verified": "true",
        "class_order": "8",
        "shard_count": "64",
        "centralizer_orbit_count": "489",
        "assigned_third_count": "3795",
        "product_tuple_count": "1827193",
        "product_inner_class_count": "228589",
        "generating_inner_class_count": str(degree),
        "verified_representative_count": str(degree),
    }
    assert all(certificate[name] == value for name, value in expected_certificate.items())

    class_vectors = read_rows(ROOT / "data/reference/hafner_2022_class_vectors.tsv")
    published_count = next(row for row in class_vectors
                           if row["class_vector"] == "8A,8A,2A,2A")
    assert int(published_count["published_inner_nielsen_count"]) == degree
    orbits = read_rows(ROOT / "data/reference/hafner_2022_braid_orbits.tsv")
    published = {(row["action"], int(row["orbit_size"])): int(row["genus"])
                 for row in orbits if row["class_vector"] == "8A,8A,2A,2A"}
    assert published == {("B4", degree): 41_277, ("symmetric", degree): 16_617}
    print("verified certified 8A bridge result against Hafner's 2022 preprint")


if __name__ == "__main__":
    main()
