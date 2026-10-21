#!/usr/bin/env sage
"""Full-support pilot lift of König's a=lambda^2 relation modulo 19^4."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
import time
from pathlib import Path

import numpy as np

from sage.all import GF, identity_matrix, matrix, vector
from sage.env import SAGE_VERSION

PRIME = 19
DIGITS = 4
PRECISION = 16384
TRAINING_TERMS = 16000
SCHEMA = "m23-koenig-a-relation-pilot-v2"
DEFAULT_FAMILY_CERTIFICATE = Path(
    "data/derived/m23_koenig_19adic_family_16384.tsv"
)


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


def parse_support(path):
    terms = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        kind, i_text, j_text, coefficient_text = line.split("\t")
        terms.append(
            (
                kind,
                int(i_text),
                int(j_text),
                int(coefficient_text),
            )
        )
    normalization = ("P", 0, 1, 1)
    assert normalization in terms
    terms.remove(normalization)
    assert len(terms) == 10573
    return normalization, terms


def truncate(mixed, value, series_ring, parameter, precision):
    return mixed.truncate(
        value, series_ring, parameter, precision
    )


def exact_residuals(full_matrix, coefficients, normalization, modulus):
    coefficients_array = np.asarray(coefficients, dtype=np.uint64)
    normalization_array = np.asarray(normalization, dtype=np.uint64)
    residual = np.empty(full_matrix.shape[0], dtype=np.uint64)
    block_size = 128
    for start in range(0, full_matrix.shape[0], block_size):
        stop = min(start + block_size, full_matrix.shape[0])
        product = (
            full_matrix[start:stop, :].astype(np.uint64)
            @ coefficients_array
        )
        residual[start:stop] = (
            product + normalization_array[start:stop]
        ) % modulus
    return residual


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--candidate",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation.tsv"),
    )
    parser.add_argument(
        "--family-certificate",
        type=Path,
        default=DEFAULT_FAMILY_CERTIFICATE,
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()
    if not args.candidate.exists():
        raise FileNotFoundError(args.candidate)
    if not args.family_certificate.exists():
        raise FileNotFoundError(args.family_certificate)

    started = time.monotonic()
    mixed = load_module(
        "koenig_a_relation_pilot_mixed",
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
    normalization_term, support = parse_support(args.candidate)
    alpha = values[lift.SPECS.index(("f2", 4))]
    beta = values[lift.SPECS.index(("f1", 5))]
    u = alpha - 7
    v = beta - 14
    target = truncate(
        mixed,
        (series_ring(9) + parameter) ** 2,
        series_ring,
        parameter,
        PRECISION,
    )

    maximum_u = max(i for _, i, _, _ in support)
    maximum_v = max(j for _, _, j, _ in support)
    u_powers = [series_ring.one()]
    v_powers = [series_ring.one()]
    for _ in range(maximum_u):
        u_powers.append(
            truncate(
                mixed,
                u_powers[-1] * u,
                series_ring,
                parameter,
                PRECISION,
            )
        )
    for _ in range(maximum_v):
        v_powers.append(
            truncate(
                mixed,
                v_powers[-1] * v,
                series_ring,
                parameter,
                PRECISION,
            )
        )
    target_v_powers = [
        truncate(
            mixed,
            -target * value,
            series_ring,
            parameter,
            PRECISION,
        )
        for value in v_powers
    ]
    normalization_series = v
    normalization_values = np.fromiter(
        (int(normalization_series[row]) for row in range(PRECISION)),
        dtype=np.uint32,
        count=PRECISION,
    )

    full_matrix = np.empty(
        (PRECISION, len(support)), dtype=np.uint32, order="F"
    )
    for column, (kind, i, j, _) in enumerate(support):
        right_factor = (
            v_powers[j] if kind == "P" else target_v_powers[j]
        )
        monomial = truncate(
            mixed,
            u_powers[i] * right_factor,
            series_ring,
            parameter,
            PRECISION,
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

    field = GF(PRIME)
    training_values_mod19 = np.ascontiguousarray(
        full_matrix[:TRAINING_TERMS, :] % PRIME,
        dtype=np.uint8,
    )
    training_matrix_mod19 = matrix(field, training_values_mod19)
    del training_values_mod19
    pivot_rows = tuple(
        training_matrix_mod19._echelonize_linbox(efd=False)
    )
    normalized_rank = training_matrix_mod19.rank()
    del training_matrix_mod19
    print(
        f"row_rank_profile_complete rank={normalized_rank} "
        f"elapsed={time.monotonic() - started:.3f}",
        flush=True,
    )
    assert normalized_rank == len(support)
    assert len(pivot_rows) == normalized_rank
    pivot_hash = hashlib.sha256(
        ("\n".join(map(str, pivot_rows)) + "\n").encode()
    ).hexdigest()
    pivot_values_mod19 = np.ascontiguousarray(
        full_matrix[pivot_rows, :] % PRIME, dtype=np.uint8
    )
    pivot_matrix_mod19 = matrix(field, pivot_values_mod19)
    del pivot_values_mod19
    print(
        f"pivot_matrix_ready elapsed={time.monotonic() - started:.3f}",
        flush=True,
    )

    candidate_coefficients = [entry[3] for entry in support]
    mod19_residual = exact_residuals(
        full_matrix,
        candidate_coefficients,
        normalization_values,
        PRIME,
    )
    assert np.count_nonzero(mod19_residual) == 0

    inverse_matrix_mod19 = (
        pivot_matrix_mod19._solve_right_nonsingular_square(
            identity_matrix(field, len(support)),
            check_rank=False,
        )
    )
    del pivot_matrix_mod19
    print(
        f"inverse_complete "
        f"elapsed={time.monotonic() - started:.3f}",
        flush=True,
    )

    solution_array = np.asarray(
        candidate_coefficients, dtype=np.uint64
    )
    digit_residual_counts = []
    rejected_digit = None
    for digit in range(1, DIGITS):
        scale = PRIME**digit
        stage_modulus = PRIME ** (digit + 1)
        residual_before = exact_residuals(
            full_matrix,
            solution_array,
            normalization_values,
            stage_modulus,
        )
        assert np.count_nonzero(residual_before % scale) == 0
        right_hand_side = vector(
            field,
            [
                (-int(residual_before[row] // scale)) % PRIME
                for row in pivot_rows
            ],
        )
        correction = inverse_matrix_mod19 * right_hand_side
        correction_array = np.fromiter(
            (int(entry) for entry in correction),
            dtype=np.uint64,
            count=len(support),
        )
        solution_array += scale * correction_array
        residual_after = exact_residuals(
            full_matrix,
            solution_array,
            normalization_values,
            stage_modulus,
        )
        fitting_count = int(
            np.count_nonzero(residual_after[:TRAINING_TERMS])
        )
        holdout_count = int(
            np.count_nonzero(residual_after[TRAINING_TERMS:])
        )
        digit_residual_counts.append(
            (digit + 1, fitting_count, holdout_count)
        )
        print(
            f"digit={digit + 1} fitting_nonzero={fitting_count} "
            f"holdout_nonzero={holdout_count} "
            f"elapsed={time.monotonic() - started:.3f}",
            flush=True,
        )
        if fitting_count or holdout_count:
            rejected_digit = digit + 1
            break

    solution_integers = [int(entry) for entry in solution_array]
    tested_digits = rejected_digit if rejected_digit is not None else DIGITS
    verified_digits = (
        rejected_digit - 1 if rejected_digit is not None else DIGITS
    )
    tested_modulus = PRIME**tested_digits
    residual = exact_residuals(
        full_matrix,
        solution_integers,
        normalization_values,
        tested_modulus,
    )
    fitting_nonzero = int(np.count_nonzero(residual[:TRAINING_TERMS]))
    holdout_nonzero = int(np.count_nonzero(residual[TRAINING_TERMS:]))
    if rejected_digit is None:
        assert fitting_nonzero == 0
        assert holdout_nonzero == 0
        status = "lift_verified"
    else:
        assert fitting_nonzero or holdout_nonzero
        status = "fixed_support_rejected"

    canonical = "\n".join(
        f"{kind}:{i}:{j}:{value}"
        for (kind, i, j, _), value in zip(support, solution_integers)
    ) + "\n"
    coefficient_hash = hashlib.sha256(canonical.encode()).hexdigest()
    candidate_hash = hashlib.sha256(args.candidate.read_bytes()).hexdigest()
    family_certificate_hash = hashlib.sha256(
        args.family_certificate.read_bytes()
    ).hexdigest()
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# candidate_sha256\t{candidate_hash}",
        f"# family_certificate_sha256\t{family_certificate_hash}",
        f"# prime\t{PRIME}",
        f"# digits\t{DIGITS}",
        f"# modulus\t{modulus}",
        f"# status\t{status}",
        f"# tested_digits\t{tested_digits}",
        f"# verified_digits\t{verified_digits}",
        f"# tested_modulus\t{tested_modulus}",
        f"# rejected_digit\t{rejected_digit or 0}",
        f"# series_precision\t{PRECISION}",
        f"# training_terms\t{TRAINING_TERMS}",
        f"# holdout_terms\t{PRECISION - TRAINING_TERMS}",
        f"# support_columns\t{len(support) + 1}",
        f"# normalized_unknowns\t{len(support)}",
        "# normalization\tP[0,1]=1",
        "# pivot_selection\tffpack_row_rank_profile",
        f"# pivot_rows_sha256\t{pivot_hash}",
        f"# normalized_rank\t{normalized_rank}",
        *[
            f"# digit_{digit}_fitting_nonzero_residuals\t{fitting}\n"
            f"# digit_{digit}_holdout_nonzero_residuals\t{holdout}"
            for digit, fitting, holdout in digit_residual_counts
        ],
        f"# tested_coefficients_sha256\t{coefficient_hash}",
        "fitting_nonzero_residuals\tholdout_nonzero_residuals",
        f"{fitting_nonzero}\t{holdout_nonzero}",
    ]
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
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
