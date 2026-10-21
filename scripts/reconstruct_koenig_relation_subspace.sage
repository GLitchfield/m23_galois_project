#!/usr/bin/env sage
"""Rationally reconstruct the canonical chart of König's relation subspace."""

from __future__ import annotations

import argparse
import hashlib
import math
import subprocess
from pathlib import Path

import numpy as np

from sage.all import GF, ZZ, matrix
from sage.env import SAGE_VERSION

PRIME = 19
EXPECTED_WIDTH = 571
EXPECTED_DIMENSION = 568
EXPECTED_CODIMENSION = 3
SCHEMAS = {
    7: "m23-koenig-a-relation-subspace-reconstruction-v1",
    8: "m23-koenig-a-relation-subspace-reconstruction-v2",
    9: "m23-koenig-a-relation-subspace-reconstruction-v3",
    10: "m23-koenig-a-relation-subspace-reconstruction-v4",
}
STABLE_LABELS = {7: "three", 8: "four", 9: "five", 10: "six"}


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path):
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def sage_matrix_to_uint(values):
    return np.asarray(
        [[int(value) for value in row] for row in values.rows()],
        dtype=np.uint64,
    )


def exact_modular_product(left, right, modulus, left_bound, right_bound):
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


def lift_chart(reduced, digits):
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
    assert np.all(effective < modulus)

    field = GF(PRIME)
    leading = matrix(
        field,
        np.ascontiguousarray(effective % PRIME, dtype=np.uint8),
    )
    pivot_columns = tuple(map(int, leading.pivots()))
    assert len(pivot_columns) == EXPECTED_CODIMENSION
    pivot_block = leading.matrix_from_columns(pivot_columns)
    pivot_rows = tuple(map(int, pivot_block.transpose().pivots()))
    unit = (
        leading.matrix_from_rows(pivot_rows)
        .matrix_from_columns(pivot_columns)
    )
    assert unit.rank() == EXPECTED_CODIMENSION

    nonpivot_columns = tuple(
        column
        for column in range(EXPECTED_WIDTH)
        if column not in set(pivot_columns)
    )
    assert len(nonpivot_columns) == EXPECTED_DIMENSION
    leading_free = (
        leading.matrix_from_rows(pivot_rows)
        .matrix_from_columns(nonpivot_columns)
    )
    pivot_values = unit.solve_right(-leading_free)
    lifts = np.zeros(
        (EXPECTED_DIMENSION, EXPECTED_WIDTH), dtype=np.uint64
    )
    lifts[:, nonpivot_columns] = np.eye(
        EXPECTED_DIMENSION, dtype=np.uint64
    )
    lifts[:, pivot_columns] = sage_matrix_to_uint(
        pivot_values.transpose()
    )
    assert lifts.shape == (EXPECTED_DIMENSION, EXPECTED_WIDTH)
    identity = np.eye(EXPECTED_DIMENSION, dtype=np.uint64)
    assert np.array_equal(lifts[:, nonpivot_columns], identity)
    assert np.count_nonzero(
        (
            np.asarray(leading, dtype=np.uint64)
            @ lifts.transpose()
        )
        % PRIME
    ) == 0

    leading_pivots = leading.matrix_from_columns(pivot_columns)
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
        residual = matrix(
            field,
            np.ascontiguousarray(
                (product // current_modulus) % PRIME,
                dtype=np.uint8,
            ),
        )
        pivot_residual = residual.matrix_from_rows(pivot_rows)
        pivot_correction = unit.solve_right(-pivot_residual)
        obstruction = residual + leading_pivots * pivot_correction
        assert obstruction.matrix_from_rows(pivot_rows).is_zero()
        assert obstruction.rank() == 0

        base_product = product
        base_residual = matrix(
            field,
            np.ascontiguousarray(
                (base_product // current_modulus) % PRIME,
                dtype=np.uint8,
            ),
        )
        correction_pivots = unit.solve_right(
            -base_residual.matrix_from_rows(pivot_rows)
        )
        correction = np.zeros(
            (EXPECTED_WIDTH, EXPECTED_DIMENSION), dtype=np.uint64
        )
        correction[list(pivot_columns), :] = sage_matrix_to_uint(
            correction_pivots
        )
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
        "valuation": valuation,
        "modulus": modulus,
        "pivot_columns": pivot_columns,
        "nonpivot_columns": nonpivot_columns,
        "chart": lifts[:, pivot_columns],
    }


def load_chart(summary_path, reduced_path):
    summary = metadata(summary_path)
    digits = int(summary["digits"])
    assert int(summary["prime"]) == PRIME
    assert int(summary["modulus"]) == PRIME**digits
    with np.load(reduced_path) as stored:
        assert int(stored["prime"]) == PRIME
        reduced = np.vstack(
            (stored["reduced_training"], stored["reduced_holdout"])
        )
    return digits, lift_chart(reduced, digits)


def reconstruct_chart(chart, modulus):
    modulus_integer = ZZ(modulus)
    successes = {}
    failures = 0
    for index, residue in enumerate(chart.reshape(-1)):
        try:
            value = ZZ(int(residue)).rational_reconstruction(
                modulus_integer
            )
        except ArithmeticError:
            failures += 1
            continue
        numerator = int(value.numerator())
        denominator = int(value.denominator())
        assert denominator > 0
        assert (int(residue) * denominator - numerator) % modulus == 0
        successes[index] = (numerator, denominator)
    return successes, failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--maximum-digits", type=int, choices=tuple(SCHEMAS), default=7
    )
    for digits in range(5, max(SCHEMAS) + 1):
        parser.add_argument(
            f"--summary{digits}",
            type=Path,
            default=Path(
                "data/derived/"
                "m23_koenig_a_relation_homogeneous_degree110_"
                f"digits{digits}.tsv"
            ),
        )
        parser.add_argument(
            f"--reduced{digits}",
            type=Path,
            default=Path(
                "data/derived/"
                "m23_koenig_a_relation_homogeneous_degree110_"
                f"digits{digits}_reduced.npz"
            ),
        )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()

    maximum_digits = args.maximum_digits
    digit_range = range(5, maximum_digits + 1)
    inputs = {}
    for digits in digit_range:
        summary_path = getattr(args, f"summary{digits}")
        reduced_path = getattr(args, f"reduced{digits}")
        for path in (summary_path, reduced_path):
            if not path.exists():
                raise FileNotFoundError(path)
        actual_digits, chart = load_chart(summary_path, reduced_path)
        assert actual_digits == digits
        inputs[digits] = (summary_path, reduced_path, chart)

    pivot_columns = inputs[maximum_digits][2]["pivot_columns"]
    assert all(
        inputs[digits][2]["pivot_columns"] == pivot_columns
        for digits in range(5, maximum_digits)
    )
    mismatches = {
        digits: int(
            np.count_nonzero(
                inputs[digits][2]["chart"]
                % inputs[digits - 1][2]["modulus"]
                != inputs[digits - 1][2]["chart"]
            )
        )
        for digits in range(6, maximum_digits + 1)
    }
    entries = EXPECTED_DIMENSION * EXPECTED_CODIMENSION
    reconstructions = {}
    failures = {}
    for digits in digit_range:
        reconstructions[digits], failures[digits] = reconstruct_chart(
            inputs[digits][2]["chart"], inputs[digits][2]["modulus"]
        )
        assert (
            len(reconstructions[digits]) + failures[digits] == entries
        )
    reconstruction_modulus = inputs[maximum_digits][2]["modulus"]
    status = (
        "complete_chart_reconstructed"
        if failures[maximum_digits] == 0
        else "incomplete_chart_reconstruction"
    )
    bound = math.isqrt((reconstruction_modulus - 1) // 2)
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
    successes = reconstructions[maximum_digits]
    maximum_numerator = max(
        (
            abs(numerator)
            for numerator, _ in successes.values()
        ),
        default=0,
    )
    maximum_denominator = max(
        (denominator for _, denominator in successes.values()), default=0
    )

    lines = [
        f"# schema\t{SCHEMAS[maximum_digits]}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        f"# status\t{status}",
        f"# chart_rows\t{EXPECTED_DIMENSION}",
        f"# chart_columns\t{EXPECTED_CODIMENSION}",
        f"# chart_entries\t{entries}",
        "# pivot_columns\t" + ",".join(map(str, pivot_columns)),
    ]
    lines.extend(
        f"# digit{digits}_effective_modulus\t"
        f"{inputs[digits][2]['modulus']}"
        for digits in digit_range
    )
    lines.extend(
        f"# digit{digits}_to_digit{digits - 1}_mismatches\t"
        f"{mismatches[digits]}"
        for digits in range(6, maximum_digits + 1)
    )
    lines.extend(
        [
        f"# reconstruction_modulus\t{reconstruction_modulus}",
        f"# symmetric_bound\t{bound}",
        ]
    )
    lines.extend(
        f"# digit{digits}_reconstructed_entries\t"
        f"{len(reconstructions[digits])}"
        for digits in digit_range
    )
    lines.extend(
        [
        f"# digit{maximum_digits}_failed_entries\t"
        f"{failures[maximum_digits]}",
        ]
    )
    lines.extend(
        f"# stable_digit{digits - 1}_to_digit{digits}_entries\t"
        f"{adjacent_stability[digits]}"
        for digits in range(6, maximum_digits + 1)
    )
    stable_label = STABLE_LABELS[maximum_digits]
    lines.extend(
        [
        f"# stable_all_{stable_label}_entries\t{stable_all}",
        f"# maximum_reconstructed_numerator\t{maximum_numerator}",
        f"# maximum_reconstructed_denominator\t{maximum_denominator}",
        ]
    )
    for digits in digit_range:
        summary_path, reduced_path, _ = inputs[digits]
        lines.extend(
            (
                f"# summary{digits}_sha256\t{sha256(summary_path)}",
                f"# reduced{digits}_sha256\t{sha256(reduced_path)}",
            )
        )
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.check_summary is not None:
        expected = [
            line
            for line in args.check_summary.read_text().splitlines()
            if not line.startswith("# code_revision\t")
        ]
        actual = [
            line
            for line in text.splitlines()
            if not line.startswith("# code_revision\t")
        ]
        assert actual == expected
    print(text, end="")


if __name__ == "__main__":
    main()
