#!/usr/bin/env python3
"""Recover one bounded power-basis field model for the numerical 8A map."""

from __future__ import annotations

import argparse
import csv
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import subprocess

from sage.all import (
    ComplexField,
    NumberField,
    PolynomialRing,
    QQ,
    ZZ,
    pari,
    set_random_seed,
)
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]
COEFFICIENT_NAMES = (
    "alpha", "a0", "a1", "b0", "b1", "c4", "c2", "c1",
    *(f"u{index}" for index in range(8)),
    *(f"v{index}" for index in range(7)),
)
EXPECTED_PARTITIONS = (
    (8, 8, 4, 2, 1),
    (8, 8, 4, 2, 1),
    (2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1),
)
INNER_CLASS_LEDGER_SHA256 = (
    "dc6089e7b9bcf9cb890e01306d286327266c0bf6ba7a7a8e48abb5ca52b3f3e8"
)


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


def read_coefficients(path: Path) -> tuple[dict[str, str], dict[str, tuple[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    if metadata.get("format") != "m23_8a_belyi_high_precision_coefficients_v1":
        raise RuntimeError(f"unexpected coefficient format in {path}")
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    values = {
        row["name"]: (row["real"], row["imaginary"])
        for row in rows
    }
    if tuple(values) != COEFFICIENT_NAMES:
        raise RuntimeError(f"unexpected coefficient order in {path}")
    return metadata, values


def read_probe(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    if metadata.get("format") != "m23_8a_algebraic_recognition_probe_v1":
        raise RuntimeError("unexpected recognition-probe format")
    return metadata, list(csv.DictReader(data_lines, delimiter="\t"))


def canonical_relation(entries) -> tuple[int, ...]:
    relation = [ZZ(entry) for entry in entries]
    content = ZZ(0)
    for entry in relation:
        content = content.gcd(entry)
    if content:
        relation = [entry // content for entry in relation]
    last_nonzero = next((entry for entry in reversed(relation) if entry), ZZ(0))
    if last_nonzero < 0:
        relation = [-entry for entry in relation]
    return tuple(int(entry) for entry in relation)


def relation_hash(relation: tuple[int, ...]) -> str:
    payload = ",".join(str(entry) for entry in relation).encode("ascii")
    return hashlib.sha256(payload).hexdigest()


def relation_height_bits(relation: tuple[int, ...]) -> int:
    return max(abs(entry).bit_length() for entry in relation)


def normalized_relation_residual_bits(
    relation: tuple[int, ...],
    theta,
    value,
) -> float:
    real_field = abs(theta).parent()
    residual = theta.parent()(0)
    scale = real_field(0)
    power = theta.parent()(1)
    for coefficient in relation[:-1]:
        residual += coefficient * power
        scale += abs(coefficient) * abs(power)
        power *= theta
    residual += relation[-1] * value
    scale += abs(relation[-1]) * abs(value)
    if residual == 0:
        return math.inf
    ratio = abs(residual) / max(scale, real_field(1))
    return float(-ratio.log2())


def recover_relation(theta, value) -> tuple[int, ...]:
    powers = [theta.parent()(1)]
    for _ in range(1, 28):
        powers.append(powers[-1] * theta)
    return canonical_relation(pari([*powers, value]).lindep())


def relation_from_field_element(value, degree: int) -> tuple[int, ...]:
    coefficients = list(value.list())
    coefficients.extend([QQ(0)] * (degree - len(coefficients)))
    denominator = ZZ(1)
    for coefficient in coefficients:
        denominator = denominator.lcm(QQ(coefficient).denominator())
    relation = [
        -ZZ(QQ(coefficient) * denominator) for coefficient in coefficients
    ]
    relation.append(denominator)
    return canonical_relation(relation)


def evaluate_field_element(value, theta):
    result = theta.parent()(0)
    for coefficient in reversed(value.list()):
        result = result * theta + coefficient
    return result


def fraction_text(value) -> int | str:
    rational = QQ(value)
    if rational.denominator() == 1:
        return int(rational)
    return f"{rational.numerator()}/{rational.denominator()}"


def element_record(value, degree: int) -> list[int | str]:
    entries = list(value.list())
    entries.extend([QQ(0)] * (degree - len(entries)))
    while len(entries) > 1 and entries[-1] == 0:
        entries.pop()
    return [fraction_text(entry) for entry in entries]


def polynomial_record(polynomial, degree: int) -> list[list[int | str]]:
    return [element_record(coefficient, degree) for coefficient in polynomial.list()]


def build_exact_map(point: dict[str, object], normalization: tuple[int, int, int]):
    field = next(iter(point.values())).parent()
    polynomial_ring = PolynomialRing(field, "x")
    x = polynomial_ring.gen()
    a = x**2 + point["a1"] * x + point["a0"]
    b = x**2 + point["b1"] * x + point["b0"]
    numerator = (
        point["alpha"]
        * a**8
        * x**normalization[0]
        * (x - 1)**normalization[1]
    )
    fibre_one = (
        b**8
        * (x - point["c4"])**4
        * (x - point["c2"])**2
        * (x - point["c1"])
    )
    u = x**8 + sum(point[f"u{index}"] * x**index for index in range(8))
    v = x**7 + sum(point[f"v{index}"] * x**index for index in range(7))
    denominator = u**2 * v
    return numerator, fibre_one, denominator


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("training_source", type=Path)
    parser.add_argument("validation_source", type=Path)
    parser.add_argument("recognition_probe", type=Path)
    parser.add_argument("--generator", default="c2")
    parser.add_argument("--generator-height-bits", type=int, default=96)
    parser.add_argument("--training-bits", default="2048,3968")
    parser.add_argument("--maximum-coordinate-height-bits", type=int, default=128)
    parser.add_argument("--minimum-holdout-bits", type=int, default=512)
    parser.add_argument("--optimization-seed", type=int, default=20260723)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--candidate-output", type=Path)
    args = parser.parse_args()

    try:
        training_bits = [int(entry) for entry in args.training_bits.split(",")]
    except ValueError as error:
        parser.error("--training-bits must be a comma-separated integer list")
    if len(training_bits) < 2 or training_bits != sorted(set(training_bits)):
        parser.error("--training-bits must contain at least two increasing values")
    if args.maximum_coordinate_height_bits < 1:
        parser.error("--maximum-coordinate-height-bits must be positive")

    training_metadata, training_values = read_coefficients(args.training_source)
    validation_metadata, validation_values = read_coefficients(args.validation_source)
    probe_metadata, probe_rows = read_probe(args.recognition_probe)
    if probe_metadata["training_source_sha256"] != sha256(args.training_source):
        raise RuntimeError("probe training-source hash mismatch")
    if probe_metadata["validation_source_sha256"] != sha256(args.validation_source):
        raise RuntimeError("probe validation-source hash mismatch")
    if training_metadata["normalization"] != validation_metadata["normalization"]:
        raise RuntimeError("coefficient normalizations differ")
    if args.generator not in training_values:
        parser.error(f"unknown generator coefficient: {args.generator}")

    probe_training_bits = [
        int(entry) for entry in probe_metadata["training_bits"].split(",")
    ]
    generator_rows = [
        row for row in probe_rows
        if (
            row["name"] == args.generator
            and int(row["height_bound_bits"]) == args.generator_height_bits
            and int(row["training_bits"]) in probe_training_bits[-2:]
            and row["status"] == "found"
        )
    ]
    if len(generator_rows) != 2:
        raise RuntimeError("generator relation was not found at both top probe precisions")
    if len({row["polynomial_sha256"] for row in generator_rows}) != 1:
        raise RuntimeError("generator relation is not stable across probe precisions")
    polynomial_coefficients = tuple(
        int(entry)
        for entry in generator_rows[-1]["coefficients_low_to_high"].split(",")
    )
    if len(polynomial_coefficients) != 29:
        raise RuntimeError("generator polynomial does not have degree 28")

    recognized_polynomials: dict[str, tuple[int, ...]] = {}
    for name in COEFFICIENT_NAMES:
        by_height: dict[int, list[dict[str, str]]] = {}
        for row in probe_rows:
            if row["name"] != name or row["status"] != "found":
                continue
            if int(row["training_bits"]) not in probe_training_bits[-2:]:
                continue
            by_height.setdefault(int(row["height_bound_bits"]), []).append(row)
        for height in sorted(by_height):
            rows = by_height[height]
            if (
                len(rows) == 2
                and len({row["polynomial_sha256"] for row in rows}) == 1
                and float(rows[-1]["validation_residual_bits"]) >= (
                    probe_training_bits[-1]
                    + int(probe_metadata["minimum_holdout_bits"])
                )
            ):
                recognized_polynomials[name] = tuple(
                    int(entry)
                    for entry in rows[-1]["coefficients_low_to_high"].split(",")
                )
                break

    polynomial_ring = PolynomialRing(QQ, "T")
    T = polynomial_ring.gen()
    generator_polynomial = sum(
        QQ(coefficient) * T**index
        for index, coefficient in enumerate(polynomial_coefficients)
    )
    monic_polynomial = generator_polynomial / generator_polynomial.leading_coefficient()
    if not monic_polynomial.is_irreducible():
        raise RuntimeError("generator polynomial is reducible over Q")
    base_field = NumberField(monic_polynomial, "c2_base")
    set_random_seed(args.optimization_seed)
    field, from_field, _ = base_field.optimized_representation(name="t")
    t = field.gen()
    theta_in_base = from_field(t)
    field_polynomial = field.polynomial()

    validation_precision = int(validation_metadata["precision_bits"]) - 64
    validation_field = ComplexField(validation_precision)
    validation_base_generator = validation_field(*validation_values[args.generator])
    validation_theta = evaluate_field_element(
        theta_in_base, validation_base_generator
    )
    validation_points = {
        name: validation_field(*validation_values[name])
        for name in COEFFICIENT_NAMES
    }

    relation_by_name: dict[str, tuple[int, ...]] = {}
    row_records: list[dict[str, str]] = []
    for name in COEFFICIENT_NAMES:
        method = "lindep"
        stable = False
        if name in recognized_polynomials:
            method = "exact_field_isomorphism"
            coefficients = recognized_polynomials[name]
            polynomial = sum(
                QQ(coefficient) * T**index
                for index, coefficient in enumerate(coefficients)
            )
            polynomial /= polynomial.leading_coefficient()
            source_field = NumberField(polynomial, f"{name}_generator")
            embeddings = source_field.embeddings(field)
            if not embeddings:
                raise RuntimeError(
                    f"recognized field for {name} is not isomorphic to the generator field"
                )
            embedded = [embedding(source_field.gen()) for embedding in embeddings]
            embedded.sort(
                key=lambda candidate: abs(
                    evaluate_field_element(candidate, validation_theta)
                    - validation_points[name]
                )
            )
            relation = relation_from_field_element(embedded[0], field.degree())
            stable = True
        else:
            relations: list[tuple[int, ...]] = []
            for bits in training_bits:
                field_at_bits = ComplexField(bits)
                base_generator_at_bits = field_at_bits(
                    *training_values[args.generator]
                )
                theta_at_bits = evaluate_field_element(
                    theta_in_base, base_generator_at_bits
                )
                value_at_bits = field_at_bits(*training_values[name])
                relations.append(recover_relation(theta_at_bits, value_at_bits))
            stable = len(set(relations)) == 1
            relation = relations[-1]
        height = relation_height_bits(relation)
        residual_bits = normalized_relation_residual_bits(
            relation, validation_theta, validation_points[name]
        )
        accepted = (
            stable
            and relation[-1] != 0
            and (
                method == "exact_field_isomorphism"
                or height <= args.maximum_coordinate_height_bits
            )
            and residual_bits >= training_bits[-1] + args.minimum_holdout_bits
        )
        if accepted:
            relation_by_name[name] = relation
        row_records.append(
            {
                "name": name,
                "status": "accepted" if accepted else "rejected",
                "method": method,
                "stable_across_training_precisions": str(stable).lower(),
                "relation_height_bits": str(height),
                "relation_last_coefficient": str(relation[-1]),
                "relation_sha256": relation_hash(relation),
                "validation_residual_bits": (
                    "inf" if residual_bits == math.inf else f"{residual_bits:.6f}"
                ),
                "relation_coefficients": ",".join(str(entry) for entry in relation),
            }
        )

    exact_identity = False
    point: dict[str, object] = {}
    if len(relation_by_name) == len(COEFFICIENT_NAMES):
        for name, relation in relation_by_name.items():
            point[name] = sum(
                -QQ(relation[index]) / QQ(relation[-1]) * t**index
                for index in range(28)
            )
        normalization = tuple(
            int(entry) for entry in training_metadata["normalization"].split(",")
        )
        numerator, fibre_one, denominator = build_exact_map(point, normalization)
        exact_identity = numerator + fibre_one == denominator
    else:
        numerator = fibre_one = denominator = None

    metadata_lines = [
        "# format\tm23_8a_number_field_recovery_v1",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# training_source\t{display_path(args.training_source)}",
        f"# training_source_sha256\t{sha256(args.training_source)}",
        f"# validation_source\t{display_path(args.validation_source)}",
        f"# validation_source_sha256\t{sha256(args.validation_source)}",
        f"# recognition_probe\t{display_path(args.recognition_probe)}",
        f"# recognition_probe_sha256\t{sha256(args.recognition_probe)}",
        f"# normalization\t{training_metadata['normalization']}",
        f"# generator\t{args.generator}",
        f"# generator_polynomial_sha256\t{generator_rows[-1]['polynomial_sha256']}",
        f"# base_generator_degree\t{monic_polynomial.degree()}",
        f"# generator_polynomial_low_to_high\t{','.join(str(entry) for entry in polynomial_coefficients)}",
        f"# optimization_seed\t{args.optimization_seed}",
        f"# optimized_generator_degree\t{field_polynomial.degree()}",
        f"# optimized_generator_polynomial_low_to_high\t{','.join(str(entry) for entry in field_polynomial.list())}",
        f"# training_bits\t{','.join(map(str, training_bits))}",
        f"# maximum_coordinate_height_bits\t{args.maximum_coordinate_height_bits}",
        f"# minimum_holdout_bits\t{args.minimum_holdout_bits}",
        f"# accepted_coordinate_count\t{len(relation_by_name)}",
        f"# exact_coefficient_identity\t{str(exact_identity).lower()}",
        "# interpretation\tbounded common-field recovery; exact map requires all coordinates, exact identity, and independent ramification verification",
    ]
    fieldnames = [
        "name",
        "status",
        "method",
        "stable_across_training_precisions",
        "relation_height_bits",
        "relation_last_coefficient",
        "relation_sha256",
        "validation_residual_bits",
        "relation_coefficients",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        handle.write("\n".join(metadata_lines) + "\n")
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(row_records)

    print(
        f"recovered {len(relation_by_name)}/{len(COEFFICIENT_NAMES)} coordinates "
        f"in a degree-{field_polynomial.degree()} field; "
        f"exact_identity={str(exact_identity).lower()}"
    )

    if args.candidate_output:
        if not exact_identity:
            raise RuntimeError("refusing to write candidate without exact identity")
        degree = field.degree()
        candidate = {
            "schema_version": "belyi-candidate-v1",
            "problem": {
                "id": "m23-8a-8a-2a-degree23",
                "expected_partitions": [list(partition) for partition in EXPECTED_PARTITIONS],
            },
            "field": {
                "generator": "t",
                "defining_polynomial": [
                    fraction_text(coefficient)
                    for coefficient in field_polynomial.list()
                ],
            },
            "map": {
                "numerator": polynomial_record(numerator, degree),
                "denominator": polynomial_record(denominator, degree),
            },
            "provenance": {
                "source": {
                    "description": (
                        "bounded common-field recovery from the certified "
                        "class-1 domain-2 numerical endpoint"
                    ),
                    "class_id": 1,
                    "dataset_sha256": INNER_CLASS_LEDGER_SHA256,
                },
                "producer": {
                    "software": f"SageMath {SAGE_VERSION}",
                    "revision": git_revision(),
                },
            },
        }
        args.candidate_output.parent.mkdir(parents=True, exist_ok=True)
        args.candidate_output.write_text(
            json.dumps(candidate, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(f"wrote exact candidate to {args.candidate_output}")


if __name__ == "__main__":
    main()
