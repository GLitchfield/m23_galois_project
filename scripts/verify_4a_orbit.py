#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data" / "derived" / "m23_4a_4a_2a_2a_orbit.tsv"


def cycle_degree(shape: str) -> int:
    return sum(int(length) * int(count) for length, count in
               (piece.split("^") for piece in shape.split()))


def main() -> None:
    lines = [line for line in PATH.read_text().splitlines() if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    assert len(rows) == 1
    row = rows[0]
    assert row["class_vector"] == "4A,4A,2A,2A"
    assert int(row["product_one_fixed_first_tuples"]) == 609_553
    assert int(row["product_one_inner_classes"]) == 19_609
    assert int(row["generating_inner_nielsen_classes"]) == 2_456
    assert int(row["pure_braid_orbit_count"]) == 1
    assert int(row["pure_braid_orbit_size"]) == 2_456
    assert int(row["pure_genus"]) == 447
    assert int(row["symmetric_orbit_size"]) == 2_456
    assert int(row["symmetric_genus"]) == 169
    for name in ("beta12_cycle_shape", "beta13_cycle_shape",
                 "beta14_cycle_shape", "beta4_cycle_shape", "eta34_cycle_shape"):
        assert cycle_degree(row[name]) == 2_456
    assert row["beta13_cycle_shape"] == row["beta14_cycle_shape"]
    print("verified the 2,456-class pure and symmetric braid actions")


if __name__ == "__main__":
    main()
