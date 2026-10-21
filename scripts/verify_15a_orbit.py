#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data" / "derived" / "m23_15a_2a3_orbit.tsv"


def main() -> None:
    lines = [line for line in PATH.read_text().splitlines() if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    assert len(rows) == 2
    assert {int(row["computed_class_number"]) for row in rows} == {9, 10}
    for row in rows:
        assert int(row["fixed_first_order"]) == 15
        assert int(row["fixed_first_centralizer_size"]) == 15
        assert int(row["product_one_fixed_first_tuples"]) == 3150
        assert int(row["product_one_inner_classes"]) == 210
        assert int(row["generating_inner_nielsen_classes"]) == 90
        assert int(row["pure_braid_orbit_size"]) == 90
        assert int(row["pure_braid_genus"]) == 4
        assert int(row["symmetric_genus"]) == 0
        assert row["beta3_cycle_shape"] == "3^1 4^2 5^5 6^9"
        assert row["eta23_cycle_shape"] == "2^45"
        assert row["eta234_cycle_shape"] == "3^30"
    print("verified both order-15 class computations and published symmetry data")


if __name__ == "__main__":
    main()
