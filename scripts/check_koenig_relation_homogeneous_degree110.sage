#!/usr/bin/env sage
"""Independently check the reduced homogeneous degree-110 kernel certificate."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

from sage.all import GF, matrix

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SUMMARY = (
    ROOT / "data/derived/m23_koenig_a_relation_homogeneous_degree110.tsv"
)
DEFAULT_REDUCED = (
    ROOT
    / "data/derived/m23_koenig_a_relation_homogeneous_degree110_reduced.npz"
)
DEFAULT_COEFFICIENTS = (
    ROOT
    / "data/derived/"
    "m23_koenig_a_relation_homogeneous_degree110_coefficients_mod130321.tsv"
)
BASIS = ROOT / "data/derived/m23_koenig_f19_a_relation_basis.npz"
PROFILES = (
    ROOT / "data/derived/m23_koenig_a_relation_degree110_profiles.tsv"
)
FAMILY = ROOT / "data/derived/m23_koenig_19adic_family_16384.tsv"
DEFAULT_OLD_SEED = (
    ROOT / "data/derived/m23_koenig_a_relation_coefficients_mod6859.tsv"
)
PRIME = 19
MAXIMUM_SUPPORTED_DIGITS = 13


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path):
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def result_rows(path):
    rows = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("scope\t"):
            continue
        fields = line.split("\t")
        rows[(fields[0], int(fields[1]))] = tuple(map(int, fields[2:]))
    return rows


def load_coefficients(path):
    result = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, i, j, value = line.split("\t")
        term = (kind, int(i), int(j))
        assert term not in result
        result[term] = int(value)
    return result


def digit_convolution_product(left, right, digits):
    """Independently multiply modulo 19^digits without uint64 overflow."""
    left = np.asarray(left, dtype=np.uint64)
    right = np.asarray(right, dtype=np.uint64)
    assert left.ndim == right.ndim == 2
    assert left.shape[1] == right.shape[0]
    modulus = PRIME**digits
    assert np.all(left < modulus)
    assert np.all(right < modulus)
    assert left.shape[1] * (PRIME - 1) ** 2 < 2**53

    answer = np.zeros((left.shape[0], right.shape[1]), dtype=np.uint64)
    carry = np.zeros_like(answer)
    left_digits = [
        ((left // PRIME**place) % PRIME).astype(np.float64)
        for place in range(digits)
    ]
    right_digits = [
        ((right // PRIME**place) % PRIME).astype(np.float64)
        for place in range(digits)
    ]
    for total_place in range(digits):
        coefficient = np.zeros(answer.shape, dtype=np.uint64)
        for left_place in range(total_place + 1):
            product = (
                left_digits[left_place]
                @ right_digits[total_place - left_place]
            )
            rounded = np.rint(product)
            assert np.array_equal(product, rounded)
            coefficient += rounded.astype(np.uint64)
        coefficient += carry
        answer += (coefficient % PRIME) * PRIME**total_place
        carry = coefficient // PRIME
    assert np.all(answer < modulus)
    return answer


def lift_block(reduced, levels):
    row_count, width = reduced.shape
    values = np.zeros(
        (levels * row_count, levels * width), dtype=np.uint8
    )
    digits = [
        ((reduced.astype(np.uint64) // PRIME**digit) % PRIME).astype(
            np.uint8
        )
        for digit in range(levels)
    ]
    for equation in range(levels):
        for variable in range(equation + 1):
            values[
                equation * row_count : (equation + 1) * row_count,
                variable * width : (variable + 1) * width,
            ] = digits[equation - variable]
    return matrix(GF(PRIME), values)


def analyze(reduced, numerator_map, levels):
    width = reduced.shape[1]
    block = lift_block(reduced, levels)
    rank = int(block.rank())
    if levels == 1:
        tail_rank = 0
    else:
        tail_rank = int(
            block.matrix_from_columns(range(width, levels * width)).rank()
        )
    kernel = block.right_kernel_matrix()
    projected = kernel.matrix_from_columns(range(width))
    basis = projected.row_space().basis_matrix()
    numerator_rank = int((basis * numerator_map.transpose()).rank())
    projected_dimension = basis.nrows()
    plane_control_dimension = projected_dimension - numerator_rank
    assert projected_dimension == (
        levels * width
        - rank
        - ((levels - 1) * width - tail_rank)
    )
    return (
        block.nrows(),
        block.ncols(),
        rank,
        tail_rank,
        projected_dimension,
        numerator_rank,
        plane_control_dimension,
        basis,
    )


def analyze_hensel(reduced, numerator_map, maximum_levels):
    """Independently replay the carry-aware projected-kernel lift."""
    field = GF(PRIME)
    width = reduced.shape[1]
    assert np.count_nonzero(reduced % PRIME**2) == 0
    assert np.count_nonzero(reduced % PRIME**3)
    effective = reduced.astype(np.uint64) // PRIME**2
    leading = matrix(
        field,
        np.ascontiguousarray(effective % PRIME, dtype=np.uint8),
    )
    pivot_columns = tuple(map(int, leading.pivots()))
    rank = len(pivot_columns)
    assert rank == 3
    leading_pivots = leading.matrix_from_columns(pivot_columns)
    pivot_rows = tuple(
        map(int, leading_pivots.transpose().pivots())
    )
    unit = (
        leading.matrix_from_rows(pivot_rows)
        .matrix_from_columns(pivot_columns)
    )
    assert unit.rank() == rank

    identity = matrix.identity(field, width)
    numerator_rank = int(
        (identity * numerator_map.transpose()).rank()
    )
    results = [
        (
            reduced.shape[0],
            width,
            0,
            width,
            numerator_rank,
            width - numerator_rank,
            identity,
        ),
        (
            reduced.shape[0],
            width,
            0,
            width,
            numerator_rank,
            width - numerator_rank,
            identity,
        ),
    ]

    kernel = leading.right_kernel_matrix()
    projected = kernel.row_space().basis_matrix()
    numerator_rank = int(
        (projected * numerator_map.transpose()).rank()
    )
    results.append(
        (
            leading.nrows(),
            leading.ncols(),
            rank,
            projected.nrows(),
            numerator_rank,
            projected.nrows() - numerator_rank,
            projected,
        )
    )
    lifts = np.asarray(
        [
            [int(value) for value in row]
            for row in projected.rows()
        ],
        dtype=np.uint64,
    )

    current_precision = 1
    while len(results) < maximum_levels:
        current_modulus = PRIME**current_precision
        next_modulus = current_modulus * PRIME
        product = digit_convolution_product(
            effective % next_modulus,
            lifts.transpose(),
            current_precision + 1,
        )
        assert np.count_nonzero(product % current_modulus) == 0
        residual = matrix(
            field,
            np.ascontiguousarray(
                (product // current_modulus) % PRIME,
                dtype=np.uint8,
            ),
        )
        pivot_correction = unit.solve_right(
            -residual.matrix_from_rows(pivot_rows)
        )
        obstruction = residual + leading_pivots * pivot_correction
        assert obstruction.matrix_from_rows(pivot_rows).is_zero()
        obstruction_rank = int(obstruction.rank())
        combinations = obstruction.right_kernel_matrix()
        combination_values = np.asarray(
            [
                [int(value) for value in row]
                for row in combinations.rows()
            ],
            dtype=np.uint64,
        )
        base_lifts = (
            combination_values @ lifts
        ) % current_modulus
        base_product = digit_convolution_product(
            effective % next_modulus,
            base_lifts.transpose(),
            current_precision + 1,
        )
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
        corrections = np.zeros(
            (width, combinations.nrows()), dtype=np.uint64
        )
        corrections[list(pivot_columns), :] = np.asarray(
            [
                [int(value) for value in row]
                for row in correction_pivots.rows()
            ],
            dtype=np.uint64,
        )
        lifts = (
            base_lifts + current_modulus * corrections.transpose()
        ) % next_modulus
        assert np.count_nonzero(
            digit_convolution_product(
                effective % next_modulus,
                lifts.transpose(),
                current_precision + 1,
            )
        ) == 0
        projected = matrix(
            field,
            np.ascontiguousarray(lifts % PRIME, dtype=np.uint8),
        )
        assert projected.rank() == projected.nrows()
        numerator_rank = int(
            (projected * numerator_map.transpose()).rank()
        )
        results.append(
            (
                obstruction.nrows(),
                obstruction.ncols(),
                obstruction_rank,
                projected.nrows(),
                numerator_rank,
                projected.nrows() - numerator_rank,
                projected,
            )
        )
        current_precision += 1
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--reduced", type=Path, default=DEFAULT_REDUCED)
    parser.add_argument(
        "--coefficients", type=Path, default=DEFAULT_COEFFICIENTS
    )
    parser.add_argument("--old-seed", type=Path, default=DEFAULT_OLD_SEED)
    args = parser.parse_args()

    summary = metadata(args.summary)
    assert summary["schema"] in {
        "m23-koenig-a-homogeneous-degree110-v1",
        "m23-koenig-a-homogeneous-degree110-v2",
    }
    digits = int(summary["digits"])
    modulus = PRIME**digits
    assert summary["status"] == (
        "homogeneous_degree110_genuine_relation_verified"
    )
    assert summary["basis_sha256"] == sha256(BASIS)
    assert summary["profiles_sha256"] == sha256(PROFILES)
    assert summary["family_certificate_sha256"] == sha256(FAMILY)
    assert int(summary["prime"]) == PRIME
    assert 4 <= digits <= MAXIMUM_SUPPORTED_DIGITS
    assert int(summary["modulus"]) == modulus
    assert int(summary["series_precision"]) == 16384
    assert int(summary["training_terms"]) == 16000
    assert int(summary["holdout_terms"]) == 384
    assert int(summary["homogeneous_unknowns"]) == 15722
    assert int(summary["mod19_rank"]) == 15151
    assert int(summary["mod19_kernel_dimension"]) == 571
    assert int(summary["mod19_numerator_projection_rank"]) == 480
    assert int(summary["plane_multiple_control_dimension"]) == 91
    if digits >= 5:
        assert int(summary["reduced_forced_valuation"]) == 2
    assert int(summary["nonpivot_training_rows"]) == 849
    assert int(summary["reduced_width"]) == 571
    assert int(summary["fitting_nonzero_residuals"]) == 0
    assert int(summary["holdout_nonzero_residuals"]) == 0

    with np.load(args.reduced) as stored:
        assert stored["schema"].item() == summary["schema"]
        assert stored["code_revision"].item() == summary["code_revision"]
        assert int(stored["prime"]) == PRIME
        training = stored["reduced_training"]
        holdout = stored["reduced_holdout"]
        numerator_values = stored["numerator_map"]
        if digits == 4:
            projected_training = stored["projected_training_mod19_4"]
            projected_all = stored["projected_all_mod19_4"]
        else:
            projected_training = stored["projected_training"]
            projected_all = stored["projected_all"]
        pivot_columns = stored["pivot_columns"]
        free_columns = stored["free_columns"]
    assert training.shape == (849, 571)
    assert holdout.shape == (384, 571)
    assert numerator_values.shape == (9506, 571)
    assert projected_training.shape == projected_all.shape
    assert projected_training.shape[1] == 571
    assert pivot_columns.shape == (15151,)
    assert free_columns.shape == (571,)
    assert len(set(map(int, pivot_columns))) == len(pivot_columns)
    assert len(set(map(int, free_columns))) == len(free_columns)
    assert set(map(int, pivot_columns)).isdisjoint(map(int, free_columns))
    assert set(map(int, pivot_columns)) | set(map(int, free_columns)) == set(
        range(15722)
    )
    arrays_digest = hashlib.sha256(
        training.tobytes()
        + holdout.tobytes()
        + numerator_values.tobytes()
        + projected_training.tobytes()
        + projected_all.tobytes()
    ).hexdigest()
    assert arrays_digest == summary["reduced_arrays_sha256"]

    # The first new constraint occurs at digit 4 and has rank exactly three.
    assert np.count_nonzero(training % PRIME) == 0
    assert np.count_nonzero((training // PRIME) % PRIME) == 0
    assert np.count_nonzero(holdout % PRIME) == 0
    assert np.count_nonzero((holdout // PRIME) % PRIME) == 0
    field = GF(PRIME)
    numerator_map = matrix(field, numerator_values)
    assert numerator_map.rank() == 480
    expected_rows = result_rows(args.summary)
    computed_bases = {}
    for scope, reduced in (
        ("training", training),
        ("all", np.vstack((training, holdout))),
    ):
        if digits == 4:
            for levels in range(1, digits):
                computed = analyze(reduced, numerator_map, levels)
                expected = expected_rows[(scope, levels + 1)]
                assert computed[:6] == expected
                assert computed[6] == 91
                computed_bases[(scope, levels + 1)] = computed[7]
        else:
            computed_results = analyze_hensel(
                reduced, numerator_map, digits - 1
            )
            for levels, computed in enumerate(computed_results, start=1):
                expected = expected_rows[(scope, levels + 1)]
                assert computed[:6] == expected
                assert computed[5] == 91
                computed_bases[(scope, levels + 1)] = computed[6]
    if digits == 4:
        assert expected_rows[("training", 4)][2:6] == (
            3,
            0,
            568,
            477,
        )
        assert expected_rows[("all", 4)][2:6] == (3, 0, 568, 477)
    else:
        assert expected_rows[("training", 4)][2:] == (3, 568, 477, 91)
        assert expected_rows[("all", 4)][2:] == (3, 568, 477, 91)
        assert expected_rows[("training", 5)][2:] == (0, 568, 477, 91)
        assert expected_rows[("all", 5)][2:] == (0, 568, 477, 91)
        for level in range(6, digits + 1):
            for scope in ("training", "all"):
                assert expected_rows[(scope, level)][2:] == (
                    0,
                    568,
                    477,
                    91,
                )

    stored_training_basis = matrix(field, projected_training)
    stored_all_basis = matrix(field, projected_all)
    assert stored_training_basis.row_space() == (
        computed_bases[("training", digits)].row_space()
    )
    assert stored_all_basis.row_space() == (
        computed_bases[("all", digits)].row_space()
    )
    assert stored_training_basis.row_space() == stored_all_basis.row_space()

    with np.load(BASIS) as stored:
        numerator_specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
        denominator_specs = [
            (int(i), int(j)) for i, j in stored["denominator_specs"]
        ]
    terms = (
        [("P", i, j) for i, j in numerator_specs]
        + [("Q", i, j) for i, j in denominator_specs]
    )
    coefficients_metadata = metadata(args.coefficients)
    assert coefficients_metadata["schema"] == (
        "m23-koenig-a-homogeneous-degree110-coefficients-v1"
    )
    assert coefficients_metadata["summary_sha256"] == sha256(args.summary)
    assert int(coefficients_metadata["modulus"]) == modulus
    sparse = load_coefficients(args.coefficients)
    assert sparse
    if digits == 4:
        assert len(sparse) == 11667
    coefficients = np.asarray(
        [sparse.get(term, 0) for term in terms], dtype=np.uint64
    )
    assert np.all(coefficients < modulus)
    assert sparse[("P", 0, 1)] % PRIME == 1
    canonical = "\n".join(
        f"{kind}:{i}:{j}:{int(value)}"
        for (kind, i, j), value in zip(terms, coefficients)
    ) + "\n"
    assert hashlib.sha256(canonical.encode()).hexdigest() == (
        summary["witness_coefficients_sha256"]
    )

    free_values = coefficients[free_columns]
    assert np.count_nonzero(
        digit_convolution_product(
            training,
            (free_values % (PRIME ** (digits - 1))).reshape(-1, 1),
            digits - 1,
        )
    ) == 0
    assert np.count_nonzero(
        digit_convolution_product(
            holdout,
            (free_values % (PRIME ** (digits - 1))).reshape(-1, 1),
            digits - 1,
        )
    ) == 0
    numerator_mod19 = np.asarray(
        numerator_map
        * matrix(field, 571, 1, list(map(int, free_values % PRIME)))
    ).reshape(-1)
    assert np.array_equal(
        np.asarray(list(map(int, numerator_mod19)), dtype=np.uint64),
        coefficients[:9506] % PRIME,
    )
    witness_free_mod19 = matrix(
        field, 1, 571, list(map(int, free_values % PRIME))
    )
    assert witness_free_mod19.row(0) in stored_all_basis.row_space()
    assert np.count_nonzero(coefficients[:9506] % PRIME)

    # The old selected mod-19 direction is one of the obstructed directions:
    # its reduced obstruction exactly reproduces Test 0120's residual counts.
    old_sparse = load_coefficients(args.old_seed)
    old_sparse[("P", 0, 1)] = 1
    old = np.asarray(
        [old_sparse.get(term, 0) % PRIME for term in terms],
        dtype=np.uint64,
    )
    old_free = old[free_columns]
    training_obstruction = (
        (training.astype(np.uint64) // PRIME**2) @ old_free
    ) % PRIME
    holdout_obstruction = (
        (holdout.astype(np.uint64) // PRIME**2) @ old_free
    ) % PRIME
    assert np.count_nonzero(training_obstruction) == 799
    assert np.count_nonzero(holdout_obstruction) == 368

    numerator_position = 5 if digits == 4 else 4
    print(
        "verified homogeneous degree-110 kernel: "
        f"{projected_all.shape[0]} directions survive modulo 19^{digits}, "
        f"{expected_rows[('all', digits)][numerator_position]} "
        "numerator-bearing, with "
        "all 91 plane controls and one 16,384-row witness"
    )


if __name__ == "__main__":
    main()
