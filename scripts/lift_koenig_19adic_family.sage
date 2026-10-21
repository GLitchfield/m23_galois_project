#!/usr/bin/env sage
"""Lift König's local family over (Z/19^N)[s]/(s^M)."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
from pathlib import Path

from sage.all import Integers, PolynomialRing, matrix, vector
from sage.env import SAGE_VERSION

PRIME = 19
DEFAULT_DIGITS = 8
DEFAULT_PRECISION = 16
SCHEMA = "m23-koenig-19adic-family-v1"
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
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


def truncate(value, series_ring, parameter, precision):
    return series_ring(value % parameter**precision)


def build_factors(values, lift, coefficient_ring, series_ring, Y):
    factors = {}
    for name, degree in lift.FACTOR_DEGREES.items():
        factors[name] = Y**degree + sum(
            values[index] * Y**exponent
            for index, (variable_name, exponent) in enumerate(lift.SPECS)
            if variable_name == name
        )
    factors["g1"] = (
        Y**3
        + series_ring(coefficient_ring(1) / 3) * Y**2
        + values[lift.SPECS.index(("g1", 1))] * Y
        + values[lift.SPECS.index(("g1", 0))]
    )
    factors["g2"] = (
        Y**3
        - series_ring(coefficient_ring(1) / 2) * Y**2
        + values[lift.SPECS.index(("g2", 1))] * Y
        + values[lift.SPECS.index(("g2", 0))]
    )
    return factors


def system(
    values,
    branch_label,
    lift,
    coefficient_ring,
    series_ring,
    Y_ring,
    Y,
    include_jacobian=False,
):
    factors = build_factors(
        values, lift, coefficient_ring, series_ring, Y
    )
    constant = values[lift.SPECS.index(("constant", 0))]
    quarter = series_ring(coefficient_ring(1) / 4)
    F1 = factors["f1"] ** 3 * factors["f2"]
    F3 = factors["f3"] ** 2 * factors["f4"]
    F5 = factors["f5"] ** 2 * factors["f6"]
    denominator = factors["g1"] ** 5 * factors["g2"]
    equation3 = (
        constant * (F3 - F1)
        + (quarter + branch_label) * denominator
    )
    equation5 = (
        constant * (F5 - F1)
        - (branch_label - quarter) * denominator
    )
    equations = vector(
        series_ring,
        [
            equation[index]
            for equation in (equation3, equation5)
            for index in range(23)
        ],
    )
    if not include_jacobian:
        return equations

    columns = []
    zero = Y_ring.zero()
    for name, exponent in lift.SPECS:
        dF1 = zero
        dF3 = zero
        dF5 = zero
        dD = zero
        dC = series_ring.zero()
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
            dC = series_ring.one()
        else:
            raise AssertionError(name)
        dE3 = (
            dC * (F3 - F1)
            + constant * (dF3 - dF1)
            + (quarter + branch_label) * dD
        )
        dE5 = (
            dC * (F5 - F1)
            + constant * (dF5 - dF1)
            - (branch_label - quarter) * dD
        )
        columns.append(
            [dE3[index] for index in range(23)]
            + [dE5[index] for index in range(23)]
        )
    jacobian = matrix(
        series_ring,
        46,
        46,
        lambda row, column: columns[column][row],
    )
    return equations, jacobian


def verify_plane_relation(
    relation, alpha, beta, coefficient_ring, series_ring, parameter, precision
):
    relation = relation.change_ring(coefficient_ring)
    modulus = parameter**precision
    alpha_variable, beta_variable = relation.parent().gens()
    alpha_powers = [series_ring.one()]
    beta_powers = [series_ring.one()]
    for _ in range(relation.degree(alpha_variable)):
        alpha_powers.append(
            truncate(
                alpha_powers[-1] * alpha,
                series_ring,
                parameter,
                precision,
            )
        )
    for _ in range(relation.degree(beta_variable)):
        beta_powers.append(
            truncate(
                beta_powers[-1] * beta,
                series_ring,
                parameter,
                precision,
            )
        )
    result = series_ring.zero()
    for (alpha_degree, beta_degree), coefficient in relation.dict().items():
        result += (
            coefficient
            * alpha_powers[alpha_degree]
            * beta_powers[beta_degree]
        )
        result %= modulus
    assert result == 0


def lift_family(digits, precision, progress=None):
    if precision < 1 or precision & (precision - 1):
        raise ValueError("precision must be a positive power of two")
    anchor_lift = load_module(
        "koenig_19adic_anchor_for_family",
        "lift_koenig_19adic_anchor.sage",
    )
    lift, anchor, modulus, determinant_mod19 = anchor_lift.lift_anchor(
        digits
    )
    coefficient_ring = Integers(modulus)
    series_ring = PolynomialRing(coefficient_ring, "s")
    parameter = series_ring.gen()
    Y_ring = PolynomialRing(series_ring, "Y")
    Y = Y_ring.gen()
    values = vector(series_ring, [series_ring(value) for value in anchor])
    branch_label = series_ring(9) + parameter

    _, jacobian_series = system(
        values,
        series_ring(9),
        lift,
        coefficient_ring,
        series_ring,
        Y_ring,
        Y,
        include_jacobian=True,
    )
    jacobian = matrix(
        coefficient_ring,
        46,
        46,
        [coefficient_ring(entry[0]) for entry in jacobian_series.list()],
    )
    inverse = jacobian.inverse()

    for order in range(1, precision):
        residual = system(
            values,
            branch_label,
            lift,
            coefficient_ring,
            series_ring,
            Y_ring,
            Y,
        )
        residual_coefficient = vector(
            coefficient_ring, [entry[order] for entry in residual]
        )
        correction = inverse * residual_coefficient
        values = vector(
            series_ring,
            [
                truncate(
                    value - series_ring(delta) * parameter**order,
                    series_ring,
                    parameter,
                    order + 1,
                )
                for value, delta in zip(values, correction)
            ],
        )
        checked = system(
            values,
            branch_label,
            lift,
            coefficient_ring,
            series_ring,
            Y_ring,
            Y,
        )
        assert all(
            truncate(entry, series_ring, parameter, order + 1) == 0
            for entry in checked
        )
        if progress is not None:
            progress(order + 1)

    final_equations = system(
        values,
        branch_label,
        lift,
        coefficient_ring,
        series_ring,
        Y_ring,
        Y,
    )
    assert all(
        truncate(entry, series_ring, parameter, precision) == 0
        for entry in final_equations
    )
    return (
        lift,
        values,
        modulus,
        determinant_mod19,
        coefficient_ring,
        series_ring,
        parameter,
    )


def lift_family_digitwise(digits, precision, progress=None):
    """Lift a high-order mod-19 family one 19-adic digit at a time."""
    if digits < 1:
        raise ValueError("digits must be positive")
    if precision < 1 or precision & (precision - 1):
        raise ValueError("precision must be a positive power of two")
    lift = load_module(
        "koenig_f19_highorder_digit_lift",
        "lift_koenig_f19_newton.sage",
    )
    mod19_values, _, inverse = lift.lift_formal_family(
        precision,
        progress=(
            None
            if progress is None
            else lambda reached: progress("series", reached)
        ),
        return_inverse=True,
    )
    coefficients = [
        [int(value[order]) for order in range(precision)]
        for value in mod19_values
    ]
    modulus = PRIME

    for digit in range(1, digits):
        next_modulus = modulus * PRIME
        coefficient_ring = Integers(next_modulus)
        series_ring = PolynomialRing(coefficient_ring, "s")
        parameter = series_ring.gen()
        Y_ring = PolynomialRing(series_ring, "Y")
        Y = Y_ring.gen()
        values = vector(
            series_ring,
            [
                series_ring([coefficient_ring(entry) for entry in row])
                for row in coefficients
            ],
        )
        residual = system(
            values,
            series_ring(9) + parameter,
            lift,
            coefficient_ring,
            series_ring,
            Y_ring,
            Y,
        )
        residual_digits = []
        for entry in residual:
            digit_coefficients = []
            for order in range(precision):
                representative = int(entry[order])
                assert representative % modulus == 0
                digit_coefficients.append(
                    lift.FIELD(representative // modulus)
                )
            residual_digits.append(
                lift.SERIES_RING(digit_coefficients)
            )
        correction = lift.truncate_vector(
            inverse * vector(lift.SERIES_RING, residual_digits),
            precision,
        )
        coefficients = [
            [
                (entry - modulus * int(delta[order])) % next_modulus
                for order, entry in enumerate(row)
            ]
            for row, delta in zip(coefficients, correction)
        ]
        modulus = next_modulus
        if progress is not None:
            progress("digit", digit + 1)

    coefficient_ring = Integers(modulus)
    series_ring = PolynomialRing(coefficient_ring, "s")
    parameter = series_ring.gen()
    Y_ring = PolynomialRing(series_ring, "Y")
    Y = Y_ring.gen()
    values = vector(
        series_ring,
        [
            series_ring([coefficient_ring(entry) for entry in row])
            for row in coefficients
        ],
    )
    final_equations = system(
        values,
        series_ring(9) + parameter,
        lift,
        coefficient_ring,
        series_ring,
        Y_ring,
        Y,
    )
    assert all(
        truncate(entry, series_ring, parameter, precision) == 0
        for entry in final_equations
    )

    anchor_lift = load_module(
        "koenig_19adic_anchor_highorder_check",
        "lift_koenig_19adic_anchor.sage",
    )
    _, anchor, anchor_modulus, determinant_mod19 = (
        anchor_lift.lift_anchor(digits)
    )
    assert anchor_modulus == modulus
    assert [int(value[0]) for value in values] == anchor
    return (
        lift,
        values,
        modulus,
        determinant_mod19,
        coefficient_ring,
        series_ring,
        parameter,
        mod19_values,
    )


def canonical_values_hash(lift, values, precision):
    digest = hashlib.sha256()
    for (name, exponent), value in zip(lift.SPECS, values):
        for order in range(precision):
            digest.update(
                f"{name}:{exponent}:{order}:{int(value[order])}\n".encode()
            )
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--digits", type=int, default=DEFAULT_DIGITS)
    parser.add_argument("--precision", type=int, default=DEFAULT_PRECISION)
    parser.add_argument(
        "--method",
        choices=("coefficientwise", "digitwise"),
        default="coefficientwise",
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()

    archive_hash = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    assert archive_hash == ARCHIVE_SHA256
    mod19_values = None
    if args.method == "coefficientwise":
        (
            lift,
            values,
            modulus,
            determinant_mod19,
            coefficient_ring,
            series_ring,
            parameter,
        ) = lift_family(
            args.digits,
            args.precision,
            progress=lambda reached: print(
                f"lifted through s^{reached}", flush=True
            ),
        )
    else:
        (
            lift,
            values,
            modulus,
            determinant_mod19,
            coefficient_ring,
            series_ring,
            parameter,
            mod19_values,
        ) = lift_family_digitwise(
            args.digits,
            args.precision,
            progress=lambda axis, reached: print(
                (
                    f"lifted through s^{reached}"
                    if axis == "series"
                    else f"lifted through 19^{reached}"
                ),
                flush=True,
            ),
        )

    verifier = load_module(
        "koenig_curve_verifier_19adic_family",
        "verify_koenig_hurwitz_curve.sage",
    )
    _, _, _, relation = verifier.load_polynomial(args.archive)
    alpha = values[lift.SPECS.index(("f2", 4))]
    beta = values[lift.SPECS.index(("f1", 5))]
    verify_plane_relation(
        relation,
        alpha,
        beta,
        coefficient_ring,
        series_ring,
        parameter,
        args.precision,
    )

    if mod19_values is None:
        mod19_lift = load_module(
            "koenig_f19_lift_family_check",
            "lift_koenig_f19_newton.sage",
        )
        mod19_values, _ = mod19_lift.lift_formal_family(args.precision)
    for mixed, mod19 in zip(values, mod19_values):
        assert all(
            int(mixed[order]) % PRIME == int(mod19[order])
            for order in range(args.precision)
        )

    values_hash = canonical_values_hash(lift, values, args.precision)
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# archive_sha256\t{archive_hash}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        f"# digits\t{args.digits}",
        f"# modulus\t{modulus}",
        f"# series_precision\t{args.precision}",
        "# parameter\tlambda=9+s",
        f"# jacobian_determinant_mod19\t{determinant_mod19}",
        f"# values_sha256\t{values_hash}",
        (
            "alpha_constant\tbeta_constant\talpha_linear\tbeta_linear\t"
            "cover_equations_zero\tplane_relation_zero\t"
            "mod19_family_compatible"
        ),
        (
            f"{int(alpha[0])}\t{int(beta[0])}\t"
            f"{int(alpha[1]) if args.precision > 1 else 0}\t"
            f"{int(beta[1]) if args.precision > 1 else 0}\t"
            "true\ttrue\ttrue"
        ),
    ]
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.check_summary is not None:
        expected_lines = [
            line
            for line in args.check_summary.read_text().splitlines()
            if not line.startswith("# code_revision\t")
        ]
        actual_lines = [
            line
            for line in text.splitlines()
            if not line.startswith("# code_revision\t")
        ]
        assert actual_lines == expected_lines

    print(f"SageMath {SAGE_VERSION}")
    print(
        f"verified unique local family modulo 19^{args.digits}, "
        f"s^{args.precision}; values_sha256={values_hash}"
    )
    print(
        "verified cover equations, characteristic-zero plane equation, "
        "and reduction to the independent F_19 formal lift"
    )


if __name__ == "__main__":
    main()
