#!/usr/bin/env sage
"""Audit the exact monodromy gate for König's published F_19 anchor."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
import re
from collections import Counter
from pathlib import Path

from sage.all import GF, PolynomialRing
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
CLASS_ATLAS = ROOT / "data" / "reference" / "m23_classes.tsv"


def metadata_and_rows(path: Path):
    lines = path.read_text().splitlines()
    metadata = dict(
        line[2:].split("\t", 1) for line in lines if line.startswith("# ")
    )
    rows = list(
        csv.DictReader(
            (line for line in lines if not line.startswith("#")),
            delimiter="\t",
        )
    )
    return metadata, rows


def parse_shape(shape: str) -> Counter[int]:
    return Counter(
        {
            int(length): int(count)
            for length, count in re.findall(r"(\d+)\^(\d+)", shape)
        }
    )


def shape_string(lengths) -> str:
    counts = Counter(lengths)
    return " ".join(
        f"{length}^{counts[length]}" for length in sorted(counts)
    )


def fixed_subsets(shape: Counter[int], subset_size: int) -> int:
    coefficients = [0] * (subset_size + 1)
    coefficients[0] = 1
    for length, count in shape.items():
        for _ in range(count):
            for index in range(subset_size, length - 1, -1):
                coefficients[index] += coefficients[index - length]
    return coefficients[subset_size]


def power_shape(shape: Counter[int], exponent: int) -> Counter[int]:
    result: Counter[int] = Counter()
    for length, count in shape.items():
        divisor = math.gcd(length, exponent)
        result[length // divisor] += count * divisor
    return result


def subset_action_cycles(shape: Counter[int], subset_size: int) -> int:
    order = math.lcm(*shape)
    return sum(
        fixed_subsets(power_shape(shape, exponent), subset_size)
        for exponent in range(order)
    ) // order


def m23_subset_orbits(class_rows, subset_size: int) -> int:
    group_order = 10_200_960
    weighted_fixed = sum(
        int(row["size"])
        * fixed_subsets(parse_shape(row["cycle_structure"]), subset_size)
        for row in class_rows
    )
    assert weighted_fixed % group_order == 0
    return weighted_fixed // group_order


def canonical_text(lines: list[str]) -> str:
    return "\n".join(lines) + "\n"


def compare_or_write(path: Path, text: str, check: bool) -> None:
    if check:
        assert path.read_text() == text
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--census", type=Path, required=True)
    parser.add_argument("--gate", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--code-revision", required=True)
    args = parser.parse_args()

    candidate_metadata, candidate_rows = metadata_and_rows(args.candidates)
    assert candidate_metadata["gap_version"] == "4.12.1"
    surviving = [
        row["transitive_id"]
        for row in candidate_rows
        if row["contained_in_A23"] == "true"
        and row["contains_required_inertia_shapes"] == "true"
    ]
    assert surviving == ["23T5", "23T6"]
    assert [candidate_rows[4]["structure"], candidate_rows[5]["structure"]] == [
        "M23",
        "A23",
    ]

    atlas_metadata, class_rows = metadata_and_rows(CLASS_ATLAS)
    assert int(atlas_metadata["group_order"]) == 10_200_960
    m23_shapes = {row["cycle_structure"] for row in class_rows}

    field = GF(19)
    ring = PolynomialRing(field, "X")
    X = ring.gen()
    f1 = X * (X**5 + X**4 - X**3 - X**2 + 7)
    f2 = X**5 + 6 * X**4 + X**3 + 4 * X**2 + 12 * X + 1
    g1 = X**3 + 2 * X**2 + 13 * X + 5
    g2 = X**3 + X**2 + 2 * X + 6
    numerator = f1**3 * f2
    denominator = g1**5 * g2

    census_rows = []
    ramified = []
    unramified_totals = {subset_size: 0 for subset_size in range(5, 12)}
    for target in field:
        polynomial = numerator - target * denominator
        if polynomial.gcd(polynomial.derivative()).degree() > 0:
            ramified.append(int(target))
            continue
        degrees = sorted(
            factor.degree()
            for factor, multiplicity in polynomial.factor()
            for _ in range(multiplicity)
        )
        cycle_shape = shape_string(degrees)
        assert cycle_shape in m23_shapes
        counts = {
            subset_size: fixed_subsets(Counter(degrees), subset_size)
            for subset_size in range(5, 12)
        }
        for subset_size, count in counts.items():
            unramified_totals[subset_size] += count
        census_rows.append((int(target), cycle_shape, counts))
    assert ramified == [0, 9, 11]
    assert len(census_rows) == 16

    atlas_hash = hashlib.sha256(CLASS_ATLAS.read_bytes()).hexdigest()
    candidate_hash = hashlib.sha256(args.candidates.read_bytes()).hexdigest()
    census_lines = [
        "# schema\tm23-koenig-f19-frobenius-census-v1",
        f"# code_revision\t{args.code_revision}",
        f"# sage_version\t{SAGE_VERSION}",
        "# field\tGF(19)",
        "# cover\tKönig dissertation Chapter 5.3 page 73",
        "# polynomial\tf1^3*f2-t*g1^5*g2",
        "# ramified_finite_values\t0,9,11",
        f"# m23_class_atlas_sha256\t{atlas_hash}",
        "t\tcycle_shape\tfixed_5_subsets\tfixed_6_subsets\tfixed_7_subsets\tfixed_8_subsets\tfixed_9_subsets\tfixed_10_subsets\tfixed_11_subsets",
    ]
    for target, cycle_shape, counts in census_rows:
        census_lines.append(
            "\t".join(
                [str(target), cycle_shape]
                + [str(counts[subset_size]) for subset_size in range(5, 12)]
            )
        )
    census_text = canonical_text(census_lines)

    inertia_shapes = [
        parse_shape("1^7 2^8"),
        parse_shape("1^7 2^8"),
        parse_shape("1^5 3^6"),
        parse_shape("1^3 5^4"),
    ]
    gate_lines = [
        "# schema\tm23-koenig-f19-transitivity-gate-v1",
        f"# code_revision\t{args.code_revision}",
        f"# sage_version\t{SAGE_VERSION}",
        "# field\tGF(19)",
        "# exact_geometric_group_candidates\tM23,A23",
        "# candidate_reason\tdegree-23 transitive, generated by even inertia, and contains all required inertia shapes",
        f"# candidate_certificate_sha256\t{candidate_hash}",
        f"# frobenius_census_sha256\t{hashlib.sha256(census_text.encode()).hexdigest()}",
        f"# m23_class_atlas_sha256\t{atlas_hash}",
        "subset_size\tsubset_degree\ta23_candidate_genus\tm23_subset_orbits\tunramified_f19_points\tasymptotic_separation_scale\tfirst_f19_extension_above_scale",
    ]
    expected = {
        5: (33_649, 7_582, 2, 8, 229_946_896, 7),
        6: (100_947, 23_060, 3, 14, 531_763_600, 7),
        7: (245_157, 56_394, 4, 28, 1_413_459_216, 8),
        8: (490_314, 113_213, 5, 28, 3_204_295_843, 8),
        9: (817_190, 189_099, 5, 18, 8_939_607_951, 8),
        10: (1_144_066, 265_048, 5, 10, 17_562_610_576, 9),
        11: (1_352_078, 313_384, 7, 28, 10_912_170_162, 8),
    }
    for subset_size in range(5, 12):
        degree = math.comb(23, subset_size)
        cycles = [
            subset_action_cycles(shape, subset_size)
            for shape in inertia_shapes
        ]
        defect = sum(degree - count for count in cycles)
        assert defect % 2 == 0
        genus = 1 - degree + defect // 2
        orbits = m23_subset_orbits(class_rows, subset_size)
        separation_numerator = 4 * genus**2
        separation_denominator = (orbits - 1) ** 2
        separation_scale = (
            separation_numerator + separation_denominator - 1
        ) // separation_denominator
        extension_degree = 1
        while 19**extension_degree <= separation_scale:
            extension_degree += 1
        row = (
            degree,
            genus,
            orbits,
            unramified_totals[subset_size],
            separation_scale,
            extension_degree,
        )
        assert row == expected[subset_size]
        gate_lines.append(
            "\t".join(
                str(value) for value in (subset_size,) + row
            )
        )
    gate_text = canonical_text(gate_lines)

    compare_or_write(args.census, census_text, args.check)
    compare_or_write(args.gate, gate_text, args.check)
    print(f"SageMath {SAGE_VERSION}")
    print("verified exact geometric monodromy candidates M23 or A23")
    print("verified all 16 unramified F_19 Frobenius shapes occur in M23")
    print(
        "verified k-set genera/orbits: the first Elkies separation scale "
        "is k=5 and requires an F_19^7 census"
    )


if __name__ == "__main__":
    main()
