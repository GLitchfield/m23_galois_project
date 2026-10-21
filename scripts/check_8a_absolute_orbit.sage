#!/usr/bin/env python3
"""Independently verify the exact 8A absolute-orbit certificate."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import re
import sys

from sage.all import NumberField, PolynomialRing, QQ
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]
REVISION = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def field_element(entries, generator):
    result = generator.parent()(0)
    for coefficient in reversed(entries):
        result = result * generator + QQ(coefficient)
    return result


def read_result(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    properties = {row["property"]: row["value"] for row in rows}
    if len(properties) != len(rows):
        raise RuntimeError("duplicate absolute-orbit properties")
    return metadata, properties


def check_source(metadata, path_key: str, hash_key: str) -> Path:
    if not SHA256.fullmatch(metadata.get(hash_key, "")):
        raise RuntimeError(f"invalid source hash: {hash_key}")
    source = (ROOT / metadata[path_key]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError(f"absolute-orbit source unavailable: {path_key}")
    if sha256(source) != metadata[hash_key]:
        raise RuntimeError(f"absolute-orbit source hash mismatch: {path_key}")
    return source


def squarefree_layers(polynomial) -> dict[int, object]:
    derivative_gcd = polynomial.gcd(polynomial.derivative()).monic()
    remaining = polynomial.quo_rem(derivative_gcd)[0].monic()
    layers = {}
    multiplicity = 1
    while remaining.degree() > 0:
        overlap = remaining.gcd(derivative_gcd).monic()
        layer = remaining.quo_rem(overlap)[0].monic()
        if layer.degree() > 0:
            layers[multiplicity] = layer
        remaining = overlap
        derivative_gcd = derivative_gcd.quo_rem(overlap)[0].monic()
        multiplicity += 1
    return layers


def parse_polynomial(text: str, ring):
    return ring([QQ(value) for value in text.split(",")])


def verify(path: Path) -> dict[str, int | bool]:
    metadata, properties = read_result(path)
    expected_metadata = {
        "format": "m23_8a_absolute_orbit_v1",
        "sage_version": SAGE_VERSION,
        "method": "canonical multiplicity-2 point invariant",
        "interpretation":
            "exact ordered and finite-branch-unlabelled Galois orbit degrees",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected absolute-orbit metadata: {key}")
    if not REVISION.fullmatch(metadata.get("code_revision", "")):
        raise RuntimeError("invalid absolute-orbit producer revision")
    candidate_path = check_source(
        metadata, "candidate", "candidate_sha256"
    )
    descended_path = check_source(
        metadata, "descended_cover", "descended_cover_sha256"
    )
    ledger_path = check_source(
        metadata, "class_ledger", "class_ledger_sha256"
    )

    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    rational_ring = PolynomialRing(QQ, "T")
    defining_polynomial = rational_ring(
        candidate["field"]["defining_polynomial"]
    )
    if (
        defining_polynomial.degree() != 28
        or not defining_polynomial.is_irreducible()
    ):
        raise RuntimeError("candidate field verification failed")
    coefficient_field = NumberField(defining_polynomial, "t")
    generator = coefficient_field.gen()
    involution = coefficient_field.hom(
        [1 / generator], coefficient_field
    )
    polynomial_ring = PolynomialRing(coefficient_field, "x")
    numerator = polynomial_ring([
        field_element(entry, generator)
        for entry in candidate["map"]["numerator"]
    ])
    denominator = polynomial_ring([
        field_element(entry, generator)
        for entry in candidate["map"]["denominator"]
    ])

    zero_layers = squarefree_layers(numerator)
    if (
        zero_layers[1] != polynomial_ring.gen()
        or zero_layers[4] != polynomial_ring.gen() - 1
        or 2 in zero_layers
        or 23 - numerator.degree() != 2
    ):
        raise RuntimeError("canonical zero-fibre normalization changed")
    one_layers = squarefree_layers(denominator - numerator)
    if any(
        one_layers.get(exponent) is None
        or one_layers[exponent].degree() != 1
        for exponent in (1, 2, 4)
    ):
        raise RuntimeError("opposite-fibre distinguished points changed")
    multiplicity_two = one_layers[2]
    ordered_invariant = -multiplicity_two[0] / multiplicity_two[1]
    unordered_invariant = ordered_invariant + involution(ordered_invariant)

    point_1 = -one_layers[1][0] / one_layers[1][1]
    point_4 = -one_layers[4][0] / one_layers[4][1]
    variable = polynomial_ring.gen()
    source_swap = (
        (variable - point_1) * (point_4 - ordered_invariant)
        / (
            (variable - ordered_invariant)
            * (point_4 - point_1)
        )
    )
    conjugate_numerator = polynomial_ring([
        involution(coefficient) for coefficient in numerator
    ])
    conjugate_denominator = polynomial_ring([
        involution(coefficient) for coefficient in denominator
    ])
    fraction_field = polynomial_ring.fraction_field()
    ordered_map = fraction_field(numerator) / denominator
    conjugate_map = (
        fraction_field(conjugate_numerator) / conjugate_denominator
    )
    if conjugate_map(source_swap) != 1 - ordered_map:
        raise RuntimeError("finite-branch swap identity changed")

    recorded_ordered = parse_polynomial(
        properties["ordered_invariant_minpoly"], rational_ring
    )
    recorded_unordered = parse_polynomial(
        properties["unordered_invariant_minpoly"], rational_ring
    )
    if rational_ring(ordered_invariant.minpoly()) != recorded_ordered:
        raise RuntimeError("ordered invariant minimal polynomial mismatch")
    if rational_ring(unordered_invariant.minpoly()) != recorded_unordered:
        raise RuntimeError("unordered invariant minimal polynomial mismatch")
    if (
        recorded_ordered.degree() != 28
        or recorded_unordered.degree() != 14
        or involution(unordered_invariant) != unordered_invariant
    ):
        raise RuntimeError("canonical invariant degrees changed")

    descended = json.loads(descended_path.read_text(encoding="utf-8"))
    fixed_polynomial = rational_ring(
        descended["field"]["defining_polynomial"]
    )
    if (
        descended.get("schema_version") != "descended-cover-v1"
        or fixed_polynomial.degree() != 14
        or not fixed_polynomial.is_irreducible()
        or rational_ring(
            (generator + 1 / generator).minpoly()
        ) != fixed_polynomial
    ):
        raise RuntimeError("descended fixed-field verification failed")

    ledger_lines = [
        line for line in ledger_path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("# ")
    ]
    ledger_rows = list(csv.DictReader(ledger_lines, delimiter="\t"))
    if (
        len(ledger_rows) != 28
        or [int(row["class_id"]) for row in ledger_rows]
        != list(range(1, 29))
    ):
        raise RuntimeError("ordered passport class count changed")

    expected_properties = {
        "ordered_source_normalization_unique": "true",
        "finite_branch_swap_verified": "true",
        "ordered_canonical_invariant": "opposite_fibre_e2_point",
        "ordered_invariant_minpoly":
            ",".join(str(value) for value in recorded_ordered),
        "ordered_invariant_degree": "28",
        "unordered_canonical_invariant":
            "sum_of_branch_choice_e2_points",
        "unordered_invariant_minpoly":
            ",".join(str(value) for value in recorded_unordered),
        "unordered_invariant_degree": "14",
        "reciprocal_fixed_field_degree": "14",
        "unordered_invariant_generates_fixed_field": "true",
        "ordered_field_of_moduli_degree": "28",
        "unordered_field_of_moduli_degree": "14",
        "ordered_absolute_galois_orbit_size": "28",
        "unordered_absolute_galois_orbit_size": "14",
        "ordered_passport_class_count": "28",
        "ordered_orbit_exhausts_passport": "true",
        "unordered_orbit_exhausts_branch_swap_pairs": "true",
        "q_defined_cover_in_this_passport": "false",
        "m23_over_q_realization_claimed": "false",
    }
    if properties != expected_properties:
        missing = set(expected_properties) - set(properties)
        extra = set(properties) - set(expected_properties)
        wrong = {
            key for key in set(properties) & set(expected_properties)
            if properties[key] != expected_properties[key]
        }
        raise RuntimeError(
            "absolute-orbit properties changed: "
            f"missing={missing}, extra={extra}, wrong={wrong}"
        )
    return {
        "ordered_orbit_size": 28,
        "unordered_orbit_size": 14,
        "exhausts_passport": True,
        "q_defined_cover": False,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} ABSOLUTE_ORBIT.tsv")
    result = verify(Path(sys.argv[1]))
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
