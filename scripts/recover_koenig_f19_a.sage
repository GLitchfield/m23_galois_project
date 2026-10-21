#!/usr/bin/env sage
"""Recover a rational expression for a=lambda^2 on König's F_19 branch.

This is deliberately a long, high-memory certificate generator.  It fixes the
monomial ansatz, computes the exact finite-field kernel, validates every kernel
vector on held-out series coefficients, and selects the first cutoff at which
the numerator projection is nonzero.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
import time
from pathlib import Path

import numpy as np

from sage.all import PolynomialRing, matrix
from sage.env import SAGE_VERSION


SCHEMA = "m23-koenig-f19-a-relation-v1"
BASIS_SCHEMA = "m23-koenig-f19-a-relation-basis-v1"
DEFAULT_PRECISION = 16384
DEFAULT_TRAINING_TERMS = 16000
NUMERATOR_U_DEGREE = 96
NUMERATOR_V_DEGREE = 97
DENOMINATOR_TOTAL_DEGREE = 110


def load_lifter():
    path = Path(__file__).with_name("lift_koenig_f19_newton.sage")
    loader = importlib.machinery.SourceFileLoader("koenig_lifter", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König Newton lifter")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def recorded_revision(path):
    for line in path.read_text().splitlines():
        if line.startswith("# code_revision\t"):
            return line.split("\t", 1)[1]
    raise ValueError("candidate has no recorded code revision")


def recorded_basis_revision(path):
    with np.load(path) as stored:
        return str(stored["code_revision"])


def basis_payload(
    archive_hash,
    revision,
    precision,
    training_terms,
    selected_cutoff,
    numerator_specs,
    denominator_specs,
    relations,
):
    return {
        "schema": np.asarray(BASIS_SCHEMA),
        "code_revision": np.asarray(revision),
        "archive_sha256": np.asarray(archive_hash),
        "sage_version": np.asarray(SAGE_VERSION),
        "field_order": np.asarray(19, dtype=np.int16),
        "fit_precision": np.asarray(precision, dtype=np.int32),
        "training_terms": np.asarray(training_terms, dtype=np.int32),
        "selected_cutoff": np.asarray(selected_cutoff, dtype=np.int16),
        "numerator_specs": np.asarray(numerator_specs, dtype=np.int16),
        "denominator_specs": np.asarray(denominator_specs, dtype=np.int16),
        "relations": np.asarray(
            [
                [int(entry) for entry in row]
                for row in relations.rows()
            ],
            dtype=np.uint8,
        ),
    }


def packed_matrix(field, columns, row_start, row_stop):
    row_count = row_stop - row_start
    packed = np.empty((row_count, len(columns)), dtype=np.int16)
    for column_index, column in enumerate(columns):
        packed[:, column_index] = np.fromiter(
            (int(column[row]) for row in range(row_start, row_stop)),
            dtype=np.int16,
            count=row_count,
        )
        if column_index and column_index % 1000 == 0:
            print(f"packed_columns={column_index}", flush=True)
    result = matrix(field, packed)
    del packed
    return result


def candidate_lines(
    archive_hash,
    revision,
    precision,
    training_terms,
    rank,
    kernel_dimension,
    heldout_valid,
    cutoff_results,
    selected_cutoff,
    common_factor_degree,
    numerator,
    denominator,
):
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{revision}",
        f"# archive_sha256\t{archive_hash}",
        f"# sage_version\t{SAGE_VERSION}",
        "# field\tGF(19)",
        "# parameter\ts=lambda-9",
        "# target\ta=lambda^2",
        "# coordinates\tu=alpha-7,v=beta-14",
        f"# fit_precision\t{precision}",
        f"# training_terms\t{training_terms}",
        f"# heldout_terms\t{precision - training_terms}",
        (
            "# numerator_basis\t"
            f"0<=deg_u<={NUMERATOR_U_DEGREE},"
            f"0<=deg_v<={NUMERATOR_V_DEGREE}"
        ),
        (
            "# denominator_basis\t"
            f"total_degree<={DENOMINATOR_TOTAL_DEGREE}"
        ),
        f"# matrix_rows\t{training_terms}",
        (
            "# matrix_columns\t"
            f"{(NUMERATOR_U_DEGREE + 1) * (NUMERATOR_V_DEGREE + 1) + (DENOMINATOR_TOTAL_DEGREE + 1) * (DENOMINATOR_TOTAL_DEGREE + 2) // 2}"
        ),
        f"# matrix_rank\t{rank}",
        f"# kernel_dimension\t{kernel_dimension}",
        f"# heldout_valid_kernel_dimension\t{heldout_valid}",
    ]
    for cutoff, dimension, numerator_rank in cutoff_results:
        lines.append(
            f"# cutoff_{cutoff}\tdimension={dimension},"
            f"numerator_rank={numerator_rank}"
        )
    lines.extend(
        [
            f"# selected_denominator_cutoff\t{selected_cutoff}",
            f"# common_polynomial_factor_degree\t{common_factor_degree}",
            f"# numerator_total_degree\t{numerator.total_degree()}",
            f"# denominator_total_degree\t{denominator.total_degree()}",
            f"# numerator_terms\t{len(numerator.dict())}",
            f"# denominator_terms\t{len(denominator.dict())}",
        ]
    )
    lines.extend(
        f"P\t{i}\t{j}\t{int(coefficient)}"
        for (i, j), coefficient in sorted(numerator.dict().items())
    )
    lines.extend(
        f"Q\t{i}\t{j}\t{int(coefficient)}"
        for (i, j), coefficient in sorted(denominator.dict().items())
    )
    return lines


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--precision", type=int, default=DEFAULT_PRECISION)
    parser.add_argument(
        "--training-terms", type=int, default=DEFAULT_TRAINING_TERMS
    )
    output_group = parser.add_mutually_exclusive_group(required=True)
    output_group.add_argument("--output", type=Path)
    output_group.add_argument("--check-candidate", type=Path)
    basis_group = parser.add_mutually_exclusive_group()
    basis_group.add_argument("--basis-output", type=Path)
    basis_group.add_argument("--check-basis", type=Path)
    args = parser.parse_args()
    if args.precision < 2 or args.precision & (args.precision - 1):
        raise ValueError("precision must be a power of two")
    if not 0 < args.training_terms < args.precision:
        raise ValueError("training terms must be between zero and precision")

    started = time.monotonic()
    lifter = load_lifter()
    verifier = lifter.load_verifier()
    _, _, _, plane_relation = verifier.load_polynomial(args.archive)

    def report(precision):
        print(
            f"lift_precision={precision} "
            f"elapsed={time.monotonic() - started:.3f}",
            flush=True,
        )

    values, branch_label = lifter.lift_formal_family(
        args.precision, progress=report
    )
    alpha = values[lifter.SPECS.index(("f2", 4))]
    beta = values[lifter.SPECS.index(("f1", 5))]
    lifter.verify_plane_relation(
        plane_relation, alpha, beta, args.precision
    )
    u = alpha - 7
    v = beta - 14
    target = lifter.truncate(branch_label**2, args.precision)

    maximum_degree = max(
        NUMERATOR_U_DEGREE,
        NUMERATOR_V_DEGREE,
        DENOMINATOR_TOTAL_DEGREE,
    )
    u_powers = [lifter.SERIES_RING.one()]
    v_powers = [lifter.SERIES_RING.one()]
    for _ in range(maximum_degree):
        u_powers.append(
            lifter.truncate(u_powers[-1] * u, args.precision)
        )
        v_powers.append(
            lifter.truncate(v_powers[-1] * v, args.precision)
        )

    numerator_specs = [
        (i, j)
        for i in range(NUMERATOR_U_DEGREE + 1)
        for j in range(NUMERATOR_V_DEGREE + 1)
    ]
    denominator_specs = [
        (i, j)
        for i in range(DENOMINATOR_TOTAL_DEGREE + 1)
        for j in range(DENOMINATOR_TOTAL_DEGREE + 1 - i)
    ]
    numerator_monomials = [
        lifter.truncate(u_powers[i] * v_powers[j], args.precision)
        for i, j in numerator_specs
    ]
    denominator_monomials = [
        lifter.truncate(u_powers[i] * v_powers[j], args.precision)
        for i, j in denominator_specs
    ]
    columns = numerator_monomials + [
        lifter.truncate(-target * monomial, args.precision)
        for monomial in denominator_monomials
    ]
    print(
        f"matrix_shape={args.training_terms}x{len(columns)} "
        f"elapsed={time.monotonic() - started:.3f}",
        flush=True,
    )
    relation_matrix = packed_matrix(
        lifter.FIELD, columns, 0, args.training_terms
    )
    kernel = relation_matrix.right_kernel()
    rank = relation_matrix.rank()
    kernel_matrix = kernel.basis_matrix()
    print(
        f"matrix_rank={rank} kernel_dimension={kernel.dimension()} "
        f"elapsed={time.monotonic() - started:.3f}",
        flush=True,
    )

    tail_matrix = packed_matrix(
        lifter.FIELD, columns, args.training_terms, args.precision
    )
    tail_residuals = tail_matrix * kernel_matrix.transpose()
    valid_indices = [
        index
        for index in range(kernel.dimension())
        if tail_residuals.column(index).is_zero()
    ]
    valid_kernel = kernel_matrix.matrix_from_rows(valid_indices)
    split = len(numerator_monomials)
    print(
        f"heldout_valid={len(valid_indices)} "
        f"numerator_projection_rank="
        f"{valid_kernel.matrix_from_columns(range(split)).rank()}",
        flush=True,
    )

    cutoff_results = []
    candidate = None
    independent_relations = None
    selected_cutoff = None
    for cutoff in range(DENOMINATOR_TOTAL_DEGREE + 1):
        high_columns = [
            split + index
            for index, (i, j) in enumerate(denominator_specs)
            if i + j > cutoff
        ]
        constraints = valid_kernel.matrix_from_columns(
            high_columns
        ).transpose()
        combinations = constraints.right_kernel()
        if combinations.dimension() == 0:
            continue
        relation_space = combinations.basis_matrix() * valid_kernel
        numerator_rank = relation_space.matrix_from_columns(
            range(split)
        ).rank()
        cutoff_results.append(
            (cutoff, relation_space.nrows(), numerator_rank)
        )
        print(
            f"cutoff={cutoff} dimension={relation_space.nrows()} "
            f"numerator_rank={numerator_rank}",
            flush=True,
        )
        if numerator_rank:
            selected_cutoff = cutoff
            independent_rows = (
                relation_space.matrix_from_columns(
                    range(split)
                ).transpose().pivots()
            )
            assert len(independent_rows) == numerator_rank
            independent_relations = relation_space.matrix_from_rows(
                independent_rows
            )
            for row in relation_space.echelon_form().rows():
                if any(row[index] for index in range(split)):
                    candidate = row
                    break
            break
    assert candidate is not None
    assert independent_relations is not None
    assert selected_cutoff is not None

    polynomial_ring = PolynomialRing(lifter.FIELD, names=("u", "v"))
    polynomial_u, polynomial_v = polynomial_ring.gens()
    numerator = sum(
        candidate[index] * polynomial_u**i * polynomial_v**j
        for index, (i, j) in enumerate(numerator_specs)
    )
    denominator = sum(
        candidate[split + index] * polynomial_u**i * polynomial_v**j
        for index, (i, j) in enumerate(denominator_specs)
    )
    common = numerator.gcd(denominator)
    numerator //= common
    denominator //= common
    assert common.total_degree() == 0

    if args.output is not None:
        revision = git_revision()
    else:
        assert args.check_candidate is not None
        revision = recorded_revision(args.check_candidate)
    if args.check_basis is not None:
        basis_revision = recorded_basis_revision(args.check_basis)
    else:
        basis_revision = revision
    lines = candidate_lines(
        verifier.ARCHIVE_SHA256,
        revision,
        args.precision,
        args.training_terms,
        rank,
        kernel.dimension(),
        len(valid_indices),
        cutoff_results,
        selected_cutoff,
        common.total_degree(),
        numerator,
        denominator,
    )
    serialized = ("\n".join(lines) + "\n").encode("ascii")
    digest = hashlib.sha256(serialized).hexdigest()
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(serialized)
        print(f"wrote={args.output}")
    else:
        assert args.check_candidate is not None
        assert serialized == args.check_candidate.read_bytes()
        print(f"verified={args.check_candidate}")
    payload = basis_payload(
        verifier.ARCHIVE_SHA256,
        basis_revision,
        args.precision,
        args.training_terms,
        selected_cutoff,
        numerator_specs,
        denominator_specs,
        independent_relations,
    )
    if args.basis_output is not None:
        args.basis_output.parent.mkdir(parents=True, exist_ok=True)
        np.savez_compressed(args.basis_output, **payload)
        print(f"wrote_basis={args.basis_output}")
    if args.check_basis is not None:
        with np.load(args.check_basis) as expected:
            assert set(expected.files) == set(payload)
            for key, value in payload.items():
                assert np.array_equal(expected[key], value), key
        print(f"verified_basis={args.check_basis}")
    print(f"candidate_sha256={digest}")
    print(f"elapsed={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
