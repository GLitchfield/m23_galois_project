#!/usr/bin/env python3
from __future__ import annotations

import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "data" / "reference"
M23_ORDER = 10_200_960


def read_tsv(path: Path) -> list[dict[str, str]]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    return list(csv.DictReader(lines, delimiter="\t"))


def cycle_degree(shape: str) -> int:
    return sum(int(length) * int(count) for length, count in
               (piece.split("^") for piece in shape.split()))


def verify_classes() -> None:
    rows = read_tsv(REFERENCE / "m23_classes.tsv")
    assert len(rows) == 17
    by_name = {row["class"]: row for row in rows}
    assert len(by_name) == len(rows)
    assert sum(int(row["size"]) for row in rows) == M23_ORDER

    for row in rows:
        size = int(row["size"])
        centralizer = int(row["centralizer_size"])
        order = int(row["order"])
        inverse = by_name[row["inverse_class"]]
        assert size * centralizer == M23_ORDER
        assert cycle_degree(row["cycle_structure"]) == 23
        assert math.lcm(*(int(piece.split("^")[0])
                          for piece in row["cycle_structure"].split())) == order
        assert inverse["inverse_class"] == row["class"]
        assert inverse["order"] == row["order"]
        assert inverse["size"] == row["size"]


def verify_hafner_rows() -> None:
    rows = read_tsv(REFERENCE / "hafner_2022_class_vectors.tsv")
    assert len(rows) == 27
    vectors = [row["class_vector"] for row in rows]
    assert len(vectors) == len(set(vectors))
    known_classes = {row["class"] for row in read_tsv(REFERENCE / "m23_classes.tsv")}
    for row in rows:
        assert set(row["class_vector"].split(",")) <= known_classes
        numerator, separator, denominator = row["computed_normalized_constant"].partition("/")
        floor = int(numerator) // int(denominator) if separator else int(numerator)
        assert floor == int(row["published_normalized_floor"])
        assert int(row["published_inner_nielsen_count"]) >= 0


def verify_reported_orbits() -> None:
    classes = {row["class"] for row in read_tsv(REFERENCE / "m23_classes.tsv")}
    orbits = read_tsv(REFERENCE / "hafner_2022_braid_orbits.tsv")
    assert len(orbits) == 28
    for row in orbits:
        assert set(row["class_vector"].split(",")) <= classes
        assert row["action"] in {"B4", "symmetric"}
        assert int(row["orbit_size"]) > 0
        assert int(row["multiplicity"]) > 0
        assert int(row["genus"]) >= 0
        assert row["provisional"] in {"true", "false"}

    search = read_tsv(REFERENCE / "hafner_2022_search_state.tsv")
    assert len(search) == 6
    quadratic = read_tsv(REFERENCE / "hafner_2022_quadratic_field_orbits.tsv")
    assert {(row["class_vector"], int(row["inner_nielsen_count"])) for row in quadratic} == {
        ("14A,2A,2A,2A", 84),
        ("15A,2A,2A,2A", 90),
    }


if __name__ == "__main__":
    verify_classes()
    verify_hafner_rows()
    verify_reported_orbits()
    print("verified M23 class invariants and Hafner structure constants")
