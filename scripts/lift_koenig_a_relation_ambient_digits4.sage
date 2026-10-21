#!/usr/bin/env sage
"""Continue König's ambient a-relation from 19^2 through 19^4."""

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
SEED_DIGITS = 2
PRECISION = 16384
TRAINING_TERMS = 16000
EXPECTED_RANK = 15091
EXPECTED_GAUGE_DIMENSION = 85
SCHEMA = "m23-koenig-a-ambient-digits4-v1"


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
        cutoff = int(stored["selected_cutoff"])
        numerator_specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
        denominator_specs = [
            (int(i), int(j))
            for i, j in stored["denominator_specs"]
            if int(i) + int(j) <= cutoff
        ]
    assert cutoff == 105
    return cutoff, numerator_specs, denominator_specs


def load_sparse_coefficients(path):
    result = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, i_text, j_text, value_text = line.split("\t")
        result[(kind, int(i_text), int(j_text))] = int(value_text)
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
            "data/derived/m23_koenig_a_relation_coefficients_mod361.tsv"
        ),
    )
    parser.add_argument(
        "--seed-summary",
        type=Path,
        default=Path(
            "data/derived/m23_koenig_a_relation_ambient_digit2.tsv"
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
    cutoff, numerator_specs, denominator_specs = load_specs(args.basis)
    all_terms = (
        [("P", i, j) for i, j in numerator_specs]
        + [("Q", i, j) for i, j in denominator_specs]
    )
    all_terms.remove(("P", 0, 1))
    assert len(all_terms) == 15176
    seed_values = load_sparse_coefficients(args.seed_coefficients)
    coefficients = np.asarray(
        [seed_values.get(term, 0) for term in all_terms],
        dtype=np.uint64,
    )
    seed_modulus = PRIME**SEED_DIGITS
    assert all(0 <= value < seed_modulus for value in coefficients)

    mixed = load_module(
        "koenig_a_ambient_digits4_mixed",
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
    assert rank == EXPECTED_RANK
    assert len(all_terms) - rank == EXPECTED_GAUGE_DIMENSION
    print(
        f"rank_profiles_complete rank={rank} "
        f"elapsed={time.monotonic() - started:.3f}",
        flush=True,
    )

    square_values = np.ascontiguousarray(
        full_matrix[np.ix_(pivot_rows, pivot_columns)] % PRIME,
        dtype=np.uint8,
    )
    pivot_matrix = matrix(field, square_values)
    del square_values
    stage_results = []
    correction_counts = []
    rejected_digit = None
    for digit in range(SEED_DIGITS, DIGITS):
        scale = PRIME**digit
        stage_modulus = PRIME ** (digit + 1)
        residual_before = exact_residuals(
            full_matrix, coefficients, normalization_values, stage_modulus
        )
        assert np.count_nonzero(residual_before % scale) == 0
        right_hand_side = matrix(
            field,
            rank,
            1,
            [
                (-int(residual_before[row] // scale)) % PRIME
                for row in pivot_rows
            ],
        )
        correction_pivot = pivot_matrix._solve_right_nonsingular_square(
            right_hand_side, check_rank=False
        )
        correction = np.zeros(len(all_terms), dtype=np.uint64)
        correction[list(pivot_columns)] = np.fromiter(
            (int(entry) for entry in correction_pivot.column(0)),
            dtype=np.uint64,
            count=rank,
        )
        previously_zero = coefficients == 0
        correction_counts.append(
            (
                digit + 1,
                int(np.count_nonzero(correction[previously_zero])),
                int(np.count_nonzero(correction[~previously_zero])),
            )
        )
        coefficients += scale * correction
        residual_after = exact_residuals(
            full_matrix, coefficients, normalization_values, stage_modulus
        )
        fitting = int(np.count_nonzero(residual_after[:TRAINING_TERMS]))
        holdout = int(np.count_nonzero(residual_after[TRAINING_TERMS:]))
        stage_results.append((digit + 1, fitting, holdout))
        print(
            f"digit={digit + 1} fitting_nonzero={fitting} "
            f"holdout_nonzero={holdout} "
            f"elapsed={time.monotonic() - started:.3f}",
            flush=True,
        )
        if fitting or holdout:
            rejected_digit = digit + 1
            break
    del pivot_matrix

    status = (
        "ambient_digits4_verified"
        if rejected_digit is None
        else "ambient_continuation_rejected"
    )
    tested_digits = rejected_digit or DIGITS
    canonical = "\n".join(
        f"{kind}:{i}:{j}:{int(value)}"
        for (kind, i, j), value in zip(all_terms, coefficients)
    ) + "\n"
    coefficient_digest = hashlib.sha256(canonical.encode()).hexdigest()
    profile_lines = [
        "# schema\tm23-koenig-a-ambient-profiles-v1",
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
    profile_indices_text = (
        "\n".join(
            [f"row:{index}" for index in pivot_rows]
            + [f"column:{index}" for index in pivot_columns]
        )
        + "\n"
    )
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
        f"# tested_digits\t{tested_digits}",
        f"# modulus\t{PRIME**tested_digits}",
        f"# status\t{status}",
        f"# series_precision\t{PRECISION}",
        f"# training_terms\t{TRAINING_TERMS}",
        f"# holdout_terms\t{PRECISION - TRAINING_TERMS}",
        f"# denominator_cutoff\t{cutoff}",
        f"# normalized_unknowns\t{len(all_terms)}",
        "# normalization\tP[0,1]=1",
        f"# normalized_rank\t{rank}",
        f"# gauge_dimension\t{len(all_terms) - rank}",
        "# gauge_choice\tnonpivot correction coordinates zero at each digit",
        f"# pivot_rows_sha256\t{digest_indices(pivot_rows)}",
        f"# pivot_columns_sha256\t{digest_indices(pivot_columns)}",
        (
            "# profile_indices_sha256\t"
            f"{hashlib.sha256(profile_indices_text.encode()).hexdigest()}"
        ),
    ]
    for digit, dormant, active in correction_counts:
        lines.extend(
            [
                f"# digit_{digit}_zero_coordinate_corrections\t{dormant}",
                f"# digit_{digit}_nonzero_coordinate_corrections\t{active}",
            ]
        )
    for digit, fitting, holdout in stage_results:
        lines.extend(
            [
                f"# digit_{digit}_fitting_nonzero_residuals\t{fitting}",
                f"# digit_{digit}_holdout_nonzero_residuals\t{holdout}",
            ]
        )
    lines.extend(
        [
            f"# final_nonzero_coefficients\t{int(np.count_nonzero(coefficients))}",
            f"# coefficients_sha256\t{coefficient_digest}",
            "fitting_nonzero_residuals\tholdout_nonzero_residuals",
            f"{stage_results[-1][1]}\t{stage_results[-1][2]}",
        ]
    )
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.profiles_output is not None:
        args.profiles_output.parent.mkdir(parents=True, exist_ok=True)
        args.profiles_output.write_text(profile_text)
    if args.coefficients_output is not None:
        coefficient_lines = [
            "# schema\tm23-koenig-a-ambient-digits4-coefficients-v1",
            f"# code_revision\t{git_revision()}",
            f"# summary_sha256\t{hashlib.sha256(text.encode()).hexdigest()}",
            f"# modulus\t{PRIME**tested_digits}",
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
