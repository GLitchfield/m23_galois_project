#!/usr/bin/env python3
"""Certify exact Frobenius cycle types for the 8A degree-14 fixed field."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from sage.all import GF, PolynomialRing, ZZ
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]
PRIMES = (7, 127, 53)


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


def factorization_text(value) -> str:
    return "*".join(
        str(prime) if exponent == 1 else f"{prime}^{exponent}"
        for prime, exponent in ZZ(value).factor()
    )


def render(source: Path, code_revision: str) -> str:
    document = json.loads(source.read_text(encoding="utf-8"))
    coefficients = [ZZ(value) for value in
                    document["field"]["defining_polynomial"]]
    integer_ring = PolynomialRing(ZZ, "x")
    polynomial = integer_ring(coefficients)
    if polynomial.degree() != 14:
        raise RuntimeError("fixed-field polynomial does not have degree 14")
    if not polynomial.is_monic():
        raise RuntimeError("fixed-field polynomial is not monic")
    if not polynomial.is_irreducible():
        raise RuntimeError("fixed-field polynomial is reducible over Q")

    discriminant = ZZ(polynomial.discriminant())
    rows = []
    for prime in PRIMES:
        if discriminant % prime == 0:
            raise RuntimeError(f"selected prime {prime} divides discriminant")
        finite_polynomial = polynomial.change_ring(GF(prime))
        if not finite_polynomial.is_squarefree():
            raise RuntimeError(f"reduction modulo {prime} is not squarefree")
        factorization = finite_polynomial.factor()
        degrees = sorted(
            (
                factor.degree()
                for factor, exponent in factorization
                for _ in range(exponent)
            ),
            reverse=True,
        )
        rows.append((
            str(prime),
            str(discriminant % prime),
            "true",
            ",".join(map(str, degrees)),
            ",".join(map(str, degrees)),
        ))

    return "\n".join([
        "# format\tm23_8a_fixed_field_frobenius_v1",
        f"# code_revision\t{code_revision}",
        f"# source\t{display_path(source)}",
        f"# source_sha256\t{sha256(source)}",
        f"# sage_version\t{SAGE_VERSION}",
        "# method\texact factorization of a monic irreducible polynomial at unramified primes",
        "# theorem\tDedekind-Frobenius cycle type from squarefree modular factorization",
        "# interpretation\tindependent cycle-type constraints on the degree-14 arithmetic Galois group",
        f"# polynomial_low_to_high\t{','.join(map(str, coefficients))}",
        "# polynomial_irreducible_over_Q\ttrue",
        f"# polynomial_discriminant\t{discriminant}",
        f"# polynomial_discriminant_factorization\t{factorization_text(abs(discriminant))}",
        "prime\tdiscriminant_mod_prime\tsquarefree\tfactor_degrees\tfrobenius_cycle_shape",
        *("\t".join(row) for row in rows),
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--code-revision")
    args = parser.parse_args()
    text = render(args.source, args.code_revision or git_revision())
    if args.output is None:
        print(text, end="")
    else:
        args.output.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
