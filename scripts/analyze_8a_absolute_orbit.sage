#!/usr/bin/env python3
"""Certify the absolute Galois orbit of the exact 8A cover without Magma."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess

from sage.all import NumberField, PolynomialRing, QQ
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


def field_element(entries, generator):
    result = generator.parent()(0)
    for coefficient in reversed(entries):
        result = result * generator + QQ(coefficient)
    return result


def apply_automorphism(polynomial, automorphism, ring):
    return ring([automorphism(coefficient) for coefficient in polynomial])


def linear_root(factor):
    if factor.degree() != 1:
        raise RuntimeError("expected a linear distinguished factor")
    return -factor[0] / factor[1]


def distinguished_affine_points(polynomial) -> dict[int, object]:
    points = {}
    for factor, exponent in polynomial.factor():
        exponent = int(exponent)
        if exponent in {1, 2, 4}:
            if factor.degree() != 1 or exponent in points:
                raise RuntimeError(
                    "distinguished affine ramification is not unique"
                )
            points[exponent] = linear_root(factor)
    return points


def serialize_polynomial(polynomial) -> str:
    return ",".join(str(coefficient) for coefficient in polynomial)


def ledger_size(path: Path) -> int:
    lines = [
        line for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("# ")
    ]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    class_ids = [int(row["class_id"]) for row in rows]
    if class_ids != list(range(1, len(rows) + 1)):
        raise RuntimeError("class ledger IDs are not contiguous")
    return len(rows)


def render(candidate_path: Path, descended_path: Path, ledger_path: Path) -> str:
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    descended = json.loads(descended_path.read_text(encoding="utf-8"))

    rational_ring = PolynomialRing(QQ, "T")
    defining_polynomial = rational_ring(
        candidate["field"]["defining_polynomial"]
    )
    if (
        defining_polynomial.degree() != 28
        or not defining_polynomial.is_irreducible()
    ):
        raise RuntimeError("ordered coefficient field is not degree 28")
    coefficient_field = NumberField(defining_polynomial, "t")
    generator = coefficient_field.gen()
    involution = coefficient_field.hom(
        [1 / generator], coefficient_field
    )
    if involution(involution(generator)) != generator:
        raise RuntimeError("reciprocal map is not an involution")

    polynomial_ring = PolynomialRing(coefficient_field, "x")
    variable = polynomial_ring.gen()
    numerator = polynomial_ring([
        field_element(entry, generator)
        for entry in candidate["map"]["numerator"]
    ])
    denominator = polynomial_ring([
        field_element(entry, generator)
        for entry in candidate["map"]["denominator"]
    ])
    if denominator.leading_coefficient() != 1:
        raise RuntimeError("ordered map denominator is not monic")
    if max(numerator.degree(), denominator.degree()) != 23:
        raise RuntimeError("ordered map does not have degree 23")

    zero_points = distinguished_affine_points(numerator)
    if (
        set(zero_points) != {1, 4}
        or zero_points[1] != 0
        or zero_points[4] != 1
        or 23 - numerator.degree() != 2
    ):
        raise RuntimeError("ordered source normalization is not canonical")

    one_fibre = denominator - numerator
    one_points = distinguished_affine_points(one_fibre)
    if set(one_points) != {1, 2, 4}:
        raise RuntimeError("opposite finite fibre is missing canonical points")
    point_1 = one_points[1]
    point_2 = one_points[2]
    point_4 = one_points[4]

    source_mobius = (
        (variable - point_1) * (point_4 - point_2)
        / ((variable - point_2) * (point_4 - point_1))
    )
    fraction_field = polynomial_ring.fraction_field()
    ordered_map = fraction_field(numerator) / denominator
    conjugate_numerator = apply_automorphism(
        numerator, involution, polynomial_ring
    )
    conjugate_denominator = apply_automorphism(
        denominator, involution, polynomial_ring
    )
    conjugate_map = (
        fraction_field(conjugate_numerator) / conjugate_denominator
    )
    if conjugate_map(source_mobius) != 1 - ordered_map:
        raise RuntimeError("reciprocal map is not the branch-swapped normal form")

    conjugate_one_points = distinguished_affine_points(
        conjugate_denominator - conjugate_numerator
    )
    if conjugate_one_points[2] != involution(point_2):
        raise RuntimeError("conjugate multiplicity-2 invariant changed")

    ordered_invariant = point_2
    unordered_invariant = point_2 + involution(point_2)
    if involution(unordered_invariant) != unordered_invariant:
        raise RuntimeError("unordered invariant is not reciprocal-fixed")
    ordered_minpoly = ordered_invariant.minpoly()
    unordered_minpoly = unordered_invariant.minpoly()
    if ordered_minpoly.degree() != 28:
        raise RuntimeError("ordered canonical invariant is not primitive")
    if unordered_minpoly.degree() != 14:
        raise RuntimeError("unordered canonical invariant is not degree 14")

    fixed_generator = generator + 1 / generator
    fixed_minpoly = rational_ring(fixed_generator.minpoly())
    if fixed_minpoly.degree() != 14:
        raise RuntimeError("reciprocal fixed field is not degree 14")
    descended_polynomial = rational_ring(
        descended["field"]["defining_polynomial"]
    )
    if (
        descended.get("schema_version") != "descended-cover-v1"
        or descended_polynomial != fixed_minpoly
        or not descended_polynomial.is_irreducible()
    ):
        raise RuntimeError("descended cover is not defined over the fixed field")

    passport_size = ledger_size(ledger_path)
    if passport_size != 28:
        raise RuntimeError("ordered passport ledger does not have 28 classes")

    metadata = [
        "# format\tm23_8a_absolute_orbit_v1",
        f"# code_revision\t{git_revision()}",
        f"# candidate\t{display_path(candidate_path)}",
        f"# candidate_sha256\t{sha256(candidate_path)}",
        f"# descended_cover\t{display_path(descended_path)}",
        f"# descended_cover_sha256\t{sha256(descended_path)}",
        f"# class_ledger\t{display_path(ledger_path)}",
        f"# class_ledger_sha256\t{sha256(ledger_path)}",
        f"# sage_version\t{SAGE_VERSION}",
        "# method\tcanonical multiplicity-2 point invariant",
        "# interpretation\texact ordered and finite-branch-unlabelled Galois orbit degrees",
    ]
    properties = [
        ("ordered_source_normalization_unique", "true"),
        ("finite_branch_swap_verified", "true"),
        ("ordered_canonical_invariant", "opposite_fibre_e2_point"),
        ("ordered_invariant_minpoly",
         serialize_polynomial(ordered_minpoly)),
        ("ordered_invariant_degree", str(ordered_minpoly.degree())),
        ("unordered_canonical_invariant",
         "sum_of_branch_choice_e2_points"),
        ("unordered_invariant_minpoly",
         serialize_polynomial(unordered_minpoly)),
        ("unordered_invariant_degree", str(unordered_minpoly.degree())),
        ("reciprocal_fixed_field_degree", str(fixed_minpoly.degree())),
        ("unordered_invariant_generates_fixed_field", "true"),
        ("ordered_field_of_moduli_degree", "28"),
        ("unordered_field_of_moduli_degree", "14"),
        ("ordered_absolute_galois_orbit_size", "28"),
        ("unordered_absolute_galois_orbit_size", "14"),
        ("ordered_passport_class_count", str(passport_size)),
        ("ordered_orbit_exhausts_passport", "true"),
        ("unordered_orbit_exhausts_branch_swap_pairs", "true"),
        ("q_defined_cover_in_this_passport", "false"),
        ("m23_over_q_realization_claimed", "false"),
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
    parser.add_argument("descended_cover", type=Path)
    parser.add_argument("class_ledger", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    text = render(
        args.candidate,
        args.descended_cover,
        args.class_ledger,
    )
    if args.output is None:
        print(text, end="")
    else:
        args.output.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
