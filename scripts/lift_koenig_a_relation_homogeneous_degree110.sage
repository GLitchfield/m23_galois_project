#!/usr/bin/env sage
"""Refine the full homogeneous degree-110 relation kernel 19-adically."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
import time
from pathlib import Path

import numpy as np

from sage.all import GF, Zmod, matrix
from sage.env import SAGE_VERSION

PRIME = 19
DEFAULT_DIGITS = 4
PRECISION = 16384
TRAINING_TERMS = 16000
EXPECTED_RANK = 15151
EXPECTED_KERNEL_DIMENSION = 571
EXPECTED_PLANE_DIMENSION = 91
EXPECTED_MOD19_NUMERATOR_RANK = 480
SCHEMA = "m23-koenig-a-homogeneous-degree110-v1"


def load_module(name, filename):
    path = Path(__file__).with_name(filename)
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError(f"could not load {filename}")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def sha256_file(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_specs(basis_path):
    with np.load(basis_path) as stored:
        numerator_specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
        denominator_specs = [
            (int(i), int(j)) for i, j in stored["denominator_specs"]
        ]
    assert len(numerator_specs) == 9506
    assert len(denominator_specs) == 6216
    assert max(i + j for i, j in denominator_specs) == 110
    return numerator_specs, denominator_specs


def load_profiles(path):
    rows = []
    columns = []
    metadata = {}
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line and not line.startswith("kind\t"):
            kind, position, index = line.split("\t")
            target = rows if kind == "row" else columns
            assert kind in {"row", "column"}
            assert int(position) == len(target)
            target.append(int(index))
    assert metadata["schema"] == "m23-koenig-a-degree110-profiles-v1"
    assert int(metadata["rank"]) == EXPECTED_RANK
    assert len(rows) == len(columns) == EXPECTED_RANK
    return tuple(rows), tuple(columns)


def truncate(mixed, value, series_ring, parameter):
    return mixed.truncate(value, series_ring, parameter, PRECISION)


def sage_matrix_to_uint(values, dtype=np.uint64):
    exported = values._export_as_string()
    result = np.fromstring(exported, dtype=dtype, sep=" ")
    return result.reshape(values.nrows(), values.ncols())


def unsigned_dtype_for_modulus(modulus):
    if modulus <= np.iinfo(np.uint32).max:
        return np.uint32
    if modulus <= np.iinfo(np.uint64).max:
        return np.uint64
    raise ValueError(f"modulus {modulus} exceeds uint64 storage")


def exact_float_product(left_float, right, bound):
    assert bound < 2**53
    product = left_float @ right.astype(np.float64)
    assert np.all(np.isfinite(product))
    rounded = np.rint(product)
    assert np.array_equal(product, rounded)
    return rounded.astype(np.uint64)


def exact_modular_product(left, right, digits):
    """Return left*right modulo 19^digits using exact digit convolutions."""
    assert left.ndim == right.ndim == 2
    assert left.shape[1] == right.shape[0]
    modulus = PRIME**digits
    left_values = np.asarray(left, dtype=np.uint64)
    right_values = np.asarray(right, dtype=np.uint64)
    assert np.all(left_values < modulus)
    assert np.all(right_values < modulus)
    digit_bound = left.shape[1] * (PRIME - 1) ** 2
    assert digit_bound < 2**53
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


def field_solve(unit_block, right_hand_side):
    field = unit_block.base_ring()
    right = matrix(
        field,
        np.ascontiguousarray(right_hand_side % PRIME, dtype=np.uint8),
    )
    solution = unit_block._solve_right_nonsingular_square(
        right, check_rank=False
    )
    return sage_matrix_to_uint(solution, dtype=np.uint64)


def hensel_unit_block(block, free_block, digits, progress=None):
    """Solve block*T = -free_block modulo 19^digits."""
    assert block.shape[0] == block.shape[1]
    assert block.shape[0] == free_block.shape[0]
    rank = block.shape[0]
    width = free_block.shape[1]
    field = GF(PRIME)
    unit_block = matrix(
        field,
        np.ascontiguousarray(block % PRIME, dtype=np.uint8),
    )
    assert unit_block.rank() == rank
    correction = field_solve(
        unit_block,
        (-free_block.astype(np.int64)) % PRIME,
    )
    solution = correction.copy()
    block_float = None
    for digit in range(1, digits):
        current_modulus = PRIME**digit
        next_modulus = PRIME ** (digit + 1)
        bound = (
            rank
            * (PRIME**digits - 1)
            * (current_modulus - 1)
        )
        if bound < 2**53:
            if block_float is None:
                block_float = block.astype(np.float64)
            product = exact_float_product(block_float, solution, bound)
        else:
            block_float = None
            stage_block = (
                block
                if next_modulus == PRIME**digits
                else block.astype(np.uint64) % next_modulus
            )
            product = exact_modular_product(
                stage_block, solution, digit + 1
            )
        residual = (product + free_block) % next_modulus
        assert np.count_nonzero(residual % current_modulus) == 0
        quotient = (residual // current_modulus) % PRIME
        right = (PRIME - quotient) % PRIME
        correction = field_solve(unit_block, right)
        solution += current_modulus * correction
        if progress is not None:
            progress(digit + 1)
    final_residual = (
        exact_modular_product(block, solution, digits) + free_block
    ) % (PRIME**digits)
    assert np.count_nonzero(final_residual) == 0
    return solution, unit_block


def schur_reduction(
    pivot_rows,
    other_rows,
    pivot_columns,
    free_columns,
    full_matrix,
    transformation,
    digits,
):
    left = full_matrix[np.ix_(other_rows, pivot_columns)]
    right = full_matrix[np.ix_(other_rows, free_columns)]
    schur = (
        exact_modular_product(left, transformation, digits)
        + right
    ) % (PRIME**digits)
    assert np.count_nonzero(schur % PRIME) == 0
    reduced = schur // PRIME
    reduced_modulus = PRIME ** (digits - 1)
    dtype = (
        np.uint16
        if reduced_modulus <= np.iinfo(np.uint16).max
        else unsigned_dtype_for_modulus(reduced_modulus)
    )
    return reduced.astype(dtype)


def block_lift_matrix(reduced, levels):
    """Encode D*y=0 mod 19^levels as one block system over F_19."""
    rows, columns = reduced.shape
    digits = [
        ((reduced.astype(np.uint64) // (PRIME**digit)) % PRIME).astype(
            np.uint8
        )
        for digit in range(levels)
    ]
    values = np.zeros(
        (levels * rows, levels * columns), dtype=np.uint8
    )
    for equation_digit in range(levels):
        row_slice = slice(equation_digit * rows, (equation_digit + 1) * rows)
        for variable_digit in range(equation_digit + 1):
            column_slice = slice(
                variable_digit * columns,
                (variable_digit + 1) * columns,
            )
            values[row_slice, column_slice] = digits[
                equation_digit - variable_digit
            ]
    return values


def analyze_reduced(reduced, numerator_map, maximum_levels):
    field = GF(PRIME)
    width = reduced.shape[1]
    results = []
    kernels = {}
    projected_bases = {}
    for levels in range(1, maximum_levels + 1):
        block_values = block_lift_matrix(reduced, levels)
        block = matrix(field, block_values)
        rank = int(block.rank())
        kernel = block.right_kernel_matrix()
        projected = kernel.matrix_from_columns(range(width))
        projected_basis = projected.row_space().basis_matrix()
        projected_dimension = projected_basis.nrows()
        numerator_rank = int(
            (projected_basis * numerator_map.transpose()).rank()
        )
        if levels == 1:
            tail_rank = 0
        else:
            tail = block.matrix_from_columns(
                range(width, levels * width)
            )
            tail_rank = int(tail.rank())
        inferred_projection = (
            levels * width
            - rank
            - ((levels - 1) * width - tail_rank)
        )
        assert inferred_projection == projected_dimension
        results.append(
            {
                "digits": levels + 1,
                "block_rows": block.nrows(),
                "block_columns": block.ncols(),
                "block_rank": rank,
                "tail_rank": tail_rank,
                "projected_dimension": projected_dimension,
                "numerator_projection_rank": numerator_rank,
                "plane_control_dimension": (
                    projected_dimension - numerator_rank
                ),
            }
        )
        kernels[levels] = kernel
        projected_bases[levels] = projected_basis
    return results, kernels, projected_bases


def p_adic_valuation(values, maximum_levels):
    """Return the common forced 19-adic valuation of a nonzero array."""
    for valuation in range(maximum_levels):
        if np.count_nonzero(
            values.astype(np.uint64) % PRIME ** (valuation + 1)
        ):
            return valuation
    return maximum_levels


def analyze_reduced_hensel(reduced, numerator_map, maximum_levels):
    """Project the modular kernel using carry-aware Hensel obstructions."""
    field = GF(PRIME)
    width = reduced.shape[1]
    valuation = p_adic_valuation(reduced, maximum_levels)
    assert valuation < maximum_levels
    effective_modulus = PRIME ** (maximum_levels - valuation)
    effective_dtype = unsigned_dtype_for_modulus(effective_modulus)
    effective = (
        reduced.astype(np.uint64) // PRIME**valuation
    ).astype(effective_dtype)
    assert np.all(effective < effective_modulus)
    leading = matrix(
        field,
        np.ascontiguousarray(effective % PRIME, dtype=np.uint8),
    )
    pivot_columns = tuple(map(int, leading.pivots()))
    rank = len(pivot_columns)
    column_block = leading.matrix_from_columns(pivot_columns)
    pivot_rows = tuple(map(int, column_block.transpose().pivots()))
    assert len(pivot_rows) == rank
    unit = (
        leading.matrix_from_rows(pivot_rows)
        .matrix_from_columns(pivot_columns)
    )
    assert unit.rank() == rank
    leading_pivots = leading.matrix_from_columns(pivot_columns)

    results = []
    representatives = {}
    projected_bases = {}
    identity = matrix.identity(field, width)
    for levels in range(1, valuation + 1):
        numerator_rank = int(
            (identity * numerator_map.transpose()).rank()
        )
        results.append(
            {
                "digits": levels + 1,
                "obstruction_rows": reduced.shape[0],
                "obstruction_columns": width,
                "obstruction_rank": 0,
                "projected_dimension": width,
                "numerator_projection_rank": numerator_rank,
                "plane_control_dimension": width - numerator_rank,
            }
        )
        representatives[levels] = np.eye(width, dtype=np.uint64)
        projected_bases[levels] = identity

    kernel = leading.right_kernel_matrix()
    lifts = sage_matrix_to_uint(kernel, dtype=np.uint64)
    projected_basis = matrix(
        field,
        np.ascontiguousarray(lifts % PRIME, dtype=np.uint8),
    )
    assert projected_basis.rank() == lifts.shape[0]
    numerator_rank = int(
        (projected_basis * numerator_map.transpose()).rank()
    )
    first_levels = valuation + 1
    results.append(
        {
            "digits": first_levels + 1,
            "obstruction_rows": leading.nrows(),
            "obstruction_columns": leading.ncols(),
            "obstruction_rank": rank,
            "projected_dimension": lifts.shape[0],
            "numerator_projection_rank": numerator_rank,
            "plane_control_dimension": lifts.shape[0] - numerator_rank,
        }
    )
    representatives[first_levels] = lifts
    projected_bases[first_levels] = projected_basis

    current_precision = 1
    for levels in range(first_levels + 1, maximum_levels + 1):
        current_modulus = PRIME**current_precision
        next_modulus = current_modulus * PRIME
        effective_stage = (
            effective.astype(np.uint64) % next_modulus
        ).astype(unsigned_dtype_for_modulus(next_modulus))
        product = exact_modular_product(
            effective_stage,
            lifts.transpose(),
            current_precision + 1,
        )
        assert np.count_nonzero(product % current_modulus) == 0
        residual_values = (
            (product // current_modulus) % PRIME
        ).astype(np.uint8)
        residual = matrix(field, residual_values)
        pivot_residual = residual.matrix_from_rows(pivot_rows)
        pivot_correction = unit.solve_right(-pivot_residual)
        obstruction = residual + leading_pivots * pivot_correction
        assert obstruction.matrix_from_rows(pivot_rows).is_zero()
        obstruction_rank = int(obstruction.rank())
        combinations = obstruction.right_kernel_matrix()
        combination_values = sage_matrix_to_uint(
            combinations, dtype=np.uint64
        )
        base_lifts = (
            combination_values @ lifts
        ) % current_modulus

        base_product = exact_modular_product(
            effective_stage,
            base_lifts.transpose(),
            current_precision + 1,
        )
        assert np.count_nonzero(base_product % current_modulus) == 0
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
            (width, combinations.nrows()), dtype=np.uint64
        )
        correction[list(pivot_columns), :] = sage_matrix_to_uint(
            correction_pivots, dtype=np.uint64
        )
        lifts = (
            base_lifts + current_modulus * correction.transpose()
        ) % next_modulus
        final_product = exact_modular_product(
            effective_stage,
            lifts.transpose(),
            current_precision + 1,
        )
        assert np.count_nonzero(final_product) == 0

        projected_basis = matrix(
            field,
            np.ascontiguousarray(lifts % PRIME, dtype=np.uint8),
        )
        assert projected_basis.rank() == lifts.shape[0]
        numerator_rank = int(
            (projected_basis * numerator_map.transpose()).rank()
        )
        results.append(
            {
                "digits": levels + 1,
                "obstruction_rows": obstruction.nrows(),
                "obstruction_columns": obstruction.ncols(),
                "obstruction_rank": obstruction_rank,
                "projected_dimension": lifts.shape[0],
                "numerator_projection_rank": numerator_rank,
                "plane_control_dimension": (
                    lifts.shape[0] - numerator_rank
                ),
            }
        )
        representatives[levels] = lifts
        projected_bases[levels] = projected_basis
        current_precision += 1
    return results, representatives, projected_bases, valuation


def homogeneous_residuals(full_matrix, coefficients, digits):
    coefficients_array = np.asarray(
        coefficients, dtype=np.uint64
    ).reshape(-1, 1)
    return exact_modular_product(
        full_matrix, coefficients_array, digits
    ).reshape(-1)


def self_test():
    rng = np.random.default_rng(120)
    digits = 5
    modulus = PRIME**digits
    block = np.asarray([[1, 2], [3, 1]], dtype=np.uint32)
    expected = rng.integers(0, modulus, size=(2, 2), dtype=np.uint32)
    free = (-block.astype(np.int64) @ expected.astype(np.int64)) % modulus
    free = free.astype(np.uint32)
    recovered, _ = hensel_unit_block(block, free, digits)
    assert np.count_nonzero(
        (
            exact_modular_product(block, recovered, digits) + free
        )
        % modulus
    ) == 0
    direct = np.asarray(
        [
            [
                sum(
                    int(block[row, inner]) * int(expected[inner, column])
                    for inner in range(block.shape[1])
                )
                % modulus
                for column in range(expected.shape[1])
            ]
            for row in range(block.shape[0])
        ],
        dtype=np.uint64,
    )
    assert np.array_equal(
        exact_modular_product(block, expected, digits), direct
    )
    stage_digits = 4
    stage_modulus = PRIME**stage_digits
    higher_precision_block = (
        block.astype(np.uint64) + stage_modulus
    )
    stage_block = (
        higher_precision_block % stage_modulus
    ).astype(np.uint32)
    assert np.array_equal(
        exact_modular_product(
            stage_block, expected % stage_modulus, stage_digits
        ),
        exact_modular_product(
            block, expected % stage_modulus, stage_digits
        ),
    )

    wide_digits = 13
    wide_modulus = PRIME**wide_digits
    wide_block = np.asarray(
        [
            [5 * PRIME**9 + 1, 2],
            [3, 5 * PRIME**9 + 1],
        ],
        dtype=np.uint64,
    )
    assert np.any(wide_block > np.iinfo(np.uint32).max)
    wide_expected = rng.integers(
        0,
        wide_modulus,
        size=(2, 2),
        dtype=np.uint64,
    )
    wide_product = exact_modular_product(
        wide_block, wide_expected, wide_digits
    )
    wide_free = (wide_modulus - wide_product) % wide_modulus
    wide_recovered, _ = hensel_unit_block(
        wide_block, wide_free, wide_digits
    )
    assert np.count_nonzero(
        (
            exact_modular_product(
                wide_block, wide_recovered, wide_digits
            )
            + wide_free
        )
        % wide_modulus
    ) == 0
    wide_values = np.asarray(
        [wide_modulus - 1, 7 * PRIME**9 + 11], dtype=np.uint64
    )
    wide_scalar = wide_modulus - 2
    scaled = exact_modular_product(
        wide_values.reshape(-1, 1),
        np.asarray([[wide_scalar]], dtype=np.uint64),
        wide_digits,
    ).reshape(-1)
    expected_scaled = np.asarray(
        [
            (int(value) * wide_scalar) % wide_modulus
            for value in wide_values
        ],
        dtype=np.uint64,
    )
    assert np.array_equal(scaled, expected_scaled)

    reduced = np.asarray(
        [[0, PRIME], [PRIME**2, 0]], dtype=np.uint16
    )
    numerator_map = matrix(GF(PRIME), [[1, 0], [0, 1]])
    results, _, _ = analyze_reduced(reduced, numerator_map, 3)
    direct = matrix(Zmod(PRIME**3), reduced).right_kernel_matrix()
    direct_reduction = matrix(
        GF(PRIME),
        np.asarray(
            [
                [int(value) % PRIME for value in row]
                for row in direct.rows()
            ],
            dtype=np.uint8,
        ),
    )
    assert results[-1]["projected_dimension"] == direct_reduction.rank()

    effective = np.asarray(
        [[1, 1], [PRIME, PRIME]], dtype=np.uint32
    )
    reduced_hensel = PRIME**2 * effective
    hensel_results, representatives, _, valuation = (
        analyze_reduced_hensel(
            reduced_hensel,
            matrix(GF(PRIME), [[1, 0], [0, 1]]),
            4,
        )
    )
    assert valuation == 2
    assert hensel_results[-1]["projected_dimension"] == 1
    final_representatives = representatives[4]
    assert np.count_nonzero(
        exact_modular_product(
            effective, final_representatives.transpose(), 2
        )
    ) == 0

    wide_effective = np.asarray(
        [[1 + 5 * PRIME**7, 0], [0, 0]], dtype=np.uint64
    )
    assert wide_effective[0, 0] > np.iinfo(np.uint32).max
    wide_reduced_hensel = PRIME**2 * wide_effective
    wide_hensel_results, _, _, wide_valuation = (
        analyze_reduced_hensel(
            wide_reduced_hensel,
            matrix(GF(PRIME), [[1, 0], [0, 1]]),
            10,
        )
    )
    assert wide_valuation == 2
    assert wide_hensel_results[-1]["projected_dimension"] == 1
    print("homogeneous degree-110 kernel self-test passed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--basis",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation_basis.npz"),
    )
    parser.add_argument(
        "--profiles",
        type=Path,
        default=Path(
            "data/derived/m23_koenig_a_relation_degree110_profiles.tsv"
        ),
    )
    parser.add_argument(
        "--family-certificate",
        type=Path,
        default=Path("data/derived/m23_koenig_19adic_family_16384.tsv"),
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--reduced-output", type=Path)
    parser.add_argument("--coefficients-output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--support-audit-output", type=Path)
    parser.add_argument("--support-representatives-output", type=Path)
    parser.add_argument("--check-support-summary", type=Path)
    parser.add_argument("--support-representatives-input", type=Path)
    parser.add_argument("--support-quotient-output", type=Path)
    parser.add_argument("--support-quotient-chart-output", type=Path)
    parser.add_argument("--check-support-quotient-summary", type=Path)
    parser.add_argument("--support-invariant-output", type=Path)
    parser.add_argument("--support-invariant-image-output", type=Path)
    parser.add_argument("--check-support-invariant-summary", type=Path)
    parser.add_argument("--support-invariant-stages-output", type=Path)
    parser.add_argument(
        "--support-invariant-stage-images-output", type=Path
    )
    parser.add_argument(
        "--check-support-invariant-stages-summary", type=Path
    )
    parser.add_argument(
        "--support-filtration",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_numerator_filtration.tsv"
        ),
    )
    parser.add_argument("--support-beta-cutoff", type=int, default=77)
    parser.add_argument("--digits", type=int, default=DEFAULT_DIGITS)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not 2 <= args.digits <= 13:
        raise ValueError("--digits must lie between 2 and 13")
    digits = args.digits
    for path in (args.basis, args.profiles, args.family_certificate):
        if not path.exists():
            raise FileNotFoundError(path)

    started = time.monotonic()
    numerator_specs, denominator_specs = load_specs(args.basis)
    all_terms = (
        [("P", i, j) for i, j in numerator_specs]
        + [("Q", i, j) for i, j in denominator_specs]
    )
    normalized_terms = list(all_terms)
    normalized_terms.remove(("P", 0, 1))
    assert len(all_terms) == 15722
    pivot_rows, normalized_pivot_columns = load_profiles(args.profiles)
    term_indices = {term: index for index, term in enumerate(all_terms)}
    pivot_columns = tuple(
        term_indices[normalized_terms[index]]
        for index in normalized_pivot_columns
    )
    pivot_column_set = set(pivot_columns)
    free_columns = tuple(
        index for index in range(len(all_terms))
        if index not in pivot_column_set
    )
    assert len(pivot_columns) == EXPECTED_RANK
    assert len(free_columns) == EXPECTED_KERNEL_DIMENSION
    assert term_indices[("P", 0, 1)] in free_columns

    mixed = load_module(
        "koenig_a_homogeneous_degree110_mixed",
        "lift_koenig_19adic_family.sage",
    )
    (
        lift,
        values,
        modulus,
        _,
        _,
        series_ring,
        parameter,
        _,
    ) = mixed.lift_family_digitwise(
        digits,
        PRECISION,
        progress=lambda axis, reached: print(
            f"{axis}={reached} elapsed={time.monotonic() - started:.3f}",
            flush=True,
        ),
    )
    assert modulus == PRIME**digits
    alpha = values[lift.SPECS.index(("f2", 4))]
    beta = values[lift.SPECS.index(("f1", 5))]
    u = alpha - 7
    v = beta - 14
    target = truncate(
        mixed,
        (series_ring(9) + parameter) ** 2,
        series_ring,
        parameter,
    )

    maximum_u = max(i for _, i, _ in all_terms)
    maximum_v = max(j for _, _, j in all_terms)
    u_powers = [series_ring.one()]
    v_powers = [series_ring.one()]
    for _ in range(maximum_u):
        u_powers.append(
            truncate(mixed, u_powers[-1] * u, series_ring, parameter)
        )
    for _ in range(maximum_v):
        v_powers.append(
            truncate(mixed, v_powers[-1] * v, series_ring, parameter)
        )
    target_v_powers = [
        truncate(mixed, -target * value, series_ring, parameter)
        for value in v_powers
    ]
    storage_dtype = unsigned_dtype_for_modulus(modulus)
    full_matrix = np.empty(
        (PRECISION, len(all_terms)), dtype=storage_dtype, order="F"
    )
    for column, (kind, i, j) in enumerate(all_terms):
        right_factor = v_powers[j] if kind == "P" else target_v_powers[j]
        monomial = truncate(
            mixed,
            u_powers[i] * right_factor,
            series_ring,
            parameter,
        )
        full_matrix[:, column] = np.fromiter(
            (int(monomial[row]) for row in range(PRECISION)),
            dtype=storage_dtype,
            count=PRECISION,
        )
        if column % 250 == 249:
            print(
                f"packed_columns={column + 1} "
                f"elapsed={time.monotonic() - started:.3f}",
                flush=True,
            )

    pivot_block = np.ascontiguousarray(
        full_matrix[np.ix_(pivot_rows, pivot_columns)],
        dtype=storage_dtype,
    )
    pivot_free = np.ascontiguousarray(
        full_matrix[np.ix_(pivot_rows, free_columns)],
        dtype=storage_dtype,
    )
    transformation, unit_block = hensel_unit_block(
        pivot_block,
        pivot_free,
        digits,
        progress=lambda reached: print(
            f"pivot_solve_digits={reached} "
            f"elapsed={time.monotonic() - started:.3f}",
            flush=True,
        ),
    )
    assert unit_block.rank() == EXPECTED_RANK
    del unit_block, pivot_block, pivot_free

    pivot_row_set = set(pivot_rows)
    nonpivot_training_rows = tuple(
        row for row in range(TRAINING_TERMS)
        if row not in pivot_row_set
    )
    holdout_rows = tuple(range(TRAINING_TERMS, PRECISION))
    assert len(nonpivot_training_rows) == (
        TRAINING_TERMS - EXPECTED_RANK
    )
    combined_rows = nonpivot_training_rows + holdout_rows
    reduced_all = schur_reduction(
        pivot_rows,
        combined_rows,
        pivot_columns,
        free_columns,
        full_matrix,
        transformation,
        digits,
    )
    reduced_training = reduced_all[: len(nonpivot_training_rows), :]
    reduced_holdout = reduced_all[len(nonpivot_training_rows) :, :]

    free_positions = {
        column: position for position, column in enumerate(free_columns)
    }
    pivot_positions = {
        column: position for position, column in enumerate(pivot_columns)
    }
    numerator_map_values = np.zeros(
        (len(numerator_specs), len(free_columns)), dtype=np.uint8
    )
    for numerator_position in range(len(numerator_specs)):
        if numerator_position in free_positions:
            numerator_map_values[
                numerator_position, free_positions[numerator_position]
            ] = 1
        else:
            numerator_map_values[numerator_position, :] = (
                transformation[pivot_positions[numerator_position], :]
                % PRIME
            )
    numerator_map = matrix(GF(PRIME), numerator_map_values)
    mod19_numerator_rank = int(numerator_map.rank())
    assert mod19_numerator_rank == EXPECTED_MOD19_NUMERATOR_RANK

    if digits == DEFAULT_DIGITS:
        training_results, training_kernels, training_bases = (
            analyze_reduced(reduced_training, numerator_map, digits - 1)
        )
        full_results, full_kernels, full_bases = analyze_reduced(
            reduced_all, numerator_map, digits - 1
        )
        forced_valuation = 2
    else:
        (
            training_results,
            training_kernels,
            training_bases,
            training_valuation,
        ) = analyze_reduced_hensel(
            reduced_training, numerator_map, digits - 1
        )
        full_results, full_kernels, full_bases, full_valuation = (
            analyze_reduced_hensel(
                reduced_all, numerator_map, digits - 1
            )
        )
        assert training_valuation == full_valuation
        forced_valuation = full_valuation
    for scope, results in (
        ("training", training_results),
        ("all", full_results),
    ):
        for result in results:
            print(
                f"scope={scope} digits={result['digits']} "
                f"projected_dimension={result['projected_dimension']} "
                "numerator_projection_rank="
                f"{result['numerator_projection_rank']} "
                "plane_control_dimension="
                f"{result['plane_control_dimension']} "
                f"elapsed={time.monotonic() - started:.3f}",
                flush=True,
            )
            assert (
                result["plane_control_dimension"]
                == EXPECTED_PLANE_DIMENSION
            )

    final_full = full_results[-1]
    status = "homogeneous_degree110_inconclusive"
    witness = None
    witness_digest = "none"
    fitting = -1
    holdout = -1
    final_kernel = full_kernels[digits - 1]
    if digits == DEFAULT_DIGITS:
        final_projected = final_kernel.matrix_from_columns(
            range(len(free_columns))
        )
    else:
        final_projected = full_bases[digits - 1]
    final_image = final_projected * numerator_map.transpose()
    if final_full["numerator_projection_rank"] > 0:
        witness_index = next(
            index for index in range(final_image.nrows())
            if not final_image.row(index).is_zero()
        )
        width = len(free_columns)
        if digits == DEFAULT_DIGITS:
            encoded = sage_matrix_to_uint(
                final_kernel.matrix_from_rows([witness_index])
            ).reshape(-1)
            free_values = np.zeros(width, dtype=np.uint64)
            for digit in range(digits - 1):
                free_values += (
                    PRIME**digit
                    * encoded[digit * width : (digit + 1) * width]
                )
        else:
            free_values = np.asarray(
                final_kernel[witness_index], dtype=np.uint64
            )
        pivot_values = exact_modular_product(
            transformation,
            free_values.reshape(-1, 1),
            digits,
        ).reshape(-1)
        witness = np.zeros(len(all_terms), dtype=np.uint64)
        witness[list(free_columns)] = free_values
        witness[list(pivot_columns)] = pivot_values
        normalization_index = term_indices[("P", 0, 1)]
        normalization_value = int(witness[normalization_index])
        assert normalization_value % PRIME
        normalization_inverse = pow(
            normalization_value, -1, modulus
        )
        witness = exact_modular_product(
            witness.reshape(-1, 1),
            np.asarray(
                [[normalization_inverse]], dtype=np.uint64
            ),
            digits,
        ).reshape(-1)
        assert witness[normalization_index] == 1
        residual = homogeneous_residuals(full_matrix, witness, digits)
        fitting = int(np.count_nonzero(residual[:TRAINING_TERMS]))
        holdout = int(np.count_nonzero(residual[TRAINING_TERMS:]))
        assert fitting == holdout == 0
        assert np.count_nonzero(witness[: len(numerator_specs)] % PRIME)
        canonical = "\n".join(
            f"{kind}:{i}:{j}:{int(value)}"
            for (kind, i, j), value in zip(all_terms, witness)
        ) + "\n"
        witness_digest = hashlib.sha256(canonical.encode()).hexdigest()
        status = "homogeneous_degree110_genuine_relation_verified"
    elif (
        final_full["projected_dimension"] == EXPECTED_PLANE_DIMENSION
        and final_full["numerator_projection_rank"] == 0
    ):
        status = (
            "homogeneous_degree110_genuine_relation_absent_mod19_"
            f"{digits}"
        )

    projected_training = sage_matrix_to_uint(
        training_bases[digits - 1], dtype=np.uint8
    )
    projected_full = sage_matrix_to_uint(
        full_bases[digits - 1], dtype=np.uint8
    )
    if digits == DEFAULT_DIGITS:
        result_header = (
            "scope\tdigits\tblock_rows\tblock_columns\tblock_rank\t"
            "tail_rank\tprojected_dimension\tnumerator_projection_rank"
        )
    else:
        result_header = (
            "scope\tdigits\tobstruction_rows\tobstruction_columns\t"
            "obstruction_rank\tprojected_dimension\t"
            "numerator_projection_rank\tplane_control_dimension"
        )
    result_lines = [result_header]
    for scope, results in (
        ("training", training_results),
        ("all", full_results),
    ):
        for result in results:
            if digits == DEFAULT_DIGITS:
                row = (
                    f"{scope}\t{result['digits']}\t"
                    f"{result['block_rows']}\t"
                    f"{result['block_columns']}\t"
                    f"{result['block_rank']}\t"
                    f"{result['tail_rank']}\t"
                    f"{result['projected_dimension']}\t"
                    f"{result['numerator_projection_rank']}"
                )
            else:
                row = (
                    f"{scope}\t{result['digits']}\t"
                    f"{result['obstruction_rows']}\t"
                    f"{result['obstruction_columns']}\t"
                    f"{result['obstruction_rank']}\t"
                    f"{result['projected_dimension']}\t"
                    f"{result['numerator_projection_rank']}"
                )
                row += f"\t{result['plane_control_dimension']}"
            result_lines.append(row)
    reduced_digest_text = (
        reduced_training.tobytes()
        + reduced_holdout.tobytes()
        + numerator_map_values.tobytes()
        + projected_training.tobytes()
        + projected_full.tobytes()
    )
    schema = (
        SCHEMA
        if digits == DEFAULT_DIGITS
        else "m23-koenig-a-homogeneous-degree110-v2"
    )
    lines = [
        f"# schema\t{schema}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# basis_sha256\t{sha256_file(args.basis)}",
        f"# profiles_sha256\t{sha256_file(args.profiles)}",
        (
            "# family_certificate_sha256\t"
            f"{sha256_file(args.family_certificate)}"
        ),
        f"# prime\t{PRIME}",
        f"# digits\t{digits}",
        f"# modulus\t{modulus}",
        f"# status\t{status}",
        f"# series_precision\t{PRECISION}",
        f"# training_terms\t{TRAINING_TERMS}",
        f"# holdout_terms\t{PRECISION - TRAINING_TERMS}",
        f"# homogeneous_unknowns\t{len(all_terms)}",
        f"# mod19_rank\t{EXPECTED_RANK}",
        f"# mod19_kernel_dimension\t{EXPECTED_KERNEL_DIMENSION}",
        f"# mod19_numerator_projection_rank\t{mod19_numerator_rank}",
        f"# plane_multiple_control_dimension\t{EXPECTED_PLANE_DIMENSION}",
        *(
            [f"# reduced_forced_valuation\t{forced_valuation}"]
            if digits != DEFAULT_DIGITS
            else []
        ),
        f"# nonpivot_training_rows\t{len(nonpivot_training_rows)}",
        f"# reduced_width\t{len(free_columns)}",
        (
            "# reduced_arrays_sha256\t"
            f"{hashlib.sha256(reduced_digest_text).hexdigest()}"
        ),
        f"# witness_coefficients_sha256\t{witness_digest}",
        f"# fitting_nonzero_residuals\t{fitting}",
        f"# holdout_nonzero_residuals\t{holdout}",
        *result_lines,
    ]
    text = "\n".join(lines) + "\n"

    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.reduced_output is not None:
        args.reduced_output.parent.mkdir(parents=True, exist_ok=True)
        projected_arrays = (
            {
                "projected_training_mod19_4": projected_training,
                "projected_all_mod19_4": projected_full,
            }
            if digits == DEFAULT_DIGITS
            else {
                "projected_training": projected_training,
                "projected_all": projected_full,
            }
        )
        np.savez_compressed(
            args.reduced_output,
            schema=np.asarray(schema),
            code_revision=np.asarray(git_revision()),
            prime=np.asarray(PRIME, dtype=np.int16),
            reduced_training=reduced_training,
            reduced_holdout=reduced_holdout,
            numerator_map=numerator_map_values,
            pivot_columns=np.asarray(pivot_columns, dtype=np.int32),
            free_columns=np.asarray(free_columns, dtype=np.int32),
            **projected_arrays,
        )
    if args.coefficients_output is not None and witness is not None:
        coefficient_lines = [
            "# schema\tm23-koenig-a-homogeneous-degree110-coefficients-v1",
            f"# code_revision\t{git_revision()}",
            f"# summary_sha256\t{hashlib.sha256(text.encode()).hexdigest()}",
            f"# modulus\t{modulus}",
            "kind\ti\tj\tcoefficient",
        ]
        coefficient_lines.extend(
            f"{kind}\t{i}\t{j}\t{int(value)}"
            for (kind, i, j), value in zip(all_terms, witness)
            if value
        )
        args.coefficients_output.parent.mkdir(parents=True, exist_ok=True)
        args.coefficients_output.write_text(
            "\n".join(coefficient_lines) + "\n"
        )
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
    if (
        args.support_audit_output is not None
        or args.support_representatives_output is not None
        or args.check_support_summary is not None
        or args.support_quotient_output is not None
        or args.support_quotient_chart_output is not None
        or args.check_support_quotient_summary is not None
        or args.support_invariant_output is not None
        or args.support_invariant_image_output is not None
        or args.check_support_invariant_summary is not None
        or args.support_invariant_stages_output is not None
        or args.support_invariant_stage_images_output is not None
        or args.check_support_invariant_stages_summary is not None
    ):
        supported = load_module(
            "koenig_a_supported_subspace",
            "audit_koenig_relation_supported_subspace.sage",
        )
        reduced_full = np.vstack(
            (reduced_training, reduced_holdout)
        )
        quotient_requested = (
            args.support_quotient_output is not None
            or args.support_quotient_chart_output is not None
            or args.check_support_quotient_summary is not None
        )
        quotient_module = (
            load_module(
                "koenig_a_supported_quotient",
                "reconstruct_koenig_relation_supported_quotient.sage",
            )
            if quotient_requested
            else None
        )
        invariant_requested = (
            args.support_invariant_output is not None
            or args.support_invariant_image_output is not None
            or args.check_support_invariant_summary is not None
            or args.support_invariant_stages_output is not None
            or args.support_invariant_stage_images_output is not None
            or args.check_support_invariant_stages_summary is not None
        )
        invariant_module = (
            load_module(
                "koenig_a_supported_invariants",
                "audit_koenig_relation_supported_invariants.sage",
            )
            if invariant_requested
            else None
        )
        support_summary_source = (
            args.check_support_summary
            if args.check_support_summary is not None
            else args.support_audit_output
        )
        support_representatives_source = (
            args.support_representatives_input
            if args.support_representatives_input is not None
            else args.support_representatives_output
        )
        if quotient_requested or invariant_requested:
            if support_summary_source is None:
                raise ValueError(
                    "supported quotient/invariants require "
                    "--check-support-summary or --support-audit-output"
                )
            if support_representatives_source is None:
                raise ValueError(
                    "supported quotient/invariants require "
                    "--support-representatives-input or "
                    "--support-representatives-output"
                )
        supported.audit_supported_subspace(
            output=args.support_audit_output,
            representatives_output=args.support_representatives_output,
            check_summary=args.check_support_summary,
            filtration=args.support_filtration,
            filtration_sha256=sha256_file(args.support_filtration),
            basis_sha256=sha256_file(args.basis),
            profiles_sha256=sha256_file(args.profiles),
            family_sha256=sha256_file(args.family_certificate),
            code_revision=git_revision(),
            sage_version=SAGE_VERSION,
            digits=digits,
            cutoff=args.support_beta_cutoff,
            modulus=modulus,
            numerator_specs=numerator_specs,
            reduced_training=reduced_training,
            reduced_all=reduced_full,
            numerator_map_values=numerator_map_values,
            transformation=transformation,
            pivot_positions=pivot_positions,
            free_positions=free_positions,
            free_columns=free_columns,
            modular_product=exact_modular_product,
            quotient_module=quotient_module,
            quotient_output=args.support_quotient_output,
            quotient_chart_output=args.support_quotient_chart_output,
            check_quotient_summary=args.check_support_quotient_summary,
            support_summary_input=support_summary_source,
            support_representatives_input=support_representatives_source,
            invariant_module=invariant_module,
            invariant_output=args.support_invariant_output,
            invariant_image_output=(
                args.support_invariant_image_output
            ),
            check_invariant_summary=(
                args.check_support_invariant_summary
            ),
            invariant_stages_output=(
                args.support_invariant_stages_output
            ),
            invariant_stage_images_output=(
                args.support_invariant_stage_images_output
            ),
            check_invariant_stages_summary=(
                args.check_support_invariant_stages_summary
            ),
        )
    print(text, end="")
    print(f"elapsed={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
