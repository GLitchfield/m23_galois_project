#!/usr/bin/env python3
"""Check the committed 8A exact-recognition evidence chain."""

from __future__ import annotations

import csv
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
DERIVED = ROOT / "data/derived"
TRAINING = DERIVED / "m23_8a_belyi_class1_high_precision_coefficients_8192.tsv"
VALIDATION = DERIVED / "m23_8a_belyi_class1_high_precision_coefficients_16384.tsv"
PROBE = DERIVED / "m23_8a_belyi_class1_recognition_probe.tsv"
RECOVERY = DERIVED / "m23_8a_belyi_class1_number_field_recovery.tsv"
CANDIDATE = DERIVED / "m23_8a_belyi_class1_exact_candidate.json"
EXPECTED_NAMES = {
    "alpha", "a0", "a1", "b0", "b1", "c4", "c2", "c1",
    *(f"u{index}" for index in range(8)),
    *(f"v{index}" for index in range(7)),
}
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REVISION = re.compile(r"^[0-9a-f]{40}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_tsv(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    return metadata, list(csv.DictReader(data_lines, delimiter="\t"))


def check_precision_artifact(path: Path, bits: int, residual_gate: str) -> None:
    metadata, rows = read_tsv(path)
    expected = {
        "format": "m23_8a_belyi_high_precision_coefficients_v1",
        "normalization": "1,4,2",
        "precision_bits": str(bits),
        "sage_version": "10.9",
        "interpretation":
            "high-precision numerical coefficients; not exact recognition",
    }
    for key, value in expected.items():
        if metadata.get(key) != value:
            raise RuntimeError(f"unexpected {path.name} metadata: {key}")
    for key in ("code_revision", "source_code_revision"):
        if not REVISION.fullmatch(metadata.get(key, "")):
            raise RuntimeError(f"invalid {path.name} revision: {key}")
    source = (ROOT / metadata["source"]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError(f"missing {path.name} source")
    if sha256(source) != metadata["source_sha256"]:
        raise RuntimeError(f"{path.name} source hash mismatch")
    if Decimal(metadata["final_residual_max"]) >= Decimal(residual_gate):
        raise RuntimeError(f"{path.name} residual misses its gate")
    if {row["name"] for row in rows} != EXPECTED_NAMES or len(rows) != 23:
        raise RuntimeError(f"{path.name} coefficient rows are incomplete")
    minimum_digits = int(bits * 0.29)
    for row in rows:
        values = (Decimal(row["real"]), Decimal(row["imaginary"]))
        if not all(value.is_finite() for value in values):
            raise RuntimeError(f"{path.name} has a nonfinite coefficient")
        if max(len(value.as_tuple().digits) for value in values) < minimum_digits:
            raise RuntimeError(f"{path.name} coefficient precision was truncated")


def check_probe() -> None:
    metadata, rows = read_tsv(PROBE)
    expected = {
        "format": "m23_8a_algebraic_recognition_probe_v1",
        "sage_version": "10.9",
        "training_source_sha256": sha256(TRAINING),
        "training_source_precision_bits": "8192",
        "validation_source_sha256": sha256(VALIDATION),
        "validation_source_precision_bits": "16384",
        "normalization": "1,4,2",
        "max_degree": "28",
        "training_bits": "2048,4096,8000",
        "height_bits": "128,160,192,224,256",
        "minimum_holdout_bits": "1024",
        "coefficient_count": "23",
        "accepted_relation_count": "22",
    }
    for key, value in expected.items():
        if metadata.get(key) != value:
            raise RuntimeError(f"unexpected recognition-probe metadata: {key}")
    if not REVISION.fullmatch(metadata.get("code_revision", "")):
        raise RuntimeError("invalid recognition-probe revision")
    if float(metadata["minimum_source_validation_agreement_bits"]) < 8100:
        raise RuntimeError("training and validation coefficients disagree")
    if len(rows) != 23 * 3 * 5:
        raise RuntimeError("recognition-probe grid is incomplete")

    by_key: dict[tuple[str, int], dict[int, dict[str, str]]] = {}
    for row in rows:
        by_key.setdefault(
            (row["name"], int(row["height_bound_bits"])), {}
        )[int(row["training_bits"])] = row
    accepted: list[tuple[str, int]] = []
    for key, by_precision in by_key.items():
        left = by_precision[4096]
        right = by_precision[8000]
        if (
            left["status"] == right["status"] == "found"
            and left["polynomial_sha256"] == right["polynomial_sha256"]
            and float(right["validation_residual_bits"]) >= 9024
        ):
            if right["returned_degree"] != "28":
                raise RuntimeError("accepted dependency has the wrong degree")
            if not SHA256.fullmatch(right["polynomial_sha256"]):
                raise RuntimeError("accepted dependency hash is malformed")
            accepted.append(key)
    if len(accepted) != 22:
        raise RuntimeError("accepted dependency count does not reproduce")
    if {name for name, _ in accepted} != {
        "a0", "a1", "b0", "b1", "c4", "c2", "c1", "u7",
    }:
        raise RuntimeError("unexpected accepted dependency names")


def check_recovery() -> None:
    metadata, rows = read_tsv(RECOVERY)
    expected = {
        "format": "m23_8a_number_field_recovery_v1",
        "sage_version": "10.9",
        "training_source_sha256": sha256(TRAINING),
        "validation_source_sha256": sha256(VALIDATION),
        "recognition_probe_sha256": sha256(PROBE),
        "normalization": "1,4,2",
        "generator": "c2",
        "base_generator_degree": "28",
        "optimization_seed": "20260723",
        "optimized_generator_degree": "28",
        "training_bits": "4096,8000",
        "maximum_coordinate_height_bits": "256",
        "minimum_holdout_bits": "1024",
        "accepted_coordinate_count": "23",
        "exact_coefficient_identity": "true",
    }
    for key, value in expected.items():
        if metadata.get(key) != value:
            raise RuntimeError(f"unexpected field-recovery metadata: {key}")
    if not REVISION.fullmatch(metadata.get("code_revision", "")):
        raise RuntimeError("invalid field-recovery revision")
    optimized = metadata["optimized_generator_polynomial_low_to_high"].split(",")
    if len(optimized) != 29 or optimized[0] == "0" or optimized[-1] == "0":
        raise RuntimeError("invalid optimized degree-28 field polynomial")
    if len(rows) != 23 or {row["name"] for row in rows} != EXPECTED_NAMES:
        raise RuntimeError("field-recovery rows are incomplete")
    for row in rows:
        if row["status"] != "accepted":
            raise RuntimeError(f"rejected recovered coordinate: {row['name']}")
        if row["stable_across_training_precisions"] != "true":
            raise RuntimeError(f"unstable recovered coordinate: {row['name']}")
        if row["validation_residual_bits"] != "inf":
            if float(row["validation_residual_bits"]) < 16000:
                raise RuntimeError(
                    f"weak recovered-coordinate holdout: {row['name']}"
                )
        if not SHA256.fullmatch(row["relation_sha256"]):
            raise RuntimeError(f"invalid relation hash: {row['name']}")


def check_candidate() -> None:
    record = json.loads(CANDIDATE.read_text(encoding="utf-8"))
    if record.get("schema_version") != "belyi-candidate-v1":
        raise RuntimeError("unexpected exact-candidate schema")
    if record["problem"].get("id") != "m23-8a-8a-2a-degree23":
        raise RuntimeError("unexpected exact-candidate problem")
    polynomial = record["field"].get("defining_polynomial")
    if not isinstance(polynomial, list) or len(polynomial) != 29:
        raise RuntimeError("exact candidate does not use a degree-28 field")
    source = record["provenance"]["source"]
    if source.get("class_id") != 1:
        raise RuntimeError("exact candidate does not identify class 1")
    if source.get("dataset_sha256") != (
        "dc6089e7b9bcf9cb890e01306d286327266c0bf6ba7a7a8e48abb5ca52b3f3e8"
    ):
        raise RuntimeError("exact candidate class-ledger hash mismatch")
    producer = record["provenance"]["producer"]
    if producer.get("software") != "SageMath 10.9":
        raise RuntimeError("unexpected exact-candidate producer")
    if producer.get("revision") != read_tsv(RECOVERY)[0]["code_revision"]:
        raise RuntimeError("exact candidate and recovery revisions differ")


def main() -> None:
    check_precision_artifact(TRAINING, 8192, "1e-2400")
    check_precision_artifact(VALIDATION, 16384, "1e-4900")
    check_probe()
    check_recovery()
    check_candidate()
    print(
        "verified bounded degree-28 recognition, 23-coordinate recovery, "
        "and exact coefficient identity"
    )


if __name__ == "__main__":
    main()
