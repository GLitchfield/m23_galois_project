#!/usr/bin/env python3
"""Independently validate the König rank-three annihilator pilot."""

from __future__ import annotations

import argparse
import hashlib
import math
import runpy
from pathlib import Path

import numpy as np

PRIME = 19
ROWS = 568
COLUMNS = 3
WIDTH = ROWS + COLUMNS
SCHEMA = "m23-koenig-a-relation-subspace-annihilator-pilot-v1"


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


def annihilator_vector(
    chart: dict[str, object], coefficients: tuple[int, ...]
) -> np.ndarray:
    modulus = int(chart["modulus"])
    residues = np.asarray(
        [value % modulus for value in coefficients], dtype=np.uint64
    )
    leading = centered(residues, modulus)
    tail = centered(
        (
            (
                (modulus - chart["chart"].astype(np.uint64))
                % modulus
            )
            @ residues
        )
        % modulus,
        modulus,
    )
    return np.concatenate((leading, tail))


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
            if row == rank:
                continue
            work[row] = (
                work[row] - work[row, column] * work[rank]
            ) % PRIME
        rank += 1
        if rank == work.shape[0]:
            break
    return rank


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_subspace_annihilator_pilot.tsv"
        ),
    )
    args = parser.parse_args()

    certificate = metadata(args.summary)
    assert certificate["schema"] == SCHEMA
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["chart_rows"]) == ROWS
    assert int(certificate["chart_columns"]) == COLUMNS
    assert int(certificate["annihilator_width"]) == WIDTH
    assert int(certificate["planted_transformed_subspace_recovered"]) == 1

    for digits in (9, 10):
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
        digits: load_chart(lift_chart, digits) for digits in (8, 9, 10)
    }
    assert int(certificate["current_modulus"]) == charts[10]["modulus"]
    assert int(certificate["previous_modulus"]) == charts[9]["modulus"]
    assert int(certificate["two_back_modulus"]) == charts[8]["modulus"]
    bound = math.isqrt((int(charts[10]["modulus"]) - 1) // 2)
    assert int(certificate["current_symmetric_bound"]) == bound

    rows = result_rows(args.summary)
    assert len(rows) == 25
    assert len(
        {row["leading_coefficients"] for row in rows}
    ) == len(rows)
    assert [row["rank"] for row in rows] == list(range(1, 26))
    for row in rows:
        coefficients = row["leading_coefficients"]
        assert isinstance(coefficients, tuple)
        assert len(coefficients) == COLUMNS
        first_nonzero = next(value for value in coefficients if value)
        assert first_nonzero > 0
        assert math.gcd(
            int(charts[10]["modulus"]), math.gcd(*coefficients)
        ) == 1

        current = annihilator_vector(charts[10], coefficients)
        previous = annihilator_vector(charts[9], coefficients)
        two_back = annihilator_vector(charts[8], coefficients)
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
    minimum_support = int(certificate["credible_minimum_support"])
    minimum_stable = int(
        certificate["credible_minimum_stable_previous"]
    )
    assert minimum_support == 2
    assert minimum_stable == math.ceil(0.9 * WIDTH)
    assert max(int(row["stable_previous"]) for row in rows) < minimum_stable
    assert int(certificate["credible_candidates"]) == 0
    assert int(certificate["credible_leading_rank"]) == 0
    assert certificate["status"] == "no_credible_rank_three_annihilator"
    assert rank_mod19(
        [
            row["leading_coefficients"]
            for row in rows
            if int(row["support"]) >= minimum_support
            and int(row["stable_previous"]) >= minimum_stable
        ]
    ) == 0
    assert int(certificate["distinct_candidates"]) >= len(rows)

    print(
        "verified bounded rank-three annihilator pilot: "
        f"{certificate['distinct_candidates']} candidates, "
        f"best stability {rows[0]['stable_previous']}/{WIDTH}, "
        "no credible rank-three basis"
    )


if __name__ == "__main__":
    main()
