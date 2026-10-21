#!/usr/bin/env python3
"""Independently verify the exact degree-14 descended 8A cover."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

from sage.all import NumberField, PolynomialRing, QQ
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_FINITE = [8, 8, 4, 2, 1]
EXPECTED_INFINITY = [2] * 8 + [1] * 7


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def field_element(entries, generator):
    result = generator.parent()(0)
    for coefficient in reversed(entries):
        result = result * generator + QQ(coefficient)
    return result


def ramification_partition(polynomial, cover_degree: int) -> list[int]:
    partition = []
    for factor, exponent in polynomial.factor():
        partition.extend([int(exponent)] * factor.degree())
    infinity_multiplicity = cover_degree - polynomial.degree()
    if infinity_multiplicity:
        partition.append(infinity_multiplicity)
    return sorted(partition, reverse=True)


def verify(path: Path) -> dict[str, object]:
    record = json.loads(path.read_text(encoding="utf-8"))
    if record.get("schema_version") != "descended-cover-v1":
        raise RuntimeError("unexpected descended-cover schema")
    rational_ring = PolynomialRing(QQ, "Y")
    defining_polynomial = rational_ring(
        record["field"]["defining_polynomial"]
    )
    if (
        defining_polynomial.degree() != 14
        or not defining_polynomial.is_irreducible()
    ):
        raise RuntimeError("descended coefficient field is not degree 14")
    coefficient_field = NumberField(defining_polynomial, "y")
    generator = coefficient_field.gen()
    polynomial_ring = PolynomialRing(coefficient_field, "X")
    numerator = polynomial_ring([
        field_element(entry, generator)
        for entry in record["map"]["numerator"]
    ])
    denominator = polynomial_ring([
        field_element(entry, generator)
        for entry in record["map"]["denominator"]
    ])
    if max(numerator.degree(), denominator.degree()) != 23:
        raise RuntimeError("descended cover does not have degree 23")
    if numerator.gcd(denominator).degree() != 0:
        raise RuntimeError("descended rational function is not reduced")

    branch_parameter = field_element(
        record["branch_locus"]["finite_quadratic_parameter"],
        generator,
    )
    if branch_parameter != generator**2 - 4:
        raise RuntimeError("unexpected finite branch parameter")
    extension_ring = PolynomialRing(coefficient_field, "S")
    extension_polynomial = extension_ring.gen()**2 - branch_parameter
    if not extension_polynomial.is_irreducible():
        raise RuntimeError("finite branch pair unexpectedly splits")
    splitting_field = coefficient_field.extension(
        extension_polynomial, "s"
    )
    square_root = splitting_field.gen()
    split_ring = PolynomialRing(splitting_field, "X")
    split_numerator = split_ring(numerator)
    split_denominator = split_ring(denominator)
    negative_fibre = (
        split_numerator + square_root / 2 * split_denominator
    )
    positive_fibre = (
        split_numerator - square_root / 2 * split_denominator
    )
    partitions = {
        "negative_finite_root":
            ramification_partition(negative_fibre, 23),
        "positive_finite_root":
            ramification_partition(positive_fibre, 23),
        "infinity": ramification_partition(split_denominator, 23),
    }
    if partitions["negative_finite_root"] != EXPECTED_FINITE:
        raise RuntimeError("negative finite fibre ramification mismatch")
    if partitions["positive_finite_root"] != EXPECTED_FINITE:
        raise RuntimeError("positive finite fibre ramification mismatch")
    if partitions["infinity"] != EXPECTED_INFINITY:
        raise RuntimeError("infinite fibre ramification mismatch")
    if partitions != record["ramification"]:
        raise RuntimeError("recorded descended ramification changed")
    riemann_hurwitz = sum(
        sum(multiplicity - 1 for multiplicity in partition)
        for partition in partitions.values()
    )
    if riemann_hurwitz != 44:
        raise RuntimeError("descended Riemann--Hurwitz sum mismatch")

    source = record["provenance"]["source"]
    for path_key, hash_key in (
        ("candidate", "candidate_sha256"),
        ("monodromy", "monodromy_sha256"),
    ):
        source_path = (ROOT / source[path_key]).resolve()
        if not source_path.is_relative_to(ROOT) or not source_path.is_file():
            raise RuntimeError(f"descended source unavailable: {path_key}")
        if sha256(source_path) != source[hash_key]:
            raise RuntimeError(f"descended source hash mismatch: {path_key}")
    if record["provenance"]["producer"]["software"] != (
        f"SageMath {SAGE_VERSION}"
    ):
        raise RuntimeError("descended producer version mismatch")
    return {
        "field_degree": int(coefficient_field.degree()),
        "cover_degree": 23,
        "riemann_hurwitz": int(riemann_hurwitz),
        "finite_branch_polynomial_irreducible": True,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} DESCENDED_COVER.json")
    result = verify(Path(sys.argv[1]))
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
