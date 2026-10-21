#!/usr/bin/env sage
"""Run exact checks on the M23 Hurwitz equation in König's external archive."""

from __future__ import annotations

import argparse
import hashlib
import re
import zipfile
from pathlib import Path

from sage.all import GF, PolynomialRing, QQ

ARCHIVE_SHA256 = "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
CURVE = (
    "Polynomials And Approximation Data/M23_(2,2,3,5)/"
    "(2,2,3,5)_hurwitzcurve_parametrization.txt"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_polynomial(path: Path):
    if sha256(path) != ARCHIVE_SHA256:
        raise ValueError("archive SHA-256 mismatch")
    with zipfile.ZipFile(path) as archive:
        source = archive.read(CURVE).decode("ascii")
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    source = re.sub(r"\\\r?\n\s*", "", source).strip()
    if not source.startswith("h:=") or not source.endswith(";"):
        raise ValueError("unexpected polynomial wrapper")
    expression = source[len("h:=") : -1]
    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    terms = []
    depth = 0
    start = 0
    for index, character in enumerate(expression):
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
        elif character in "+-" and depth == 0 and index > start:
            terms.append(expression[start:index])
            start = index
    terms.append(expression[start:])
    polynomial = ring.zero()
    for term in terms:
        term = term.strip()
        outer_sign = 1
        if term.startswith("+"):
            term = term[1:].lstrip()
        elif term.startswith("-"):
            outer_sign = -1
            term = term[1:].lstrip()
        t_match = re.search(r"\*t(?:\^(\d+))?\s*$", term)
        if t_match:
            t_degree = int(t_match.group(1) or 1)
            coefficient = term[: t_match.start()].strip()
        else:
            t_degree = 0
            coefficient = term
        while coefficient.startswith("(") and coefficient.endswith(")"):
            coefficient = coefficient[1:-1]
        coefficient = re.sub(r"\s+", "", coefficient)
        pieces = re.findall(r"[+-]?[^+-]+", coefficient)
        for piece in pieces:
            match = re.fullmatch(r"([+-]?)(\d+)(?:\*x(?:\^(\d+))?)?", piece)
            if not match:
                raise ValueError(
                    f"cannot parse coefficient term {piece[:80]!r}; "
                    f"outer term starts {term[:80]!r} and ends {term[-80:]!r}"
                )
            inner_sign = -1 if match.group(1) == "-" else 1
            integer = int(match.group(2))
            x_degree = int(match.group(3) or (1 if "*x" in piece else 0))
            polynomial += outer_sign * inner_sign * integer * t**t_degree * x**x_degree
    return ring, t, x, polynomial


def convex_hull(points):
    """Return the counterclockwise convex hull of integer lattice points."""
    points = sorted(set(points))
    if len(points) <= 1:
        return tuple(points)

    def cross(origin, left, right):
        return (
            (left[0] - origin[0]) * (right[1] - origin[1])
            - (left[1] - origin[1]) * (right[0] - origin[0])
        )

    lower = []
    for point in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    upper = []
    for point in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return tuple(lower[:-1] + upper[:-1])


def verify_absolute_irreducibility(polynomial):
    """Certify geometric irreducibility using a smooth irreducible reduction."""
    field = GF(11)
    reduced = polynomial.change_ring(field)
    t, x = reduced.parent().gens()
    assert reduced.degree(t) == 97
    assert reduced.degree(x) == 98

    factors = tuple(reduced.factor())
    assert len(factors) == 1
    factor, multiplicity = factors[0]
    assert multiplicity == 1
    assert factor.degree(t) == 97
    assert factor.degree(x) == 98

    # An irreducible curve over a finite field that is geometrically reducible
    # has all rational points in intersections of conjugate components, hence
    # singular.  This smooth F_11 point therefore proves that the reduction is
    # geometrically irreducible.  Geometric irreducibility of a degree-
    # preserving reduction proves absolute irreducibility over Q.
    point = (field(QQ(31) / 18), field(0))
    assert reduced(t=point[0], x=point[1]) == 0
    assert (
        reduced.derivative(t)(t=point[0], x=point[1]) != 0
        or reduced.derivative(x)(t=point[0], x=point[1]) != 0
    )


def tangent_cone(polynomial, point):
    ring = PolynomialRing(QQ, names=("u", "v"))
    u, v = ring.gens()
    shifted = ring(polynomial(t=point[0] + u, x=point[1] + v))
    multiplicity = min(sum(exponent) for exponent in shifted.dict())
    cone = sum(
        coefficient * u**exponent[0] * v**exponent[1]
        for exponent, coefficient in shifted.dict().items()
        if sum(exponent) == multiplicity
    )
    return ring, u, v, multiplicity, cone


def assert_associate(left, right):
    quotient, remainder = left.quo_rem(right)
    assert remainder == 0
    assert quotient.degree() == 0
    assert quotient != 0


def verify_singular_tangent_cones(polynomial):
    point = (QQ(35) / 9, QQ(2) / 3)
    _, u, v, multiplicity, cone = tangent_cone(polynomial, point)
    assert multiplicity == 8
    assert_associate(
        cone,
        (u - 17 * v)
        * (9 * u - 43 * v)
        * (u - 2 * v) ** 2
        * (u**2 - 19 * u * v + 134 * v**2) ** 2,
    )

    point = (QQ(295) / 288, -QQ(11) / 96)
    _, u, v, multiplicity, cone = tangent_cone(polynomial, point)
    assert multiplicity == 2
    assert_associate(cone, (19 * u - 27 * v) ** 2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()

    _, t, x, polynomial = load_polynomial(args.archive)
    assert polynomial.degree(t) == 97
    assert polynomial.degree(x) == 98
    newton_vertices = convex_hull(
        tuple(map(int, exponent)) for exponent in polynomial.dict()
    )
    assert newton_vertices == ((0, 0), (97, 0), (96, 2), (0, 98))
    verify_absolute_irreducibility(polynomial)

    points = (
        (QQ(31) / 18, QQ(0)),
        (QQ(5) / 9, QQ(2) / 3),
        (QQ(35) / 9, QQ(2) / 3),
        (QQ(410) / 9, QQ(2) / 3),
        (QQ(295) / 288, -QQ(11) / 96),
    )
    for point in points:
        assert polynomial(t=point[0], x=point[1]) == 0

    derivative_t = polynomial.derivative(t)
    derivative_x = polynomial.derivative(x)
    nonsingular = tuple(
        point
        for point in points
        if (
            derivative_t(t=point[0], x=point[1]) != 0
            or derivative_x(t=point[0], x=point[1]) != 0
        )
    )
    assert nonsingular == (points[0], points[1], points[3])
    verify_singular_tangent_cones(polynomial)

    print("verified exact bidegree (97,98) and all five reported rational points")
    print("verified Newton polygon vertices (0,0), (97,0), (96,2), (0,98)")
    print("verified absolute irreducibility via a smooth irreducible mod-11 reduction")
    print("verified the three reported nonsingular points by exact derivatives")
    print("verified multiplicities and tangent cones at both singular rational points")


if __name__ == "__main__":
    main()
