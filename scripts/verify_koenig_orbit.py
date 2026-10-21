#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data" / "derived" / "m23_koenig_2a2a3a5a_orbit.tsv"


def cycle_data(shape: str) -> tuple[int, int]:
    pieces = [tuple(map(int, part.split("^"))) for part in shape.split()]
    return sum(length * count for length, count in pieces), sum(
        count for _, count in pieces
    )


def main() -> None:
    raw_lines = PATH.read_text().splitlines()
    metadata = dict(
        line[2:].split("\t", 1) for line in raw_lines if line.startswith("# ")
    )
    assert metadata["generated_by"] == (
        "scripts/gap/reproduce_koenig_2A_2A_3A_5A.g"
    )
    assert re.fullmatch(r"[0-9a-f]{40}", metadata["code_revision"])
    assert metadata["gap_version"] == "4.12.1"
    assert metadata["atlasrep_version"] == "2.1.8"
    assert metadata["ctbllib_version"] == "1.3.7"
    assert metadata["transgrp_version"] == "3.6.5"
    assert int(metadata["group_order"]) == 10_200_960

    rows = list(
        csv.DictReader(
            (line for line in raw_lines if not line.startswith("#")),
            delimiter="\t",
        )
    )
    assert len(rows) == 1
    row = rows[0]
    assert row["class_vector"] == "3A,5A,2A,2A"
    assert int(row["product_one_fixed_first_tuples"]) == 1_526_400
    assert int(row["product_one_inner_classes"]) == 8_490
    assert int(row["generating_inner_nielsen_classes"]) == 980
    assert int(row["pure_braid_orbit_count"]) == 1
    assert row["pure_braid_orbit_sizes"] == "980"
    assert int(row["pure_genus"]) == 119
    assert int(row["symmetric_orbit_count"]) == 1
    assert int(row["symmetric_orbit_size"]) == 980
    assert int(row["symmetric_genus"]) == 43

    shapes = {
        name: cycle_data(row[name])
        for name in (
            "beta12_cycle_shape",
            "beta13_cycle_shape",
            "beta14_cycle_shape",
            "beta4_cycle_shape",
            "eta34_cycle_shape",
        )
    }
    assert all(degree == 980 for degree, _ in shapes.values())
    pure_cycles = sum(shapes[name][1] for name in (
        "beta12_cycle_shape",
        "beta13_cycle_shape",
        "beta14_cycle_shape",
    ))
    symmetric_cycles = sum(shapes[name][1] for name in (
        "beta13_cycle_shape",
        "beta4_cycle_shape",
        "eta34_cycle_shape",
    ))
    assert 1 - 980 + (3 * 980 - pure_cycles) // 2 == 119
    assert 1 - 980 + (3 * 980 - symmetric_cycles) // 2 == 43
    print("verified König's 980-class orbit and genera 119/43")


if __name__ == "__main__":
    main()
