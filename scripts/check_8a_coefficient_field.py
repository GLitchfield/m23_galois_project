#!/usr/bin/env python3
"""Check the committed exact coefficient-field analysis for the 8A map."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
REVISION = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_FIXED_POLYNOMIAL = (
    768, -1344, -1308, 4496, -1512, -5352, 7292, -3360,
    -276, 872, -248, -60, 52, -12, 1,
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
        raise RuntimeError("duplicate coefficient-field properties")
    return metadata, properties


def check(path: Path) -> None:
    metadata, properties = read_result(path)
    expected_metadata = {
        "format": "m23_8a_coefficient_field_v1",
        "sage_version": "10.9",
        "construction":
            "fixed generator y=t+t^-1 under reciprocal involution",
        "exact_polynomial_identity": "t^14*g(t+t^-1)=f(t)",
        "interpretation":
            "exact arithmetic invariants of the Belyi coefficient field",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected coefficient-field metadata: {key}")
    if not REVISION.fullmatch(metadata.get("code_revision", "")):
        raise RuntimeError("invalid coefficient-field producer revision")
    if not SHA256.fullmatch(metadata.get("source_sha256", "")):
        raise RuntimeError("invalid coefficient-field source hash")
    source = (ROOT / metadata["source"]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError("coefficient-field source is unavailable")
    if sha256(source) != metadata["source_sha256"]:
        raise RuntimeError("coefficient-field source hash mismatch")

    expected_properties = {
        "coefficient_field_degree": "28",
        "coefficient_field_signature": "0,14",
        "coefficient_field_automorphism_count": "2",
        "coefficient_field_discriminant":
            str(2**66 * 3**10 * 11**4 * 23**6),
        "coefficient_field_discriminant_factorization":
            "2^66*3^10*11^4*23^6",
        "reciprocal_involution": "t->t^-1",
        "fixed_field_degree": "14",
        "fixed_field_signature": "2,6",
        "fixed_field_automorphism_count": "1",
        "fixed_field_discriminant":
            str(2**31 * 3**5 * 11**2 * 23**3),
        "fixed_field_discriminant_factorization":
            "2^31*3^5*11^2*23^3",
        "discriminant_ratio_DK_over_DL_squared": "16",
        "fixed_polynomial_low_to_high":
            ",".join(map(str, EXPECTED_FIXED_POLYNOMIAL)),
    }
    if properties != expected_properties:
        missing = set(expected_properties) - set(properties)
        extra = set(properties) - set(expected_properties)
        wrong = {
            key for key in set(properties) & set(expected_properties)
            if properties[key] != expected_properties[key]
        }
        raise RuntimeError(
            "coefficient-field properties changed: "
            f"missing={missing}, extra={extra}, wrong={wrong}"
        )

    candidate = json.loads(source.read_text(encoding="utf-8"))
    defining = candidate["field"]["defining_polynomial"]
    if len(defining) != 29 or defining != list(reversed(defining)):
        raise RuntimeError("candidate field polynomial is not reciprocal degree 28")
    coefficient_discriminant = int(properties["coefficient_field_discriminant"])
    fixed_discriminant = int(properties["fixed_field_discriminant"])
    if coefficient_discriminant != 16 * fixed_discriminant**2:
        raise RuntimeError("coefficient/fixed discriminant identity failed")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} COEFFICIENT_FIELD.tsv")
    check(Path(sys.argv[1]))
    print(
        "verified reciprocal degree-28 coefficient field and "
        "degree-14 fixed subfield"
    )


if __name__ == "__main__":
    main()
