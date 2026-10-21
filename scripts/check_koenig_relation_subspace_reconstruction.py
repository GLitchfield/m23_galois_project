#!/usr/bin/env python3
"""Independently replay the König relation-subspace reconstruction audit."""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

import numpy as np

PRIME = 19
WIDTH = 571
DIMENSION = 568
CODIMENSION = 3
SCHEMAS = {
    "m23-koenig-a-relation-subspace-reconstruction-v1": 7,
    "m23-koenig-a-relation-subspace-reconstruction-v2": 8,
    "m23-koenig-a-relation-subspace-reconstruction-v3": 9,
    "m23-koenig-a-relation-subspace-reconstruction-v4": 10,
}
STABLE_LABELS = {7: "three", 8: "four", 9: "five", 10: "six"}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def matrix_pivots(values: np.ndarray) -> tuple[int, ...]:
    work = values.astype(np.int64) % PRIME
    rows, columns = work.shape
    pivot_row = 0
    pivots = []
    for column in range(columns):
        candidates = np.flatnonzero(work[pivot_row:, column])
        if not len(candidates):
            continue
        selected = pivot_row + int(candidates[0])
        work[[pivot_row, selected]] = work[[selected, pivot_row]]
        work[pivot_row] = (
            work[pivot_row]
            * pow(int(work[pivot_row, column]), -1, PRIME)
        ) % PRIME
        for row in range(rows):
            if row == pivot_row:
                continue
            multiplier = int(work[row, column])
            if multiplier:
                work[row] = (
                    work[row] - multiplier * work[pivot_row]
                ) % PRIME
        pivots.append(column)
        pivot_row += 1
        if pivot_row == rows:
            break
    return tuple(pivots)


def inverse_mod(values: np.ndarray) -> np.ndarray:
    size = values.shape[0]
    assert values.shape == (size, size)
    work = np.hstack(
        (values.astype(np.int64) % PRIME, np.eye(size, dtype=np.int64))
    )
    for column in range(size):
        selected = next(
            row
            for row in range(column, size)
            if work[row, column] % PRIME
        )
        work[[column, selected]] = work[[selected, column]]
        work[column] = (
            work[column]
            * pow(int(work[column, column]), -1, PRIME)
        ) % PRIME
        for row in range(size):
            if row == column:
                continue
            multiplier = int(work[row, column])
            work[row] = (
                work[row] - multiplier * work[column]
            ) % PRIME
    assert np.array_equal(
        work[:, :size], np.eye(size, dtype=np.int64)
    )
    return work[:, size:].astype(np.uint64)


def solve_mod(inverse: np.ndarray, right: np.ndarray) -> np.ndarray:
    return (inverse @ (right.astype(np.uint64) % PRIME)) % PRIME


def exact_modular_product(
    left: np.ndarray,
    right: np.ndarray,
    modulus: int,
    left_bound: int,
    right_bound: int,
) -> np.ndarray:
    assert left.dtype == np.uint64
    assert right.dtype == np.uint64
    assert left.shape[1] == right.shape[0]
    assert np.all(left <= left_bound)
    assert np.all(right <= right_bound)
    term_bound = left_bound * right_bound
    assert term_bound > 0
    chunk_width = int(np.iinfo(np.uint64).max) // term_bound
    assert chunk_width > 0

    answer = np.zeros((left.shape[0], right.shape[1]), dtype=np.uint64)
    for start in range(0, left.shape[1], chunk_width):
        stop = min(start + chunk_width, left.shape[1])
        assert (stop - start) * term_bound <= np.iinfo(np.uint64).max
        partial = left[:, start:stop] @ right[start:stop, :]
        answer = (answer + partial % modulus) % modulus
    return answer


def lift_chart(reduced: np.ndarray, digits: int) -> dict[str, object]:
    maximum_levels = digits - 1
    valuation = next(
        level
        for level in range(maximum_levels)
        if np.count_nonzero(
            reduced.astype(np.uint64) % PRIME ** (level + 1)
        )
    )
    assert valuation == 2
    effective = (
        reduced.astype(np.uint64) // PRIME**valuation
    ).astype(np.uint32)
    effective_digits = maximum_levels - valuation
    modulus = PRIME**effective_digits
    leading = effective.astype(np.uint64) % PRIME
    pivot_columns = matrix_pivots(leading)
    assert len(pivot_columns) == CODIMENSION
    nonpivot_columns = tuple(
        column
        for column in range(WIDTH)
        if column not in set(pivot_columns)
    )
    pivot_rows = matrix_pivots(
        leading[:, pivot_columns].transpose()
    )
    unit = leading[np.ix_(pivot_rows, pivot_columns)]
    unit_inverse = inverse_mod(unit)
    leading_free = leading[np.ix_(pivot_rows, nonpivot_columns)]
    pivot_values = solve_mod(
        unit_inverse, (-leading_free.astype(np.int64)) % PRIME
    )

    lifts = np.zeros((DIMENSION, WIDTH), dtype=np.uint64)
    identity = np.eye(DIMENSION, dtype=np.uint64)
    lifts[:, nonpivot_columns] = identity
    lifts[:, pivot_columns] = pivot_values.transpose()
    assert np.count_nonzero((leading @ lifts.transpose()) % PRIME) == 0

    leading_pivots = leading[:, pivot_columns]
    current_precision = 1
    while current_precision < effective_digits:
        current_modulus = PRIME**current_precision
        next_modulus = current_modulus * PRIME
        effective_stage = effective.astype(np.uint64) % next_modulus
        product = exact_modular_product(
            effective_stage,
            lifts.transpose(),
            next_modulus,
            next_modulus - 1,
            current_modulus - 1,
        )
        assert np.count_nonzero(product % current_modulus) == 0
        residual = (product // current_modulus) % PRIME
        pivot_residual = residual[list(pivot_rows), :]
        pivot_correction = solve_mod(
            unit_inverse,
            (-pivot_residual.astype(np.int64)) % PRIME,
        )
        obstruction = (
            residual + leading_pivots @ pivot_correction
        ) % PRIME
        assert np.count_nonzero(obstruction) == 0

        correction = np.zeros((WIDTH, DIMENSION), dtype=np.uint64)
        correction[list(pivot_columns), :] = pivot_correction
        lifts = (
            lifts + current_modulus * correction.transpose()
        ) % next_modulus
        assert np.array_equal(lifts[:, nonpivot_columns], identity)
        correction_product = (
            effective_stage[:, pivot_columns]
            @ correction[list(pivot_columns), :]
        ) % PRIME
        lifted_product = (
            product + current_modulus * correction_product
        ) % next_modulus
        assert np.count_nonzero(lifted_product) == 0
        current_precision += 1

    return {
        "modulus": modulus,
        "pivot_columns": pivot_columns,
        "chart": lifts[:, pivot_columns],
    }


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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_subspace_reconstruction.tsv"
        ),
    )
    args = parser.parse_args()
    certificate = metadata(args.summary)
    maximum_digits = SCHEMAS[certificate["schema"]]
    digit_range = range(5, maximum_digits + 1)
    assert int(certificate["prime"]) == PRIME
    assert certificate["status"] in {
        "complete_chart_reconstructed",
        "incomplete_chart_reconstruction",
    }
    assert int(certificate["chart_rows"]) == DIMENSION
    assert int(certificate["chart_columns"]) == CODIMENSION
    assert int(certificate["chart_entries"]) == DIMENSION * CODIMENSION

    charts = {}
    for digits in digit_range:
        summary_path = Path(
            "data/derived/"
            "m23_koenig_a_relation_homogeneous_degree110_"
            f"digits{digits}.tsv"
        )
        reduced_path = Path(
            "data/derived/"
            "m23_koenig_a_relation_homogeneous_degree110_"
            f"digits{digits}_reduced.npz"
        )
        assert certificate[f"summary{digits}_sha256"] == sha256(
            summary_path
        )
        assert certificate[f"reduced{digits}_sha256"] == sha256(
            reduced_path
        )
        with np.load(reduced_path) as stored:
            reduced = np.vstack(
                (stored["reduced_training"], stored["reduced_holdout"])
            )
        charts[digits] = lift_chart(reduced, digits)
        assert int(
            certificate[f"digit{digits}_effective_modulus"]
        ) == charts[digits]["modulus"]

    pivots = charts[maximum_digits]["pivot_columns"]
    assert all(
        charts[digits]["pivot_columns"] == pivots
        for digits in range(5, maximum_digits)
    )
    assert certificate["pivot_columns"] == ",".join(map(str, pivots))
    mismatches = {
        digits: int(
            np.count_nonzero(
                charts[digits]["chart"]
                % charts[digits - 1]["modulus"]
                != charts[digits - 1]["chart"]
            )
        )
        for digits in range(6, maximum_digits + 1)
    }
    for digits, mismatch_count in mismatches.items():
        assert int(
            certificate[
                f"digit{digits}_to_digit{digits - 1}_mismatches"
            ]
        ) == mismatch_count
        assert mismatch_count == 0

    reconstructions = {
        digits: reconstruct(
            charts[digits]["chart"], int(charts[digits]["modulus"])
        )
        for digits in digit_range
    }
    for digits in digit_range:
        assert int(
            certificate[f"digit{digits}_reconstructed_entries"]
        ) == len(reconstructions[digits])
    failed_entries = DIMENSION * CODIMENSION - len(
        reconstructions[maximum_digits]
    )
    assert int(
        certificate[f"digit{maximum_digits}_failed_entries"]
    ) == failed_entries
    expected_status = (
        "complete_chart_reconstructed"
        if failed_entries == 0
        else "incomplete_chart_reconstruction"
    )
    assert certificate["status"] == expected_status
    adjacent_stability = {
        digits: sum(
            value == reconstructions[digits - 1].get(index)
            for index, value in reconstructions[digits].items()
            if index in reconstructions[digits - 1]
        )
        for digits in range(6, maximum_digits + 1)
    }
    stable_all = sum(
        all(
            value == reconstructions[digits].get(index)
            for digits in range(5, maximum_digits)
        )
        for index, value in reconstructions[maximum_digits].items()
        if all(
            index in reconstructions[digits]
            for digits in range(5, maximum_digits)
        )
    )
    for digits, stable_count in adjacent_stability.items():
        assert int(
            certificate[
                f"stable_digit{digits - 1}_to_digit{digits}_entries"
            ]
        ) == stable_count
    stable_label = STABLE_LABELS[maximum_digits]
    assert int(certificate[f"stable_all_{stable_label}_entries"]) == (
        stable_all
    )
    reconstruction_modulus = PRIME ** (maximum_digits - 3)
    assert int(certificate["reconstruction_modulus"]) == (
        reconstruction_modulus
    )
    assert int(certificate["symmetric_bound"]) == math.isqrt(
        (reconstruction_modulus - 1) // 2
    )

    print(
        "verified coherent 568-by-3 relation chart: "
        f"{len(reconstructions[maximum_digits])}/1704 entries reconstruct "
        f"at 19^{maximum_digits - 3}, {failed_entries} unresolved"
    )


if __name__ == "__main__":
    main()
