#!/usr/bin/env sage
"""Exact local elimination for the M24 genus-11 (-6,0) unit corridor."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import subprocess
from importlib.machinery import SourceFileLoader
from pathlib import Path

from sage.all import PolynomialRing, Qp, QQ, valuation
from sage.env import SAGE_VERSION


SCHEMA = "m23-m24-genus11-local-elimination-v1"
UNIT_DEPTH = 25
LOCAL_PRECISION = 160


def load_unit_module():
    path = Path(__file__).with_name(
        "audit_m24_genus11_unit_charts.sage"
    )
    loader = SourceFileLoader("m24_genus11_unit_charts_local", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


unit = load_unit_module()


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def polynomial_digest(polynomial):
    return hashlib.sha256(
        str(polynomial).encode("ascii")
    ).hexdigest()


def nested_polynomial(polynomial, ring_t, ring_x):
    t = ring_t.gen()
    x = ring_x.gen()
    result = ring_x.zero()
    for (t_degree, x_degree), coefficient in polynomial.dict().items():
        result += (
            ring_t(coefficient)
            * t**t_degree
            * x**x_degree
        )
    return result


def first_subresultant_mod_factor(left, right, factor):
    ring_x = left.parent()
    for index, item in enumerate(left.subresultants(right)):
        reduced = ring_x(
            {
                exponent: coefficient % factor
                for exponent, coefficient in item.dict().items()
                if coefficient % factor
            }
        )
        if reduced:
            return index, reduced
    raise AssertionError("subresultant sequence vanishes modulo factor")


def exact_local_elimination(polynomial):
    audit = unit.canonical_unit_audit(
        polynomial,
        -6,
        0,
        UNIT_DEPTH,
    )
    assert len(audit["residues"]) == 16
    chart = audit["global_chart"]
    source_t, source_x = chart.parent().gens()

    resultant = chart.resultant(
        chart.derivative(source_x),
        source_x,
    ).univariate_polynomial()
    factorization = resultant.factor()
    repeated = resultant.gcd(resultant.derivative())
    repeated_factorization = repeated.factor()
    singular_factor = next(
        factor.monic()
        for factor, multiplicity in repeated_factorization
        if factor.degree() == 442
    )
    assert singular_factor.is_irreducible()

    ring_t = singular_factor.parent()
    ring_x = PolynomialRing(ring_t, names=("x",))
    nested_f = nested_polynomial(chart, ring_t, ring_x)
    nested_fx = nested_polynomial(
        chart.derivative(source_x),
        ring_t,
        ring_x,
    )
    nested_ft = nested_polynomial(
        chart.derivative(source_t),
        ring_t,
        ring_x,
    )
    fx_index, fx_witness = first_subresultant_mod_factor(
        nested_f,
        nested_fx,
        singular_factor,
    )
    ft_index, ft_witness = first_subresultant_mod_factor(
        nested_f,
        nested_ft,
        singular_factor,
    )
    assert fx_witness.degree() == 1
    assert ft_witness.degree() == 1
    fx_lead, fx_constant = fx_witness[1], fx_witness[0]
    ft_lead, ft_constant = ft_witness[1], ft_witness[0]
    assert fx_lead.gcd(singular_factor).degree() == 0
    assert ft_lead.gcd(singular_factor).degree() == 0
    proportionality = (
        fx_lead * ft_constant - ft_lead * fx_constant
    ) % singular_factor
    assert not proportionality

    t_centers = sorted(
        {left for left, _ in audit["residues"]}
    )
    hensel_rows = [
        (
            center,
            valuation(singular_factor(center), 2),
            valuation(singular_factor.derivative()(center), 2),
        )
        for center in t_centers
    ]
    assert {row[2] for row in hensel_rows} == {0}
    assert min(row[1] for row in hensel_rows) >= 23
    assert len({center % (1 << 23) for center in t_centers}) == 1

    field = Qp(2, LOCAL_PRECISION)
    best_center = max(hensel_rows, key=lambda row: row[1])[0]
    t_root = field(best_center)
    for _ in range(8):
        t_root -= (
            singular_factor(t_root)
            / singular_factor.derivative()(t_root)
        )
    x_root = -fx_constant(t_root) / fx_lead(t_root)

    derivative_t = chart.derivative(source_t)
    derivative_x = chart.derivative(source_x)
    discriminant = -(
        derivative_t.derivative(source_t)(
            t=t_root,
            x=x_root,
        )
        * derivative_x.derivative(source_x)(
            t=t_root,
            x=x_root,
        )
        - derivative_t.derivative(source_x)(
            t=t_root,
            x=x_root,
        )
        ** 2
    )
    discriminant_valuation = discriminant.valuation()
    discriminant_unit = (
        discriminant >> discriminant_valuation
    )
    assert discriminant_valuation == 8
    assert int(discriminant_unit.lift()) % 8 == 7
    assert not discriminant.is_square()

    return {
        "audit": audit,
        "resultant": resultant,
        "factorization": factorization,
        "repeated": repeated,
        "repeated_factorization": repeated_factorization,
        "singular_factor": singular_factor,
        "fx_index": fx_index,
        "ft_index": ft_index,
        "fx_witness": fx_witness,
        "ft_witness": ft_witness,
        "hensel_rows": hensel_rows,
        "t_root": t_root,
        "x_root": x_root,
        "discriminant_valuation": discriminant_valuation,
        "discriminant_unit": int(discriminant_unit.lift()) % 8,
    }


def factor_signature(factorization):
    return ",".join(
        f"{factor.degree()}^{multiplicity}"
        for factor, multiplicity in factorization
    )


def summary_text(result):
    fx_witness = result["fx_witness"]
    ft_witness = result["ft_witness"]
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        "# source\tKönig dissertation Theorem 5.2 and Appendix 5.1.12",
        f"# archive_sha256\t{unit.boundary.ARCHIVE_SHA256}",
        f"# model_sha256\t{unit.boundary.MODEL_SHA256}",
        "# status\texact_singular_nonsquare_normalization_excluded",
        f"resultant_degree\t{result['resultant'].degree()}",
        "resultant_sha256\t"
        + polynomial_digest(result["resultant"]),
        "resultant_factorization\t"
        + factor_signature(result["factorization"]),
        f"repeated_degree\t{result['repeated'].degree()}",
        "repeated_factorization\t"
        + factor_signature(result["repeated_factorization"]),
        f"singular_factor_degree\t{result['singular_factor'].degree()}",
        "singular_factor_sha256\t"
        + polynomial_digest(result["singular_factor"]),
        f"fx_first_nonzero_subresultant_index\t{result['fx_index']}",
        f"ft_first_nonzero_subresultant_index\t{result['ft_index']}",
        f"fx_witness_degree\t{fx_witness.degree()}",
        f"ft_witness_degree\t{ft_witness.degree()}",
        "fx_witness_lead_sha256\t"
        + polynomial_digest(fx_witness[1]),
        "fx_witness_constant_sha256\t"
        + polynomial_digest(fx_witness[0]),
        "ft_witness_lead_sha256\t"
        + polynomial_digest(ft_witness[1]),
        "ft_witness_constant_sha256\t"
        + polynomial_digest(ft_witness[0]),
        "witness_proportional_mod_singular_factor\ttrue",
        f"hensel_center_count\t{len(result['hensel_rows'])}",
        "hensel_factor_valuations\t"
        + ",".join(str(row[1]) for row in result["hensel_rows"]),
        "hensel_derivative_valuations\t"
        + ",".join(str(row[2]) for row in result["hensel_rows"]),
        f"hensel_common_residue_modulus\t{1 << 23}",
        "local_t_mod_2^64\t"
        + str(int(result["t_root"].lift()) % (1 << 64)),
        "local_x_mod_2^64\t"
        + str(int(result["x_root"].lift()) % (1 << 64)),
        "local_hessian_discriminant\t"
        + f"{result['discriminant_valuation']},"
        + f"{result['discriminant_unit']},nonsquare",
        "minus6_status\texact_ordinary_double_point_no_Q2_branches",
    ]
    return "\n".join(lines) + "\n"


def self_test():
    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    polynomial = (
        x**2 * (x + 1)
        + t * (x**2 + 3 * x)
        + t**2
    )
    ring_t = PolynomialRing(QQ, names=("t",))
    factor = ring_t.gen()
    ring_x = PolynomialRing(ring_t, names=("x",))
    nested = nested_polynomial(polynomial, ring_t, ring_x)
    nested_fx = nested_polynomial(
        polynomial.derivative(x),
        ring_t,
        ring_x,
    )
    nested_ft = nested_polynomial(
        polynomial.derivative(t),
        ring_t,
        ring_x,
    )
    fx_index, fx_witness = first_subresultant_mod_factor(
        nested,
        nested_fx,
        factor,
    )
    ft_index, ft_witness = first_subresultant_mod_factor(
        nested,
        nested_ft,
        factor,
    )
    assert fx_index == 1
    assert ft_index == 1
    assert fx_witness.degree() == 1
    assert ft_witness.degree() == 1
    assert not (
        fx_witness[1] * ft_witness[0]
        - ft_witness[1] * fx_witness[0]
    ) % factor
    print(
        "M24 genus-11 local-elimination self-test passed: "
        "linear subresultants agree on an exact ordinary node"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        if args.archive is None:
            return
    if args.archive is None:
        parser.error("archive is required outside --self-test")

    _, polynomial = unit.boundary.load_model(args.archive)
    text = summary_text(exact_local_elimination(polynomial))
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


if __name__ == "__main__":
    main()
