#!/usr/bin/env python3
from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RESULT = ROOT / "data/derived/m23_5a_homogeneous_bridge_orbit.tsv"
EXPECTED = {
    4: {"bridge": 2_456, "degree": 7_368, "pure_size": 2_456,
        "pure_genus": 459, "symmetric_genus": 169},
    5: {"bridge": 30_400, "degree": 91_200, "pure_size": 30_400,
        "pure_genus": 5_626, "symmetric_genus": 2_071},
}


def read_rows(path: Path) -> list[dict[str, str]]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    return list(csv.DictReader(lines, delimiter="\t"))


def cycle_data(shape: str) -> tuple[int, int]:
    pieces = [tuple(map(int, piece.split("^"))) for piece in shape.split()]
    return (sum(length * count for length, count in pieces),
            sum(count for _, count in pieces))


def main() -> None:
    result_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_RESULT
    result_rows = read_rows(result_path)
    assert len(result_rows) == 1
    result = result_rows[0]
    order = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    expected = EXPECTED[order]
    degree = expected["degree"]

    assert int(result["class_order"]) == order
    assert int(result["bridge_class_count"]) == expected["bridge"]
    assert int(result["bridge_translate_count"]) == expected["bridge"]
    assert int(result["translated_pure_orbit_count"]) == 1
    assert int(result["homogeneous_class_count"]) == degree
    assert int(result["pure_braid_orbit_count"]) == 3
    assert [int(value) for value in result["pure_braid_orbit_sizes"].split(",")] == [
        expected["pure_size"]] * 3
    pure_genera = [int(value) for value in result["pure_braid_orbit_genera"].split(",")]
    assert pure_genera == [expected["pure_genus"]] * 3
    assert int(result["symmetric_orbit_count"]) == 1
    assert int(result["symmetric_orbit_sizes"]) == degree
    assert int(result["symmetric_orbit_genera"]) == expected["symmetric_genus"]

    cycle_counts: dict[str, int] = {}
    names = ("beta12_cycle_shape", "beta13_cycle_shape", "beta14_cycle_shape",
             "beta3_cycle_shape", "eta23_cycle_shape", "eta234_cycle_shape")
    for name in names:
        cycle_degree, cycle_count = cycle_data(result[name])
        assert cycle_degree == degree
        cycle_counts[name] = cycle_count
    pure_defect = degree - sum(cycle_counts[name] for name in
        ("beta12_cycle_shape", "beta13_cycle_shape", "beta14_cycle_shape"))
    symmetric_defect = degree - sum(cycle_counts[name] for name in
        ("beta3_cycle_shape", "eta23_cycle_shape", "eta234_cycle_shape"))
    assert pure_defect % 2 == symmetric_defect % 2 == 0
    pure_genus_sum = 3 + pure_defect // 2
    symmetric_genus = 1 + symmetric_defect // 2
    assert pure_genus_sum == sum(pure_genera)
    assert symmetric_genus == expected["symmetric_genus"]

    class_vector = ",".join([f"{order}A"] * 4)
    published_rows = [row for row in read_rows(
        ROOT / "data/reference/hafner_2022_braid_orbits.tsv")
        if row["class_vector"] == class_vector]
    published = {(row["action"], int(row["orbit_size"])):
                 (int(row["multiplicity"]), int(row["genus"]))
                 for row in published_rows}
    assert published[("B4", expected["pure_size"])] == (3, expected["pure_genus"])
    assert published[("symmetric", degree)] == (1, expected["symmetric_genus"])
    print(f"verified translated {order}A homogeneous components against Hafner")


if __name__ == "__main__":
    main()
