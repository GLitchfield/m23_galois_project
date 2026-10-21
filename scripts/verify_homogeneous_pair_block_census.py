#!/usr/bin/env python3
from __future__ import annotations

import csv
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "data" / "reference"
M23_ORDER = 10_200_960
EXPECTED_TOTALS = {
    "4A": {"pairs": 10_099, "macroblocks": 7_928_185},
    "5A": {"pairs": 45_344, "macroblocks": 161_177_452},
}
EXPECTED_FAMILIES = {
    "1A", "2A", "3A", "4A", "5A", "6A", "7AB", "8A",
    "11AB", "14AB", "15AB", "23AB",
}


def read_rows(path: Path) -> list[dict[str, str]]:
    lines = [line for line in path.read_text().splitlines() if not line.startswith("#")]
    return list(csv.DictReader(lines, delimiter="\t"))


def shape_count(shape: str) -> int:
    return sum(int(piece.split("^")[1]) for piece in shape.split())


def main() -> None:
    rows = read_rows(REFERENCE / "m23_homogeneous_pair_block_census.tsv")
    assert len(rows) == 24
    vectors = {row["class_vector"]: Fraction(row["computed_normalized_constant"])
               for row in read_rows(REFERENCE / "hafner_2022_class_vectors.tsv")}

    for target, expected in EXPECTED_TOTALS.items():
        target_rows = [row for row in rows if row["target_class"] == target]
        assert {row["product_family"] for row in target_rows} == EXPECTED_FAMILIES
        assert {int(row["total_pair_orbit_count"]) for row in target_rows} == {
            expected["pairs"]}
        assert {int(row["total_macroblock_count"]) for row in target_rows} == {
            expected["macroblocks"]}
        assert sum(int(row["pair_orbit_count"]) for row in target_rows) == expected["pairs"]
        assert sum(int(row["macroblock_count"]) for row in target_rows) == expected["macroblocks"]

        normalized_total = sum(Fraction(row["normalized_inner_weight"])
                               for row in target_rows)
        reference_total = vectors[",".join([target] * 4)]
        assert normalized_total == reference_total
        assert {Fraction(row["total_normalized_inner_weight"])
                for row in target_rows} == {reference_total}

        for row in target_rows:
            family = row["product_family"]
            family_count = int(row["family_class_count"])
            assert family_count == (2 if family.endswith("AB") else 1)
            assert int(row["product_class_size"]) * int(row["centralizer_order"]) == M23_ORDER
            pair_count = int(row["pair_orbit_count"])
            assert shape_count(row["pair_stabilizer_shape"]) == pair_count
            expected_macroblocks = pair_count * pair_count // family_count
            assert int(row["macroblock_count"]) == expected_macroblocks
            twist_order = int(family.removesuffix("AB").removesuffix("A"))
            assert int(row["twist_order"]) == twist_order
            if row["cyclic_centralizer"] == "true":
                assert int(row["twist_index"]) * twist_order == int(row["centralizer_order"])
            else:
                assert row["cyclic_centralizer"] == "false"
                assert row["twist_index"] == "-"

    print("verified exact homogeneous pair-product block census")


if __name__ == "__main__":
    main()
