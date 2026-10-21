#!/usr/bin/env sage
"""Lift König's normalized F_19 family by exact Newton doubling."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
import time
from pathlib import Path

from sage.all import GF, PolynomialRing, identity_matrix, matrix, vector
from sage.env import SAGE_VERSION


DEFAULT_PRECISION = 4096
SUMMARY_SCHEMA = "m23-koenig-f19-newton-summary-v1"
FIELD = GF(19)
SERIES_RING = PolynomialRing(FIELD, "s")
s = SERIES_RING.gen()
Y_RING = PolynomialRing(SERIES_RING, "Y")
Y = Y_RING.gen()

FACTOR_DEGREES = {
    "f1": 6,
    "f2": 5,
    "f3": 8,
    "f4": 7,
    "f5": 8,
    "f6": 7,
}
BASE_FACTORS = {
    "f1": (15, 5, 7, 7, 2, 14),
    "f2": (7, 15, 4, 18, 7),
    "f3": (18, 5, 1, 12, 12, 11, 6, 9),
    "f4": (17, 9, 8, 14, 1, 8, 12),
    "f5": (0, 8, 8, 0, 7, 6, 1, 1),
    "f6": (17, 15, 4, 18, 17, 11, 9),
    "g1": (6, 15),
    "g2": (2, 3),
}
SPECS = []
for factor_name, factor_degree in FACTOR_DEGREES.items():
    SPECS.extend(
        (factor_name, exponent) for exponent in range(factor_degree)
    )
SPECS.extend(("g1", exponent) for exponent in range(2))
SPECS.extend(("g2", exponent) for exponent in range(2))
SPECS.append(("constant", 0))
assert len(SPECS) == 46


def truncate(value, precision):
    return SERIES_RING(value % s**precision)


def truncate_vector(values, precision):
    return vector(SERIES_RING, [truncate(value, precision) for value in values])


def truncate_matrix(values, precision):
    return matrix(
        SERIES_RING,
        values.nrows(),
        values.ncols(),
        [truncate(value, precision) for value in values.list()],
    )


def build_factors(values):
    factors = {}
    for name, degree in FACTOR_DEGREES.items():
        factors[name] = Y**degree + sum(
            values[index] * Y**exponent
            for index, (variable_name, exponent) in enumerate(SPECS)
            if variable_name == name
        )
    factors["g1"] = (
        Y**3
        + SERIES_RING(FIELD(1) / 3) * Y**2
        + values[SPECS.index(("g1", 1))] * Y
        + values[SPECS.index(("g1", 0))]
    )
    factors["g2"] = (
        Y**3
        - SERIES_RING(FIELD(1) / 2) * Y**2
        + values[SPECS.index(("g2", 1))] * Y
        + values[SPECS.index(("g2", 0))]
    )
    return factors


def system(values, branch_label, include_jacobian=False):
    factors = build_factors(values)
    constant = values[SPECS.index(("constant", 0))]
    F1 = factors["f1"] ** 3 * factors["f2"]
    F3 = factors["f3"] ** 2 * factors["f4"]
    F5 = factors["f5"] ** 2 * factors["f6"]
    denominator = factors["g1"] ** 5 * factors["g2"]
    equation3 = (
        constant * (F3 - F1) + (5 + branch_label) * denominator
    )
    equation5 = (
        constant * (F5 - F1) - (branch_label - 5) * denominator
    )
    equations = vector(
        SERIES_RING,
        [equation[index] for equation in (equation3, equation5) for index in range(23)],
    )
    if not include_jacobian:
        return equations

    columns = []
    zero = Y_RING.zero()
    for name, exponent in SPECS:
        dF1 = zero
        dF3 = zero
        dF5 = zero
        dD = zero
        dC = SERIES_RING.zero()
        monomial = Y**exponent
        if name == "f1":
            dF1 = 3 * factors["f1"] ** 2 * factors["f2"] * monomial
        elif name == "f2":
            dF1 = factors["f1"] ** 3 * monomial
        elif name == "f3":
            dF3 = 2 * factors["f3"] * factors["f4"] * monomial
        elif name == "f4":
            dF3 = factors["f3"] ** 2 * monomial
        elif name == "f5":
            dF5 = 2 * factors["f5"] * factors["f6"] * monomial
        elif name == "f6":
            dF5 = factors["f5"] ** 2 * monomial
        elif name == "g1":
            dD = 5 * factors["g1"] ** 4 * factors["g2"] * monomial
        elif name == "g2":
            dD = factors["g1"] ** 5 * monomial
        elif name == "constant":
            dC = SERIES_RING.one()
        else:
            raise AssertionError(name)
        dE3 = (
            dC * (F3 - F1)
            + constant * (dF3 - dF1)
            + (5 + branch_label) * dD
        )
        dE5 = (
            dC * (F5 - F1)
            + constant * (dF5 - dF1)
            - (branch_label - 5) * dD
        )
        columns.append(
            [dE3[index] for index in range(23)]
            + [dE5[index] for index in range(23)]
        )
    jacobian = matrix(
        SERIES_RING,
        46,
        46,
        lambda row_index, column_index: columns[column_index][row_index],
    )
    return equations, jacobian


def valuation_at_least(value, minimum):
    return value == 0 or value.valuation() >= minimum


def load_verifier():
    path = Path(__file__).with_name("verify_koenig_hurwitz_curve.sage")
    loader = importlib.machinery.SourceFileLoader("koenig_verifier", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König curve verifier")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def verify_plane_relation(relation, alpha, beta, precision):
    relation = relation.change_ring(FIELD)
    modulus = s**precision
    alpha_powers = [SERIES_RING.one()]
    beta_powers = [SERIES_RING.one()]
    for _ in range(relation.degree(relation.parent().gen(0))):
        alpha_powers.append(
            truncate(alpha_powers[-1] * alpha, precision)
        )
    for _ in range(relation.degree(relation.parent().gen(1))):
        beta_powers.append(
            truncate(beta_powers[-1] * beta, precision)
        )
    result = SERIES_RING.zero()
    for (alpha_degree, beta_degree), coefficient in relation.dict().items():
        result += (
            coefficient
            * alpha_powers[alpha_degree]
            * beta_powers[beta_degree]
        )
        result %= modulus
    assert result == 0


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def series_coefficients(value, precision):
    return tuple(int(value[index]) for index in range(precision))


def lift_formal_family(target, progress=None, return_inverse=False):
    """Return the exact normalized family modulo ``s^target``.

    ``target`` must be a power of two.  The optional progress callback receives
    the precision reached after every Newton doubling.  When
    ``return_inverse`` is true, also return the inverse series Jacobian at the
    lifted family.
    """
    if target < 1 or target & (target - 1):
        raise ValueError("target must be a positive power of two")
    base_values = []
    for name, exponent in SPECS:
        if name in BASE_FACTORS:
            base_values.append(SERIES_RING(BASE_FACTORS[name][exponent]))
        elif name == "constant":
            base_values.append(SERIES_RING(14))
        else:
            raise AssertionError(name)
    values = vector(SERIES_RING, base_values)
    branch_label = SERIES_RING(9) + s

    _, base_jacobian_series = system(
        values, SERIES_RING(9), include_jacobian=True
    )
    base_jacobian = matrix(
        FIELD,
        46,
        46,
        [FIELD(entry[0]) for entry in base_jacobian_series.list()],
    )
    assert base_jacobian.determinant() != 0
    inverse = matrix(
        SERIES_RING,
        46,
        46,
        [SERIES_RING(entry) for entry in base_jacobian.inverse().list()],
    )
    precision = 1
    identity = identity_matrix(SERIES_RING, 46)

    while precision < target:
        next_precision = min(2 * precision, target)
        residual = truncate_vector(
            system(values, branch_label), next_precision
        )
        assert all(
            valuation_at_least(entry, precision) for entry in residual
        )
        correction = truncate_vector(inverse * residual, next_precision)
        values = truncate_vector(values - correction, next_precision)
        lifted_residual, lifted_jacobian = system(
            values, branch_label, include_jacobian=True
        )
        lifted_residual = truncate_vector(
            lifted_residual, next_precision
        )
        assert lifted_residual == 0

        lifted_jacobian = truncate_matrix(
            lifted_jacobian, next_precision
        )
        inverse_error = truncate_matrix(
            identity - lifted_jacobian * inverse, next_precision
        )
        inverse = truncate_matrix(
            inverse + inverse * inverse_error, next_precision
        )
        assert truncate_matrix(
            lifted_jacobian * inverse - identity, next_precision
        ).is_zero()
        precision = next_precision
        if progress is not None:
            progress(precision)

    if return_inverse:
        return values, branch_label, inverse
    return values, branch_label


def summary_lines(
    archive_hash,
    revision,
    precision,
    values,
    branch_label,
    alpha,
    beta,
):
    labelled_series = [
        (
            f"{name}_x{exponent}" if name != "constant" else "constant",
            series_coefficients(value, precision),
        )
        for (name, exponent), value in zip(SPECS, values)
    ]
    labelled_series.append(
        ("lambda", series_coefficients(branch_label, precision))
    )
    canonical = "".join(
        f"{label}\t{','.join(map(str, coefficients))}\n"
        for label, coefficients in labelled_series
    ).encode("ascii")
    digest = hashlib.sha256(canonical).hexdigest()
    alpha_coefficients = series_coefficients(alpha, precision)
    beta_coefficients = series_coefficients(beta, precision)
    return (
        f"# schema\t{SUMMARY_SCHEMA}",
        f"# code_revision\t{revision}",
        f"# archive_sha256\t{archive_hash}",
        f"# sage_version\t{SAGE_VERSION}",
        f"precision\t{precision}",
        f"series_count\t{len(labelled_series)}",
        f"series_sha256\t{digest}",
        "parameter\ts=lambda-9",
        "universal_identity_residual\t0",
        "plane_relation_residual\t0",
        "alpha_first_16\t" + ",".join(map(str, alpha_coefficients[:16])),
        "alpha_last_16\t" + ",".join(map(str, alpha_coefficients[-16:])),
        "beta_first_16\t" + ",".join(map(str, beta_coefficients[:16])),
        "beta_last_16\t" + ",".join(map(str, beta_coefficients[-16:])),
    )


def parse_summary(path):
    parsed = {}
    for line in path.read_text().splitlines():
        if not line:
            continue
        key, value = line.removeprefix("# ").split("\t", 1)
        parsed[key] = value
    return parsed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--precision", type=int, default=DEFAULT_PRECISION)
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument("--output", type=Path)
    output_group.add_argument("--check-summary", type=Path)
    args = parser.parse_args()
    if args.precision < 8 or args.precision & (args.precision - 1):
        raise ValueError("precision must be a power of two at least 8")
    target = args.precision

    verifier = load_verifier()
    _, _, _, relation = verifier.load_polynomial(args.archive)
    started = time.monotonic()

    def report(precision):
        print(
            f"precision={precision} elapsed={time.monotonic() - started:.3f}",
            flush=True,
        )

    values, branch_label = lift_formal_family(target, progress=report)
    alpha = values[SPECS.index(("f2", 4))]
    beta = values[SPECS.index(("f1", 5))]
    print("alpha degree", alpha.degree())
    print("beta degree", beta.degree())
    relation_started = time.monotonic()
    verify_plane_relation(relation, alpha, beta, target)
    print(
        "plane relation verified elapsed",
        time.monotonic() - relation_started,
    )
    lines = summary_lines(
        verifier.ARCHIVE_SHA256,
        git_revision(),
        target,
        values,
        branch_label,
        alpha,
        beta,
    )
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("\n".join(lines) + "\n")
        print(f"wrote {args.output}")
    if args.check_summary is not None:
        expected = parse_summary(args.check_summary)
        actual = {
            key: value
            for key, value in (
                line.removeprefix("# ").split("\t", 1) for line in lines
            )
        }
        for key in (
            "schema",
            "archive_sha256",
            "sage_version",
            "precision",
            "series_count",
            "series_sha256",
            "parameter",
            "universal_identity_residual",
            "plane_relation_residual",
            "alpha_first_16",
            "alpha_last_16",
            "beta_first_16",
            "beta_last_16",
        ):
            assert actual[key] == expected[key], (
                key,
                actual[key],
                expected[key],
            )
        print(f"verified {args.check_summary}")
    print(next(line for line in lines if line.startswith("series_sha256\t")))
    print("elapsed", time.monotonic() - started)


if __name__ == "__main__":
    main()
