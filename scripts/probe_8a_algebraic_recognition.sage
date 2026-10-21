#!/usr/bin/env python3
"""Run a bounded, holdout-validated algebraic-dependency probe."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
from pathlib import Path
import subprocess

from sage.all import ComplexField, ZZ, algdep
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
    if not values:
        raise RuntimeError(f"no coefficients in {path}")
    return metadata, values


def parse_positive_list(text: str, label: str) -> list[int]:
    try:
        values = [int(entry) for entry in text.split(",")]
    except ValueError as error:
        raise ValueError(f"{label} must be a comma-separated integer list") from error
    if not values or any(value <= 0 for value in values):
        raise ValueError(f"{label} entries must be positive")
    if values != sorted(set(values)):
        raise ValueError(f"{label} entries must be strictly increasing")
    return values


def canonical_coefficients(polynomial) -> tuple[int, ...]:
    coefficients = [ZZ(entry) for entry in polynomial.list()]
    while len(coefficients) > 1 and coefficients[-1] == 0:
        coefficients.pop()
    content = ZZ(0)
    for coefficient in coefficients:
        content = content.gcd(coefficient)
    if content:
        coefficients = [coefficient // content for coefficient in coefficients]
    if coefficients[-1] < 0:
        coefficients = [-coefficient for coefficient in coefficients]
    return tuple(int(coefficient) for coefficient in coefficients)


def polynomial_hash(coefficients: tuple[int, ...]) -> str:
    payload = ",".join(str(entry) for entry in coefficients).encode("ascii")
    return hashlib.sha256(payload).hexdigest()


def normalized_residual_bits(coefficients: tuple[int, ...], value) -> float:
    residual = value.parent()(0)
    real_field = abs(value).parent()
    scale = real_field(0)
    absolute_value = abs(value)
    power = real_field(1)
    for coefficient in reversed(coefficients):
        residual = residual * value + coefficient
    for coefficient in coefficients:
        scale += abs(coefficient) * power
        power *= absolute_value
    if residual == 0:
        return math.inf
    ratio = abs(residual) / max(scale, real_field(1))
    return float(-ratio.log2())


def agreement_bits(left, right) -> float:
    denominator = max(abs(right), abs(right).parent()(1))
    relative = abs(left - right) / denominator
    if relative == 0:
        return math.inf
    return float(-relative.log2())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("training_source", type=Path)
    parser.add_argument("validation_source", type=Path)
    parser.add_argument("--max-degree", type=int, default=28)
    parser.add_argument(
        "--training-bits",
        default="512,1024,2048,3968",
        help="strictly increasing precision levels",
    )
    parser.add_argument(
        "--height-bits",
        default="16,32,64,96,128",
        help="strictly increasing coefficient-height bounds",
    )
    parser.add_argument(
        "--minimum-holdout-bits",
        type=int,
        default=512,
        help="validation residual bits required beyond the largest training precision",
    )
    parser.add_argument(
        "--names",
        help="optional comma-separated coefficient names; default is every coefficient",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    if args.max_degree < 1:
        parser.error("--max-degree must be positive")
    if args.minimum_holdout_bits < 1:
        parser.error("--minimum-holdout-bits must be positive")
    try:
        training_bits = parse_positive_list(args.training_bits, "--training-bits")
        height_bits = parse_positive_list(args.height_bits, "--height-bits")
    except ValueError as error:
        parser.error(str(error))

    training_metadata, training_values = read_coefficients(args.training_source)
    validation_metadata, validation_values = read_coefficients(args.validation_source)
    if set(training_values) != set(validation_values):
        raise RuntimeError("training and validation coefficient names differ")
    if training_metadata.get("normalization") != validation_metadata.get("normalization"):
        raise RuntimeError("training and validation normalizations differ")

    training_precision = int(training_metadata["precision_bits"])
    validation_precision = int(validation_metadata["precision_bits"])
    if training_bits[-1] > training_precision - 64:
        raise RuntimeError("largest training precision exceeds the stored-digit safety margin")
    if validation_precision <= training_precision:
        raise RuntimeError("validation source must have higher precision than training source")

    if args.names:
        names = args.names.split(",")
        unknown = sorted(set(names) - set(training_values))
        if unknown:
            parser.error(f"unknown coefficient names: {','.join(unknown)}")
    else:
        names = list(training_values)

    validation_field = ComplexField(validation_precision - 64)
    validation_points = {
        name: validation_field(*validation_values[name])
        for name in names
    }
    training_at_validation = {
        name: validation_field(*training_values[name])
        for name in names
    }
    agreements = {
        name: agreement_bits(training_at_validation[name], validation_points[name])
        for name in names
    }

    rows: list[dict[str, str]] = []
    candidates: dict[tuple[str, int], dict[int, tuple[str, float]]] = {}
    for name in names:
        for bits in training_bits:
            field = ComplexField(bits)
            value = field(*training_values[name])
            for height in height_bits:
                status = "not_found"
                coefficients: tuple[int, ...] = ()
                detail = ""
                try:
                    polynomial = algdep(
                        value,
                        args.max_degree,
                        known_bits=bits - 32,
                        height_bound=ZZ(2) ** height,
                        proof=True,
                    )
                    if polynomial is not None:
                        coefficients = canonical_coefficients(polynomial)
                        status = "found"
                except ValueError as error:
                    status = "insufficient_precision"
                    detail = " ".join(str(error).split())

                if coefficients:
                    digest = polynomial_hash(coefficients)
                    residual_bits = normalized_residual_bits(
                        coefficients, validation_points[name]
                    )
                    coefficient_height_bits = max(
                        abs(entry).bit_length() for entry in coefficients
                    )
                    candidates.setdefault((name, height), {})[bits] = (
                        digest,
                        residual_bits,
                    )
                else:
                    digest = ""
                    residual_bits = math.nan
                    coefficient_height_bits = 0
                rows.append(
                    {
                        "name": name,
                        "training_bits": str(bits),
                        "height_bound_bits": str(height),
                        "status": status,
                        "returned_degree": (
                            str(len(coefficients) - 1) if coefficients else ""
                        ),
                        "coefficient_height_bits": (
                            str(coefficient_height_bits) if coefficients else ""
                        ),
                        "polynomial_sha256": digest,
                        "validation_residual_bits": (
                            f"{residual_bits:.6f}" if math.isfinite(residual_bits)
                            else ("inf" if residual_bits == math.inf else "")
                        ),
                        "coefficients_low_to_high": (
                            ",".join(str(entry) for entry in coefficients)
                        ),
                        "detail": detail,
                    }
                )

    largest_two = training_bits[-2:]
    accepted: list[tuple[str, int, str, float]] = []
    for (name, height), by_precision in candidates.items():
        entries = [by_precision.get(bits) for bits in largest_two]
        if None in entries:
            continue
        hashes = [entry[0] for entry in entries if entry is not None]
        residual_bits = entries[-1][1]
        if (
            len(set(hashes)) == 1
            and residual_bits >= training_bits[-1] + args.minimum_holdout_bits
        ):
            accepted.append((name, height, hashes[0], residual_bits))

    minimum_agreement = min(agreements.values())
    metadata_lines = [
        "# format\tm23_8a_algebraic_recognition_probe_v1",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# training_source\t{display_path(args.training_source)}",
        f"# training_source_sha256\t{sha256(args.training_source)}",
        f"# training_source_precision_bits\t{training_precision}",
        f"# validation_source\t{display_path(args.validation_source)}",
        f"# validation_source_sha256\t{sha256(args.validation_source)}",
        f"# validation_source_precision_bits\t{validation_precision}",
        f"# normalization\t{training_metadata['normalization']}",
        f"# max_degree\t{args.max_degree}",
        f"# training_bits\t{','.join(map(str, training_bits))}",
        f"# height_bits\t{','.join(map(str, height_bits))}",
        f"# minimum_holdout_bits\t{args.minimum_holdout_bits}",
        f"# minimum_source_validation_agreement_bits\t{minimum_agreement:.6f}",
        f"# coefficient_count\t{len(names)}",
        f"# accepted_relation_count\t{len(accepted)}",
        "# interpretation\tbounded numerical dependency probe; exact recognition requires accepted relations and exact substitution",
    ]
    fieldnames = [
        "name",
        "training_bits",
        "height_bound_bits",
        "status",
        "returned_degree",
        "coefficient_height_bits",
        "polynomial_sha256",
        "validation_residual_bits",
        "coefficients_low_to_high",
        "detail",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        handle.write("\n".join(metadata_lines) + "\n")
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)

    print(
        f"probed {len(names)} coefficients through degree {args.max_degree}; "
        f"accepted_relations={len(accepted)} "
        f"minimum_agreement_bits={minimum_agreement:.1f}"
    )
    for name, height, digest, residual_bits in accepted:
        print(
            f"accepted name={name} height_bits={height} "
            f"sha256={digest} validation_residual_bits={residual_bits:.1f}"
        )


if __name__ == "__main__":
    main()
