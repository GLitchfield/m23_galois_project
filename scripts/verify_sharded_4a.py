#!/usr/bin/env python3
from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MONOLITHIC = ROOT / "data" / "derived" / "m23_4a_4a_2a_2a_orbit.tsv"


def read_one(path: Path) -> dict[str, str]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    assert len(rows) == 1
    return rows[0]


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify_sharded_4a.py RESULT CERTIFICATE")
    sharded = read_one(Path(sys.argv[1]))
    certificate = read_one(Path(sys.argv[2]))
    monolithic = read_one(MONOLITHIC)

    assert int(sharded["class_order"]) == 4
    assert int(sharded["shard_count"]) == 4
    assert int(sharded["centralizer_orbit_count"]) == 144
    assert int(sharded["assigned_third_count"]) == 3_795
    mappings = {
        "product_one_fixed_first_tuples": "product_one_fixed_first_tuples",
        "product_one_inner_classes": "product_one_inner_classes",
        "generating_inner_nielsen_classes": "generating_inner_nielsen_classes",
    }
    for sharded_name, monolithic_name in mappings.items():
        assert sharded[sharded_name] == monolithic[monolithic_name]
    assert int(sharded["pure_braid_orbit_count"]) == 1
    assert sharded["pure_braid_orbit_sizes"] == "2456"
    assert sharded["pure_braid_orbit_genera"] == monolithic["pure_genus"]
    assert int(sharded["symmetric_orbit_count"]) == 1
    assert sharded["symmetric_orbit_sizes"] == "2456"
    assert sharded["symmetric_orbit_genera"] == monolithic["symmetric_genus"]
    for name in ("beta12_cycle_shape", "beta13_cycle_shape", "beta14_cycle_shape",
                 "beta4_cycle_shape", "eta34_cycle_shape"):
        assert sharded[name] == monolithic[name]

    assert int(certificate["schema_version"]) == 1
    assert certificate["deep_verified"] == "true"
    assert int(certificate["class_order"]) == 4
    assert int(certificate["shard_count"]) == 4
    assert int(certificate["centralizer_orbit_count"]) == 144
    assert int(certificate["assigned_third_count"]) == 3_795
    assert int(certificate["generating_inner_class_count"]) == 2_456
    assert int(certificate["verified_representative_count"]) == 2_456
    print("verified four-shard result against the monolithic 4A computation")


if __name__ == "__main__":
    main()
