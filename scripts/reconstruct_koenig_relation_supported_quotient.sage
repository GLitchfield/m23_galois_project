#!/usr/bin/env sage
"""Canonicalize and reconstruct the supported König numerator quotient."""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

import numpy as np

from sage.all import GF, ZZ, Zmod, matrix

PRIME = 19
TARGET_BASE_DIGITS = 4
TARGET_DIMENSION = 7
EXPECTED_NUMERATOR_COLUMNS = 9506
EXPECTED_SELECTED_COLUMNS = 7566
SCHEMA = "m23-koenig-a-relation-supported-quotient-reconstruction-v1"
CHART_SCHEMA = "m23-koenig-a-relation-supported-quotient-chart-v1"
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


def export_uint(values, force_generic=False):
    if hasattr(values, "_export_as_string") and not force_generic:
        exported = values._export_as_string()
        result = np.fromstring(
            exported, dtype=np.uint64, sep=" "
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


def arrays_sha256(charts, pivots, nonpivots, selected):
    digest = hashlib.sha256()
    for digits in sorted(charts):
        digest.update(
            np.asarray(
                charts[digits]["chart"], dtype=np.uint64
            ).tobytes()
        )
    digest.update(np.asarray(pivots, dtype=np.int32).tobytes())
    digest.update(np.asarray(nonpivots, dtype=np.int32).tobytes())
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
    assert np.all(vectors < modulus)
    return vectors


def canonical_image_chart(vectors, digits):
    modulus = PRIME**digits
    field_values = matrix(
        GF(PRIME),
        np.ascontiguousarray(vectors % PRIME, dtype=np.uint8),
    )
    assert field_values.rank() == TARGET_DIMENSION
    row_indices = tuple(map(int, field_values.transpose().pivots()))
    assert len(row_indices) == TARGET_DIMENSION
    basis = vectors[list(row_indices), :]
    basis_mod19 = matrix(
        GF(PRIME),
        np.ascontiguousarray(basis % PRIME, dtype=np.uint8),
    )
    pivot_columns = tuple(map(int, basis_mod19.pivots()))
    assert len(pivot_columns) == TARGET_DIMENSION
    nonpivot_columns = tuple(
        column
        for column in range(vectors.shape[1])
        if column not in set(pivot_columns)
    )

    ring = Zmod(modulus)
    basis_ring = matrix(
        ring,
        [[int(value) for value in row] for row in basis],
    )
    unit = basis_ring.matrix_from_columns(pivot_columns)
    assert unit.is_invertible()
    normalized = unit.inverse() * basis_ring
    normalized_values = export_uint(normalized)
    assert np.array_equal(
        normalized_values[:, pivot_columns],
        np.eye(TARGET_DIMENSION, dtype=np.uint64),
    )
    return {
        "row_indices": row_indices,
        "pivot_columns": pivot_columns,
        "nonpivot_columns": nonpivot_columns,
        "full": normalized_values,
        "chart": normalized_values[:, nonpivot_columns],
    }


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


def audit_supported_quotient(
    *,
    output,
    chart_output,
    check_summary,
    support_summary,
    support_representatives,
    basis_sha256,
    code_revision,
    sage_version,
    digits,
    cutoff,
    numerator_specs,
    lift_history,
    transformation,
    pivot_positions,
    free_positions,
    free_columns,
    modular_product,
):
    assert digits >= TARGET_BASE_DIGITS
    support = metadata(support_summary)
    assert support["schema"] == SUPPORT_SCHEMA
    assert support["status"] == "beta_degree_block_persists"
    assert int(support["digits"]) == digits
    assert int(support["beta_degree_cutoff"]) == cutoff
    assert int(support["target_quotient_dimension"]) == TARGET_DIMENSION
    assert support["basis_sha256"] == basis_sha256

    with np.load(support_representatives) as stored:
        assert str(stored["schema"]) == REPRESENTATIVE_SCHEMA
        assert int(stored["prime"]) == PRIME
        assert int(stored["digits"]) == digits
        assert int(stored["beta_cutoff"]) == cutoff
        stored_lifts = np.asarray(stored["free_lifts"], dtype=np.uint64)
        stored_free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert np.array_equal(stored_lifts, lift_history[digits])
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
    assert len(complement) == (
        EXPECTED_NUMERATOR_COLUMNS - EXPECTED_SELECTED_COLUMNS
    )

    charts = {}
    for current_digits in range(TARGET_BASE_DIGITS, digits + 1):
        numerator_vectors = exact_numerator_vectors(
            lift_history[current_digits],
            current_digits,
            numerator_specs,
            transformation,
            pivot_positions,
            free_positions,
            modular_product,
        )
        assert np.count_nonzero(
            numerator_vectors[:, complement]
        ) == 0
        charts[current_digits] = canonical_image_chart(
            numerator_vectors[:, selected],
            current_digits,
        )

    pivot_columns = charts[digits]["pivot_columns"]
    nonpivot_columns = charts[digits]["nonpivot_columns"]
    assert all(
        charts[current_digits]["pivot_columns"] == pivot_columns
        for current_digits in range(TARGET_BASE_DIGITS, digits)
    )
    mismatches = {
        current_digits: int(
            np.count_nonzero(
                charts[current_digits]["chart"]
                % (PRIME ** (current_digits - 1))
                != charts[current_digits - 1]["chart"]
            )
        )
        for current_digits in range(
            TARGET_BASE_DIGITS + 1, digits + 1
        )
    }
    coherent = all(value == 0 for value in mismatches.values())

    entries = TARGET_DIMENSION * len(nonpivot_columns)
    reconstructions = {}
    failures = {}
    for current_digits in range(TARGET_BASE_DIGITS, digits + 1):
        reconstructions[current_digits], failures[current_digits] = (
            rational_reconstruction(
                charts[current_digits]["chart"],
                PRIME**current_digits,
            )
        )
        assert (
            len(reconstructions[current_digits])
            + failures[current_digits]
            == entries
        )
    adjacent_stability = {
        current_digits: sum(
            value
            == reconstructions[current_digits - 1].get(index)
            for index, value in reconstructions[current_digits].items()
            if index in reconstructions[current_digits - 1]
        )
        for current_digits in range(
            TARGET_BASE_DIGITS + 1, digits + 1
        )
    }
    stable_all = sum(
        all(
            value == reconstructions[current_digits].get(index)
            for current_digits in range(TARGET_BASE_DIGITS, digits)
        )
        for index, value in reconstructions[digits].items()
        if all(
            index in reconstructions[current_digits]
            for current_digits in range(TARGET_BASE_DIGITS, digits)
        )
    )
    final_successes = reconstructions[digits]
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
        status = "incoherent_supported_quotient_chart"
    elif failures[digits] == 0 and stable_all == entries:
        status = "complete_stable_rational_chart"
    else:
        status = "incomplete_or_unstable_rational_chart"

    arrays_digest = arrays_sha256(
        charts, pivot_columns, nonpivot_columns, selected
    )
    if chart_output is not None:
        chart_output.parent.mkdir(parents=True, exist_ok=True)
        chart_arrays = {
            f"chart_digit{current_digits}": charts[
                current_digits
            ]["chart"]
            for current_digits in range(
                TARGET_BASE_DIGITS, digits + 1
            )
        }
        np.savez_compressed(
            chart_output,
            schema=np.asarray(CHART_SCHEMA),
            code_revision=np.asarray(code_revision),
            prime=np.asarray(PRIME, dtype=np.int16),
            digits=np.asarray(digits, dtype=np.int16),
            modulus=np.asarray(PRIME**digits, dtype=np.uint64),
            beta_cutoff=np.asarray(cutoff, dtype=np.int16),
            pivot_columns=np.asarray(pivot_columns, dtype=np.int32),
            nonpivot_columns=np.asarray(
                nonpivot_columns, dtype=np.int32
            ),
            selected_numerator_positions=np.asarray(
                selected, dtype=np.int32
            ),
            **chart_arrays,
        )

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{code_revision}",
        f"# sage_version\t{sage_version}",
        f"# prime\t{PRIME}",
        f"# digits\t{digits}",
        f"# modulus\t{PRIME**digits}",
        f"# beta_degree_cutoff\t{cutoff}",
        f"# selected_numerator_columns\t{len(selected)}",
        f"# quotient_dimension\t{TARGET_DIMENSION}",
        f"# chart_rows\t{TARGET_DIMENSION}",
        f"# chart_columns\t{len(nonpivot_columns)}",
        f"# chart_entries\t{entries}",
        "# pivot_columns\t" + ",".join(map(str, pivot_columns)),
        f"# chart_arrays_sha256\t{arrays_digest}",
        f"# coherent_transition_count\t"
        f"{sum(value == 0 for value in mismatches.values())}",
        f"# support_summary_sha256\t{sha256(support_summary)}",
        (
            "# support_representatives_sha256\t"
            f"{sha256(support_representatives)}"
        ),
        f"# basis_sha256\t{basis_sha256}",
        f"# stable_all_digits_entries\t{stable_all}",
        f"# final_failed_entries\t{failures[digits]}",
        f"# maximum_reconstructed_numerator\t{maximum_numerator}",
        f"# maximum_reconstructed_denominator\t{maximum_denominator}",
        f"# status\t{status}",
        (
            "digits\tmodulus\tmismatches_from_previous\t"
            "reconstructed_entries\tfailed_entries\t"
            "stable_from_previous"
        ),
    ]
    for current_digits in range(TARGET_BASE_DIGITS, digits + 1):
        lines.append(
            f"{current_digits}\t{PRIME**current_digits}\t"
            f"{mismatches.get(current_digits, -1)}\t"
            f"{len(reconstructions[current_digits])}\t"
            f"{failures[current_digits]}\t"
            f"{adjacent_stability.get(current_digits, -1)}"
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
        "supported quotient chart: "
        f"{TARGET_DIMENSION}x{len(nonpivot_columns)}, "
        f"{sum(mismatches.values())} adjacent-digit mismatches, "
        f"{len(final_successes)}/{entries} final entries reconstruct, "
        f"{stable_all} stable across all digits",
        flush=True,
    )
    return text


def self_test():
    modulus = PRIME**4
    small = np.asarray(
        [
            [1, 0, 2, modulus - 3, 5],
            [0, 1, 7, 11, modulus - 13],
        ],
        dtype=np.uint64,
    )
    transform = np.asarray(
        [[2, 1], [1, 1]], dtype=np.uint64
    )
    changed = (transform @ small) % modulus

    global TARGET_DIMENSION
    original_dimension = TARGET_DIMENSION
    TARGET_DIMENSION = 2
    try:
        first = canonical_image_chart(small, 4)
        second = canonical_image_chart(changed, 4)
        assert first["pivot_columns"] == second["pivot_columns"]
        assert np.array_equal(first["chart"], second["chart"])
        assert np.array_equal(
            export_uint(matrix(Zmod(modulus), small)),
            export_uint(
                matrix(Zmod(modulus), small), force_generic=True
            ),
        )
        reconstructed, failures = rational_reconstruction(
            first["chart"], modulus
        )
        assert failures == 0
        assert len(reconstructed) == first["chart"].size
    finally:
        TARGET_DIMENSION = original_dimension

    torsion = np.asarray(
        [[1, 2], [0, PRIME]], dtype=np.uint64
    )
    changed_torsion_basis = np.asarray(
        [[1, 2 + PRIME], [0, PRIME]], dtype=np.uint64
    )
    TARGET_DIMENSION = 1
    try:
        torsion_first = canonical_image_chart(torsion, 2)
        torsion_second = canonical_image_chart(
            changed_torsion_basis, 2
        )
        assert not np.array_equal(
            torsion_first["chart"], torsion_second["chart"]
        )
        assert np.array_equal(
            torsion_first["chart"] % PRIME,
            torsion_second["chart"] % PRIME,
        )
    finally:
        TARGET_DIMENSION = original_dimension
    print("supported quotient chart self-test passed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if not args.self_test:
        raise SystemExit("this module is invoked by the homogeneous lift")
    self_test()


if __name__ == "__main__":
    main()
