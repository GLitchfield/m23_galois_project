#!/usr/bin/env python3
"""Independently validate the supported rank-seven free-lattice pilot."""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

import numpy as np

PRIME = 19
DIMENSION = 7
CHART_COLUMNS = 7559
WIDTH = DIMENSION + CHART_COLUMNS
SCHEMA = "m23-koenig-a-relation-supported-free-lattice-pilot-v1"
CHART_SCHEMA = (
    "m23-koenig-a-relation-supported-free-quotient-chart-v1"
)


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
    numeric = set(header) - {"leading_coefficients", "configurations"}
    for line in lines[1:]:
        fields = dict(zip(header, line.split("\t"), strict=True))
        for name in numeric:
            fields[name] = int(fields[name])
        fields["leading_coefficients"] = tuple(
            map(int, str(fields["leading_coefficients"]).split(","))
        )
        result.append(fields)
    return result


def centered(values: np.ndarray, modulus: int) -> np.ndarray:
    values = np.asarray(values, dtype=np.uint64)
    return (
        ((values + modulus // 2) % modulus).astype(np.int64)
        - modulus // 2
    )


def exact_row_product(
    coefficients: tuple[int, ...],
    chart: np.ndarray,
    modulus: int,
) -> np.ndarray:
    residues = tuple(value % modulus for value in coefficients)
    return np.fromiter(
        (
            sum(
                residues[row] * int(chart[row, column])
                for row in range(DIMENSION)
            )
            % modulus
            for column in range(CHART_COLUMNS)
        ),
        dtype=np.uint64,
        count=CHART_COLUMNS,
    )


def module_vector(
    chart: np.ndarray,
    coefficients: tuple[int, ...],
    modulus: int,
) -> np.ndarray:
    leading = centered(
        np.asarray(coefficients, dtype=np.int64) % modulus, modulus
    )
    tail = centered(
        exact_row_product(coefficients, chart, modulus), modulus
    )
    return np.concatenate((leading, tail))


def rank_mod19(rows: list[tuple[int, ...]]) -> int:
    if not rows:
        return 0
    work = np.asarray(rows, dtype=np.int64) % PRIME
    rank = 0
    for column in range(work.shape[1]):
        candidates = np.flatnonzero(work[rank:, column])
        if not len(candidates):
            continue
        selected = rank + int(candidates[0])
        work[[rank, selected]] = work[[selected, rank]]
        work[rank] = (
            work[rank]
            * pow(int(work[rank, column]), -1, PRIME)
        ) % PRIME
        for row in range(work.shape[0]):
            if row != rank:
                work[row] = (
                    work[row] - work[row, column] * work[rank]
                ) % PRIME
        rank += 1
        if rank == work.shape[0]:
            break
    return rank


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "free_lattice_pilot.tsv"
        ),
    )
    parser.add_argument(
        "--free-summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "free_quotient_digits10.tsv"
        ),
    )
    parser.add_argument(
        "--chart",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "free_quotient_chart_digits10.npz"
        ),
    )
    args = parser.parse_args()

    certificate = metadata(args.summary)
    assert certificate["schema"] == SCHEMA
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["module_dimension"]) == DIMENSION
    assert int(certificate["chart_columns"]) == CHART_COLUMNS
    assert int(certificate["module_width"]) == WIDTH
    assert int(certificate["planted_gl7_module_recovered"]) == 1
    assert certificate["summary_sha256"] == sha256(args.free_summary)
    assert certificate["chart_sha256"] == sha256(args.chart)

    with np.load(args.chart) as stored:
        assert str(stored["schema"]) == CHART_SCHEMA
        charts = {
            digits: np.asarray(
                stored[f"chart_effective_digits{digits}"],
                dtype=np.uint64,
            )
            for digits in (8, 9, 10)
        }
    assert all(
        chart.shape == (DIMENSION, CHART_COLUMNS)
        for chart in charts.values()
    )
    assert np.array_equal(charts[10] % PRIME**9, charts[9])
    assert np.array_equal(charts[9] % PRIME**8, charts[8])
    moduli = {digits: PRIME**digits for digits in charts}
    assert int(certificate["current_modulus"]) == moduli[10]
    assert int(certificate["previous_modulus"]) == moduli[9]
    assert int(certificate["two_back_modulus"]) == moduli[8]
    bound = math.isqrt((moduli[10] - 1) // 2)
    assert int(certificate["current_symmetric_bound"]) == bound

    rows = result_rows(args.summary)
    recurrent_count = int(certificate["recurrent_candidates"])
    assert len(rows) == min(25, recurrent_count)
    assert [row["rank"] for row in rows] == list(
        range(1, len(rows) + 1)
    )
    assert len(
        {row["leading_coefficients"] for row in rows}
    ) == len(rows)
    for row in rows:
        coefficients = row["leading_coefficients"]
        assert isinstance(coefficients, tuple)
        assert len(coefficients) == DIMENSION
        first_nonzero = next(value for value in coefficients if value)
        assert first_nonzero > 0
        assert math.gcd(
            moduli[10], math.gcd(*coefficients)
        ) == 1

        current = module_vector(charts[10], coefficients, moduli[10])
        previous = module_vector(charts[9], coefficients, moduli[9])
        two_back = module_vector(charts[8], coefficients, moduli[8])
        assert row["maximum_absolute_coefficient"] == int(
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
        assert all(
            configuration.startswith("size=")
            and ",offset=" in configuration
            and ",weight=" in configuration
            for configuration in configurations
        )

    ordering = [
        (
            -int(row["stable_previous"]),
            -int(row["stable_two_back"]),
            int(row["maximum_absolute_coefficient"]),
            -int(row["support"]),
            row["leading_coefficients"],
        )
        for row in rows
    ]
    assert ordering == sorted(ordering)
    minimum_support = int(certificate["recurrent_minimum_support"])
    minimum_stable = int(
        certificate["credible_minimum_stable_previous"]
    )
    assert minimum_support == 2
    assert minimum_stable == math.ceil(0.9 * WIDTH)
    assert max(int(row["stable_previous"]) for row in rows) < minimum_stable
    assert int(certificate["credible_candidates"]) == 0
    assert int(certificate["credible_leading_rank"]) == 0
    assert certificate["status"] == "no_credible_rank_seven_short_module"
    assert rank_mod19(
        [
            row["leading_coefficients"]
            for row in rows
            if int(row["support"]) >= minimum_support
            and int(row["stable_previous"]) >= minimum_stable
        ]
    ) == 0
    distinct = int(certificate["distinct_candidates"])
    assert distinct >= recurrent_count >= len(rows)

    print(
        "verified supported free-lattice pilot: "
        f"{distinct} candidates, {recurrent_count} recurrent, "
        f"best stability {rows[0]['stable_previous']}/{WIDTH}, "
        "no credible rank-seven short basis"
    )


if __name__ == "__main__":
    main()
