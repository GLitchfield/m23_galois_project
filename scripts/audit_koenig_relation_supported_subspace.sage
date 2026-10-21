#!/usr/bin/env sage
"""Audit exact 19-adic persistence of a numerator support block."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

from sage.all import GF, matrix

PRIME = 19
EXPECTED_WIDTH = 571
EXPECTED_PLANE_DIMENSION = 91
EXPECTED_AMBIENT_QUOTIENT_DIMENSION = 10
EXPECTED_TARGET_QUOTIENT_DIMENSION = 7
TARGET_BASE_DIGITS = 4
EXPECTED_NUMERATOR_COLUMNS = 9506
SCHEMA = "m23-koenig-a-relation-supported-subspace-v1"
REPRESENTATIVE_SCHEMA = (
    "m23-koenig-a-relation-supported-subspace-representatives-v1"
)


def export_uint(values, dtype=np.uint64):
    exported = values._export_as_string()
    result = np.fromstring(exported, dtype=dtype, sep=" ")
    return result.reshape(values.nrows(), values.ncols())


def exact_digit_product(left, right, digits):
    """Small independent exact product used by the synthetic self-test."""
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


def analyze_supported_system(
    system,
    numerator_map,
    maximum_digits,
    modular_product,
    expected_plane_dimension=None,
):
    field = GF(PRIME)
    width = system.shape[1]
    assert width == numerator_map.ncols()
    leading = matrix(
        field,
        np.ascontiguousarray(system % PRIME, dtype=np.uint8),
    )
    pivot_columns = tuple(map(int, leading.pivots()))
    constraint_rank = len(pivot_columns)
    leading_pivots = leading.matrix_from_columns(pivot_columns)
    pivot_rows = tuple(
        map(int, leading_pivots.transpose().pivots())
    )
    unit = (
        leading.matrix_from_rows(pivot_rows)
        .matrix_from_columns(pivot_columns)
    )
    assert unit.rank() == constraint_rank

    kernel = leading.right_kernel_matrix().row_space().basis_matrix()
    lifts = export_uint(kernel)
    results = []
    lift_history = {1: lifts.copy()}

    def append_result(digits, obstruction_rank):
        projected = matrix(
            field,
            np.ascontiguousarray(lifts % PRIME, dtype=np.uint8),
        )
        assert projected.rank() == projected.nrows()
        numerator_rank = int(
            (projected * numerator_map.transpose()).rank()
        )
        plane_dimension = projected.nrows() - numerator_rank
        if expected_plane_dimension is not None:
            assert plane_dimension == expected_plane_dimension
        results.append(
            {
                "digits": digits,
                "obstruction_rank": obstruction_rank,
                "projected_dimension": projected.nrows(),
                "numerator_projection_rank": numerator_rank,
                "plane_control_dimension": plane_dimension,
            }
        )

    append_result(1, 0)
    for digits in range(2, maximum_digits + 1):
        current_modulus = PRIME ** (digits - 1)
        next_modulus = current_modulus * PRIME
        stage_system = (
            system.astype(np.uint64) % next_modulus
        )
        product = modular_product(
            stage_system, lifts.transpose(), digits
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
        combination_values = export_uint(combinations)
        base_lifts = (
            combination_values @ lifts
        ) % current_modulus

        base_product = modular_product(
            stage_system, base_lifts.transpose(), digits
        )
        assert np.count_nonzero(
            base_product % current_modulus
        ) == 0
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
        correction[list(pivot_columns), :] = export_uint(
            correction_pivots
        )
        lifts = (
            base_lifts
            + current_modulus * correction.transpose()
        ) % next_modulus
        assert np.count_nonzero(
            modular_product(
                stage_system, lifts.transpose(), digits
            )
        ) == 0
        lift_history[digits] = lifts.copy()
        append_result(digits, obstruction_rank)

    return results, lifts, constraint_rank, lift_history


def validate_filtration(path, cutoff):
    matching = []
    for line in path.read_text().splitlines():
        if line.startswith(f"beta_degree\t{cutoff}\t"):
            matching.append(line.split("\t"))
    assert len(matching) == 1
    _, _, selected, complement_rank, supported = matching[0]
    assert int(selected) == 7566
    assert int(complement_rank) == 470
    assert int(supported) == EXPECTED_TARGET_QUOTIENT_DIMENSION


def build_support_map(
    numerator_specs,
    cutoff,
    transformation,
    pivot_positions,
    free_positions,
):
    complement = [
        position
        for position, (_, beta_degree) in enumerate(numerator_specs)
        if beta_degree > cutoff
    ]
    result = np.zeros(
        (len(complement), EXPECTED_WIDTH), dtype=np.uint64
    )
    for row, numerator_position in enumerate(complement):
        if numerator_position in free_positions:
            result[row, free_positions[numerator_position]] = 1
        else:
            result[row, :] = transformation[
                pivot_positions[numerator_position], :
            ]
    return result, complement


def arrays_sha256(lifts, free_columns):
    digest = hashlib.sha256()
    digest.update(np.asarray(lifts, dtype=np.uint64).tobytes())
    digest.update(np.asarray(free_columns, dtype=np.int32).tobytes())
    return digest.hexdigest()


def audit_supported_subspace(
    *,
    output,
    representatives_output,
    check_summary,
    filtration,
    filtration_sha256,
    basis_sha256,
    profiles_sha256,
    family_sha256,
    code_revision,
    sage_version,
    digits,
    cutoff,
    modulus,
    numerator_specs,
    reduced_training,
    reduced_all,
    numerator_map_values,
    transformation,
    pivot_positions,
    free_positions,
    free_columns,
    modular_product,
    quotient_module=None,
    quotient_output=None,
    quotient_chart_output=None,
    check_quotient_summary=None,
    support_summary_input=None,
    support_representatives_input=None,
    invariant_module=None,
    invariant_output=None,
    invariant_image_output=None,
    check_invariant_summary=None,
    invariant_stages_output=None,
    invariant_stage_images_output=None,
    check_invariant_stages_summary=None,
):
    validate_filtration(filtration, cutoff)
    support_map, complement = build_support_map(
        numerator_specs,
        cutoff,
        transformation,
        pivot_positions,
        free_positions,
    )
    assert len(numerator_specs) == EXPECTED_NUMERATOR_COLUMNS
    assert len(complement) == 1940
    assert np.all(support_map < modulus)
    numerator_map = matrix(GF(PRIME), numerator_map_values)
    assert support_map.shape == (1940, EXPECTED_WIDTH)
    assert matrix(
        GF(PRIME),
        np.ascontiguousarray(support_map % PRIME, dtype=np.uint8),
    ).rank() == 470

    scoped_results = {}
    scoped_lifts = {}
    scoped_lift_histories = {}
    constraint_rank = None
    for scope, reduced in (
        ("training", reduced_training),
        ("all", reduced_all),
    ):
        relation_system = (
            PRIME * reduced.astype(np.uint64)
        ) % modulus
        system = np.vstack((support_map, relation_system))
        results, lifts, current_rank, lift_history = analyze_supported_system(
            system,
            numerator_map,
            digits,
            modular_product,
        )
        if constraint_rank is None:
            constraint_rank = current_rank
        assert current_rank == constraint_rank == 470
        assert np.count_nonzero(
            modular_product(
                support_map, lifts.transpose(), digits
            )
        ) == 0
        assert np.count_nonzero(
            modular_product(
                relation_system, lifts.transpose(), digits
            )
        ) == 0
        scoped_results[scope] = results
        scoped_lifts[scope] = lifts
        scoped_lift_histories[scope] = lift_history

    all_results = scoped_results["all"]
    assert digits >= TARGET_BASE_DIGITS
    assert all_results[0]["numerator_projection_rank"] == (
        EXPECTED_AMBIENT_QUOTIENT_DIMENSION
    )
    final_quotient_dimension = all_results[-1][
        "numerator_projection_rank"
    ]
    first_changed = next(
        (
            row["digits"]
            for row in all_results
            if row["digits"] >= TARGET_BASE_DIGITS
            and row["numerator_projection_rank"]
            != EXPECTED_TARGET_QUOTIENT_DIMENSION
        ),
        0,
    )
    status = (
        "beta_degree_block_persists"
        if first_changed == 0
        else f"beta_degree_block_changes_at_digit_{first_changed}"
    )

    final_lifts = scoped_lifts["all"]
    representatives_digest = arrays_sha256(
        final_lifts, free_columns
    )
    reduced_inputs_digest = hashlib.sha256(
        reduced_training.tobytes()
        + reduced_all.tobytes()
        + numerator_map_values.tobytes()
        + np.asarray(free_columns, dtype=np.int32).tobytes()
    ).hexdigest()
    if representatives_output is not None:
        representatives_output.parent.mkdir(
            parents=True, exist_ok=True
        )
        np.savez_compressed(
            representatives_output,
            schema=np.asarray(REPRESENTATIVE_SCHEMA),
            code_revision=np.asarray(code_revision),
            prime=np.asarray(PRIME, dtype=np.int16),
            digits=np.asarray(digits, dtype=np.int16),
            modulus=np.asarray(modulus, dtype=np.uint64),
            beta_cutoff=np.asarray(cutoff, dtype=np.int16),
            free_lifts=final_lifts,
            free_columns=np.asarray(free_columns, dtype=np.int32),
        )

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{code_revision}",
        f"# sage_version\t{sage_version}",
        f"# basis_sha256\t{basis_sha256}",
        f"# profiles_sha256\t{profiles_sha256}",
        f"# family_certificate_sha256\t{family_sha256}",
        f"# filtration_sha256\t{filtration_sha256}",
        f"# prime\t{PRIME}",
        f"# digits\t{digits}",
        f"# modulus\t{modulus}",
        f"# beta_degree_cutoff\t{cutoff}",
        f"# selected_numerator_columns\t{len(numerator_specs) - len(complement)}",
        f"# complementary_numerator_columns\t{len(complement)}",
        f"# mod19_support_constraint_rank\t{constraint_rank}",
        (
            "# initial_ambient_quotient_dimension\t"
            f"{EXPECTED_AMBIENT_QUOTIENT_DIMENSION}"
        ),
        f"# target_base_digits\t{TARGET_BASE_DIGITS}",
        (
            "# target_quotient_dimension\t"
            f"{EXPECTED_TARGET_QUOTIENT_DIMENSION}"
        ),
        f"# final_quotient_dimension\t{final_quotient_dimension}",
        f"# first_changed_digit\t{first_changed}",
        f"# reduced_support_inputs_sha256\t{reduced_inputs_digest}",
        f"# final_representatives_arrays_sha256\t{representatives_digest}",
        f"# status\t{status}",
        (
            "scope\tdigits\tobstruction_rank\tprojected_dimension\t"
            "numerator_projection_rank\tplane_control_dimension"
        ),
    ]
    for scope in ("training", "all"):
        for row in scoped_results[scope]:
            lines.append(
                f"{scope}\t{row['digits']}\t"
                f"{row['obstruction_rank']}\t"
                f"{row['projected_dimension']}\t"
                f"{row['numerator_projection_rank']}\t"
                f"{row['plane_control_dimension']}"
            )
    text = "\n".join(lines) + "\n"
    if output is not None:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text)
    if check_summary is not None:
        expected = [
            line
            for line in check_summary.read_text().splitlines()
            if not line.startswith("# code_revision\t")
        ]
        actual = [
            line
            for line in text.splitlines()
            if not line.startswith("# code_revision\t")
        ]
        assert actual == expected
    if quotient_module is not None:
        assert support_summary_input is not None
        assert support_representatives_input is not None
        quotient_module.audit_supported_quotient(
            output=quotient_output,
            chart_output=quotient_chart_output,
            check_summary=check_quotient_summary,
            support_summary=support_summary_input,
            support_representatives=support_representatives_input,
            basis_sha256=basis_sha256,
            code_revision=code_revision,
            sage_version=sage_version,
            digits=digits,
            cutoff=cutoff,
            numerator_specs=numerator_specs,
            lift_history=scoped_lift_histories["all"],
            transformation=transformation,
            pivot_positions=pivot_positions,
            free_positions=free_positions,
            free_columns=free_columns,
            modular_product=modular_product,
        )
    single_invariant_requested = (
        invariant_output is not None
        or invariant_image_output is not None
        or check_invariant_summary is not None
    )
    stage_invariants_requested = (
        invariant_stages_output is not None
        or invariant_stage_images_output is not None
        or check_invariant_stages_summary is not None
    )
    if invariant_module is not None and single_invariant_requested:
        assert support_summary_input is not None
        assert support_representatives_input is not None
        invariant_module.audit_supported_invariants(
            output=invariant_output,
            image_output=invariant_image_output,
            check_summary=check_invariant_summary,
            support_summary=support_summary_input,
            support_representatives=support_representatives_input,
            basis_sha256=basis_sha256,
            code_revision=code_revision,
            sage_version=sage_version,
            digits=digits,
            cutoff=cutoff,
            numerator_specs=numerator_specs,
            final_lifts=scoped_lifts["all"],
            transformation=transformation,
            pivot_positions=pivot_positions,
            free_positions=free_positions,
            free_columns=free_columns,
            modular_product=modular_product,
        )
    if invariant_module is not None and stage_invariants_requested:
        assert support_summary_input is not None
        assert support_representatives_input is not None
        invariant_module.audit_supported_invariant_stages(
            output=invariant_stages_output,
            image_output=invariant_stage_images_output,
            check_summary=check_invariant_stages_summary,
            support_summary=support_summary_input,
            support_representatives=support_representatives_input,
            basis_sha256=basis_sha256,
            code_revision=code_revision,
            sage_version=sage_version,
            maximum_digits=digits,
            minimum_digits=TARGET_BASE_DIGITS,
            cutoff=cutoff,
            numerator_specs=numerator_specs,
            lift_history=scoped_lift_histories["all"],
            transformation=transformation,
            pivot_positions=pivot_positions,
            free_positions=free_positions,
            free_columns=free_columns,
            modular_product=modular_product,
        )
    print(
        "supported-subspace audit: "
        f"beta<={cutoff}, quotient dimensions "
        + ",".join(
            str(row["numerator_projection_rank"])
            for row in all_results
        ),
        flush=True,
    )
    return text


def self_test():
    field = GF(PRIME)
    system = np.array(
        [
            [1, 0, 0, 0],
            [0, 0, 1, 0],
            [0, PRIME, 0, 0],
        ],
        dtype=np.uint64,
    )
    numerator_map = matrix(
        field,
        [
            [0, 1, 0, 0],
        ],
    )
    results, lifts, rank, history = analyze_supported_system(
        system,
        numerator_map,
        3,
        exact_digit_product,
        expected_plane_dimension=1,
    )
    assert rank == 2
    assert sorted(history) == [1, 2, 3]
    assert [row["projected_dimension"] for row in results] == [2, 1, 1]
    assert [row["numerator_projection_rank"] for row in results] == [1, 0, 0]
    assert np.count_nonzero(
        exact_digit_product(system, lifts.transpose(), 3)
    ) == 0

    plane_obstructed = np.array(
        [
            [1, 0, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, PRIME],
        ],
        dtype=np.uint64,
    )
    plane_results, _, _, plane_history = analyze_supported_system(
        plane_obstructed,
        numerator_map,
        3,
        exact_digit_product,
    )
    assert [
        row["numerator_projection_rank"] for row in plane_results
    ] == [1, 1, 1]
    assert [
        row["plane_control_dimension"] for row in plane_results
    ] == [1, 0, 0]
    assert sorted(plane_history) == [1, 2, 3]
    print("supported-subspace synthetic self-test passed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if not args.self_test:
        raise SystemExit("this module is invoked by the homogeneous lift")
    self_test()


if __name__ == "__main__":
    main()
