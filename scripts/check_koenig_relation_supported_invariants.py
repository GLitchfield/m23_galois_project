#!/usr/bin/env python3
"""Independently validate supported König numerator invariants."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

PRIME = 19
WIDTH = 571
NUMERATOR_COLUMNS = 9506
SELECTED_COLUMNS = 7566
UNIT_RANK = 7
SCHEMA = "m23-koenig-a-relation-supported-invariants-v1"
IMAGE_SCHEMA = "m23-koenig-a-relation-supported-numerator-image-v1"
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


def arrays_sha256(image: np.ndarray, selected: np.ndarray) -> str:
    digest = hashlib.sha256()
    digest.update(np.asarray(image, dtype=np.uint64).tobytes())
    digest.update(np.asarray(selected, dtype=np.int32).tobytes())
    return digest.hexdigest()


def representative_arrays_sha256(
    lifts: np.ndarray, free_columns: np.ndarray
) -> str:
    digest = hashlib.sha256()
    digest.update(np.asarray(lifts, dtype=np.uint64).tobytes())
    digest.update(np.asarray(free_columns, dtype=np.int32).tobytes())
    return digest.hexdigest()


def matrix_pivots(values: np.ndarray) -> tuple[int, ...]:
    work = np.asarray(values, dtype=np.int64).copy() % PRIME
    pivot_row = 0
    pivots = []
    for column in range(work.shape[1]):
        candidates = np.flatnonzero(work[pivot_row:, column])
        if not len(candidates):
            continue
        selected = pivot_row + int(candidates[0])
        work[[pivot_row, selected]] = work[[selected, pivot_row]]
        work[pivot_row] = (
            work[pivot_row]
            * pow(int(work[pivot_row, column]), -1, PRIME)
        ) % PRIME
        factors = work[pivot_row + 1 :, column].copy()
        work[pivot_row + 1 :] = (
            work[pivot_row + 1 :]
            - factors[:, None] * work[pivot_row][None, :]
        ) % PRIME
        pivots.append(column)
        pivot_row += 1
        if pivot_row == work.shape[0]:
            break
    return tuple(pivots)


def inverse_mod19(values: np.ndarray) -> np.ndarray:
    size = values.shape[0]
    work = np.hstack(
        (
            np.asarray(values, dtype=np.int64) % PRIME,
            np.eye(size, dtype=np.int64),
        )
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
            factor = int(work[row, column])
            work[row] = (
                work[row] - factor * work[column]
            ) % PRIME
    assert np.array_equal(
        work[:, :size], np.eye(size, dtype=np.int64)
    )
    return work[:, size:].astype(np.uint64)


def exact_digit_product(
    left: np.ndarray, right: np.ndarray, digits: int
) -> np.ndarray:
    modulus = PRIME**digits
    left_values = np.asarray(left, dtype=np.uint64)
    right_values = np.asarray(right, dtype=np.uint64)
    result = np.zeros(
        (left.shape[0], right.shape[1]), dtype=np.uint64
    )
    coefficients = [np.zeros_like(result) for _ in range(digits)]
    right_digits = [
        ((right_values // PRIME**digit) % PRIME).astype(np.float64)
        for digit in range(digits)
    ]
    for left_digit in range(digits):
        left_part = (
            (left_values // PRIME**left_digit) % PRIME
        ).astype(np.float64)
        for right_digit in range(digits - left_digit):
            product = left_part @ right_digits[right_digit]
            rounded = np.rint(product)
            assert np.array_equal(product, rounded)
            coefficients[left_digit + right_digit] += (
                rounded.astype(np.uint64)
            )
    carry = np.zeros_like(result)
    place = 1
    for total_digit, coefficient in enumerate(coefficients):
        coefficient += carry
        digit_values = coefficient % PRIME
        result += digit_values * place
        carry = coefficient // PRIME
        place *= PRIME
    assert np.all(result < modulus)
    return result


def inverse_unit(values: np.ndarray, digits: int) -> np.ndarray:
    size = values.shape[0]
    inverse = inverse_mod19(values % PRIME)
    identity = np.eye(size, dtype=np.uint64)
    for current_digits in range(2, digits + 1):
        current_modulus = PRIME ** (current_digits - 1)
        next_modulus = current_modulus * PRIME
        product = exact_digit_product(
            values % next_modulus,
            inverse,
            current_digits,
        )
        residual = np.where(
            identity >= product,
            identity - product,
            identity + next_modulus - product,
        ) % next_modulus
        assert np.count_nonzero(residual % current_modulus) == 0
        right = (residual // current_modulus) % PRIME
        correction = (
            inverse_mod19(values % PRIME) @ right
        ) % PRIME
        inverse = (
            inverse + current_modulus * correction
        ) % next_modulus
    assert np.array_equal(
        exact_digit_product(values, inverse, digits),
        identity,
    )
    return inverse


def modular_difference(
    left: np.ndarray, right: np.ndarray, modulus: int
) -> np.ndarray:
    return np.where(
        left >= right,
        left - right,
        left + modulus - right,
    ).astype(np.uint64)


def local_smith_valuations(
    values: np.ndarray, digits: int
) -> tuple[int, ...]:
    current = np.asarray(values, dtype=np.uint64).copy()
    valuations = []
    for valuation in range(digits):
        if current.shape[0] == 0 or current.shape[1] == 0:
            break
        remaining_digits = digits - valuation
        modulus = PRIME**remaining_digits
        leading = current % PRIME
        pivot_columns = matrix_pivots(leading)
        rank = len(pivot_columns)
        if rank:
            pivot_rows = matrix_pivots(
                leading[:, pivot_columns].transpose()
            )
            assert len(pivot_rows) == rank
            other_rows = tuple(
                row
                for row in range(current.shape[0])
                if row not in set(pivot_rows)
            )
            other_columns = tuple(
                column
                for column in range(current.shape[1])
                if column not in set(pivot_columns)
            )
            unit = current[np.ix_(pivot_rows, pivot_columns)]
            unit_inverse = inverse_unit(unit, remaining_digits)
            upper_right = current[
                np.ix_(pivot_rows, other_columns)
            ]
            lower_left = current[
                np.ix_(other_rows, pivot_columns)
            ]
            lower_right = current[
                np.ix_(other_rows, other_columns)
            ]
            solved_upper = exact_digit_product(
                unit_inverse, upper_right, remaining_digits
            )
            correction = exact_digit_product(
                lower_left, solved_upper, remaining_digits
            )
            residual = modular_difference(
                lower_right, correction, modulus
            )
            valuations.extend([valuation] * rank)
        else:
            residual = current
        assert np.count_nonzero(residual % PRIME) == 0
        if valuation + 1 < digits:
            current = (residual // PRIME).astype(np.uint64)
        else:
            assert np.count_nonzero(residual) == 0
    return tuple(valuations)


def self_test() -> None:
    planted = np.zeros((5, 6), dtype=np.uint64)
    planted[0, 0] = 1
    planted[1, 1] = PRIME
    planted[2, 2] = PRIME**3
    row_change = np.asarray(
        [
            [1, 1, 0, 0, 0],
            [0, 1, 1, 0, 0],
            [0, 0, 1, 1, 0],
            [0, 0, 0, 1, 1],
            [0, 0, 0, 0, 1],
        ],
        dtype=np.uint64,
    )
    changed = exact_digit_product(row_change, planted, 5)
    changed = changed[:, [2, 5, 0, 4, 1, 3]]
    assert local_smith_valuations(changed, 5) == (0, 1, 3)
    print("independent supported invariant self-test passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "invariants_digits10.tsv"
        ),
    )
    parser.add_argument(
        "--image",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "numerator_image_digits10.npz"
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
    assert support["status"] == "beta_degree_block_persists"

    digits = int(certificate["digits"])
    modulus = PRIME**digits
    cutoff = int(certificate["beta_degree_cutoff"])
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["modulus"]) == modulus
    assert int(certificate["selected_numerator_columns"]) == (
        SELECTED_COLUMNS
    )

    with np.load(args.image) as stored:
        assert str(stored["schema"]) == IMAGE_SCHEMA
        assert int(stored["prime"]) == PRIME
        assert int(stored["digits"]) == digits
        assert int(stored["modulus"]) == modulus
        assert int(stored["beta_cutoff"]) == cutoff
        image = np.asarray(
            stored["numerator_image"], dtype=np.uint64
        )
        selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
    assert image.shape == (
        int(certificate["source_generators"]),
        SELECTED_COLUMNS,
    )
    assert np.all(image < modulus)
    assert certificate["image_arrays_sha256"] == arrays_sha256(
        image, selected
    )

    with np.load(args.basis) as stored:
        numerator_specs = np.asarray(
            stored["numerator_specs"], dtype=np.int32
        )
    assert len(numerator_specs) == NUMERATOR_COLUMNS
    expected_selected = np.asarray(
        [
            position
            for position, (_, beta_degree) in enumerate(numerator_specs)
            if beta_degree <= cutoff
        ],
        dtype=np.int32,
    )
    assert np.array_equal(selected, expected_selected)

    with np.load(args.support_representatives) as stored:
        assert str(stored["schema"]) == REPRESENTATIVE_SCHEMA
        lifts = np.asarray(stored["free_lifts"], dtype=np.uint64)
        free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert lifts.shape == (image.shape[0], WIDTH)
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
    expected_mod19 = (
        (lifts % PRIME)
        @ numerator_map[selected, :].transpose()
    ) % PRIME
    assert np.array_equal(image % PRIME, expected_mod19)

    valuations = local_smith_valuations(image, digits)
    multiplicities = [
        valuations.count(valuation) for valuation in range(digits)
    ]
    rows = result_rows(args.summary)
    assert [row["valuation"] for row in rows] == list(range(digits))
    for row in rows:
        valuation = row["valuation"]
        assert row["multiplicity"] == multiplicities[valuation]
        assert row["annihilator_exponent"] == digits - valuation
    assert int(certificate["mod19_image_rank"]) == multiplicities[0]
    assert multiplicities[0] == UNIT_RANK
    assert int(certificate["unit_invariant_factors"]) == (
        multiplicities[0]
    )
    assert int(certificate["nonzero_invariant_factors"]) == len(
        valuations
    )
    divisible = len(valuations) - multiplicities[0]
    assert int(certificate["divisible_invariant_factors"]) == divisible
    assert int(certificate["zero_generator_relations"]) == (
        image.shape[0] - len(valuations)
    )
    length = sum(
        (digits - valuation) * multiplicities[valuation]
        for valuation in range(digits)
    )
    assert int(certificate["module_length_over_f19"]) == length
    status = (
        "saturated_free_rank7_image"
        if divisible == 0
        else "nonsaturated_image_with_divisible_factors"
    )
    assert certificate["status"] == status
    print(
        "verified supported numerator invariants: "
        + ",".join(
            f"v{valuation}:{multiplicity}"
            for valuation, multiplicity in enumerate(multiplicities)
            if multiplicity
        )
    )


if __name__ == "__main__":
    main()
