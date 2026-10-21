#!/usr/bin/env sage
"""Export a fixed-plane-point König cover system for exact finite-field solving."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
from pathlib import Path

from sage.all import GF, PolynomialRing, is_prime


FACTOR_DEGREES = {
    "f1": 6,
    "f2": 5,
    "f3": 8,
    "f4": 7,
    "f5": 8,
    "f6": 7,
}
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)


def load_curve_verifier():
    path = Path(__file__).with_name("verify_koenig_hurwitz_curve.sage")
    loader = importlib.machinery.SourceFileLoader(
        "koenig_curve_second_prime", str(path)
    )
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König curve verifier")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def variable_specs(presentation="raw"):
    if presentation not in ("raw", "scaled"):
        raise ValueError(f"unknown presentation {presentation}")
    specs = []
    for name, degree in FACTOR_DEGREES.items():
        variable_factor = (
            f"h{name[1:]}"
            if presentation == "scaled" and name in ("f4", "f6")
            else name
        )
        specs.extend(
            (variable_factor, exponent) for exponent in range(degree)
        )
    specs.extend(("g1", exponent) for exponent in range(2))
    specs.extend(("g2", exponent) for exponent in range(2))
    specs.extend((("constant", 0), ("lambda", 0)))
    assert len(specs) == 47
    return specs


def variable_name(spec):
    name, exponent = spec
    return name if name in ("constant", "lambda") else f"{name}_{exponent}"


def fixed_system(
    prime,
    alpha,
    beta,
    branch_label=None,
    presentation="raw",
    variable_order="standard",
):
    field = GF(prime)
    specs = variable_specs(presentation)
    fixed = {
        ("f1", 5): field(beta),
        ("f2", 4): field(alpha),
    }
    if branch_label is not None:
        fixed[("lambda", 0)] = field(branch_label)
    free_specs = [spec for spec in specs if spec not in fixed]
    simple_specs = [
        spec for spec in free_specs if spec[0] in ("h4", "h6")
    ]
    other_specs = [
        spec for spec in free_specs if spec[0] not in ("h4", "h6")
    ]
    if variable_order == "simple-first":
        free_specs = simple_specs + other_specs
    elif variable_order == "simple-last":
        free_specs = other_specs + simple_specs
    elif variable_order != "standard":
        raise ValueError(f"unknown variable order {variable_order}")
    coefficient_ring = PolynomialRing(
        field,
        names=[variable_name(spec) for spec in free_specs],
        order="degrevlex",
    )
    free_values = dict(zip(free_specs, coefficient_ring.gens()))
    values = {**free_values, **fixed}
    y_ring = PolynomialRing(coefficient_ring, "Y")
    Y = y_ring.gen()

    factors = {}
    for name, degree in FACTOR_DEGREES.items():
        if presentation == "scaled" and name in ("f4", "f6"):
            continue
        factors[name] = Y**degree + sum(
            values[(name, exponent)] * Y**exponent
            for exponent in range(degree)
        )
    factors["g1"] = (
        Y**3
        + coefficient_ring(field(1) / 3) * Y**2
        + values[("g1", 1)] * Y
        + values[("g1", 0)]
    )
    factors["g2"] = (
        Y**3
        - coefficient_ring(field(1) / 2) * Y**2
        + values[("g2", 1)] * Y
        + values[("g2", 0)]
    )
    constant = values[("constant", 0)]
    branch_label_value = values[("lambda", 0)]
    quarter = coefficient_ring(field(1) / 4)
    F1 = factors["f1"] ** 3 * factors["f2"]
    denominator = factors["g1"] ** 5 * factors["g2"]
    if presentation == "raw":
        F3 = factors["f3"] ** 2 * factors["f4"]
        F5 = factors["f5"] ** 2 * factors["f6"]
        polynomial_equations = (
            constant * (F3 - F1)
            + (quarter + branch_label_value) * denominator,
            constant * (F5 - F1)
            - (branch_label_value - quarter) * denominator,
        )
    else:
        h4 = constant * Y**7 + sum(
            values[("h4", exponent)] * Y**exponent
            for exponent in range(7)
        )
        h6 = constant * Y**7 + sum(
            values[("h6", exponent)] * Y**exponent
            for exponent in range(7)
        )
        polynomial_equations = (
            factors["f3"] ** 2 * h4
            - constant * F1
            + (quarter + branch_label_value) * denominator,
            factors["f5"] ** 2 * h6
            - constant * F1
            - (branch_label_value - quarter) * denominator,
        )
    equations = [
        equation[exponent]
        for equation in polynomial_equations
        for exponent in range(23)
    ]
    assert len(equations) == 46
    return coefficient_ring, free_specs, equations


def archive_relation(archive):
    verifier = load_curve_verifier()
    _, alpha_variable, beta_variable, relation = verifier.load_polynomial(
        archive
    )
    return alpha_variable, beta_variable, relation


def assert_smooth_plane_point(archive, prime, alpha, beta):
    alpha_variable, beta_variable, relation = archive_relation(archive)
    field = GF(prime)
    reduced = relation.change_ring(field)
    point = {
        str(alpha_variable): field(alpha),
        str(beta_variable): field(beta),
    }
    if reduced(**point) != 0:
        raise ValueError("selected alpha,beta is not on the reduced plane curve")
    derivatives = (
        reduced.derivative(reduced.parent().gen(0)),
        reduced.derivative(reduced.parent().gen(1)),
    )
    if all(derivative(**point) == 0 for derivative in derivatives):
        raise ValueError("selected alpha,beta is singular on the reduced plane curve")


def self_test():
    base = {
        "f1": (15, 5, 7, 7, 2, 14),
        "f2": (7, 15, 4, 18, 7),
        "f3": (18, 5, 1, 12, 12, 11, 6, 9),
        "f4": (17, 9, 8, 14, 1, 8, 12),
        "f5": (0, 8, 8, 0, 7, 6, 1, 1),
        "f6": (17, 15, 4, 18, 17, 11, 9),
        "g1": (6, 15),
        "g2": (2, 3),
    }
    for presentation in ("raw", "scaled"):
        orders = (
            ("standard",)
            if presentation == "raw"
            else ("standard", "simple-first", "simple-last")
        )
        for variable_order in orders:
            ring, free_specs, equations = fixed_system(
                19,
                7,
                14,
                presentation=presentation,
                variable_order=variable_order,
            )
            values = {}
            for spec in free_specs:
                name, exponent = spec
                if name in base:
                    value = base[name][exponent]
                elif name in ("h4", "h6"):
                    value = 14 * base[f"f{name[1:]}"][exponent]
                elif name == "constant":
                    value = 14
                elif name == "lambda":
                    value = 9
                else:
                    raise AssertionError(spec)
                values[variable_name(spec)] = ring.base_ring()(value)
            assert all(equation(**values) == 0 for equation in equations)
            assert len(ring.variable_names()) == 45
            fixed_ring, fixed_specs, fixed_equations = fixed_system(
                19,
                7,
                14,
                9,
                presentation,
                variable_order,
            )
            fixed_values = {
                variable_name(spec): values[variable_name(spec)]
                for spec in fixed_specs
            }
            assert all(
                equation(**fixed_values) == 0
                for equation in fixed_equations
            )
            assert len(fixed_ring.variable_names()) == 44
    print(
        "second-prime exporter self-test passed: known F_19 anchor "
        "satisfies 46 equations with free and fixed lambda"
    )


def msolve_text(ring, equations):
    lines = [
        ",".join(ring.variable_names()),
        str(ring.base_ring().order()),
    ]
    lines.extend(
        str(equation) + ("," if index + 1 < len(equations) else "")
        for index, equation in enumerate(equations)
    )
    return "\n".join(lines) + "\n"


def write_msolve(path, ring, equations):
    path.write_text(msolve_text(ring, equations), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument("--prime", type=int)
    parser.add_argument("--alpha", type=int)
    parser.add_argument("--beta", type=int)
    parser.add_argument("--lambda", dest="branch_label", type=int)
    parser.add_argument(
        "--presentation",
        choices=("raw", "scaled"),
        default="scaled",
    )
    parser.add_argument(
        "--variable-order",
        choices=("standard", "simple-first", "simple-last"),
        default="standard",
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.archive is None:
        parser.error("archive is required outside --self-test")
    if args.prime is None or args.alpha is None or args.beta is None:
        parser.error("--prime, --alpha, and --beta are required")
    if args.output is None:
        parser.error("--output is required")
    if not is_prime(args.prime) or args.prime in (2, 3, 5):
        parser.error("--prime must be a prime other than 2, 3, or 5")
    archive_hash = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    if archive_hash != ARCHIVE_SHA256:
        raise ValueError("archive SHA-256 mismatch")

    assert_smooth_plane_point(
        args.archive, args.prime, args.alpha, args.beta
    )
    ring, _, equations = fixed_system(
        args.prime,
        args.alpha,
        args.beta,
        args.branch_label,
        args.presentation,
        args.variable_order,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_msolve(args.output, ring, equations)
    print(
        f"prime={args.prime} alpha={args.alpha % args.prime} "
        f"beta={args.beta % args.prime} variables={ring.ngens()} "
        f"lambda={('free' if args.branch_label is None else args.branch_label % args.prime)} "
        f"presentation={args.presentation} "
        f"variable_order={args.variable_order} "
        f"equations={len(equations)} "
        f"terms={sum(len(equation.dict()) for equation in equations)} "
        f"max_degree={max(equation.total_degree() for equation in equations)} "
        f"output={args.output}"
    )


if __name__ == "__main__":
    main()
