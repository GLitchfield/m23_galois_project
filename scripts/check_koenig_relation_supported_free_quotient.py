#!/usr/bin/env python3
"""Independently validate the transient-free supported quotient."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

from check_koenig_relation_supported_invariants import (
    PRIME,
    exact_digit_product,
    inverse_unit,
    matrix_pivots,
    metadata,
    sha256,
)
from check_koenig_relation_supported_quotient import reconstruct

TRANSIENT_EXPONENT = 3
MINIMUM_STAGE_DIGITS = 4
MAXIMUM_SUPPORTED_STAGE_DIGITS = 13
DIMENSION = 7
SELECTED_COLUMNS = 7566
SCHEMA = "m23-koenig-a-relation-supported-free-quotient-v1"
CHART_SCHEMA = (
    "m23-koenig-a-relation-supported-free-quotient-chart-v1"
)
STAGE_SCHEMA = "m23-koenig-a-relation-supported-invariant-stages-v1"
STAGE_IMAGE_SCHEMA = (
    "m23-koenig-a-relation-supported-invariant-stage-images-v1"
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


def chart_arrays_sha256(
    charts: dict[int, np.ndarray],
    pivots: np.ndarray,
    nonpivots: np.ndarray,
    selected: np.ndarray,
) -> str:
    digest = hashlib.sha256()
    for effective_digits in sorted(charts):
        digest.update(
            np.asarray(
                charts[effective_digits], dtype=np.uint64
            ).tobytes()
        )
    digest.update(np.asarray(pivots, dtype=np.int32).tobytes())
    digest.update(np.asarray(nonpivots, dtype=np.int32).tobytes())
    digest.update(np.asarray(selected, dtype=np.int32).tobytes())
    return digest.hexdigest()


def canonical_free_chart(
    image: np.ndarray, effective_digits: int
) -> tuple[np.ndarray, tuple[int, ...], tuple[int, ...]]:
    modulus = PRIME**effective_digits
    values = np.asarray(image, dtype=np.uint64) % modulus
    row_indices = matrix_pivots((values % PRIME).transpose())
    assert len(row_indices) == DIMENSION
    basis = values[list(row_indices), :]
    pivot_columns = matrix_pivots(basis % PRIME)
    assert len(pivot_columns) == DIMENSION
    unit_inverse = inverse_unit(
        basis[:, pivot_columns], effective_digits
    )
    normalized = exact_digit_product(
        unit_inverse, basis, effective_digits
    )
    assert np.array_equal(
        normalized[:, pivot_columns],
        np.eye(DIMENSION, dtype=np.uint64),
    )
    nonpivot_columns = tuple(
        column
        for column in range(values.shape[1])
        if column not in set(pivot_columns)
    )
    return (
        normalized[:, nonpivot_columns],
        pivot_columns,
        nonpivot_columns,
    )


def stable_range(
    reconstructions: dict[int, dict[int, tuple[int, int]]],
    first_digits: int,
    final_digits: int,
) -> int:
    final = reconstructions[final_digits]
    return sum(
        all(
            value == reconstructions[digits].get(index)
            for digits in range(first_digits, final_digits)
        )
        for index, value in final.items()
        if all(
            index in reconstructions[digits]
            for digits in range(first_digits, final_digits)
        )
    )


def self_test() -> None:
    original_dimension = globals()["DIMENSION"]
    globals()["DIMENSION"] = 2
    try:
        high_digits = 4
        modulus = PRIME**high_digits
        free = np.asarray(
            [
                [1, 0, 2, modulus - 3],
                [0, 1, 5, 7],
            ],
            dtype=np.uint64,
        )
        transient = np.asarray(
            [[0, 0, PRIME**2, 0]], dtype=np.uint64
        )
        image = np.vstack((free, transient))
        chart, pivots, _ = canonical_free_chart(image, 2)
        assert pivots == (0, 1)
        assert np.array_equal(chart, free[:, 2:] % PRIME**2)
    finally:
        globals()["DIMENSION"] = original_dimension
    print("independent supported free quotient self-test passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "free_quotient_digits7.tsv"
        ),
    )
    parser.add_argument(
        "--chart",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "free_quotient_chart_digits7.npz"
        ),
    )
    parser.add_argument(
        "--stage-summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "invariant_stages_digits4to10.tsv"
        ),
    )
    parser.add_argument(
        "--stage-archive",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "numerator_stage_images_digits4to10.npz"
        ),
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return

    certificate = metadata(args.summary)
    stage_certificate = metadata(args.stage_summary)
    assert certificate["schema"] == SCHEMA
    assert stage_certificate["schema"] == STAGE_SCHEMA
    assert certificate["stage_summary_sha256"] == sha256(
        args.stage_summary
    )
    assert certificate["stage_archive_sha256"] == sha256(
        args.stage_archive
    )
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["transient_annihilator_exponent"]) == (
        TRANSIENT_EXPONENT
    )
    minimum_stage_digits = int(certificate["minimum_stage_digits"])
    maximum_stage_digits = int(certificate["maximum_stage_digits"])
    assert minimum_stage_digits == MINIMUM_STAGE_DIGITS
    assert (
        minimum_stage_digits
        <= maximum_stage_digits
        <= MAXIMUM_SUPPORTED_STAGE_DIGITS
    )
    assert int(stage_certificate["minimum_digits"]) == (
        minimum_stage_digits
    )
    assert int(stage_certificate["maximum_digits"]) == (
        maximum_stage_digits
    )
    minimum_effective = minimum_stage_digits - TRANSIENT_EXPONENT
    maximum_effective = maximum_stage_digits - TRANSIENT_EXPONENT
    assert int(certificate["minimum_effective_digits"]) == (
        minimum_effective
    )
    assert int(certificate["maximum_effective_digits"]) == (
        maximum_effective
    )
    assert int(certificate["quotient_dimension"]) == DIMENSION
    assert int(certificate["selected_numerator_columns"]) == (
        SELECTED_COLUMNS
    )
    assert int(certificate["chart_columns"]) == (
        SELECTED_COLUMNS - DIMENSION
    )
    entries = DIMENSION * (SELECTED_COLUMNS - DIMENSION)
    assert int(certificate["chart_entries"]) == entries

    with np.load(args.stage_archive) as stored:
        assert str(stored["schema"]) == STAGE_IMAGE_SCHEMA
        selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
        stage_images = {
            stage_digits: np.asarray(
                stored[f"numerator_image_digits{stage_digits}"],
                dtype=np.uint64,
            )
            for stage_digits in range(
                minimum_stage_digits, maximum_stage_digits + 1
            )
        }
        stage_lifts = {
            stage_digits: np.asarray(
                stored[f"free_lifts_digits{stage_digits}"],
                dtype=np.uint64,
            )
            for stage_digits in range(
                minimum_stage_digits, maximum_stage_digits + 1
            )
        }
    assert stage_certificate["stage_arrays_sha256"] == (
        stage_arrays_sha256(stage_images, stage_lifts, selected)
    )

    with np.load(args.chart) as stored:
        assert str(stored["schema"]) == CHART_SCHEMA
        assert int(stored["prime"]) == PRIME
        assert int(stored["transient_exponent"]) == TRANSIENT_EXPONENT
        assert int(stored["minimum_stage_digits"]) == minimum_stage_digits
        assert int(stored["maximum_stage_digits"]) == maximum_stage_digits
        pivots = np.asarray(
            stored["pivot_columns"], dtype=np.int32
        )
        nonpivots = np.asarray(
            stored["nonpivot_columns"], dtype=np.int32
        )
        chart_selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
        charts = {
            effective_digits: np.asarray(
                stored[f"chart_effective_digits{effective_digits}"],
                dtype=np.uint64,
            )
            for effective_digits in range(
                minimum_effective, maximum_effective + 1
            )
        }
    assert np.array_equal(selected, chart_selected)
    assert np.array_equal(
        np.sort(np.concatenate((pivots, nonpivots))),
        np.arange(SELECTED_COLUMNS, dtype=np.int32),
    )
    assert certificate["pivot_columns"] == ",".join(map(str, pivots))
    assert certificate["chart_arrays_sha256"] == chart_arrays_sha256(
        charts, pivots, nonpivots, selected
    )

    for stage_digits in range(
        minimum_stage_digits, maximum_stage_digits + 1
    ):
        effective_digits = stage_digits - TRANSIENT_EXPONENT
        expected_chart, expected_pivots, expected_nonpivots = (
            canonical_free_chart(
                stage_images[stage_digits], effective_digits
            )
        )
        assert tuple(map(int, pivots)) == expected_pivots
        assert tuple(map(int, nonpivots)) == expected_nonpivots
        assert np.array_equal(
            charts[effective_digits], expected_chart
        )

    mismatches = {}
    for effective_digits in range(
        minimum_effective + 1, maximum_effective + 1
    ):
        mismatches[effective_digits] = int(
            np.count_nonzero(
                charts[effective_digits]
                % (PRIME ** (effective_digits - 1))
                != charts[effective_digits - 1]
            )
        )
    assert int(certificate["coherent_transition_count"]) == sum(
        value == 0 for value in mismatches.values()
    )
    assert int(certificate["total_transition_mismatches"]) == sum(
        mismatches.values()
    )

    rows = result_rows(args.summary)
    assert [row["stage_digits"] for row in rows] == list(
        range(minimum_stage_digits, maximum_stage_digits + 1)
    )
    reconstructions = {}
    for row in rows:
        stage_digits = row["stage_digits"]
        effective_digits = stage_digits - TRANSIENT_EXPONENT
        assert row["effective_digits"] == effective_digits
        assert row["modulus"] == PRIME**effective_digits
        expected_mismatches = mismatches.get(effective_digits, -1)
        assert row["mismatches_from_previous"] == expected_mismatches
        reconstructions[effective_digits] = reconstruct(
            charts[effective_digits], PRIME**effective_digits
        )
        reconstructed = len(reconstructions[effective_digits])
        assert row["reconstructed_entries"] == reconstructed
        assert row["failed_entries"] == entries - reconstructed
        if effective_digits == minimum_effective:
            assert row["stable_from_previous"] == -1
        else:
            stable = sum(
                value
                == reconstructions[effective_digits - 1].get(index)
                for index, value in reconstructions[
                    effective_digits
                ].items()
                if index in reconstructions[effective_digits - 1]
            )
            assert row["stable_from_previous"] == stable

    stable_all = stable_range(
        reconstructions, minimum_effective, maximum_effective
    )
    stable_last_four = stable_range(
        reconstructions, maximum_effective - 3, maximum_effective
    )
    assert int(certificate["stable_all_effective_digits_entries"]) == (
        stable_all
    )
    assert int(
        certificate["stable_last_four_effective_digits_entries"]
    ) == stable_last_four
    final = reconstructions[maximum_effective]
    assert int(certificate["final_reconstructed_entries"]) == len(final)
    assert int(certificate["final_failed_entries"]) == entries - len(final)
    maximum_numerator = max(
        (abs(numerator) for numerator, _ in final.values()),
        default=0,
    )
    maximum_denominator = max(
        (denominator for _, denominator in final.values()),
        default=0,
    )
    assert int(certificate["maximum_reconstructed_numerator"]) == (
        maximum_numerator
    )
    assert int(certificate["maximum_reconstructed_denominator"]) == (
        maximum_denominator
    )
    status = (
        "incoherent_transient_free_quotient"
        if any(mismatches.values())
        else (
            "complete_stable_rational_free_quotient"
            if len(final) == entries and stable_all == entries
            else "coherent_free_quotient_incomplete_reconstruction"
        )
    )
    assert certificate["status"] == status
    print(
        "verified supported free quotient: "
        f"{sum(mismatches.values())} transition mismatches, "
        f"{len(final)}/{entries} final entries reconstruct, "
        f"{stable_all} stable across all effective digits"
    )


if __name__ == "__main__":
    main()
