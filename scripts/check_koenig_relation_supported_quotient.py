#!/usr/bin/env python3
"""Independently validate the supported König quotient chart."""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

import numpy as np

PRIME = 19
TARGET_BASE_DIGITS = 4
DIMENSION = 7
NUMERATOR_COLUMNS = 9506
SELECTED_COLUMNS = 7566
SCHEMA = "m23-koenig-a-relation-supported-quotient-reconstruction-v1"
CHART_SCHEMA = "m23-koenig-a-relation-supported-quotient-chart-v1"
SUPPORT_SCHEMA = "m23-koenig-a-relation-supported-subspace-v1"
REPRESENTATIVE_SCHEMA = (
    "m23-koenig-a-relation-supported-subspace-representatives-v1"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def result_rows(path: Path) -> list[dict[str, int]]:
    lines = [
        line
        for line in path.read_text().splitlines()
        if line and not line.startswith("#")
    ]
    header = lines[0].split("\t")
    return [
        {
            name: int(value)
            for name, value in zip(
                header, line.split("\t"), strict=True
            )
        }
        for line in lines[1:]
    ]


def arrays_sha256(
    charts: dict[int, np.ndarray],
    pivots: np.ndarray,
    nonpivots: np.ndarray,
    selected: np.ndarray,
) -> str:
    digest = hashlib.sha256()
    for digits in sorted(charts):
        digest.update(
            np.asarray(charts[digits], dtype=np.uint64).tobytes()
        )
    digest.update(np.asarray(pivots, dtype=np.int32).tobytes())
    digest.update(np.asarray(nonpivots, dtype=np.int32).tobytes())
    digest.update(np.asarray(selected, dtype=np.int32).tobytes())
    return digest.hexdigest()


def representative_arrays_sha256(
    lifts: np.ndarray, free_columns: np.ndarray
) -> str:
    digest = hashlib.sha256()
    digest.update(np.asarray(lifts, dtype=np.uint64).tobytes())
    digest.update(np.asarray(free_columns, dtype=np.int32).tobytes())
    return digest.hexdigest()


def row_space_rref(
    values: np.ndarray,
) -> tuple[np.ndarray, tuple[int, ...]]:
    work = np.asarray(values, dtype=np.int64).copy() % PRIME
    pivot_row = 0
    pivots = []
    for column in range(work.shape[1]):
        candidates = np.flatnonzero(work[pivot_row:, column])
        if not len(candidates):
            continue
        selected = pivot_row + int(candidates[0])
        work[[pivot_row, selected]] = work[[selected, pivot_row]]
        inverse = pow(int(work[pivot_row, column]), -1, PRIME)
        work[pivot_row] = (work[pivot_row] * inverse) % PRIME
        factors = work[:, column].copy()
        factors[pivot_row] = 0
        work = (
            work - factors[:, None] * work[pivot_row][None, :]
        ) % PRIME
        pivots.append(column)
        pivot_row += 1
        if pivot_row == work.shape[0]:
            break
    return work[:pivot_row].astype(np.uint64), tuple(pivots)


def rational_reconstruction(
    residue: int, modulus: int
) -> tuple[int, int] | None:
    bound = math.isqrt((modulus - 1) // 2)
    old_remainder, remainder = modulus, residue
    old_coefficient, coefficient = 0, 1
    while remainder > bound:
        quotient = old_remainder // remainder
        old_remainder, remainder = (
            remainder,
            old_remainder - quotient * remainder,
        )
        old_coefficient, coefficient = (
            coefficient,
            old_coefficient - quotient * coefficient,
        )
    numerator = remainder
    denominator = coefficient
    if denominator < 0:
        numerator = -numerator
        denominator = -denominator
    if (
        denominator == 0
        or denominator > bound
        or math.gcd(numerator, denominator) != 1
        or math.gcd(denominator, modulus) != 1
        or (residue * denominator - numerator) % modulus
    ):
        return None
    return numerator, denominator


def reconstruct(
    chart: np.ndarray, modulus: int
) -> dict[int, tuple[int, int]]:
    result = {}
    for index, residue in enumerate(chart.reshape(-1)):
        value = rational_reconstruction(int(residue), modulus)
        if value is not None:
            result[index] = value
    return result


def self_test() -> None:
    base = np.asarray(
        [[1, 0, 2, 3], [0, 1, 4, 5]], dtype=np.uint64
    )
    changed = (
        np.asarray([[2, 1], [1, 1]], dtype=np.uint64) @ base
    ) % PRIME
    first, first_pivots = row_space_rref(base)
    second, second_pivots = row_space_rref(changed)
    assert first_pivots == second_pivots == (0, 1)
    assert np.array_equal(first, second)
    assert rational_reconstruction(PRIME**4 - 3, PRIME**4) == (-3, 1)
    print("independent supported quotient chart self-test passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "quotient_reconstruction_digits10.tsv"
        ),
    )
    parser.add_argument(
        "--chart",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "quotient_chart_digits10.npz"
        ),
    )
    parser.add_argument(
        "--support-summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_digits10.tsv"
        ),
    )
    parser.add_argument(
        "--support-representatives",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "digits10_representatives.npz"
        ),
    )
    parser.add_argument(
        "--reduced",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_homogeneous_degree110_"
            "digits10_reduced.npz"
        ),
    )
    parser.add_argument(
        "--basis",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation_basis.npz"),
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return

    certificate = metadata(args.summary)
    support = metadata(args.support_summary)
    assert certificate["schema"] == SCHEMA
    assert support["schema"] == SUPPORT_SCHEMA
    assert certificate["support_summary_sha256"] == sha256(
        args.support_summary
    )
    assert certificate["support_representatives_sha256"] == sha256(
        args.support_representatives
    )
    assert certificate["basis_sha256"] == sha256(args.basis)
    assert support["basis_sha256"] == certificate["basis_sha256"]
    assert support["status"] == "beta_degree_block_persists"

    digits = int(certificate["digits"])
    modulus = PRIME**digits
    cutoff = int(certificate["beta_degree_cutoff"])
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["modulus"]) == modulus
    assert int(certificate["quotient_dimension"]) == DIMENSION
    assert int(certificate["selected_numerator_columns"]) == (
        SELECTED_COLUMNS
    )
    assert int(certificate["chart_rows"]) == DIMENSION
    assert int(certificate["chart_columns"]) == (
        SELECTED_COLUMNS - DIMENSION
    )
    assert int(certificate["chart_entries"]) == (
        DIMENSION * (SELECTED_COLUMNS - DIMENSION)
    )
    assert int(support["final_quotient_dimension"]) == DIMENSION

    with np.load(args.chart) as stored:
        assert str(stored["schema"]) == CHART_SCHEMA
        assert int(stored["prime"]) == PRIME
        assert int(stored["digits"]) == digits
        assert int(stored["modulus"]) == modulus
        assert int(stored["beta_cutoff"]) == cutoff
        charts = {
            current_digits: np.asarray(
                stored[f"chart_digit{current_digits}"],
                dtype=np.uint64,
            )
            for current_digits in range(
                TARGET_BASE_DIGITS, digits + 1
            )
        }
        pivots = np.asarray(stored["pivot_columns"], dtype=np.int32)
        nonpivots = np.asarray(
            stored["nonpivot_columns"], dtype=np.int32
        )
        selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
    for current_digits, chart in charts.items():
        assert chart.shape == (
            DIMENSION,
            SELECTED_COLUMNS - DIMENSION,
        )
        assert np.all(chart < PRIME**current_digits)
    assert np.array_equal(
        np.sort(np.concatenate((pivots, nonpivots))),
        np.arange(SELECTED_COLUMNS, dtype=np.int32),
    )
    assert certificate["pivot_columns"] == ",".join(map(str, pivots))
    assert certificate["chart_arrays_sha256"] == arrays_sha256(
        charts, pivots, nonpivots, selected
    )

    with np.load(args.basis) as stored:
        numerator_specs = np.asarray(
            stored["numerator_specs"], dtype=np.int32
        )
    expected_selected = np.asarray(
        [
            position
            for position, (_, beta_degree) in enumerate(numerator_specs)
            if beta_degree <= cutoff
        ],
        dtype=np.int32,
    )
    assert len(numerator_specs) == NUMERATOR_COLUMNS
    assert np.array_equal(selected, expected_selected)

    with np.load(args.support_representatives) as stored:
        assert str(stored["schema"]) == REPRESENTATIVE_SCHEMA
        lifts = np.asarray(stored["free_lifts"], dtype=np.uint64)
        free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert support["final_representatives_arrays_sha256"] == (
        representative_arrays_sha256(lifts, free_columns)
    )
    with np.load(args.reduced) as stored:
        numerator_map = np.asarray(
            stored["numerator_map"], dtype=np.uint64
        )
        stored_free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert np.array_equal(free_columns, stored_free_columns)
    numerator_mod19 = (
        (lifts % PRIME) @ numerator_map.transpose()
    ) % PRIME
    complement = np.asarray(
        [
            position
            for position, (_, beta_degree) in enumerate(numerator_specs)
            if beta_degree > cutoff
        ],
        dtype=np.int32,
    )
    assert np.count_nonzero(numerator_mod19[:, complement]) == 0
    canonical_mod19, canonical_pivots = row_space_rref(
        numerator_mod19[:, selected]
    )
    assert canonical_mod19.shape == (DIMENSION, SELECTED_COLUMNS)
    assert canonical_pivots == tuple(map(int, pivots))
    full = np.zeros(
        (DIMENSION, SELECTED_COLUMNS), dtype=np.uint64
    )
    full[:, pivots] = np.eye(DIMENSION, dtype=np.uint64)
    for chart in charts.values():
        full[:, nonpivots] = chart
        assert np.array_equal(full % PRIME, canonical_mod19)

    rows = result_rows(args.summary)
    assert [row["digits"] for row in rows] == list(
        range(TARGET_BASE_DIGITS, digits + 1)
    )
    reconstructions = {}
    for row in rows:
        current_digits = row["digits"]
        current_modulus = PRIME**current_digits
        assert row["modulus"] == current_modulus
        if current_digits == TARGET_BASE_DIGITS:
            assert row["mismatches_from_previous"] == -1
            assert row["stable_from_previous"] == -1
        else:
            mismatch_count = int(
                np.count_nonzero(
                    charts[current_digits]
                    % (PRIME ** (current_digits - 1))
                    != charts[current_digits - 1]
                )
            )
            assert row["mismatches_from_previous"] == mismatch_count
        reconstructions[current_digits] = reconstruct(
            charts[current_digits], current_modulus
        )
        reconstructed = len(reconstructions[current_digits])
        assert row["reconstructed_entries"] == reconstructed
        assert row["failed_entries"] == (
            charts[current_digits].size - reconstructed
        )
        if current_digits > TARGET_BASE_DIGITS:
            stable = sum(
                value
                == reconstructions[current_digits - 1].get(index)
                for index, value in reconstructions[
                    current_digits
                ].items()
                if index in reconstructions[current_digits - 1]
            )
            assert row["stable_from_previous"] == stable

    stable_all = sum(
        all(
            value == reconstructions[current_digits].get(index)
            for current_digits in range(
                TARGET_BASE_DIGITS, digits
            )
        )
        for index, value in reconstructions[digits].items()
        if all(
            index in reconstructions[current_digits]
            for current_digits in range(
                TARGET_BASE_DIGITS, digits
            )
        )
    )
    assert int(certificate["stable_all_digits_entries"]) == stable_all
    entries = charts[digits].size
    final_failed = entries - len(reconstructions[digits])
    assert int(certificate["final_failed_entries"]) == final_failed
    final_values = reconstructions[digits].values()
    maximum_numerator = max(
        (abs(numerator) for numerator, _ in final_values),
        default=0,
    )
    maximum_denominator = max(
        (
            denominator
            for _, denominator in reconstructions[digits].values()
        ),
        default=0,
    )
    assert int(certificate["maximum_reconstructed_numerator"]) == (
        maximum_numerator
    )
    assert int(certificate["maximum_reconstructed_denominator"]) == (
        maximum_denominator
    )
    status = (
        "incoherent_supported_quotient_chart"
        if any(
            row["mismatches_from_previous"] > 0
            for row in rows[1:]
        )
        else (
            "complete_stable_rational_chart"
            if final_failed == 0 and stable_all == entries
            else "incomplete_or_unstable_rational_chart"
        )
    )
    assert certificate["status"] == status
    assert int(certificate["coherent_transition_count"]) == sum(
        row["mismatches_from_previous"] == 0 for row in rows[1:]
    )
    print(
        "verified supported quotient chart audit: "
        f"{len(reconstructions[digits])}/{entries} entries "
        f"reconstruct at 19^{digits}, {stable_all} stable across all "
        "available digits"
    )


if __name__ == "__main__":
    main()
