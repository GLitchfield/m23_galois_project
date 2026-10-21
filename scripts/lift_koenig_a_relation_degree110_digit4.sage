#!/usr/bin/env sage
"""Test König's original denominator-degree-110 ansatz modulo 19^4."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
import time
from pathlib import Path

import numpy as np

from sage.all import GF, matrix
from sage.env import SAGE_VERSION

PRIME = 19
DIGITS = 4
SEED_DIGITS = 3
PRECISION = 16384
TRAINING_TERMS = 16000
EXPECTED_RANK = 15151
EXPECTED_GAUGE_DIMENSION = 570
SCHEMA = "m23-koenig-a-degree110-digit4-v1"


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


def load_sparse_coefficients(path):
    result = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, i, j, value = line.split("\t")
        result[(kind, int(i), int(j))] = int(value)
    return result


def truncate(mixed, value, series_ring, parameter):
    return mixed.truncate(value, series_ring, parameter, PRECISION)


def exact_residuals(full_matrix, coefficients, normalization, modulus):
    coefficients_array = np.asarray(coefficients, dtype=np.uint64)
    normalization_array = np.asarray(normalization, dtype=np.uint64)
    residual = np.empty(full_matrix.shape[0], dtype=np.uint64)
    for start in range(0, full_matrix.shape[0], 128):
        stop = min(start + 128, full_matrix.shape[0])
        product = (
            full_matrix[start:stop, :].astype(np.uint64)
            @ coefficients_array
        )
        residual[start:stop] = (
            product + normalization_array[start:stop]
        ) % modulus
    return residual


def digest_indices(indices):
    return hashlib.sha256(
        ("\n".join(map(str, indices)) + "\n").encode()
    ).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--basis",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation_basis.npz"),
    )
    parser.add_argument(
        "--seed-coefficients",
        type=Path,
        default=Path(
            "data/derived/m23_koenig_a_relation_coefficients_mod6859.tsv"
        ),
    )
    parser.add_argument(
        "--seed-summary",
        type=Path,
        default=Path(
            "data/derived/m23_koenig_a_relation_ambient_digits4.tsv"
        ),
    )
    parser.add_argument(
        "--family-certificate",
        type=Path,
        default=Path("data/derived/m23_koenig_19adic_family_16384.tsv"),
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--coefficients-output", type=Path)
    parser.add_argument("--profiles-output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()
    for path in (
        args.basis,
        args.seed_coefficients,
        args.seed_summary,
        args.family_certificate,
    ):
        if not path.exists():
            raise FileNotFoundError(path)

    started = time.monotonic()
    numerator_specs, denominator_specs = load_specs(args.basis)
    all_terms = (
        [("P", i, j) for i, j in numerator_specs]
        + [("Q", i, j) for i, j in denominator_specs]
    )
    all_terms.remove(("P", 0, 1))
    assert len(all_terms) == 15721
    seed_values = load_sparse_coefficients(args.seed_coefficients)
    coefficients = np.asarray(
        [seed_values.get(term, 0) for term in all_terms],
        dtype=np.uint64,
    )
    seed_modulus = PRIME**SEED_DIGITS
    assert all(0 <= value < seed_modulus for value in coefficients)

    mixed = load_module(
        "koenig_a_degree110_digit4_mixed",
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
        DIGITS,
        PRECISION,
        progress=lambda axis, reached: print(
            f"{axis}={reached} elapsed={time.monotonic() - started:.3f}",
            flush=True,
        ),
    )
    assert modulus == PRIME**DIGITS
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
    normalization_values = np.fromiter(
        (int(v[row]) for row in range(PRECISION)),
        dtype=np.uint32,
        count=PRECISION,
    )

    full_matrix = np.empty(
        (PRECISION, len(all_terms)), dtype=np.uint32, order="F"
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
            dtype=np.uint32,
            count=PRECISION,
        )
        if column % 250 == 249:
            print(
                f"packed_columns={column + 1} "
                f"elapsed={time.monotonic() - started:.3f}",
                flush=True,
            )

    seed_residual = exact_residuals(
        full_matrix, coefficients, normalization_values, seed_modulus
    )
    assert np.count_nonzero(seed_residual) == 0
    residual_before = exact_residuals(
        full_matrix, coefficients, normalization_values, modulus
    )
    assert np.count_nonzero(residual_before % seed_modulus) == 0

    field = GF(PRIME)
    training_values = np.ascontiguousarray(
        full_matrix[:TRAINING_TERMS, :] % PRIME, dtype=np.uint8
    )
    training_matrix = matrix(field, training_values)
    del training_values
    pivot_rows = tuple(training_matrix._echelonize_linbox(efd=False))
    rank = int(training_matrix.rank())
    pivot_columns = tuple(int(index) for index in training_matrix.pivots())
    del training_matrix
    print(
        f"rank_profiles_complete rank={rank} "
        f"elapsed={time.monotonic() - started:.3f}",
        flush=True,
    )
    assert rank == EXPECTED_RANK
    assert len(all_terms) - rank == EXPECTED_GAUGE_DIMENSION

    square_values = np.ascontiguousarray(
        full_matrix[np.ix_(pivot_rows, pivot_columns)] % PRIME,
        dtype=np.uint8,
    )
    pivot_matrix = matrix(field, square_values)
    del square_values
    right_hand_side = matrix(
        field,
        rank,
        1,
        [
            (-int(residual_before[row] // seed_modulus)) % PRIME
            for row in pivot_rows
        ],
    )
    correction_pivot = pivot_matrix._solve_right_nonsingular_square(
        right_hand_side, check_rank=False
    )
    del pivot_matrix
    correction = np.zeros(len(all_terms), dtype=np.uint64)
    correction[list(pivot_columns)] = np.fromiter(
        (int(entry) for entry in correction_pivot.column(0)),
        dtype=np.uint64,
        count=rank,
    )
    initially_zero = coefficients == 0
    zero_coordinate_corrections = int(
        np.count_nonzero(correction[initially_zero])
    )
    nonzero_coordinate_corrections = int(
        np.count_nonzero(correction[~initially_zero])
    )
    high_denominator_corrections = sum(
        correction[index] != 0
        for index, (kind, i, j) in enumerate(all_terms)
        if kind == "Q" and i + j > 105
    )
    coefficients += seed_modulus * correction
    residual_after = exact_residuals(
        full_matrix, coefficients, normalization_values, modulus
    )
    fitting = int(np.count_nonzero(residual_after[:TRAINING_TERMS]))
    holdout = int(np.count_nonzero(residual_after[TRAINING_TERMS:]))
    status = (
        "degree110_digit4_verified"
        if fitting == 0 and holdout == 0
        else "degree110_digit4_rejected"
    )

    canonical = "\n".join(
        f"{kind}:{i}:{j}:{int(value)}"
        for (kind, i, j), value in zip(all_terms, coefficients)
    ) + "\n"
    coefficient_digest = hashlib.sha256(canonical.encode()).hexdigest()
    profile_indices_text = (
        "\n".join(
            [f"row:{index}" for index in pivot_rows]
            + [f"column:{index}" for index in pivot_columns]
        )
        + "\n"
    )
    profile_lines = [
        "# schema\tm23-koenig-a-degree110-profiles-v1",
        f"# code_revision\t{git_revision()}",
        f"# rank\t{rank}",
        "kind\tposition\tindex",
    ]
    profile_lines.extend(
        f"row\t{position}\t{index}"
        for position, index in enumerate(pivot_rows)
    )
    profile_lines.extend(
        f"column\t{position}\t{index}"
        for position, index in enumerate(pivot_columns)
    )
    profile_text = "\n".join(profile_lines) + "\n"
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# basis_sha256\t{sha256_file(args.basis)}",
        f"# seed_summary_sha256\t{sha256_file(args.seed_summary)}",
        f"# seed_coefficients_sha256\t{sha256_file(args.seed_coefficients)}",
        (
            "# family_certificate_sha256\t"
            f"{sha256_file(args.family_certificate)}"
        ),
        f"# prime\t{PRIME}",
        f"# seed_digits\t{SEED_DIGITS}",
        f"# target_digits\t{DIGITS}",
        f"# modulus\t{modulus}",
        f"# status\t{status}",
        f"# series_precision\t{PRECISION}",
        f"# training_terms\t{TRAINING_TERMS}",
        f"# holdout_terms\t{PRECISION - TRAINING_TERMS}",
        "# denominator_cutoff\t110",
        f"# normalized_unknowns\t{len(all_terms)}",
        "# normalization\tP[0,1]=1",
        f"# normalized_rank\t{rank}",
        f"# gauge_dimension\t{len(all_terms) - rank}",
        "# gauge_choice\tnonpivot correction coordinates zero",
        f"# pivot_rows_sha256\t{digest_indices(pivot_rows)}",
        f"# pivot_columns_sha256\t{digest_indices(pivot_columns)}",
        (
            "# profile_indices_sha256\t"
            f"{hashlib.sha256(profile_indices_text.encode()).hexdigest()}"
        ),
        (
            "# zero_coordinate_corrections\t"
            f"{zero_coordinate_corrections}"
        ),
        (
            "# nonzero_coordinate_corrections\t"
            f"{nonzero_coordinate_corrections}"
        ),
        (
            "# high_denominator_nonzero_corrections\t"
            f"{high_denominator_corrections}"
        ),
        f"# final_nonzero_coefficients\t{int(np.count_nonzero(coefficients))}",
        f"# coefficients_sha256\t{coefficient_digest}",
        "fitting_nonzero_residuals\tholdout_nonzero_residuals",
        f"{fitting}\t{holdout}",
    ]
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.profiles_output is not None:
        args.profiles_output.parent.mkdir(parents=True, exist_ok=True)
        args.profiles_output.write_text(profile_text)
    if args.coefficients_output is not None and status.endswith("_verified"):
        coefficient_lines = [
            "# schema\tm23-koenig-a-degree110-digit4-coefficients-v1",
            f"# code_revision\t{git_revision()}",
            f"# summary_sha256\t{hashlib.sha256(text.encode()).hexdigest()}",
            f"# modulus\t{modulus}",
            "kind\ti\tj\tcoefficient",
        ]
        coefficient_lines.extend(
            f"{kind}\t{i}\t{j}\t{int(value)}"
            for (kind, i, j), value in zip(all_terms, coefficients)
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
    print(text, end="")
    print(f"elapsed={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
