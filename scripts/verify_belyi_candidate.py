#!/usr/bin/env python3
"""Verify exact ramification data for a rational function over a number field."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from fractions import Fraction
import json
from pathlib import Path
import re
import shutil
import subprocess
from typing import Any


TARGET = (
    (8, 8, 4, 2, 1),
    (8, 8, 4, 2, 1),
    (2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1),
)

SCHEMA_VERSION = "belyi-candidate-v1"
M23_8A_PROBLEM = "m23-8a-8a-2a-degree23"
M23_8A_SOURCE_SHA256 = "dc6089e7b9bcf9cb890e01306d286327266c0bf6ba7a7a8e48abb5ca52b3f3e8"
M23_RELATED_START_PROBLEM = "m23-4a-3a-8a-degree23-related-start"
M23_RELATED_START_TARGET = (
    (4, 4, 4, 4, 2, 2, 1, 1, 1),
    (3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 1),
    (8, 8, 4, 2, 1),
)
M23_RELATED_START_SOURCE_SHA256 = (
    "98dbfb414ea3ef869240794a3bdc8e76ac2c7761c7682ba6777a61b8ee34fb05"
)
RATIONAL_PATTERN = re.compile(r"^-?[0-9]+(?:/[1-9][0-9]*)?$")


Element = tuple[Fraction, ...]
Polynomial = list[Element]


def parse_fraction(value: Any) -> Fraction:
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise ValueError("rational values must be JSON integers or fraction strings")
    if isinstance(value, str) and RATIONAL_PATTERN.fullmatch(value) is None:
        raise ValueError(f"invalid rational string: {value}")
    return Fraction(value)


@dataclass(frozen=True)
class NumberField:
    """Power-basis arithmetic for Q or Q[t]/(a monic polynomial)."""

    modulus: tuple[Fraction, ...] | None = None

    def __post_init__(self) -> None:
        if self.modulus is not None:
            if len(self.modulus) < 2 or self.modulus[-1] != 1:
                raise ValueError("field polynomial must be monic and nonconstant")

    @property
    def degree(self) -> int:
        return 1 if self.modulus is None else len(self.modulus) - 1

    @property
    def zero(self) -> Element:
        return (Fraction(0),) * self.degree

    @property
    def one(self) -> Element:
        return (Fraction(1),) + (Fraction(0),) * (self.degree - 1)

    def parse(self, value: Any) -> Element:
        entries = value if isinstance(value, list) else [value]
        if len(entries) > self.degree:
            raise ValueError("coefficient exceeds the field power-basis degree")
        result = tuple(parse_fraction(entry) for entry in entries)
        return result + (Fraction(0),) * (self.degree - len(result))

    def add(self, left: Element, right: Element) -> Element:
        return tuple(a + b for a, b in zip(left, right, strict=True))

    def neg(self, value: Element) -> Element:
        return tuple(-entry for entry in value)

    def subtract(self, left: Element, right: Element) -> Element:
        return self.add(left, self.neg(right))

    def multiply(self, left: Element, right: Element) -> Element:
        if self.modulus is None:
            return (left[0] * right[0],)
        degree = self.degree
        product = [Fraction(0)] * (2 * degree - 1)
        for i, a in enumerate(left):
            for j, b in enumerate(right):
                product[i + j] += a * b
        for exponent in range(2 * degree - 2, degree - 1, -1):
            coefficient = product[exponent]
            if coefficient:
                for index in range(degree):
                    product[exponent - degree + index] -= coefficient * self.modulus[index]
        return tuple(product[:degree])

    def inverse(self, value: Element) -> Element:
        if value == self.zero:
            raise ZeroDivisionError("zero coefficient")
        if self.modulus is None:
            return (1 / value[0],)
        degree = self.degree
        columns = []
        for index in range(degree):
            basis = tuple(Fraction(i == index) for i in range(degree))
            columns.append(self.multiply(value, basis))
        matrix = [[columns[column][row] for column in range(degree)]
                  + [Fraction(row == 0)] for row in range(degree)]
        for column in range(degree):
            pivot = next((row for row in range(column, degree)
                          if matrix[row][column]), None)
            if pivot is None:
                raise ValueError("coefficient is not invertible; field polynomial may be reducible")
            matrix[column], matrix[pivot] = matrix[pivot], matrix[column]
            scale = matrix[column][column]
            matrix[column] = [entry / scale for entry in matrix[column]]
            for row in range(degree):
                if row == column:
                    continue
                scale = matrix[row][column]
                if scale:
                    matrix[row] = [a - scale * b
                                   for a, b in zip(matrix[row], matrix[column], strict=True)]
        return tuple(matrix[row][-1] for row in range(degree))


def _fraction_text(value: Fraction) -> str:
    return (str(value.numerator) if value.denominator == 1
            else f"({value.numerator}/{value.denominator})")


def verify_irreducible_with_gap(modulus: tuple[Fraction, ...],
                                gap_executable: str = "gap") -> str:
    """Ask GAP to prove that a monic rational polynomial is irreducible."""
    executable = shutil.which(gap_executable)
    if executable is None:
        raise ValueError(f"GAP executable not found: {gap_executable}")
    terms = []
    for exponent, coefficient in enumerate(modulus):
        if coefficient:
            terms.append(f"({_fraction_text(coefficient)})*x^{exponent}")
    expression = "+".join(terms) or "0"
    program = (
        'x:=Indeterminate(Rationals,"x");;\n'
        f"f:={expression};;\n"
        'Print("M23_IRREDUCIBLE=",IsIrreducibleRingElement(f),"\\n");\n'
        'Print("M23_GAP_VERSION=",GAPInfo.Version,"\\n");\n'
        'QUIT_GAP(0);\n'
    )
    try:
        completed = subprocess.run(
            [executable, "-q", "-b"], input=program, text=True,
            capture_output=True, timeout=30, check=False)
    except subprocess.TimeoutExpired as error:
        raise ValueError("GAP irreducibility check timed out") from error
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise ValueError(f"GAP irreducibility check failed: {detail}")
    lines = completed.stdout.splitlines()
    verdict = next((line.split("=", 1)[1] for line in lines
                    if line.startswith("M23_IRREDUCIBLE=")), None)
    version = next((line.split("=", 1)[1] for line in lines
                    if line.startswith("M23_GAP_VERSION=")), "unknown")
    if verdict is None:
        raise ValueError("GAP returned no irreducibility verdict")
    if verdict not in {"true", "false"}:
        raise ValueError(f"GAP returned a malformed irreducibility verdict: {verdict}")
    if verdict == "false":
        raise ValueError("field polynomial is reducible over Q")
    return version


def _require_mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object")
    return value


def normalize_record(record: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    """Normalize the versioned interchange format or the legacy flat format."""
    record = _require_mapping(record, "candidate")
    schema = record.get("schema_version")
    if schema is None:
        return record, {"schema_version": "legacy", "problem": "unspecified"}
    if schema != SCHEMA_VERSION:
        raise ValueError(f"unsupported schema_version: {schema}")

    problem = _require_mapping(record.get("problem"), "problem")
    problem_id = problem.get("id")
    partitions = problem.get("expected_partitions")
    if not isinstance(problem_id, str) or not problem_id:
        raise ValueError("problem.id must be a nonempty string")
    if not isinstance(partitions, list) or len(partitions) != 3:
        raise ValueError("problem.expected_partitions must contain three partitions")

    field_data = _require_mapping(record.get("field"), "field")
    defining_polynomial = field_data.get("defining_polynomial")
    generator = field_data.get("generator")
    if defining_polynomial is not None and (not isinstance(generator, str) or not generator):
        raise ValueError("field.generator is required for a number field")

    map_data = _require_mapping(record.get("map"), "map")
    provenance = _require_mapping(record.get("provenance"), "provenance")
    source = _require_mapping(provenance.get("source"), "provenance.source")
    producer = _require_mapping(provenance.get("producer"), "provenance.producer")
    if not isinstance(source.get("description"), str) or not source["description"]:
        raise ValueError("provenance.source.description must be nonempty")
    if not isinstance(producer.get("software"), str) or not producer["software"]:
        raise ValueError("provenance.producer.software must be nonempty")
    if not isinstance(producer.get("revision"), str) or not producer["revision"]:
        raise ValueError("provenance.producer.revision must be nonempty")

    if any(not isinstance(partition, list) for partition in partitions):
        raise ValueError("each expected partition must be an array")
    if any(isinstance(entry, bool) or not isinstance(entry, int) or entry < 1
           for partition in partitions for entry in partition):
        raise ValueError("partition entries must be positive JSON integers")
    expected = tuple(tuple(partition) for partition in partitions)
    if problem_id == M23_8A_PROBLEM:
        if expected != TARGET:
            raise ValueError("the M23 8A problem must use the committed target passport")
        class_id = source.get("class_id")
        if (isinstance(class_id, bool) or not isinstance(class_id, int) or
                not 1 <= class_id <= 28):
            raise ValueError("the M23 8A source class_id must be in 1..28")
        if source.get("dataset_sha256") != M23_8A_SOURCE_SHA256:
            raise ValueError("the M23 8A source dataset hash does not match the certificate")
    elif problem_id == M23_RELATED_START_PROBLEM:
        if expected != M23_RELATED_START_TARGET:
            raise ValueError(
                "the M23 related-start problem must use the committed source passport")
        class_id = source.get("class_id")
        if (isinstance(class_id, bool) or not isinstance(class_id, int) or
                not 1 <= class_id <= 54):
            raise ValueError("the M23 related-start source class_id must be in 1..54")
        if source.get("dataset_sha256") != M23_RELATED_START_SOURCE_SHA256:
            raise ValueError(
                "the M23 related-start dataset hash does not match the certificate")

    normalized = {
        "field_polynomial": defining_polynomial,
        "numerator": map_data["numerator"],
        "denominator": map_data["denominator"],
        "expected_partitions": partitions,
    }
    metadata = {
        "schema_version": schema,
        "problem": problem_id,
        "source": source,
        "producer": producer,
    }
    return normalized, metadata


def trim(field: NumberField, polynomial: Polynomial) -> Polynomial:
    result = polynomial[:]
    while len(result) > 1 and result[-1] == field.zero:
        result.pop()
    return result or [field.zero]


def poly_subtract(field: NumberField, left: Polynomial, right: Polynomial) -> Polynomial:
    result = [field.zero] * max(len(left), len(right))
    for index in range(len(result)):
        a = left[index] if index < len(left) else field.zero
        b = right[index] if index < len(right) else field.zero
        result[index] = field.subtract(a, b)
    return trim(field, result)


def poly_divide(field: NumberField, numerator: Polynomial,
                denominator: Polynomial) -> tuple[Polynomial, Polynomial]:
    numerator = trim(field, numerator)
    denominator = trim(field, denominator)
    if denominator == [field.zero]:
        raise ZeroDivisionError("zero polynomial")
    quotient = [field.zero] * max(1, len(numerator) - len(denominator) + 1)
    inverse = field.inverse(denominator[-1])
    while numerator != [field.zero] and len(numerator) >= len(denominator):
        shift = len(numerator) - len(denominator)
        coefficient = field.multiply(numerator[-1], inverse)
        quotient[shift] = coefficient
        for index, value in enumerate(denominator):
            location = index + shift
            numerator[location] = field.subtract(
                numerator[location], field.multiply(coefficient, value))
        numerator = trim(field, numerator)
    return trim(field, quotient), numerator


def poly_gcd(field: NumberField, left: Polynomial, right: Polynomial) -> Polynomial:
    left, right = trim(field, left), trim(field, right)
    while right != [field.zero]:
        _, remainder = poly_divide(field, left, right)
        left, right = right, remainder
    if left == [field.zero]:
        return left
    inverse = field.inverse(left[-1])
    return [field.multiply(coefficient, inverse) for coefficient in left]


def derivative(field: NumberField, polynomial: Polynomial) -> Polynomial:
    result = []
    for index in range(1, len(polynomial)):
        scalar = field.parse(index)
        result.append(field.multiply(scalar, polynomial[index]))
    return trim(field, result or [field.zero])


def exact_quotient(field: NumberField, numerator: Polynomial,
                   denominator: Polynomial) -> Polynomial:
    quotient, remainder = poly_divide(field, numerator, denominator)
    if remainder != [field.zero]:
        raise ValueError("internal nonexact polynomial quotient")
    return quotient


def multiplicity_partition(field: NumberField, polynomial: Polynomial,
                           total_degree: int) -> tuple[int, ...]:
    polynomial = trim(field, polynomial)
    if polynomial == [field.zero]:
        raise ValueError("a branch-fibre polynomial vanishes identically")
    finite_degree = len(polynomial) - 1
    repeated = poly_gcd(field, polynomial, derivative(field, polynomial))
    squarefree_part = exact_quotient(field, polynomial, repeated)
    partition: list[int] = []
    multiplicity = 1
    while len(squarefree_part) > 1:
        overlap = poly_gcd(field, squarefree_part, repeated)
        exact = exact_quotient(field, squarefree_part, overlap)
        partition.extend([multiplicity] * (len(exact) - 1))
        squarefree_part = overlap
        repeated = exact_quotient(field, repeated, overlap)
        multiplicity += 1
    if len(repeated) > 1:
        raise ValueError("squarefree decomposition did not terminate")
    infinity_multiplicity = total_degree - finite_degree
    if infinity_multiplicity < 0:
        raise ValueError("fibre degree exceeds map degree")
    if infinity_multiplicity:
        partition.append(infinity_multiplicity)
    return tuple(sorted(partition, reverse=True))


def verify_record(record: dict[str, Any], *, check_irreducibility: bool = True,
                  gap_executable: str = "gap") -> dict[str, Any]:
    normalized, metadata = normalize_record(record)
    field_data = normalized.get("field_polynomial")
    modulus = None if field_data is None else tuple(parse_fraction(entry) for entry in field_data)
    field = NumberField(modulus)
    gap_version = None
    if modulus is not None and check_irreducibility:
        gap_version = verify_irreducible_with_gap(modulus, gap_executable)
    numerator = trim(field, [field.parse(value) for value in normalized["numerator"]])
    denominator = trim(field, [field.parse(value) for value in normalized["denominator"]])
    if numerator == [field.zero] or denominator == [field.zero]:
        raise ValueError("numerator and denominator must be nonzero")
    common = poly_gcd(field, numerator, denominator)
    if len(common) != 1:
        raise ValueError("numerator and denominator are not coprime")
    degree = max(len(numerator), len(denominator)) - 1
    if degree <= 0:
        raise ValueError("map must have positive degree")
    fibres = (
        multiplicity_partition(field, numerator, degree),
        multiplicity_partition(field, poly_subtract(field, numerator, denominator), degree),
        multiplicity_partition(field, denominator, degree),
    )
    expected_data = normalized.get("expected_partitions", TARGET)
    expected = tuple(tuple(partition) for partition in expected_data)
    if fibres != expected:
        raise ValueError(f"ramification mismatch: got {fibres}, expected {expected}")
    ramification = sum(entry - 1 for partition in fibres for entry in partition)
    if ramification != 2 * degree - 2:
        raise ValueError("Riemann-Hurwitz check failed")
    field_verified = modulus is None or check_irreducibility
    result = {
        "degree": degree,
        "field_degree": field.degree,
        "field_irreducibility": ("rational" if modulus is None else
                                  "verified_by_gap" if check_irreducibility else
                                  "not_checked"),
        "partitions": [list(partition) for partition in fibres],
        "problem": metadata["problem"],
        "ramification_sum": ramification,
        "schema_version": metadata["schema_version"],
        "status": "verified" if field_verified else "diagnostic_field_unchecked",
        "scope": ("exact field and ramification only; monodromy is not certified"
                  if field_verified else
                  "ramification in an unchecked quotient ring; not an accepted candidate"),
    }
    if gap_version is not None:
        result["gap_version"] = gap_version
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--gap", default="gap",
                        help="GAP executable used to certify field irreducibility")
    parser.add_argument("--skip-irreducibility-check", action="store_true",
                        help="diagnostic only: do not accept this as a verified field")
    args = parser.parse_args()
    try:
        result = verify_record(
            json.loads(args.candidate.read_text()),
            check_irreducibility=not args.skip_irreducibility_check,
            gap_executable=args.gap)
    except (KeyError, TypeError, ValueError, ZeroDivisionError,
            json.JSONDecodeError, OSError) as error:
        raise SystemExit(f"verification failed: {error}") from error
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["status"] != "verified":
        raise SystemExit(3)


if __name__ == "__main__":
    main()
