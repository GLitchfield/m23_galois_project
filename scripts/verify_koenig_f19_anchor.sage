#!/usr/bin/env sage
"""Verify König's published F_19 cover against the archived plane equation."""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
from pathlib import Path

from sage.all import GF, PolynomialRing
from sage.env import SAGE_VERSION


def load_verifier():
    path = Path(__file__).with_name("verify_koenig_hurwitz_curve.sage")
    loader = importlib.machinery.SourceFileLoader("koenig_verifier", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König curve verifier")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def geometric_multiplicities(polynomial):
    """Return root multiplicities over an algebraic closure."""
    return sorted(
        multiplicity
        for factor, multiplicity in polynomial.factor()
        for _ in range(factor.degree())
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()

    verifier = load_verifier()
    _, alpha_variable, beta_variable, relation = verifier.load_polynomial(
        args.archive
    )

    field = GF(19)
    ring = PolynomialRing(field, "X")
    X = ring.gen()

    # Dissertation, Chapter 5.3, page 73.  The displayed polynomial is
    # N(X) - t D(X); the degree-six factor includes the printed X factor.
    f1 = X * (X**5 + X**4 - X**3 - X**2 + 7)
    f2 = X**5 + 6 * X**4 + X**3 + 4 * X**2 + 12 * X + 1
    g1 = X**3 + 2 * X**2 + 13 * X + 5
    g2 = X**3 + X**2 + 2 * X + 6
    numerator = f1**3 * f2
    denominator = g1**5 * g2

    assert numerator.degree() == 23
    assert denominator.degree() == 18
    assert numerator.gcd(denominator) == 1

    # The target change T = 10*t + 5 sends the order-three value 0 to
    # 1/4=5 and the two order-two values 9,11 to 1,0.  The order-five
    # value remains infinity.
    finite_fibers = {
        field(5): 10 * numerator,
        field(0): 10 * numerator + 5 * denominator,
        field(1): 10 * numerator + 4 * denominator,
    }
    partitions = (
        geometric_multiplicities(finite_fibers[field(0)]),
        geometric_multiplicities(finite_fibers[field(1)]),
        geometric_multiplicities(finite_fibers[field(5)]),
        sorted(geometric_multiplicities(denominator) + [5]),
    )
    assert partitions == (
        [1] * 7 + [2] * 8,
        [1] * 7 + [2] * 8,
        [1] * 5 + [3] * 6,
        [1] * 3 + [5] * 4,
    )
    assert sum(
        multiplicity - 1
        for partition in partitions
        for multiplicity in partition
    ) == 2 * 23 - 2

    # X = 5Y+2 is the affine change that puts the two monic cubics in
    # König's normalization:
    # their Y^2 coefficients become 1/3 and -1/2.
    normalized_ring = PolynomialRing(field, "Y")
    Y = normalized_ring.gen()
    normalized = tuple(
        normalized_ring(
            polynomial(X=5 * Y + 2) / field(5) ** polynomial.degree()
        )
        for polynomial in (f1, f2, g1, g2)
    )
    normalized_f1, normalized_f2, normalized_g1, normalized_g2 = normalized
    assert all(polynomial.is_monic() for polynomial in normalized)
    assert normalized_g1[2] == field(1) / 3
    assert normalized_g2[2] == -field(1) / 2

    beta = normalized_f1[5]
    alpha = normalized_f2[4]
    constant = 10 * field(5) ** 5
    assert (alpha, beta, constant) == (field(7), field(14), field(14))

    substituted_numerator = normalized_ring(numerator(X=5 * Y + 2))
    substituted_denominator = normalized_ring(denominator(X=5 * Y + 2))
    assert substituted_numerator == (
        field(5) ** 23 * normalized_f1**3 * normalized_f2
    )
    assert substituted_denominator == (
        field(5) ** 18 * normalized_g1**5 * normalized_g2
    )
    assert (
        10 * substituted_numerator * normalized_g1**5 * normalized_g2
        == constant
        * normalized_f1**3
        * normalized_f2
        * substituted_denominator
    )

    reduced_relation = relation.change_ring(field)
    assert reduced_relation(
        **{
            str(alpha_variable): alpha,
            str(beta_variable): beta,
        }
    ) == 0

    print(f"SageMath {SAGE_VERSION}")
    print(
        "verified exact F_19 branch partitions "
        "(2^8.1^7,2^8.1^7,3^6.1^5,5^4.1^3)"
    )
    print(
        "verified König normalization alpha=7, beta=14, C=14 "
        "and h(alpha,beta)=0 modulo 19"
    )
    print(
        "this is one exact finite-field anchor, not a component-wide "
        "characteristic-zero coefficient-map certificate"
    )


if __name__ == "__main__":
    main()
