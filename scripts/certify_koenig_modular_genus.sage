#!/usr/bin/env sage
"""Certify the genera of two exact reductions of König's M23 plane curve."""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import re
import time
from pathlib import Path

from sage.all import GF, PolynomialRing, QQ
from sage.interfaces.singular import singular


EXPECTED = {
    13: {
        "candidate_factors": 21,
        "common_resultant_degree": 9220,
        "squarefree_t_degree": 4569,
        "singular_points": 4571,
        "ordinary_nodes": 4563,
        "exceptional_points": 8,
        "exceptional_delta": 45,
    },
    17: {
        "candidate_factors": 19,
        "common_resultant_degree": 9222,
        "squarefree_t_degree": 4564,
        "singular_points": 4565,
        "ordinary_nodes": 4556,
        "exceptional_points": 9,
        "exceptional_delta": 52,
    },
}


def load_verifier():
    path = Path(__file__).with_name("verify_koenig_hurwitz_curve.sage")
    loader = importlib.machinery.SourceFileLoader("koenig_verifier", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König curve verifier")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def local_invariants(polynomial, point):
    local = rational_local_polynomial(polynomial, point)
    delta = int(str(local._singular_().delta()))
    milnor = int(str(local._singular_().milnor()))
    tjurina = int(str(local._singular_().tjurina()))
    branches = 2 * delta - milnor + 1
    return delta, milnor, tjurina, branches


def rational_local_polynomial(polynomial, point):
    ring = PolynomialRing(QQ, names=("u", "v"), order="negdegrevlex")
    u, v = ring.gens()
    t, x = polynomial.parent().gens()
    return ring(polynomial(t=point[0] + u, x=point[1] + v))


def branch_orbit_degrees(local):
    essential = singular('"ess"')
    expansion = local._singular_().hnexpansion(essential)
    degrees = tuple(map(int, re.findall(r"\d+", str(expansion[2]))))
    return degrees, expansion[1]


def infinity_polynomial(polynomial, field):
    ring = PolynomialRing(field, names=("u", "z"), order="negdegrevlex")
    u, z = ring.gens()
    degree = polynomial.total_degree()
    return sum(
        ring(coefficient)
        * (1 + u) ** exponent[1]
        * z ** (degree - sum(exponent))
        for exponent, coefficient in polynomial.dict().items()
    )


def verify_only_infinity_singularity(polynomial, prime):
    field = GF(prime)
    reduced = polynomial.change_ring(field)
    t, x = reduced.parent().gens()
    degree = reduced.total_degree()
    top = sum(
        coefficient * t**exponent[0] * x**exponent[1]
        for exponent, coefficient in reduced.dict().items()
        if sum(exponent) == degree
    )
    next_form = sum(
        coefficient * t**exponent[0] * x**exponent[1]
        for exponent, coefficient in reduced.dict().items()
        if sum(exponent) == degree - 1
    )
    univariate = PolynomialRing(field, "q")
    q = univariate.gen()
    top_x_chart = univariate(top(t=q, x=1))
    next_x_chart = univariate(next_form(t=q, x=1))
    singular = (
        top_x_chart.gcd(top_x_chart.derivative()).gcd(next_x_chart).monic()
    )
    assert singular == (q - 1) ** 4

    # The missing point [1:0:0] is smooth because the coefficient of z in
    # the t=1 chart is nonzero there.
    top_t_chart = univariate(top(t=1, x=q))
    next_t_chart = univariate(next_form(t=1, x=q))
    assert top_t_chart.valuation(q) == 2
    assert next_t_chart(q=0) != 0


def specialize(polynomial, t_value, target_ring):
    X = target_ring.gen()
    return sum(
        target_ring.base_ring()(coefficient)
        * t_value**t_degree
        * X**x_degree
        for (t_degree, x_degree), coefficient in polynomial.dict().items()
    )


def finite_local_delta(polynomial, t_value, x_value, field):
    local_ring = PolynomialRing(
        field,
        names=("u", "v"),
        order="negdegrevlex",
    )
    u, v = local_ring.gens()
    local = sum(
        local_ring(field(coefficient))
        * (local_ring(t_value) + u) ** t_degree
        * (local_ring(x_value) + v) ** x_degree
        for (t_degree, x_degree), coefficient in polynomial.dict().items()
    )
    return int(str(local._singular_().delta()))


def certify_prime(polynomial, prime):
    started = time.monotonic()
    field = GF(prime)
    ring = PolynomialRing(field, names=("t", "x"), order="lex")
    t, x = ring.gens()
    reduced = ring(polynomial)

    factors = tuple(reduced.factor())
    assert len(factors) == 1 and factors[0][1] == 1
    point = (field(QQ(31) / 18), field(0))
    assert reduced(t=point[0], x=point[1]) == 0
    assert (
        reduced.derivative(t)(t=point[0], x=point[1]) != 0
        or reduced.derivative(x)(t=point[0], x=point[1]) != 0
    )

    derivative_t = reduced.derivative(t)
    derivative_x = reduced.derivative(x)
    hessian = (
        reduced.derivative(t, 2) * reduced.derivative(x, 2)
        - derivative_t.derivative(x) ** 2
    )
    resultant_x = reduced.resultant(derivative_x, x)
    resultant_t = reduced.resultant(derivative_t, x)
    common_resultant = resultant_x.gcd(resultant_t)
    resultant_factors = tuple(common_resultant.factor())

    singular_points = 0
    ordinary_nodes = 0
    exceptional_points = 0
    exceptional_delta = 0
    base_univariate = PolynomialRing(field, "T")
    T = base_univariate.gen()

    for index, (factor, _) in enumerate(resultant_factors, 1):
        modulus = base_univariate(factor(t=T, x=0)).monic()
        t_degree = modulus.degree()
        extension = GF(
            field.order() ** t_degree,
            name=f"a{prime}_{index}",
            modulus=modulus,
        )
        a = extension.gen()
        x_ring = PolynomialRing(extension, "X")

        specialized = specialize(reduced, a, x_ring)
        specialized_t = specialize(derivative_t, a, x_ring)
        specialized_x = specialize(derivative_x, a, x_ring)
        singular_x = (
            specialized.gcd(specialized_t).gcd(specialized_x).radical()
        )
        if singular_x.degree() == 0:
            continue
        specialized_hessian = specialize(hessian, a, x_ring)

        for x_factor, _ in singular_x.factor():
            x_degree = x_factor.degree()
            point_count = t_degree * x_degree
            singular_points += point_count
            if specialized_hessian % x_factor != 0:
                ordinary_nodes += point_count
                continue

            # This holds for every exceptional stratum at the certificate
            # primes. It keeps the local field and delta computation explicit.
            assert x_degree == 1
            x_value = -x_factor[0] / x_factor[1]
            local_delta = finite_local_delta(reduced, a, x_value, extension)
            exceptional_points += t_degree
            exceptional_delta += t_degree * local_delta

    verify_only_infinity_singularity(polynomial, prime)
    infinity_local = infinity_polynomial(polynomial, field)
    infinity_delta = int(str(infinity_local._singular_().delta()))
    affine_delta = ordinary_nodes + exceptional_delta
    projective_delta = affine_delta + infinity_delta
    arithmetic_genus = (polynomial.total_degree() - 1) * (
        polynomial.total_degree() - 2
    ) // 2
    geometric_genus = arithmetic_genus - projective_delta

    result = {
        "candidate_factors": len(resultant_factors),
        "common_resultant_degree": common_resultant.degree(t),
        "squarefree_t_degree": common_resultant.radical().degree(t),
        "singular_points": singular_points,
        "ordinary_nodes": ordinary_nodes,
        "exceptional_points": exceptional_points,
        "exceptional_delta": exceptional_delta,
    }
    assert result == EXPECTED[prime]
    assert infinity_delta == 5
    assert affine_delta == 4608
    assert projective_delta == 4613
    assert arithmetic_genus == 4656
    assert geometric_genus == 43

    print(
        f"p={prime}: singular_points={singular_points} "
        f"ordinary_nodes={ordinary_nodes} "
        f"exceptional_points={exceptional_points} "
        f"exceptional_delta={exceptional_delta} "
        f"affine_delta={affine_delta} infinity_delta={infinity_delta} "
        f"genus={geometric_genus} "
        f"elapsed_seconds={time.monotonic() - started:.3f}"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument(
        "--primes",
        type=int,
        nargs="+",
        default=(13, 17),
        choices=tuple(EXPECTED),
    )
    args = parser.parse_args()

    singular.lib("hnoether.lib")
    verifier = load_verifier()
    _, _, _, polynomial = verifier.load_polynomial(args.archive)

    point_8 = local_invariants(polynomial, (QQ(35) / 9, QQ(2) / 3))
    point_2 = local_invariants(
        polynomial,
        (QQ(295) / 288, -QQ(11) / 96),
    )
    infinity = infinity_polynomial(polynomial, QQ)
    infinity_delta = int(str(infinity._singular_().delta()))
    infinity_milnor = int(str(infinity._singular_().milnor()))
    infinity_branches = 2 * infinity_delta - infinity_milnor + 1
    assert point_8 == (30, 54, 45, 7)
    assert point_2 == (1, 2, 2, 1)
    assert (infinity_delta, infinity_milnor, infinity_branches) == (5, 9, 2)

    point_8_orbits, point_8_hn = branch_orbit_degrees(
        rational_local_polynomial(polynomial, (QQ(35) / 9, QQ(2) / 3))
    )
    point_2_orbits, _ = branch_orbit_degrees(
        rational_local_polynomial(
            polynomial,
            (QQ(295) / 288, -QQ(11) / 96),
        )
    )
    infinity_orbits, infinity_hn = branch_orbit_degrees(infinity)
    assert point_8_orbits == (1, 1, 1, 2, 2)
    assert point_2_orbits == (1,)
    assert infinity_orbits == (2,)
    assert "134a2-19a+1" in str(point_8_hn)
    assert "5242880a2-49152a+117" in str(infinity_hn)
    print(
        "Q local invariants: "
        f"(35/9,2/3)={point_8},branch_orbits={point_8_orbits}; "
        f"(295/288,-11/96)={point_2},branch_orbits={point_2_orbits}; "
        f"infinity=(delta={infinity_delta},milnor={infinity_milnor},"
        f"branches={infinity_branches}),"
        f"branch_orbits={infinity_orbits}"
    )

    for prime in args.primes:
        certify_prime(polynomial, prime)


if __name__ == "__main__":
    main()
