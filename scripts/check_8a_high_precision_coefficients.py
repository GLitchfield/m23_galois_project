#!/usr/bin/env python3
"""Check the committed high-precision 8A coefficient artifact."""

from __future__ import annotations

import csv
from decimal import Decimal, InvalidOperation
import hashlib
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT = (
    ROOT / "data/derived/m23_8a_belyi_class1_high_precision_coefficients.tsv"
)
EXPECTED_NAMES = {
    "alpha", "a0", "a1", "b0", "b1", "c4", "c2", "c1",
    *(f"u{index}" for index in range(8)),
    *(f"v{index}" for index in range(7)),
}
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REVISION = re.compile(r"^[0-9a-f]{40}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_result(
    path: Path,
) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        else:
            data_lines.append(line)
    return metadata, list(csv.DictReader(data_lines, delimiter="\t"))


def check(path: Path) -> None:
    metadata, rows = read_result(path)
    expected_metadata = {
        "format": "m23_8a_belyi_high_precision_coefficients_v1",
        "normalization": "1,4,2",
        "precision_bits": "4096",
        "sage_version": "10.9",
        "interpretation":
            "high-precision numerical coefficients; not exact recognition",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected high-precision metadata: {key}")
    for key in ("code_revision", "source_code_revision"):
        if not REVISION.fullmatch(metadata.get(key, "")):
            raise RuntimeError(f"invalid high-precision revision: {key}")
    if not SHA256.fullmatch(metadata.get("source_sha256", "")):
        raise RuntimeError("invalid high-precision source hash")
    source = (ROOT / metadata["source"]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError("high-precision source is unavailable")
    if sha256(source) != metadata["source_sha256"]:
        raise RuntimeError("high-precision source hash mismatch")
    if int(metadata["iterations"]) <= 0:
        raise RuntimeError("invalid high-precision Newton iteration count")
    if Decimal(metadata["final_residual_max"]) >= Decimal("1e-1200"):
        raise RuntimeError("high-precision residual does not pass its gate")

    if len(rows) != 23 or {row["name"] for row in rows} != EXPECTED_NAMES:
        raise RuntimeError("high-precision coefficient rows are incomplete")
    for row in rows:
        try:
            values = (Decimal(row["real"]), Decimal(row["imaginary"]))
        except InvalidOperation as error:
            raise RuntimeError("invalid high-precision decimal") from error
        if not all(value.is_finite() for value in values):
            raise RuntimeError("nonfinite high-precision coefficient")
        if max(
            len(value.as_tuple().digits) for value in values
        ) < 1000:
            raise RuntimeError("coefficient precision was truncated")


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) == 2 else DEFAULT
    if len(sys.argv) > 2:
        raise SystemExit(f"usage: {sys.argv[0]} [COEFFICIENTS.tsv]")
    check(path)
    print("verified 4096-bit numerical coefficient artifact")


if __name__ == "__main__":
    main()
