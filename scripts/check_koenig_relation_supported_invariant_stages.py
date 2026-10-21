#!/usr/bin/env python3
"""Independently validate stage-wise supported numerator invariants."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

from check_koenig_relation_supported_invariants import (
    IMAGE_SCHEMA,
    PRIME,
    REPRESENTATIVE_SCHEMA,
    SELECTED_COLUMNS,
    SUPPORT_SCHEMA,
    UNIT_RANK,
    WIDTH,
    exact_digit_product,
    local_smith_valuations,
    matrix_pivots,
    metadata,
    sha256,
)

SCHEMA = "m23-koenig-a-relation-supported-invariant-stages-v1"
STAGE_IMAGE_SCHEMA = (
    "m23-koenig-a-relation-supported-invariant-stage-images-v1"
)
MINIMUM_DIGITS = 4
MAXIMUM_SUPPORTED_DIGITS = 13


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


def support_dimensions(path: Path) -> dict[int, int]:
    lines = [
        line.split("\t")
        for line in path.read_text().splitlines()
        if line.startswith("all\t")
    ]
    return {
        int(fields[1]): int(fields[3])
        for fields in lines
    }


def stage_arrays_sha256(
    stage_images: dict[int, np.ndarray],
    stage_lifts: dict[int, np.ndarray],
    selected: np.ndarray,
) -> str:
    digest = hashlib.sha256()
    for digits in sorted(stage_images):
        digest.update(np.asarray(digits, dtype=np.int16).tobytes())
        digest.update(
            np.asarray(
                stage_images[digits], dtype=np.uint64
            ).tobytes()
        )
        digest.update(
            np.asarray(
                stage_lifts[digits], dtype=np.uint64
            ).tobytes()
        )
    digest.update(np.asarray(selected, dtype=np.int32).tobytes())
    return digest.hexdigest()


def rank_mod19(values: np.ndarray) -> int:
    return len(matrix_pivots(values))


def assert_nested_row_spaces(
    earlier: np.ndarray, later: np.ndarray
) -> None:
    earlier_mod19 = np.asarray(earlier % PRIME, dtype=np.uint64)
    later_mod19 = np.asarray(later % PRIME, dtype=np.uint64)
    earlier_rank = rank_mod19(earlier_mod19)
    later_rank = rank_mod19(later_mod19)
    assert earlier_rank == earlier.shape[0]
    assert later_rank == later.shape[0]
    combined = np.vstack((earlier_mod19, later_mod19))
    assert rank_mod19(combined) == earlier_rank


def self_test() -> None:
    stage_images = {}
    stage_lifts = {}
    for digits in range(4, 7):
        image = np.zeros((3, 4), dtype=np.uint64)
        image[0, 0] = 1
        image[1, 1] = 1
        image[2, 2] = PRIME ** (digits - 2)
        assert local_smith_valuations(image, digits) == (
            0,
            0,
            digits - 2,
        )
        stage_images[digits] = image
        stage_lifts[digits] = np.eye(3, 5, dtype=np.uint64)
    selected = np.arange(4, dtype=np.int32)
    digest = stage_arrays_sha256(
        stage_images, stage_lifts, selected
    )
    assert len(digest) == 64
    assert_nested_row_spaces(stage_lifts[4], stage_lifts[5])
    print("independent supported invariant-stage self-test passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "invariant_stages_digits4to10.tsv"
        ),
    )
    parser.add_argument(
        "--archive",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "numerator_stage_images_digits4to10.npz"
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
        "--final-image",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "numerator_image_digits10.npz"
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
        default=Path(
            "data/derived/m23_koenig_f19_a_relation_basis.npz"
        ),
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
    assert int(certificate["prime"]) == PRIME
    minimum_digits = int(certificate["minimum_digits"])
    maximum_digits = int(certificate["maximum_digits"])
    assert minimum_digits == MINIMUM_DIGITS
    assert minimum_digits <= maximum_digits <= MAXIMUM_SUPPORTED_DIGITS
    assert int(certificate["beta_degree_cutoff"]) == 77
    assert int(certificate["selected_numerator_columns"]) == (
        SELECTED_COLUMNS
    )
    assert int(certificate["unit_invariant_factors"]) == UNIT_RANK
    stages = list(range(minimum_digits, maximum_digits + 1))

    with np.load(args.archive) as stored:
        assert str(stored["schema"]) == STAGE_IMAGE_SCHEMA
        assert int(stored["prime"]) == PRIME
        assert int(stored["minimum_digits"]) == minimum_digits
        assert int(stored["maximum_digits"]) == maximum_digits
        assert int(stored["beta_cutoff"]) == 77
        selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
        free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
        stage_images = {
            digits: np.asarray(
                stored[f"numerator_image_digits{digits}"],
                dtype=np.uint64,
            )
            for digits in stages
        }
        stage_lifts = {
            digits: np.asarray(
                stored[f"free_lifts_digits{digits}"],
                dtype=np.uint64,
            )
            for digits in stages
        }
    assert certificate["stage_arrays_sha256"] == stage_arrays_sha256(
        stage_images, stage_lifts, selected
    )

    with np.load(args.basis) as stored:
        numerator_specs = np.asarray(
            stored["numerator_specs"], dtype=np.int32
        )
    expected_selected = np.asarray(
        [
            position
            for position, (_, beta_degree) in enumerate(numerator_specs)
            if beta_degree <= 77
        ],
        dtype=np.int32,
    )
    assert np.array_equal(selected, expected_selected)

    with np.load(args.reduced) as stored:
        training = np.asarray(
            stored["reduced_training"], dtype=np.uint64
        )
        holdout = np.asarray(
            stored["reduced_holdout"], dtype=np.uint64
        )
        numerator_map = np.asarray(
            stored["numerator_map"], dtype=np.uint64
        )
        stored_free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert np.array_equal(free_columns, stored_free_columns)
    reduced_all = np.vstack((training, holdout))

    dimensions = support_dimensions(args.support_summary)
    rows = result_rows(args.summary)
    by_stage = {
        digits: [row for row in rows if row["digits"] == digits]
        for digits in stages
    }
    short_exponents = []
    short_multiplicities = []
    for digits in stages:
        image = stage_images[digits]
        lifts = stage_lifts[digits]
        modulus = PRIME**digits
        assert image.shape == (
            dimensions[digits],
            SELECTED_COLUMNS,
        )
        assert lifts.shape == (dimensions[digits], WIDTH)
        assert np.all(image < modulus)
        assert np.all(lifts < modulus)
        assert rank_mod19(lifts) == lifts.shape[0]

        relation_system = (PRIME * reduced_all) % modulus
        residual = exact_digit_product(
            relation_system, lifts.transpose(), digits
        )
        assert np.count_nonzero(residual) == 0
        expected_mod19 = (
            (lifts % PRIME)
            @ numerator_map[selected, :].transpose()
        ) % PRIME
        assert np.array_equal(image % PRIME, expected_mod19)

        valuations = local_smith_valuations(image, digits)
        multiplicities = [
            valuations.count(valuation)
            for valuation in range(digits)
        ]
        assert len(by_stage[digits]) == digits
        for row in by_stage[digits]:
            valuation = row["valuation"]
            assert row["source_generators"] == image.shape[0]
            assert row["multiplicity"] == multiplicities[valuation]
            assert row["annihilator_exponent"] == digits - valuation
        assert multiplicities[0] == UNIT_RANK
        positive = [
            (valuation, multiplicity)
            for valuation, multiplicity in enumerate(multiplicities)
            if valuation and multiplicity
        ]
        assert len(positive) == 1
        valuation, multiplicity = positive[0]
        short_exponents.append(digits - valuation)
        short_multiplicities.append(multiplicity)

    for earlier_digits, later_digits in zip(
        stages[:-1], stages[1:], strict=True
    ):
        assert_nested_row_spaces(
            stage_lifts[earlier_digits],
            stage_lifts[later_digits],
        )

    with np.load(args.support_representatives) as stored:
        assert str(stored["schema"]) == REPRESENTATIVE_SCHEMA
        final_lifts = np.asarray(
            stored["free_lifts"], dtype=np.uint64
        )
    assert np.array_equal(stage_lifts[maximum_digits], final_lifts)

    with np.load(args.final_image) as stored:
        assert str(stored["schema"]) == IMAGE_SCHEMA
        final_image_digits = int(stored["digits"])
        final_image = np.asarray(
            stored["numerator_image"], dtype=np.uint64
        )
        final_selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
    assert final_image_digits in stage_images
    assert np.array_equal(stage_images[final_image_digits], final_image)
    assert np.array_equal(selected, final_selected)

    assert len(set(short_exponents)) == 1
    assert len(set(short_multiplicities)) == 1
    assert int(certificate["short_factor_annihilator_exponent"]) == (
        short_exponents[0]
    )
    assert int(certificate["short_factor_multiplicity"]) == (
        short_multiplicities[0]
    )
    assert certificate["status"] == "constant_bounded_short_factors"
    print(
        "verified supported invariant stages: "
        + ";".join(
            f"d{digits}=v0:{UNIT_RANK},"
            f"v{digits - short_exponents[0]}:"
            f"{short_multiplicities[0]}"
            for digits in stages
        )
    )


if __name__ == "__main__":
    main()
