#!/usr/bin/env python3
"""Analyze the reciprocal involution on the exact class-1 8A Belyi map."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess

from sage.all import identity_matrix, matrix, NumberField, PolynomialRing, QQ
from sage.env import SAGE_VERSION

from barth_wenz_preprocess import Permutation
from check_8a_cover_monodromy import gap_group, matching_classes


ROOT = Path(__file__).resolve().parents[1]
CLASS_LEDGER = ROOT / "data/derived/m23_8a_8a_2a_inner_classes.tsv"


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
    values = entries if isinstance(entries, list) else [entries]
    result = generator.parent()(0)
    for coefficient in reversed(values):
        result = result * generator + QQ(coefficient)
    return result


def apply_automorphism_to_rational_function(value, automorphism, ring):
    fraction = ring.fraction_field()(value)
    numerator = ring([automorphism(entry) for entry in fraction.numerator()])
    denominator = ring([
        automorphism(entry) for entry in fraction.denominator()
    ])
    return ring.fraction_field()(numerator) / denominator


def read_interval_permutations(path: Path):
    data_lines = [
        line for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("# ")
    ]
    rows = {
        row["loop"]: row
        for row in csv.DictReader(data_lines, delimiter="\t")
    }
    if set(rows) != {"zero", "one", "infinity"}:
        raise RuntimeError("interval artifact does not contain three loops")
    return {
        label: Permutation(tuple(
            int(value) - 1 for value in rows[label]["images"].split(",")
        ))
        for label in rows
    }


def canonical_element(value) -> list[str]:
    coefficients = list(value)
    coefficients.extend([QQ(0)] * (28 - len(coefficients)))
    return [str(coefficient) for coefficient in coefficients]


def matrix_hash(entries) -> str:
    serialized = json.dumps(
        [canonical_element(entry) for entry in entries],
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(serialized).hexdigest()


def relative_map_hash(numerator, denominator) -> str:
    def serialize(polynomial):
        return [
            [str(coefficient) for coefficient in value.list()]
            for value in polynomial
        ]

    encoded = json.dumps(
        {
            "numerator": serialize(numerator),
            "denominator": serialize(denominator),
        },
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def serialize_relative_polynomial(polynomial) -> list[list[str]]:
    return [
        [str(coefficient) for coefficient in value.list()]
        for value in polynomial
    ]


def ramification_partition(polynomial, cover_degree: int) -> list[int]:
    partition = []
    for factor, exponent in polynomial.factor():
        partition.extend([int(exponent)] * factor.degree())
    infinity_multiplicity = cover_degree - polynomial.degree()
    if infinity_multiplicity:
        partition.append(infinity_multiplicity)
    return sorted(partition, reverse=True)


def render(candidate_path: Path, monodromy_path: Path):
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    rational_ring = PolynomialRing(QQ, "T")
    coefficient_field = NumberField(
        rational_ring(candidate["field"]["defining_polynomial"]), "t"
    )
    generator = coefficient_field.gen()
    involution = coefficient_field.hom(
        [1 / generator], coefficient_field
    )
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
    conjugate_numerator = polynomial_ring([
        field_element(entry, 1 / generator)
        for entry in candidate["map"]["numerator"]
    ])
    conjugate_denominator = polynomial_ring([
        field_element(entry, 1 / generator)
        for entry in candidate["map"]["denominator"]
    ])
    fraction_field = polynomial_ring.fraction_field()
    belyi_map = fraction_field(numerator) / denominator
    conjugate_map = (
        fraction_field(conjugate_numerator) / conjugate_denominator
    )
    ordered_equal = (
        numerator * conjugate_denominator
        == conjugate_numerator * denominator
    )
    if ordered_equal:
        raise RuntimeError("reciprocal conjugate unexpectedly fixes the map")

    one_fibre = denominator - numerator
    distinguished = {
        exponent: -factor[0] / factor[1]
        for factor, exponent in one_fibre.factor()
        if factor.degree() == 1 and exponent in {1, 2, 4}
    }
    if set(distinguished) != {1, 2, 4}:
        raise RuntimeError("one-fibre distinguished points are incomplete")
    point_1 = distinguished[1]
    point_2 = distinguished[2]
    point_4 = distinguished[4]
    source_matrix_entries = (
        point_4 - point_2,
        -(point_4 - point_2) * point_1,
        point_4 - point_1,
        -(point_4 - point_1) * point_2,
    )
    source_mobius = (
        source_matrix_entries[0] * variable + source_matrix_entries[1]
    ) / (
        source_matrix_entries[2] * variable + source_matrix_entries[3]
    )
    if (
        source_mobius(x=point_1) != 0
        or source_mobius(x=point_4) != 1
    ):
        raise RuntimeError("source Möbius normalization failed")
    color_swap_equal = (
        conjugate_map(source_mobius) == 1 - belyi_map
    )
    if not color_swap_equal:
        raise RuntimeError("reciprocal color-swap identity failed")

    conjugate_mobius = apply_automorphism_to_rational_function(
        source_mobius, involution, polynomial_ring
    )
    cocycle_equal = (
        conjugate_mobius(source_mobius) == variable
    )
    if not cocycle_equal:
        raise RuntimeError("source Möbius cocycle identity failed")

    matrix_value = matrix(
        coefficient_field, 2, source_matrix_entries
    )
    conjugate_matrix = matrix(
        coefficient_field,
        2,
        [involution(entry) for entry in matrix_value.list()],
    )
    cocycle_product = conjugate_matrix * matrix_value
    if (
        cocycle_product[0, 1] != 0
        or cocycle_product[1, 0] != 0
        or cocycle_product[0, 0] != cocycle_product[1, 1]
    ):
        raise RuntimeError("Möbius matrix cocycle is not scalar")
    cocycle_scalar = cocycle_product[0, 0]
    if involution(cocycle_scalar) != cocycle_scalar:
        raise RuntimeError("Möbius cocycle scalar is not fixed")

    fixed_generator = generator + 1 / generator
    relative_field = coefficient_field.relativize(
        fixed_generator, "u"
    )
    to_absolute, from_absolute = relative_field.structure()
    fixed_field = relative_field.base_field()
    fixed_scalar = fixed_field(from_absolute(cocycle_scalar))
    is_norm, relative_norm_witness = fixed_scalar.is_norm(
        relative_field, element=True, proof=True
    )
    if not is_norm:
        raise RuntimeError("source PGL2 cocycle is a nonsplit twist")
    norm_witness = to_absolute(relative_norm_witness)
    normalized_matrix = matrix_value / norm_witness
    conjugate_normalized_matrix = matrix(
        coefficient_field,
        2,
        [involution(entry) for entry in normalized_matrix.list()],
    )
    if (
        conjugate_normalized_matrix * normalized_matrix
        != identity_matrix(coefficient_field, 2)
    ):
        raise RuntimeError("normalized GL2 cocycle identity failed")
    trivialization = (
        identity_matrix(coefficient_field, 2) + normalized_matrix
    )
    if trivialization.det() == 0:
        raise RuntimeError("Hilbert-90 trivialization is singular")
    conjugate_trivialization = matrix(
        coefficient_field,
        2,
        [involution(entry) for entry in trivialization.list()],
    )
    if (
        conjugate_trivialization * normalized_matrix
        != trivialization
    ):
        raise RuntimeError("Hilbert-90 trivialization identity failed")

    inverse_trivialization = trivialization.inverse()
    old_variable = (
        inverse_trivialization[0, 0] * variable
        + inverse_trivialization[0, 1]
    ) / (
        inverse_trivialization[1, 0] * variable
        + inverse_trivialization[1, 1]
    )
    anti_fixed_generator = generator - 1 / generator
    descended_map = fraction_field(
        anti_fixed_generator
        * (belyi_map(old_variable) - coefficient_field(1) / 2)
    )
    descended_numerator = descended_map.numerator()
    descended_denominator = descended_map.denominator()
    scale = descended_denominator.leading_coefficient()
    descended_numerator /= scale
    descended_denominator /= scale
    if not all(
        involution(entry) == entry
        for entry in (
            list(descended_numerator) + list(descended_denominator)
        )
    ):
        raise RuntimeError("descended map coefficients are not fixed")
    fixed_polynomial_ring = PolynomialRing(fixed_field, "X")
    fixed_numerator = fixed_polynomial_ring([
        fixed_field(from_absolute(entry))
        for entry in descended_numerator
    ])
    fixed_denominator = fixed_polynomial_ring([
        fixed_field(from_absolute(entry))
        for entry in descended_denominator
    ])
    if max(fixed_numerator.degree(), fixed_denominator.degree()) != 23:
        raise RuntimeError("descended map has the wrong degree")
    branch_quadratic_parameter = fixed_field(
        from_absolute(anti_fixed_generator**2)
    )
    if branch_quadratic_parameter != fixed_field.gen()**2 - 4:
        raise RuntimeError("unexpected descended branch parameter")
    expected_finite = [8, 8, 4, 2, 1]
    expected_infinity = [2] * 8 + [1] * 7
    negative_fibre = (
        descended_numerator
        + anti_fixed_generator / 2 * descended_denominator
    )
    positive_fibre = (
        descended_numerator
        - anti_fixed_generator / 2 * descended_denominator
    )
    if ramification_partition(negative_fibre, 23) != expected_finite:
        raise RuntimeError("negative descended fibre has wrong ramification")
    if ramification_partition(positive_fibre, 23) != expected_finite:
        raise RuntimeError("positive descended fibre has wrong ramification")
    if (
        ramification_partition(descended_denominator, 23)
        != expected_infinity
    ):
        raise RuntimeError("infinite descended fibre has wrong ramification")

    permutations = read_interval_permutations(monodromy_path)
    matches = matching_classes(
        permutations["one"], permutations["zero"]
    )
    if len(matches) != 1:
        raise RuntimeError(f"swapped monodromy class is ambiguous: {matches}")
    class_id, conjugator = matches[0]
    group_size, group_structure, centralizer_size = gap_group(
        permutations["one"], permutations["zero"]
    )
    if (
        group_size,
        group_structure,
        centralizer_size,
    ) != (10_200_960, "M23", 1):
        raise RuntimeError("swapped monodromy does not reproduce M23")

    metadata = [
        "# format\tm23_8a_reciprocal_descent_v2",
        f"# code_revision\t{git_revision()}",
        f"# candidate\t{display_path(candidate_path)}",
        f"# candidate_sha256\t{sha256(candidate_path)}",
        f"# monodromy\t{display_path(monodromy_path)}",
        f"# monodromy_sha256\t{sha256(monodromy_path)}",
        f"# class_ledger\t{display_path(CLASS_LEDGER)}",
        f"# class_ledger_sha256\t{sha256(CLASS_LEDGER)}",
        f"# sage_version\t{SAGE_VERSION}",
        "# coefficient_involution\tt->t^-1",
        "# target_mobius\tz->1-z",
        "# interpretation\texact reciprocal color-swap descent and split degree-14 cover",
    ]
    properties = [
        ("source_class_id", "1"),
        ("reciprocal_class_id", str(class_id)),
        ("ordered_belyi_equivalent", str(ordered_equal).lower()),
        ("color_swap_equivalent", str(color_swap_equal).lower()),
        ("source_mobius_maps_multiplicities", "1->1,4->4,2->2"),
        ("source_mobius_matrix_sha256",
         matrix_hash(source_matrix_entries)),
        ("source_mobius_cocycle", str(cocycle_equal).lower()),
        ("target_mobius_cocycle", "true"),
        ("source_cocycle_scalar_is_relative_norm",
         str(is_norm).lower()),
        ("hilbert90_source_trivialization", "true"),
        ("hilbert90_source_matrix_sha256",
         matrix_hash(trivialization.list())),
        ("target_twist_split", "true"),
        ("swapped_group_order", str(group_size)),
        ("swapped_group_structure", group_structure),
        ("swapped_group_centralizer_order", str(centralizer_size)),
        ("swapped_class_conjugator", ",".join(
            str(value + 1) for value in conjugator
        )),
        ("ordered_descent_to_fixed_field", "false"),
        ("color_swap_descent_datum", "true"),
        ("source_twist_split", "true"),
        ("descended_cover_degree", "23"),
        ("descended_coefficient_field_degree",
         str(fixed_field.degree())),
        ("descended_map_sha256",
         relative_map_hash(fixed_numerator, fixed_denominator)),
        ("descended_finite_branch_polynomial",
         "W^2-(y^2-4)/4"),
        ("descended_branch_points_individually_fixed", "false"),
    ]
    text = "\n".join([
        *metadata,
        "property\tvalue",
        *("\t".join(row) for row in properties),
        "",
    ])
    cover_record = {
        "schema_version": "descended-cover-v1",
        "field": {
            "defining_polynomial": [
                str(coefficient)
                for coefficient in fixed_field.defining_polynomial()
            ],
            "generator": str(fixed_field.gen()),
        },
        "map": {
            "numerator": serialize_relative_polynomial(fixed_numerator),
            "denominator": serialize_relative_polynomial(fixed_denominator),
        },
        "branch_locus": {
            "finite_quadratic_parameter": [
                str(coefficient)
                for coefficient in branch_quadratic_parameter.list()
            ],
            "finite_polynomial": "W^2-(y^2-4)/4",
            "infinity": "rational",
        },
        "ramification": {
            "negative_finite_root": expected_finite,
            "positive_finite_root": expected_finite,
            "infinity": expected_infinity,
        },
        "descent": {
            "coefficient_involution": "t->t^-1",
            "target_coordinate":
                "W=(t-t^-1)*(z-1/2)",
            "source_mobius_matrix_sha256":
                matrix_hash(source_matrix_entries),
            "hilbert90_source_matrix_sha256":
                matrix_hash(trivialization.list()),
        },
        "provenance": {
            "producer": {
                "revision": git_revision(),
                "software": f"SageMath {SAGE_VERSION}",
            },
            "source": {
                "candidate": display_path(candidate_path),
                "candidate_sha256": sha256(candidate_path),
                "monodromy": display_path(monodromy_path),
                "monodromy_sha256": sha256(monodromy_path),
            },
        },
        "interpretation":
            "degree-23 cover over the degree-14 fixed field; "
            "finite branch points form a quadratic pair",
    }
    return text, cover_record


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("monodromy", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--cover-output", type=Path)
    args = parser.parse_args()
    text, cover_record = render(args.candidate, args.monodromy)
    if args.output is None:
        print(text, end="")
    else:
        args.output.write_text(text, encoding="utf-8")
    if args.cover_output is not None:
        args.cover_output.write_text(
            json.dumps(cover_record, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
