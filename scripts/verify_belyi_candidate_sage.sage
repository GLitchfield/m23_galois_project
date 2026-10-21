#!/usr/bin/env python3
"""Verify an exact Belyi candidate with Sage number-field arithmetic."""

from __future__ import annotations

import argparse
from fractions import Fraction
import json
from pathlib import Path
import sys

from sage.all import NumberField, PolynomialRing, QQ
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from verify_belyi_candidate import (  # noqa: E402
    normalize_record,
    verify_irreducible_with_gap,
)


def rational(value):
    return QQ(Fraction(value))


def parse_element(field, value):
    entries = value if isinstance(value, list) else [value]
    if len(entries) > field.degree():
        raise ValueError("coefficient exceeds the field power-basis degree")
    return sum(rational(entry) * field.gen() ** index
               for index, entry in enumerate(entries))


def multiplicity_partition(polynomial, total_degree: int) -> tuple[int, ...]:
    finite_degree = polynomial.degree()
    repeated = polynomial.gcd(polynomial.derivative())
    squarefree_part = polynomial // repeated
    partition: list[int] = []
    multiplicity = 1
    while squarefree_part.degree() > 0:
        overlap = squarefree_part.gcd(repeated)
        exact = squarefree_part // overlap
        partition.extend([multiplicity] * exact.degree())
        squarefree_part = overlap
        repeated //= overlap
        multiplicity += 1
    if repeated.degree() > 0:
        raise ValueError("squarefree decomposition did not terminate")
    infinity_multiplicity = total_degree - finite_degree
    if infinity_multiplicity < 0:
        raise ValueError("fibre degree exceeds map degree")
    if infinity_multiplicity:
        partition.append(infinity_multiplicity)
    return tuple(sorted(partition, reverse=True))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--gap", default="gap")
    args = parser.parse_args()

    record = json.loads(args.candidate.read_text(encoding="utf-8"))
    normalized, metadata = normalize_record(record)
    defining_polynomial = normalized["field_polynomial"]
    if defining_polynomial is None:
        raise ValueError("this verifier requires a nontrivial number field")
    modulus = tuple(Fraction(entry) for entry in defining_polynomial)
    gap_version = verify_irreducible_with_gap(modulus, args.gap)

    rational_polynomial_ring = PolynomialRing(QQ, "T")
    T = rational_polynomial_ring.gen()
    polynomial = sum(
        rational(coefficient) * T**index
        for index, coefficient in enumerate(defining_polynomial)
    )
    field = NumberField(polynomial, "t")
    polynomial_ring = PolynomialRing(field, "x")
    x = polynomial_ring.gen()

    numerator = polynomial_ring([
        parse_element(field, coefficient)
        for coefficient in normalized["numerator"]
    ])
    denominator = polynomial_ring([
        parse_element(field, coefficient)
        for coefficient in normalized["denominator"]
    ])
    if numerator == 0 or denominator == 0:
        raise ValueError("numerator and denominator must be nonzero")
    if numerator.gcd(denominator).degree() != 0:
        raise ValueError("numerator and denominator are not coprime")

    degree = max(numerator.degree(), denominator.degree())
    fibres = (
        multiplicity_partition(numerator, degree),
        multiplicity_partition(numerator - denominator, degree),
        multiplicity_partition(denominator, degree),
    )
    expected = tuple(
        tuple(partition) for partition in normalized["expected_partitions"]
    )
    if fibres != expected:
        raise ValueError(f"ramification mismatch: got {fibres}, expected {expected}")
    ramification = sum(entry - 1 for fibre in fibres for entry in fibre)
    if ramification != 2 * degree - 2:
        raise ValueError("Riemann-Hurwitz check failed")

    result = {
        "degree": int(degree),
        "field_degree": int(field.degree()),
        "field_irreducibility": "verified_by_gap",
        "gap_version": gap_version,
        "partitions": [
            [int(entry) for entry in partition] for partition in fibres
        ],
        "problem": metadata["problem"],
        "ramification_sum": int(ramification),
        "sage_version": SAGE_VERSION,
        "schema_version": metadata["schema_version"],
        "status": "verified",
        "scope": "exact field and ramification only; monodromy is not certified",
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
