#!/usr/bin/env python3
"""Analyze the exact coefficient field of the class-1 8A Belyi map."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from sage.all import LaurentPolynomialRing, NumberField, PolynomialRing, QQ
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_revision() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path.resolve())


def coefficient_text(polynomial) -> str:
    return ",".join(str(value) for value in polynomial.list())


def factorization_text(value) -> str:
    return "*".join(
        str(prime) if exponent == 1 else f"{prime}^{exponent}"
        for prime, exponent in value.factor()
    )


def render(candidate_path: Path) -> str:
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    rational_ring = PolynomialRing(QQ, "T")
    defining_polynomial = rational_ring(
        candidate["field"]["defining_polynomial"]
    )
    if defining_polynomial.degree() != 28:
        raise RuntimeError("coefficient field does not have degree 28")
    if not defining_polynomial.is_irreducible():
        raise RuntimeError("coefficient-field polynomial is reducible")
    if defining_polynomial != rational_ring(
        list(reversed(defining_polynomial.list()))
    ):
        raise RuntimeError("coefficient-field polynomial is not reciprocal")

    coefficient_field = NumberField(defining_polynomial, "t")
    generator = coefficient_field.gen()
    inverse_generator = 1 / generator
    if defining_polynomial(inverse_generator) != 0:
        raise RuntimeError("generator inversion does not preserve the field")
    involution = coefficient_field.hom([inverse_generator], coefficient_field)
    if involution(involution(generator)) != generator:
        raise RuntimeError("generator inversion is not an involution")

    fixed_generator = generator + inverse_generator
    fixed_polynomial = fixed_generator.minpoly()
    if fixed_polynomial.degree() != 14 or not fixed_polynomial.is_irreducible():
        raise RuntimeError("reciprocal fixed generator has the wrong degree")
    laurent_ring = LaurentPolynomialRing(QQ, "U")
    variable = laurent_ring.gen()
    if (
        variable**14
        * laurent_ring(fixed_polynomial)(variable + variable**-1)
        != laurent_ring(defining_polynomial)
    ):
        raise RuntimeError("degree-28/degree-14 polynomial identity failed")

    fixed_field = NumberField(fixed_polynomial, "y")
    coefficient_discriminant = coefficient_field.discriminant()
    fixed_discriminant = fixed_field.discriminant()
    discriminant_ratio = (
        coefficient_discriminant / fixed_discriminant**2
    )
    if discriminant_ratio != 16:
        raise RuntimeError("unexpected relative discriminant ratio")

    coefficient_automorphisms = coefficient_field.automorphisms()
    fixed_automorphisms = fixed_field.automorphisms()
    if len(coefficient_automorphisms) != 2:
        raise RuntimeError("coefficient field has unexpected automorphisms")
    if len(fixed_automorphisms) != 1:
        raise RuntimeError("fixed field has unexpected automorphisms")

    metadata = [
        "# format\tm23_8a_coefficient_field_v1",
        f"# code_revision\t{git_revision()}",
        f"# source\t{display_path(candidate_path)}",
        f"# source_sha256\t{sha256(candidate_path)}",
        f"# sage_version\t{SAGE_VERSION}",
        "# construction\tfixed generator y=t+t^-1 under reciprocal involution",
        "# exact_polynomial_identity\tt^14*g(t+t^-1)=f(t)",
        "# interpretation\texact arithmetic invariants of the Belyi coefficient field",
    ]
    properties = [
        ("coefficient_field_degree", str(coefficient_field.degree())),
        ("coefficient_field_signature", ",".join(
            map(str, coefficient_field.signature())
        )),
        ("coefficient_field_automorphism_count",
         str(len(coefficient_automorphisms))),
        ("coefficient_field_discriminant", str(coefficient_discriminant)),
        ("coefficient_field_discriminant_factorization",
         factorization_text(coefficient_discriminant)),
        ("reciprocal_involution", "t->t^-1"),
        ("fixed_field_degree", str(fixed_field.degree())),
        ("fixed_field_signature", ",".join(
            map(str, fixed_field.signature())
        )),
        ("fixed_field_automorphism_count", str(len(fixed_automorphisms))),
        ("fixed_field_discriminant", str(fixed_discriminant)),
        ("fixed_field_discriminant_factorization",
         factorization_text(fixed_discriminant)),
        ("discriminant_ratio_DK_over_DL_squared", str(discriminant_ratio)),
        ("fixed_polynomial_low_to_high",
         coefficient_text(fixed_polynomial)),
    ]
    return "\n".join([
        *metadata,
        "property\tvalue",
        *("\t".join(row) for row in properties),
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    text = render(args.candidate)
    if args.output is None:
        print(text, end="")
    else:
        args.output.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
