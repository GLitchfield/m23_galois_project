#!/usr/bin/env sage
"""Compute local Smith invariants of the supported König numerator image."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

from sage.all import GF, Zmod, matrix

PRIME = 19
EXPECTED_WIDTH = 571
EXPECTED_NUMERATOR_COLUMNS = 9506
EXPECTED_SELECTED_COLUMNS = 7566
EXPECTED_UNIT_RANK = 7
SCHEMA = "m23-koenig-a-relation-supported-invariants-v1"
IMAGE_SCHEMA = "m23-koenig-a-relation-supported-numerator-image-v1"
STAGE_SCHEMA = "m23-koenig-a-relation-supported-invariant-stages-v1"
STAGE_IMAGE_SCHEMA = (
    "m23-koenig-a-relation-supported-invariant-stage-images-v1"
)
SUPPORT_SCHEMA = "m23-koenig-a-relation-supported-subspace-v1"
REPRESENTATIVE_SCHEMA = (
    "m23-koenig-a-relation-supported-subspace-representatives-v1"
)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path):
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def export_uint(values):
    if hasattr(values, "_export_as_string"):
        result = np.fromstring(
            values._export_as_string(), dtype=np.uint64, sep=" "
        )
    else:
        result = np.fromiter(
            (
                int(value)
                for row in values.rows()
                for value in row
            ),
            dtype=np.uint64,
            count=values.nrows() * values.ncols(),
        )
    return result.reshape(values.nrows(), values.ncols())


def arrays_sha256(image, selected):
    digest = hashlib.sha256()
    digest.update(np.asarray(image, dtype=np.uint64).tobytes())
    digest.update(np.asarray(selected, dtype=np.int32).tobytes())
    return digest.hexdigest()


def stage_arrays_sha256(stage_images, stage_lifts, selected):
    digest = hashlib.sha256()
    for digits in sorted(stage_images):
        digest.update(np.asarray(digits, dtype=np.int16).tobytes())
        digest.update(
            np.asarray(stage_images[digits], dtype=np.uint64).tobytes()
        )
        digest.update(
            np.asarray(stage_lifts[digits], dtype=np.uint64).tobytes()
        )
    digest.update(np.asarray(selected, dtype=np.int32).tobytes())
    return digest.hexdigest()


def exact_numerator_vectors(
    lifts,
    digits,
    numerator_specs,
    transformation,
    pivot_positions,
    free_positions,
    modular_product,
):
    modulus = PRIME**digits
    assert len(numerator_specs) == EXPECTED_NUMERATOR_COLUMNS
    vectors = np.zeros(
        (lifts.shape[0], len(numerator_specs)), dtype=np.uint64
    )
    free_numerator = [
        position
        for position in range(len(numerator_specs))
        if position in free_positions
    ]
    pivot_numerator = [
        position
        for position in range(len(numerator_specs))
        if position in pivot_positions
    ]
    assert len(free_numerator) + len(pivot_numerator) == len(
        numerator_specs
    )
    vectors[:, free_numerator] = lifts[
        :, [free_positions[position] for position in free_numerator]
    ]
    pivot_transformation = (
        transformation[
            [pivot_positions[position] for position in pivot_numerator], :
        ]
        % modulus
    )
    vectors[:, pivot_numerator] = modular_product(
        pivot_transformation,
        lifts.transpose(),
        digits,
    ).transpose()
    return vectors


def modular_difference(left, right, modulus):
    assert left.shape == right.shape
    return np.where(
        left >= right,
        left - right,
        left + modulus - right,
    ).astype(np.uint64)


def local_smith_valuations(values, digits, modular_product):
    current = np.asarray(values, dtype=np.uint64).copy()
    valuations = []
    for valuation in range(digits):
        if current.shape[0] == 0 or current.shape[1] == 0:
            break
        remaining_digits = digits - valuation
        modulus = PRIME**remaining_digits
        assert np.all(current < modulus)
        leading = matrix(
            GF(PRIME),
            np.ascontiguousarray(current % PRIME, dtype=np.uint8),
        )
        pivot_columns = tuple(map(int, leading.pivots()))
        rank = len(pivot_columns)
        if rank:
            pivot_rows = tuple(
                map(
                    int,
                    leading.matrix_from_columns(
                        pivot_columns
                    ).transpose().pivots(),
                )
            )
            assert len(pivot_rows) == rank
            pivot_row_set = set(pivot_rows)
            pivot_column_set = set(pivot_columns)
            other_rows = tuple(
                row
                for row in range(current.shape[0])
                if row not in pivot_row_set
            )
            other_columns = tuple(
                column
                for column in range(current.shape[1])
                if column not in pivot_column_set
            )
            unit_values = current[
                np.ix_(pivot_rows, pivot_columns)
            ]
            unit = matrix(
                Zmod(modulus),
                [
                    [int(value) for value in row]
                    for row in unit_values
                ],
            )
            assert unit.is_invertible()
            unit_inverse = export_uint(unit.inverse())
            upper_right = current[
                np.ix_(pivot_rows, other_columns)
            ]
            lower_left = current[
                np.ix_(other_rows, pivot_columns)
            ]
            lower_right = current[
                np.ix_(other_rows, other_columns)
            ]
            solved_upper = modular_product(
                unit_inverse,
                upper_right,
                remaining_digits,
            )
            correction = modular_product(
                lower_left,
                solved_upper,
                remaining_digits,
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


def audit_supported_invariants(
    *,
    output,
    image_output,
    check_summary,
    support_summary,
    support_representatives,
    basis_sha256,
    code_revision,
    sage_version,
    digits,
    cutoff,
    numerator_specs,
    final_lifts,
    transformation,
    pivot_positions,
    free_positions,
    free_columns,
    modular_product,
):
    support = metadata(support_summary)
    assert support["schema"] == SUPPORT_SCHEMA
    assert support["status"] == "beta_degree_block_persists"
    assert int(support["digits"]) == digits
    assert int(support["beta_degree_cutoff"]) == cutoff
    assert support["basis_sha256"] == basis_sha256
    assert final_lifts.shape[1] == EXPECTED_WIDTH

    with np.load(support_representatives) as stored:
        assert str(stored["schema"]) == REPRESENTATIVE_SCHEMA
        stored_lifts = np.asarray(stored["free_lifts"], dtype=np.uint64)
        stored_free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert np.array_equal(stored_lifts, final_lifts)
    assert np.array_equal(
        stored_free_columns,
        np.asarray(free_columns, dtype=np.int32),
    )

    selected = tuple(
        position
        for position, (_, beta_degree) in enumerate(numerator_specs)
        if beta_degree <= cutoff
    )
    complement = tuple(
        position
        for position, (_, beta_degree) in enumerate(numerator_specs)
        if beta_degree > cutoff
    )
    assert len(selected) == EXPECTED_SELECTED_COLUMNS
    exact_numerator = exact_numerator_vectors(
        final_lifts,
        digits,
        numerator_specs,
        transformation,
        pivot_positions,
        free_positions,
        modular_product,
    )
    assert np.count_nonzero(exact_numerator[:, complement]) == 0
    image = exact_numerator[:, selected]
    mod19_rank = int(
        matrix(
            GF(PRIME),
            np.ascontiguousarray(image % PRIME, dtype=np.uint8),
        ).rank()
    )
    assert mod19_rank == EXPECTED_UNIT_RANK

    valuations = local_smith_valuations(
        image, digits, modular_product
    )
    multiplicities = [
        valuations.count(valuation) for valuation in range(digits)
    ]
    assert multiplicities[0] == EXPECTED_UNIT_RANK
    nonzero_factors = len(valuations)
    divisible_factors = nonzero_factors - multiplicities[0]
    zero_generator_relations = image.shape[0] - nonzero_factors
    module_length = sum(
        (digits - valuation) * multiplicities[valuation]
        for valuation in range(digits)
    )
    status = (
        "saturated_free_rank7_image"
        if divisible_factors == 0
        else "nonsaturated_image_with_divisible_factors"
    )

    arrays_digest = arrays_sha256(image, selected)
    if image_output is not None:
        image_output.parent.mkdir(parents=True, exist_ok=True)
        np.savez_compressed(
            image_output,
            schema=np.asarray(IMAGE_SCHEMA),
            code_revision=np.asarray(code_revision),
            prime=np.asarray(PRIME, dtype=np.int16),
            digits=np.asarray(digits, dtype=np.int16),
            modulus=np.asarray(PRIME**digits, dtype=np.uint64),
            beta_cutoff=np.asarray(cutoff, dtype=np.int16),
            numerator_image=image,
            selected_numerator_positions=np.asarray(
                selected, dtype=np.int32
            ),
        )

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{code_revision}",
        f"# sage_version\t{sage_version}",
        f"# prime\t{PRIME}",
        f"# digits\t{digits}",
        f"# modulus\t{PRIME**digits}",
        f"# beta_degree_cutoff\t{cutoff}",
        f"# source_generators\t{image.shape[0]}",
        f"# selected_numerator_columns\t{image.shape[1]}",
        f"# mod19_image_rank\t{mod19_rank}",
        f"# nonzero_invariant_factors\t{nonzero_factors}",
        f"# unit_invariant_factors\t{multiplicities[0]}",
        f"# divisible_invariant_factors\t{divisible_factors}",
        f"# zero_generator_relations\t{zero_generator_relations}",
        f"# module_length_over_f19\t{module_length}",
        f"# image_arrays_sha256\t{arrays_digest}",
        f"# support_summary_sha256\t{sha256(support_summary)}",
        (
            "# support_representatives_sha256\t"
            f"{sha256(support_representatives)}"
        ),
        f"# basis_sha256\t{basis_sha256}",
        f"# status\t{status}",
        "valuation\tmultiplicity\tannihilator_exponent",
    ]
    lines.extend(
        f"{valuation}\t{multiplicities[valuation]}\t"
        f"{digits - valuation}"
        for valuation in range(digits)
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
    print(
        "supported numerator invariants: "
        + ",".join(
            f"v{valuation}:{multiplicity}"
            for valuation, multiplicity in enumerate(multiplicities)
            if multiplicity
        ),
        flush=True,
    )
    return text


def audit_supported_invariant_stages(
    *,
    output,
    image_output,
    check_summary,
    support_summary,
    support_representatives,
    basis_sha256,
    code_revision,
    sage_version,
    maximum_digits,
    minimum_digits,
    cutoff,
    numerator_specs,
    lift_history,
    transformation,
    pivot_positions,
    free_positions,
    free_columns,
    modular_product,
):
    support = metadata(support_summary)
    assert support["schema"] == SUPPORT_SCHEMA
    assert support["status"] == "beta_degree_block_persists"
    assert int(support["digits"]) == maximum_digits
    assert int(support["beta_degree_cutoff"]) == cutoff
    assert support["basis_sha256"] == basis_sha256
    assert sorted(lift_history) == list(range(1, maximum_digits + 1))

    with np.load(support_representatives) as stored:
        assert str(stored["schema"]) == REPRESENTATIVE_SCHEMA
        stored_lifts = np.asarray(stored["free_lifts"], dtype=np.uint64)
        stored_free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert np.array_equal(
        stored_lifts, lift_history[maximum_digits]
    )
    assert np.array_equal(
        stored_free_columns,
        np.asarray(free_columns, dtype=np.int32),
    )

    selected = tuple(
        position
        for position, (_, beta_degree) in enumerate(numerator_specs)
        if beta_degree <= cutoff
    )
    complement = tuple(
        position
        for position, (_, beta_degree) in enumerate(numerator_specs)
        if beta_degree > cutoff
    )
    assert len(selected) == EXPECTED_SELECTED_COLUMNS

    stage_images = {}
    stage_lifts = {}
    profiles = {}
    for digits in range(minimum_digits, maximum_digits + 1):
        lifts = np.asarray(lift_history[digits], dtype=np.uint64)
        exact_numerator = exact_numerator_vectors(
            lifts,
            digits,
            numerator_specs,
            transformation,
            pivot_positions,
            free_positions,
            modular_product,
        )
        assert np.count_nonzero(exact_numerator[:, complement]) == 0
        image = exact_numerator[:, selected]
        valuations = local_smith_valuations(
            image, digits, modular_product
        )
        multiplicities = [
            valuations.count(valuation)
            for valuation in range(digits)
        ]
        assert multiplicities[0] == EXPECTED_UNIT_RANK
        stage_images[digits] = image
        stage_lifts[digits] = lifts
        profiles[digits] = multiplicities

    short_exponents = []
    short_multiplicities = []
    for digits, multiplicities in profiles.items():
        positive = [
            (valuation, multiplicity)
            for valuation, multiplicity in enumerate(multiplicities)
            if valuation and multiplicity
        ]
        if len(positive) == 1:
            valuation, multiplicity = positive[0]
            short_exponents.append(digits - valuation)
            short_multiplicities.append(multiplicity)
        else:
            short_exponents.append(-1)
            short_multiplicities.append(-1)
    constant_short = (
        len(set(short_exponents)) == 1
        and short_exponents[0] > 0
        and len(set(short_multiplicities)) == 1
        and short_multiplicities[0] > 0
    )
    status = (
        "constant_bounded_short_factors"
        if constant_short
        else "stage_profile_not_constant_bounded"
    )

    arrays_digest = stage_arrays_sha256(
        stage_images, stage_lifts, selected
    )
    if image_output is not None:
        image_output.parent.mkdir(parents=True, exist_ok=True)
        archive = {
            "schema": np.asarray(STAGE_IMAGE_SCHEMA),
            "code_revision": np.asarray(code_revision),
            "prime": np.asarray(PRIME, dtype=np.int16),
            "minimum_digits": np.asarray(
                minimum_digits, dtype=np.int16
            ),
            "maximum_digits": np.asarray(
                maximum_digits, dtype=np.int16
            ),
            "beta_cutoff": np.asarray(cutoff, dtype=np.int16),
            "selected_numerator_positions": np.asarray(
                selected, dtype=np.int32
            ),
            "free_columns": np.asarray(
                free_columns, dtype=np.int32
            ),
        }
        for digits in range(minimum_digits, maximum_digits + 1):
            archive[f"numerator_image_digits{digits}"] = (
                stage_images[digits]
            )
            archive[f"free_lifts_digits{digits}"] = stage_lifts[digits]
        np.savez_compressed(image_output, **archive)

    lines = [
        f"# schema\t{STAGE_SCHEMA}",
        f"# code_revision\t{code_revision}",
        f"# sage_version\t{sage_version}",
        f"# prime\t{PRIME}",
        f"# minimum_digits\t{minimum_digits}",
        f"# maximum_digits\t{maximum_digits}",
        f"# beta_degree_cutoff\t{cutoff}",
        f"# selected_numerator_columns\t{len(selected)}",
        f"# unit_invariant_factors\t{EXPECTED_UNIT_RANK}",
        (
            "# short_factor_multiplicity\t"
            f"{short_multiplicities[0] if constant_short else 0}"
        ),
        (
            "# short_factor_annihilator_exponent\t"
            f"{short_exponents[0] if constant_short else 0}"
        ),
        f"# stage_arrays_sha256\t{arrays_digest}",
        f"# support_summary_sha256\t{sha256(support_summary)}",
        (
            "# support_representatives_sha256\t"
            f"{sha256(support_representatives)}"
        ),
        f"# basis_sha256\t{basis_sha256}",
        f"# status\t{status}",
        (
            "digits\tsource_generators\tvaluation\tmultiplicity\t"
            "annihilator_exponent"
        ),
    ]
    for digits in range(minimum_digits, maximum_digits + 1):
        for valuation, multiplicity in enumerate(profiles[digits]):
            lines.append(
                f"{digits}\t{stage_images[digits].shape[0]}\t"
                f"{valuation}\t{multiplicity}\t"
                f"{digits - valuation}"
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
    print(
        "supported numerator invariant stages: "
        + ";".join(
            f"d{digits}="
            + ",".join(
                f"v{valuation}:{multiplicity}"
                for valuation, multiplicity in enumerate(
                    profiles[digits]
                )
                if multiplicity
            )
            for digits in range(minimum_digits, maximum_digits + 1)
        ),
        flush=True,
    )
    return text


def exact_digit_product(left, right, digits):
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


def self_test():
    digits = 5
    modulus = PRIME**digits
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
    assert round(np.linalg.det(row_change.astype(np.float64))) == 1
    changed = exact_digit_product(row_change, planted, digits)
    changed = changed[:, [2, 5, 0, 4, 1, 3]]
    assert np.all(changed < modulus)
    assert local_smith_valuations(
        changed, digits, exact_digit_product
    ) == (0, 1, 3)
    print("supported numerator invariant self-test passed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if not args.self_test:
        raise SystemExit("this module is invoked by the homogeneous lift")
    self_test()


if __name__ == "__main__":
    main()
