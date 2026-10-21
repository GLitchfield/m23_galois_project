#!/usr/bin/env sage
"""Hensel-lift König's normalized anchor from F_19 to Z/19^N."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
from pathlib import Path

from sage.all import GF, Integers, PolynomialRing, matrix, vector
from sage.env import SAGE_VERSION

PRIME = 19
DEFAULT_DIGITS = 32
SCHEMA = "m23-koenig-19adic-anchor-v1"


def load_module(name: str, filename: str):
    path = Path(__file__).with_name(filename)
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError(f"could not load {filename}")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def equations(values: list[int], modulus: int):
    coefficient_ring = Integers(modulus)
    polynomial_ring = PolynomialRing(coefficient_ring, "Y")
    Y = polynomial_ring.gen()
    lift = load_module("koenig_f19_lift_specs", "lift_koenig_f19_newton.sage")
    specs = lift.SPECS
    factor_degrees = lift.FACTOR_DEGREES
    current = [coefficient_ring(value) for value in values]

    factors = {}
    for name, degree in factor_degrees.items():
        factors[name] = Y**degree + sum(
            current[index] * Y**exponent
            for index, (variable_name, exponent) in enumerate(specs)
            if variable_name == name
        )
    factors["g1"] = (
        Y**3
        + coefficient_ring(1) / 3 * Y**2
        + current[specs.index(("g1", 1))] * Y
        + current[specs.index(("g1", 0))]
    )
    factors["g2"] = (
        Y**3
        - coefficient_ring(1) / 2 * Y**2
        + current[specs.index(("g2", 1))] * Y
        + current[specs.index(("g2", 0))]
    )
    constant = current[specs.index(("constant", 0))]
    branch_label = coefficient_ring(9)
    quarter = coefficient_ring(1) / 4
    F1 = factors["f1"] ** 3 * factors["f2"]
    F3 = factors["f3"] ** 2 * factors["f4"]
    F5 = factors["f5"] ** 2 * factors["f6"]
    denominator = factors["g1"] ** 5 * factors["g2"]
    equation3 = constant * (F3 - F1) + (
        quarter + branch_label
    ) * denominator
    equation5 = constant * (F5 - F1) - (
        branch_label - quarter
    ) * denominator
    return [
        equation[index]
        for equation in (equation3, equation5)
        for index in range(23)
    ]


def base_values():
    lift = load_module("koenig_f19_lift_base", "lift_koenig_f19_newton.sage")
    values = []
    for name, exponent in lift.SPECS:
        if name in lift.BASE_FACTORS:
            values.append(int(lift.BASE_FACTORS[name][exponent]))
        elif name == "constant":
            values.append(14)
        else:
            raise AssertionError(name)
    return lift, values


def lift_anchor(digits: int):
    if digits < 1:
        raise ValueError("digits must be positive")
    lift, values = base_values()
    field = GF(PRIME)
    base_series_values = vector(
        lift.SERIES_RING,
        [lift.SERIES_RING(value) for value in values],
    )
    _, jacobian_series = lift.system(
        base_series_values,
        lift.SERIES_RING(9),
        include_jacobian=True,
    )
    jacobian = matrix(
        field,
        46,
        46,
        [field(entry[0]) for entry in jacobian_series.list()],
    )
    assert jacobian.determinant() != 0
    inverse = jacobian.inverse()
    assert all(entry == 0 for entry in equations(values, PRIME))

    modulus = PRIME
    for digit in range(1, digits):
        next_modulus = modulus * PRIME
        residual = equations(values, next_modulus)
        residual_digits = []
        for entry in residual:
            representative = int(entry)
            assert representative % modulus == 0
            residual_digits.append(field(representative // modulus))
        correction = inverse * vector(field, residual_digits)
        values = [
            (value - modulus * int(delta)) % next_modulus
            for value, delta in zip(values, correction)
        ]
        assert all(entry == 0 for entry in equations(values, next_modulus))
        modulus = next_modulus
    return lift, values, modulus, int(jacobian.determinant())


def git_revision() -> str:
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--digits", type=int, default=DEFAULT_DIGITS)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()

    verifier = load_module(
        "koenig_curve_verifier_19adic", "verify_koenig_hurwitz_curve.sage"
    )
    _, alpha_variable, beta_variable, relation = verifier.load_polynomial(
        args.archive
    )
    lift, values, modulus, jacobian_determinant = lift_anchor(args.digits)
    residue_ring = Integers(modulus)
    alpha = values[lift.SPECS.index(("f2", 4))]
    beta = values[lift.SPECS.index(("f1", 5))]
    reduced_relation = relation.change_ring(residue_ring)
    plane_residue = reduced_relation(
        **{
            str(alpha_variable): residue_ring(alpha),
            str(beta_variable): residue_ring(beta),
        }
    )
    assert plane_residue == 0

    canonical_values = "\n".join(
        f"{name}:{exponent}:{value}"
        for (name, exponent), value in zip(lift.SPECS, values)
    ) + "\n"
    values_hash = hashlib.sha256(canonical_values.encode()).hexdigest()
    archive_hash = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    assert (
        archive_hash
        == "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
    )
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# archive_sha256\t{archive_hash}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        f"# digits\t{args.digits}",
        f"# modulus\t{modulus}",
        "# branch_label\tlambda=9",
        f"# jacobian_determinant_mod19\t{jacobian_determinant}",
        f"# values_sha256\t{values_hash}",
        "alpha_residue\tbeta_residue\tcover_equations_zero\tplane_relation_zero",
        f"{alpha}\t{beta}\ttrue\ttrue",
    ]
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.check_summary is not None:
        assert args.check_summary.read_text() == text

    print(f"SageMath {SAGE_VERSION}")
    print(
        f"verified unique normalized anchor lift modulo 19^{args.digits}; "
        f"values_sha256={values_hash}"
    )
    print("verified exact universal-cover equations and h(alpha,beta)=0")


if __name__ == "__main__":
    main()
