#!/usr/bin/env sage
"""Recover König's normalized F_19 cover functions with one denominator."""

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


SCHEMA = "m23-koenig-f19-family-v1"
BASIS_SCHEMA = "m23-koenig-f19-a-relation-basis-v1"
DEFAULT_PRECISION = 16384
DEFAULT_TRAINING_TERMS = 12000
NUMERATOR_U_DEGREE = 96
NUMERATOR_V_DEGREE = 120


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
    raise ValueError("family artifact has no recorded code revision")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def packed_matrix(field, columns, row_stop):
    packed = np.empty((row_stop, len(columns)), dtype=np.int16)
    for column_index, column in enumerate(columns):
        packed[:, column_index] = np.fromiter(
            (int(column[row]) for row in range(row_stop)),
            dtype=np.int16,
            count=row_stop,
        )
        if column_index and column_index % 1000 == 0:
            print(f"packed_columns={column_index}", flush=True)
    result = matrix(field, packed)
    del packed
    return result


def series_combination(lifter, coefficients, series, precision):
    result = lifter.SERIES_RING.zero()
    nonzero_count = 0
    for coefficient, value in zip(coefficients, series):
        if coefficient:
            result += coefficient * value
            nonzero_count += 1
            if nonzero_count % 128 == 0:
                result = lifter.truncate(result, precision)
    return lifter.truncate(result, precision)


def target_series(lifter, values, branch_label, precision):
    specs = [("a", 0), ("constant", 0)]
    specs.extend(("f1", exponent) for exponent in range(5))
    specs.extend(("f2", exponent) for exponent in range(4))
    specs.extend(("g1", exponent) for exponent in range(2))
    specs.extend(("g2", exponent) for exponent in range(2))
    assert len(specs) == 15
    series = [lifter.truncate(branch_label**2, precision)]
    series.extend(
        values[lifter.SPECS.index(spec)] for spec in specs[1:]
    )
    labels = [
        "a" if name == "a" else (
            "constant" if name == "constant" else f"{name}_x{exponent}"
        )
        for name, exponent in specs
    ]
    return labels, series


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("relation_basis", type=Path)
    parser.add_argument("--precision", type=int, default=DEFAULT_PRECISION)
    parser.add_argument(
        "--training-terms", type=int, default=DEFAULT_TRAINING_TERMS
    )
    output_group = parser.add_mutually_exclusive_group(required=True)
    output_group.add_argument("--output", type=Path)
    output_group.add_argument("--check-family", type=Path)
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
    u_powers = [lifter.SERIES_RING.one()]
    v_powers = [lifter.SERIES_RING.one()]
    for _ in range(NUMERATOR_V_DEGREE):
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
    numerator_monomials = [
        lifter.truncate(u_powers[i] * v_powers[j], args.precision)
        for i, j in numerator_specs
    ]
    numerator_matrix = packed_matrix(
        lifter.FIELD, numerator_monomials, args.training_terms
    )
    left_kernel = numerator_matrix.left_kernel()
    assert left_kernel.dimension() == (
        args.training_terms - len(numerator_specs)
    )
    left_basis = left_kernel.basis_matrix()
    print(
        f"numerator_rank={len(numerator_specs)} "
        f"left_kernel_dimension={left_kernel.dimension()}",
        flush=True,
    )

    with np.load(args.relation_basis) as stored:
        assert str(stored["schema"]) == BASIS_SCHEMA
        assert int(stored["field_order"]) == 19
        assert int(stored["selected_cutoff"]) == 105
        basis_numerator_specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
        denominator_specs = [
            (int(i), int(j)) for i, j in stored["denominator_specs"]
        ]
        relation_rows = matrix(
            lifter.FIELD,
            np.asarray(stored["relations"], dtype=np.int16),
        )
    assert relation_rows.nrows() == 50
    denominator_coefficients = relation_rows.matrix_from_columns(
        range(len(basis_numerator_specs), relation_rows.ncols())
    )
    denominator_monomials = [
        lifter.truncate(u_powers[i] * v_powers[j], args.precision)
        for i, j in denominator_specs
    ]
    q_series_basis = [
        series_combination(
            lifter,
            row,
            denominator_monomials,
            args.precision,
        )
        for row in denominator_coefficients.rows()
    ]
    assert all(value != 0 for value in q_series_basis)

    labels, targets = target_series(
        lifter, values, branch_label, args.precision
    )
    obstructions = []
    for label, target in zip(labels, targets):
        target_q_series = [
            lifter.truncate(target * q_value, args.precision)
            for q_value in q_series_basis
        ]
        target_q_matrix = packed_matrix(
            lifter.FIELD, target_q_series, args.training_terms
        )
        obstruction = left_basis * target_q_matrix
        obstructions.append(obstruction)
        print(
            f"target={label} obstruction_rank={obstruction.rank()} "
            f"kernel_dimension={obstruction.right_kernel().dimension()}",
            flush=True,
        )
    common_obstruction = obstructions[0]
    for obstruction in obstructions[1:]:
        common_obstruction = common_obstruction.stack(obstruction)
    common_kernel = common_obstruction.right_kernel()
    assert common_kernel.dimension() > 0
    denominator_combination = common_kernel.basis_matrix().row(0)
    selected_denominator_coefficients = (
        denominator_combination * denominator_coefficients
    )
    denominator_series = series_combination(
        lifter,
        selected_denominator_coefficients,
        denominator_monomials,
        args.precision,
    )
    assert denominator_series != 0
    print(
        f"common_denominator_kernel_dimension={common_kernel.dimension()} "
        f"denominator_valuation={denominator_series.valuation()}",
        flush=True,
    )

    rhs_series = [
        lifter.truncate(target * denominator_series, args.precision)
        for target in targets
    ]
    rhs = matrix(
        lifter.FIELD,
        args.training_terms,
        len(targets),
        lambda row, column: rhs_series[column][row],
    )
    solutions = numerator_matrix.solve_right(rhs)

    polynomial_ring = PolynomialRing(lifter.FIELD, names=("u", "v"))
    polynomial_u, polynomial_v = polynomial_ring.gens()
    denominator_polynomial = sum(
        coefficient * polynomial_u**i * polynomial_v**j
        for coefficient, (i, j) in zip(
            selected_denominator_coefficients, denominator_specs
        )
        if coefficient
    )
    numerators = []
    for target_index, label in enumerate(labels):
        coefficients = solutions.column(target_index)
        numerator_polynomial = sum(
            coefficient * polynomial_u**i * polynomial_v**j
            for coefficient, (i, j) in zip(
                coefficients, numerator_specs
            )
            if coefficient
        )
        assert numerator_polynomial.gcd(
            denominator_polynomial
        ).total_degree() == 0
        numerator_series = series_combination(
            lifter, coefficients, numerator_monomials, args.precision
        )
        residual = lifter.truncate(
            numerator_series - rhs_series[target_index], args.precision
        )
        assert residual == 0
        numerators.append(numerator_polynomial)
        print(
            f"recovered={label} "
            f"degree={numerator_polynomial.total_degree()} "
            f"terms={len(numerator_polynomial.dict())}",
            flush=True,
        )

    if args.output is not None:
        revision = git_revision()
    else:
        assert args.check_family is not None
        revision = recorded_revision(args.check_family)
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{revision}",
        f"# archive_sha256\t{verifier.ARCHIVE_SHA256}",
        f"# relation_basis_sha256\t{sha256(args.relation_basis)}",
        f"# sage_version\t{SAGE_VERSION}",
        "# field\tGF(19)",
        "# parameter\ts=lambda-9",
        "# coordinates\tu=alpha-7,v=beta-14",
        f"# fit_precision\t{args.precision}",
        f"# training_terms\t{args.training_terms}",
        f"# heldout_terms\t{args.precision - args.training_terms}",
        (
            "# numerator_basis\t"
            f"0<=deg_u<={NUMERATOR_U_DEGREE},"
            f"0<=deg_v<={NUMERATOR_V_DEGREE}"
        ),
        f"# numerator_basis_rank\t{len(numerator_specs)}",
        f"# left_kernel_dimension\t{left_kernel.dimension()}",
        f"# denominator_source_dimension\t{relation_rows.nrows()}",
        (
            "# common_denominator_kernel_dimension\t"
            f"{common_kernel.dimension()}"
        ),
        (
            "# common_denominator_total_degree\t"
            f"{denominator_polynomial.total_degree()}"
        ),
        (
            "# common_denominator_terms\t"
            f"{len(denominator_polynomial.dict())}"
        ),
        (
            "# common_denominator_valuation\t"
            f"{denominator_series.valuation()}"
        ),
    ]
    for label, numerator in zip(labels, numerators):
        lines.append(
            f"# target_{label}\tdegree={numerator.total_degree()},"
            f"terms={len(numerator.dict())}"
        )
    lines.extend(
        f"D\t{i}\t{j}\t{int(coefficient)}"
        for (i, j), coefficient in sorted(
            denominator_polynomial.dict().items()
        )
    )
    for label, numerator in zip(labels, numerators):
        lines.extend(
            f"N\t{label}\t{i}\t{j}\t{int(coefficient)}"
            for (i, j), coefficient in sorted(numerator.dict().items())
        )
    serialized = ("\n".join(lines) + "\n").encode("ascii")
    digest = hashlib.sha256(serialized).hexdigest()
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(serialized)
        print(f"wrote={args.output}")
    else:
        assert args.check_family is not None
        assert serialized == args.check_family.read_bytes()
        print(f"verified={args.check_family}")
    print(f"family_sha256={digest}")
    print(f"elapsed={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
