#!/usr/bin/env python3
"""Independently validate the supported hard-column lattice pilot."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np

from check_koenig_relation_supported_free_lattice import (
    CHART_COLUMNS,
    CHART_SCHEMA,
    DIMENSION,
    PRIME,
    WIDTH,
    metadata,
    module_vector,
    rank_mod19,
    sha256,
)

SCHEMA = "m23-koenig-a-relation-supported-hard-lattice-pilot-v1"


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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "hard_lattice_pilot.tsv"
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
    assert int(certificate["planted_hard_gl7_module_recovered"]) == 1
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
    moduli = {digits: PRIME**digits for digits in charts}
    assert np.array_equal(charts[10] % moduli[9], charts[9])
    assert np.array_equal(charts[9] % moduli[8], charts[8])
    assert int(certificate["current_modulus"]) == moduli[10]
    assert int(certificate["previous_modulus"]) == moduli[9]
    assert int(certificate["two_back_modulus"]) == moduli[8]
    bound = math.isqrt((moduli[10] - 1) // 2)
    assert int(certificate["current_symmetric_bound"]) == bound

    centered = {
        digits: (
            (
                charts[digits].astype(np.uint64)
                + moduli[digits] // 2
            )
            % moduli[digits]
        ).astype(np.int64)
        - moduli[digits] // 2
        for digits in charts
    }
    stable = (
        (centered[10] == centered[9])
        & (centered[10] == centered[8])
    )
    stable_counts = stable.sum(axis=0)
    unstable_previous = (centered[10] != centered[9]).sum(axis=0)
    fully_unstable = int(np.count_nonzero(stable_counts == 0))
    partially_stable = int(
        np.count_nonzero(
            (stable_counts > 0) & (stable_counts < DIMENSION)
        )
    )
    fully_stable = int(np.count_nonzero(stable_counts == DIMENSION))
    assert int(certificate["fully_unstable_columns"]) == fully_unstable
    assert int(certificate["partially_stable_columns"]) == partially_stable
    assert int(certificate["fully_stable_columns"]) == fully_stable
    assert int(certificate["fully_unstable_previous7"]) == int(
        np.count_nonzero(
            (stable_counts == 0) & (unstable_previous == DIMENSION)
        )
    )
    assert (fully_unstable, partially_stable, fully_stable) == (
        5437,
        106,
        2016,
    )

    rows = result_rows(args.summary)
    evaluated = int(certificate["evaluated_candidates"])
    assert len(rows) == min(25, evaluated)
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
        blocks = {
            configuration.rsplit(",weight=", 1)[0]
            for configuration in configurations
        }
        assert row["support_configurations"] == len(set(configurations))
        assert row["support_blocks"] == len(blocks)
        assert all(
            block.startswith("size=")
            and ",route=" in block
            and ",offset=" in block
            and ",step=" in block
            for block in blocks
        )

    ordering = [
        (
            -int(row["stable_previous"]),
            -int(row["stable_two_back"]),
            int(row["maximum_absolute_coefficient"]),
            -int(row["support_blocks"]),
            -int(row["support_configurations"]),
            row["leading_coefficients"],
        )
        for row in rows
    ]
    assert ordering == sorted(ordering)
    minimum_blocks = int(
        certificate["recurrent_minimum_independent_blocks"]
    )
    minimum_stable = int(
        certificate["credible_minimum_stable_previous"]
    )
    assert minimum_blocks == 2
    assert minimum_stable == math.ceil(0.9 * WIDTH)
    assert int(certificate["recurrent_candidates"]) == 0
    assert all(int(row["support_blocks"]) == 1 for row in rows)
    assert max(int(row["stable_previous"]) for row in rows) < minimum_stable
    assert int(certificate["credible_candidates"]) == 0
    assert int(certificate["credible_leading_rank"]) == 0
    assert certificate["status"] == (
        "no_credible_rank_seven_hard_lattice_module"
    )
    assert rank_mod19(
        [
            row["leading_coefficients"]
            for row in rows
            if int(row["support_blocks"]) >= minimum_blocks
            and int(row["stable_previous"]) >= minimum_stable
        ]
    ) == 0
    distinct = int(certificate["distinct_candidates"])
    assert evaluated == distinct
    assert distinct >= len(rows)

    print(
        "verified supported hard-lattice pilot: "
        f"{fully_unstable} hard columns, {distinct} candidates, "
        f"0 recurrent, best stability {rows[0]['stable_previous']}/{WIDTH}"
    )


if __name__ == "__main__":
    main()
