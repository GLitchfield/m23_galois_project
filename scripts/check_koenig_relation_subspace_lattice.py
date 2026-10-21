#!/usr/bin/env python3
"""Independently validate the König simultaneous-denominator pilot."""

from __future__ import annotations

import argparse
import hashlib
import math
import runpy
from pathlib import Path

import numpy as np

PRIME = 19
ENTRIES = 1704
SCHEMAS = {
    "m23-koenig-a-relation-subspace-lattice-pilot-v1": 9,
    "m23-koenig-a-relation-subspace-lattice-pilot-v2": 10,
}
UNRESOLVED_COUNTS = {9: 718, 10: 723}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def result_rows(path: Path) -> list[dict[str, object]]:
    lines = [
        line
        for line in path.read_text().splitlines()
        if line and not line.startswith("#")
    ]
    header = lines[0].split("\t")
    result = []
    for line in lines[1:]:
        fields = dict(zip(header, line.split("\t"), strict=True))
        for name in header[:-1]:
            fields[name] = int(fields[name])
        result.append(fields)
    return result


def centered_product(chart: np.ndarray, denominator: int, modulus: int):
    product = (
        chart.astype(np.uint64) * np.uint64(denominator)
    ) % modulus
    return (
        (product.astype(np.int64) + modulus // 2) % modulus
    ) - modulus // 2


def load_chart(lift_chart, digits: int) -> dict[str, object]:
    reduced_path = Path(
        "data/derived/"
        "m23_koenig_a_relation_homogeneous_degree110_"
        f"digits{digits}_reduced.npz"
    )
    with np.load(reduced_path) as stored:
        reduced = np.vstack(
            (stored["reduced_training"], stored["reduced_holdout"])
        )
    return lift_chart(reduced, digits)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_subspace_lattice_pilot.tsv"
        ),
    )
    args = parser.parse_args()

    certificate = metadata(args.summary)
    current_digits = SCHEMAS[certificate["schema"]]
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["chart_entries"]) == ENTRIES
    assert (
        int(certificate["unresolved_scalar_entries"])
        == UNRESOLVED_COUNTS[current_digits]
    )
    assert int(certificate["planted_denominator"]) == 12347
    assert int(certificate["planted_denominator_recovered"]) == 1

    for digits in (current_digits - 1, current_digits):
        for kind, suffix in (("summary", ".tsv"), ("reduced", "_reduced.npz")):
            path = Path(
                "data/derived/"
                "m23_koenig_a_relation_homogeneous_degree110_"
                f"digits{digits}{suffix}"
            )
            assert certificate[f"{kind}{digits}_sha256"] == sha256(path)

    independent = runpy.run_path(
        "scripts/check_koenig_relation_subspace_reconstruction.py"
    )
    lift_chart = independent["lift_chart"]
    charts = {
        digits: load_chart(lift_chart, digits)
        for digits in range(current_digits - 2, current_digits + 1)
    }
    assert (
        int(certificate["current_modulus"])
        == charts[current_digits]["modulus"]
    )
    assert (
        int(certificate["previous_modulus"])
        == charts[current_digits - 1]["modulus"]
    )
    assert (
        int(certificate["two_back_modulus"])
        == charts[current_digits - 2]["modulus"]
    )
    bound = math.isqrt(
        (int(charts[current_digits]["modulus"]) - 1) // 2
    )
    assert int(certificate["current_symmetric_bound"]) == bound

    rows = result_rows(args.summary)
    assert len(rows) == 25
    assert len({row["denominator"] for row in rows}) == len(rows)
    expected_ranks = list(range(1, len(rows) + 1))
    assert [row["rank"] for row in rows] == expected_ranks
    for row in rows:
        denominator = int(row["denominator"])
        assert (
            0
            < denominator
            <= int(charts[current_digits]["modulus"]) // 2
        )
        assert math.gcd(denominator, PRIME) == 1
        current = centered_product(
            charts[current_digits]["chart"],
            denominator,
            int(charts[current_digits]["modulus"]),
        ).reshape(-1)
        previous = centered_product(
            charts[current_digits - 1]["chart"],
            denominator,
            int(charts[current_digits - 1]["modulus"]),
        ).reshape(-1)
        two_back = centered_product(
            charts[current_digits - 2]["chart"],
            denominator,
            int(charts[current_digits - 2]["modulus"]),
        ).reshape(-1)
        assert row["maximum_absolute_numerator"] == int(
            np.max(np.abs(current))
        )
        assert row["squared_norm"] == sum(
            int(value) ** 2 for value in current
        )
        assert row["within_symmetric_bound"] == int(
            np.count_nonzero(np.abs(current) <= bound)
        )
        assert row["stable_previous"] == int(
            np.count_nonzero(current == previous)
        )
        assert row["stable_two_back"] == int(
            np.count_nonzero(
                (current == previous) & (current == two_back)
            )
        )
        configurations = str(row["configurations"]).split(";")
        assert row["support"] == len(set(configurations))

    ordering = [
        (
            -int(row["stable_previous"]),
            -int(row["stable_two_back"]),
            int(row["maximum_absolute_numerator"]),
            -int(row["support"]),
            int(row["denominator"]),
        )
        for row in rows
    ]
    assert ordering == sorted(ordering)
    minimum_support = int(certificate["credible_minimum_support"])
    minimum_stable = int(
        certificate["credible_minimum_stable_previous"]
    )
    assert minimum_support == 2
    assert minimum_stable == math.ceil(0.9 * ENTRIES)
    assert max(int(row["stable_previous"]) for row in rows) < (
        minimum_stable
    )
    assert int(certificate["credible_candidates"]) == 0
    assert certificate["status"] == (
        "no_credible_shared_denominator_candidate"
    )
    assert int(certificate["distinct_candidates"]) >= len(rows)

    print(
        "verified bounded simultaneous-denominator pilot: "
        f"{certificate['distinct_candidates']} candidates, "
        f"best stability {rows[0]['stable_previous']}/{ENTRIES}, "
        "none credible"
    )


if __name__ == "__main__":
    main()
