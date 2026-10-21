#!/usr/bin/env sage
"""Construct the transient-free supported König numerator quotient."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

from sage.all import GF, ZZ, Zmod, matrix

PRIME = 19
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


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path):
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def result_rows(path):
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


def chart_arrays_sha256(charts, pivots, nonpivots, selected):
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


def canonical_free_chart(image, effective_digits):
    modulus = PRIME**effective_digits
    values = np.asarray(image, dtype=np.uint64) % modulus
    leading = matrix(
        GF(PRIME),
        np.ascontiguousarray(values % PRIME, dtype=np.uint8),
    )
    assert leading.rank() == DIMENSION
    row_indices = tuple(map(int, leading.transpose().pivots()))
    assert len(row_indices) == DIMENSION
    basis = values[list(row_indices), :]
    basis_leading = matrix(
        GF(PRIME),
        np.ascontiguousarray(basis % PRIME, dtype=np.uint8),
    )
    pivot_columns = tuple(map(int, basis_leading.pivots()))
    assert len(pivot_columns) == DIMENSION
    nonpivot_columns = tuple(
        column
        for column in range(values.shape[1])
        if column not in set(pivot_columns)
    )
    ring_basis = matrix(
        Zmod(modulus),
        [[int(value) for value in row] for row in basis],
    )
    unit = ring_basis.matrix_from_columns(pivot_columns)
    assert unit.is_invertible()
    normalized = export_uint(unit.inverse() * ring_basis)
    assert np.array_equal(
        normalized[:, pivot_columns],
        np.eye(DIMENSION, dtype=np.uint64),
    )
    return (
        normalized[:, nonpivot_columns],
        row_indices,
        pivot_columns,
        nonpivot_columns,
    )


def rational_reconstruction(chart, modulus):
    successes = {}
    failures = 0
    modulus_integer = ZZ(modulus)
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


def build_free_quotient(
    *,
    stage_summary,
    stage_archive,
    output,
    chart_output,
    check_summary,
    code_revision,
    sage_version,
):
    certificate = metadata(stage_summary)
    assert certificate["schema"] == STAGE_SCHEMA
    assert certificate["status"] == "constant_bounded_short_factors"
    assert int(certificate["prime"]) == PRIME
    minimum_stage_digits = int(certificate["minimum_digits"])
    maximum_stage_digits = int(certificate["maximum_digits"])
    assert minimum_stage_digits == MINIMUM_STAGE_DIGITS
    assert (
        minimum_stage_digits
        <= maximum_stage_digits
        <= MAXIMUM_SUPPORTED_STAGE_DIGITS
    )
    assert int(certificate["unit_invariant_factors"]) == DIMENSION
    assert int(certificate["short_factor_annihilator_exponent"]) == (
        TRANSIENT_EXPONENT
    )

    rows = result_rows(stage_summary)
    for stage_digits in range(
        minimum_stage_digits, maximum_stage_digits + 1
    ):
        stage_rows = [
            row for row in rows if row["digits"] == stage_digits
        ]
        multiplicities = {
            row["valuation"]: row["multiplicity"]
            for row in stage_rows
            if row["multiplicity"]
        }
        assert multiplicities == {
            0: DIMENSION,
            stage_digits - TRANSIENT_EXPONENT: 3,
        }

    with np.load(stage_archive) as stored:
        assert str(stored["schema"]) == STAGE_IMAGE_SCHEMA
        assert int(stored["prime"]) == PRIME
        assert int(stored["minimum_digits"]) == minimum_stage_digits
        assert int(stored["maximum_digits"]) == maximum_stage_digits
        selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
        assert selected.shape == (SELECTED_COLUMNS,)
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
    assert certificate["stage_arrays_sha256"] == stage_arrays_sha256(
        stage_images, stage_lifts, selected
    )

    charts = {}
    row_indices = {}
    pivots = None
    nonpivots = None
    for stage_digits in range(
        minimum_stage_digits, maximum_stage_digits + 1
    ):
        effective_digits = stage_digits - TRANSIENT_EXPONENT
        (
            chart,
            current_rows,
            current_pivots,
            current_nonpivots,
        ) = canonical_free_chart(
            stage_images[stage_digits], effective_digits
        )
        charts[effective_digits] = chart
        row_indices[effective_digits] = current_rows
        if pivots is None:
            pivots = current_pivots
            nonpivots = current_nonpivots
        else:
            assert current_pivots == pivots
            assert current_nonpivots == nonpivots
    assert pivots is not None
    assert nonpivots is not None

    effective_minimum = minimum_stage_digits - TRANSIENT_EXPONENT
    effective_maximum = maximum_stage_digits - TRANSIENT_EXPONENT
    mismatches = {
        effective_digits: int(
            np.count_nonzero(
                charts[effective_digits]
                % (PRIME ** (effective_digits - 1))
                != charts[effective_digits - 1]
            )
        )
        for effective_digits in range(
            effective_minimum + 1, effective_maximum + 1
        )
    }
    coherent = all(value == 0 for value in mismatches.values())
    entries = DIMENSION * len(nonpivots)
    reconstructions = {}
    failures = {}
    for effective_digits in range(
        effective_minimum, effective_maximum + 1
    ):
        reconstructions[effective_digits], failures[effective_digits] = (
            rational_reconstruction(
                charts[effective_digits],
                PRIME**effective_digits,
            )
        )
        assert (
            len(reconstructions[effective_digits])
            + failures[effective_digits]
            == entries
        )
    adjacent_stability = {
        effective_digits: sum(
            value
            == reconstructions[effective_digits - 1].get(index)
            for index, value in reconstructions[
                effective_digits
            ].items()
            if index in reconstructions[effective_digits - 1]
        )
        for effective_digits in range(
            effective_minimum + 1, effective_maximum + 1
        )
    }

    def stable_range(first_digits):
        final = reconstructions[effective_maximum]
        return sum(
            all(
                value == reconstructions[digits].get(index)
                for digits in range(first_digits, effective_maximum)
            )
            for index, value in final.items()
            if all(
                index in reconstructions[digits]
                for digits in range(first_digits, effective_maximum)
            )
        )

    stable_all = stable_range(effective_minimum)
    stable_last_four = stable_range(effective_maximum - 3)
    final_successes = reconstructions[effective_maximum]
    maximum_numerator = max(
        (
            abs(numerator)
            for numerator, _ in final_successes.values()
        ),
        default=0,
    )
    maximum_denominator = max(
        (
            denominator
            for _, denominator in final_successes.values()
        ),
        default=0,
    )
    if not coherent:
        status = "incoherent_transient_free_quotient"
    elif failures[effective_maximum] == 0 and stable_all == entries:
        status = "complete_stable_rational_free_quotient"
    else:
        status = "coherent_free_quotient_incomplete_reconstruction"

    arrays_digest = chart_arrays_sha256(
        charts, pivots, nonpivots, selected
    )
    if chart_output is not None:
        chart_output.parent.mkdir(parents=True, exist_ok=True)
        chart_arrays = {
            f"chart_effective_digits{effective_digits}": charts[
                effective_digits
            ]
            for effective_digits in range(
                effective_minimum, effective_maximum + 1
            )
        }
        np.savez_compressed(
            chart_output,
            schema=np.asarray(CHART_SCHEMA),
            code_revision=np.asarray(code_revision),
            prime=np.asarray(PRIME, dtype=np.int16),
            transient_exponent=np.asarray(
                TRANSIENT_EXPONENT, dtype=np.int16
            ),
            minimum_stage_digits=np.asarray(
                minimum_stage_digits, dtype=np.int16
            ),
            maximum_stage_digits=np.asarray(
                maximum_stage_digits, dtype=np.int16
            ),
            pivot_columns=np.asarray(pivots, dtype=np.int32),
            nonpivot_columns=np.asarray(nonpivots, dtype=np.int32),
            selected_numerator_positions=selected,
            **chart_arrays,
        )

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{code_revision}",
        f"# sage_version\t{sage_version}",
        f"# prime\t{PRIME}",
        f"# transient_annihilator_exponent\t{TRANSIENT_EXPONENT}",
        f"# minimum_stage_digits\t{minimum_stage_digits}",
        f"# maximum_stage_digits\t{maximum_stage_digits}",
        f"# minimum_effective_digits\t{effective_minimum}",
        f"# maximum_effective_digits\t{effective_maximum}",
        f"# quotient_dimension\t{DIMENSION}",
        f"# selected_numerator_columns\t{SELECTED_COLUMNS}",
        f"# chart_columns\t{len(nonpivots)}",
        f"# chart_entries\t{entries}",
        "# pivot_columns\t" + ",".join(map(str, pivots)),
        f"# chart_arrays_sha256\t{arrays_digest}",
        f"# coherent_transition_count\t"
        f"{sum(value == 0 for value in mismatches.values())}",
        f"# total_transition_mismatches\t{sum(mismatches.values())}",
        f"# stable_all_effective_digits_entries\t{stable_all}",
        f"# stable_last_four_effective_digits_entries\t{stable_last_four}",
        f"# final_reconstructed_entries\t{len(final_successes)}",
        f"# final_failed_entries\t{failures[effective_maximum]}",
        f"# maximum_reconstructed_numerator\t{maximum_numerator}",
        f"# maximum_reconstructed_denominator\t{maximum_denominator}",
        f"# stage_summary_sha256\t{sha256(stage_summary)}",
        f"# stage_archive_sha256\t{sha256(stage_archive)}",
        f"# status\t{status}",
        (
            "stage_digits\teffective_digits\tmodulus\t"
            "mismatches_from_previous\treconstructed_entries\t"
            "failed_entries\tstable_from_previous"
        ),
    ]
    for stage_digits in range(
        minimum_stage_digits, maximum_stage_digits + 1
    ):
        effective_digits = stage_digits - TRANSIENT_EXPONENT
        lines.append(
            f"{stage_digits}\t{effective_digits}\t"
            f"{PRIME**effective_digits}\t"
            f"{mismatches.get(effective_digits, -1)}\t"
            f"{len(reconstructions[effective_digits])}\t"
            f"{failures[effective_digits]}\t"
            f"{adjacent_stability.get(effective_digits, -1)}"
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
        "supported free quotient: "
        f"{sum(mismatches.values())} transition mismatches, "
        f"{len(final_successes)}/{entries} final entries reconstruct, "
        f"{stable_all} stable across all effective digits",
        flush=True,
    )
    return text


def self_test():
    high_digits = 7
    modulus = PRIME**high_digits
    free = np.asarray(
        [
            [1, 0, 2, modulus - 3, 5],
            [0, 1, 7, 11, modulus - 13],
        ],
        dtype=np.uint64,
    )
    global DIMENSION
    original_dimension = DIMENSION
    DIMENSION = 2
    try:
        previous = None
        for stage_digits in range(4, 8):
            effective_digits = stage_digits - TRANSIENT_EXPONENT
            stage_modulus = PRIME**stage_digits
            transient = np.asarray(
                [[0, 0, 0, PRIME**effective_digits, 0]],
                dtype=np.uint64,
            )
            image = np.vstack(
                (free % stage_modulus, transient)
            )
            chart, _, pivots, _ = canonical_free_chart(
                image, effective_digits
            )
            assert pivots == (0, 1)
            if previous is not None:
                assert np.array_equal(
                    chart % (PRIME ** (effective_digits - 1)),
                    previous,
                )
            previous = chart
    finally:
        DIMENSION = original_dimension
    print("supported free quotient self-test passed")


def main():
    parser = argparse.ArgumentParser()
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
    parser.add_argument("--output", type=Path)
    parser.add_argument("--chart-output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--code-revision", required=False)
    parser.add_argument("--sage-version", default="10.9")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    revision = args.code_revision
    if revision is None:
        import subprocess

        revision = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    build_free_quotient(
        stage_summary=args.stage_summary,
        stage_archive=args.stage_archive,
        output=args.output,
        chart_output=args.chart_output,
        check_summary=args.check_summary,
        code_revision=revision,
        sage_version=args.sage_version,
    )


if __name__ == "__main__":
    main()
