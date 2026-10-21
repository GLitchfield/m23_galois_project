#!/usr/bin/env python3
"""Independently check a certified Barth--Wenz continuation endpoint."""

from __future__ import annotations

import csv
import hashlib
import math
from pathlib import Path
import re
import sys

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import prepare_barth_wenz_root_seed as prepare  # noqa: E402
import refine_barth_wenz_root_seed as refine  # noqa: E402


INVERSE_NAMES = (
    "inverse_alpha",
    "inverse_p",
    "inverse_f",
    "inverse_q",
    "inverse_pf",
    "inverse_pq",
    "inverse_fq",
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REVISION = re.compile(r"^[0-9a-f]{40}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_endpoint(
    path: Path,
) -> tuple[dict[str, str], dict[str, complex]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("=", 1)
            if key in metadata:
                raise RuntimeError(f"duplicate endpoint metadata: {key}")
            metadata[key] = value
        else:
            data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    if not rows or set(rows[0]) != {"name", "real", "imag"}:
        raise RuntimeError("unexpected endpoint columns")
    values: dict[str, complex] = {}
    for row in rows:
        name = row["name"]
        if name in values:
            raise RuntimeError(f"duplicate endpoint variable: {name}")
        value = complex(float(row["real"]), float(row["imag"]))
        if not math.isfinite(value.real) or not math.isfinite(value.imag):
            raise RuntimeError(f"nonfinite endpoint variable: {name}")
        values[name] = value
    return metadata, values


def vandermonde(values: list[complex]) -> complex:
    result = 1 + 0j
    for left_index, left in enumerate(values):
        for right in values[left_index + 1:]:
            result *= left - right
    return result


def strong_saturation_values(point: np.ndarray) -> np.ndarray:
    p = [*point[1:3], 0j, 1 + 0j]
    f = list(point[3:8])
    q = list(point[8:23])

    def cross(left: list[complex], right: list[complex]) -> complex:
        result = 1 + 0j
        for first in left:
            for second in right:
                result *= first - second
        return result

    return np.array(
        [
            point[0],
            vandermonde(p),
            vandermonde(f),
            vandermonde(q),
            cross(p, f),
            cross(p, q),
            cross(f, q),
        ],
        dtype=complex,
    )


def check(path: Path) -> dict[str, float]:
    metadata, values = read_endpoint(path)
    expected_metadata = {
        "format": "m23_8a_root_saturated_endpoint_v2",
        "normalization": "1,4,2",
        "gamma_angle": "1.4",
        "regularization": "0.0",
        "saturation_mode": "strong",
        "return_code": "success",
        "certified": "true",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(
                f"endpoint metadata {key}: expected {expected!r}, "
                f"found {metadata.get(key)!r}"
            )
    if not REVISION.fullmatch(metadata.get("code_revision", "")):
        raise RuntimeError("invalid endpoint code revision")
    if not SHA256.fullmatch(metadata.get("seed_sha256", "")):
        raise RuntimeError("invalid endpoint seed hash")
    if abs(float(metadata["homotopy_parameter"])) > 1e-30:
        raise RuntimeError("certified endpoint is not at the target parameter")

    expected_names = set(prepare.ROOT_NAMES) | set(INVERSE_NAMES)
    if set(values) != expected_names:
        raise RuntimeError("endpoint has unexpected variable names")

    seed_path = (ROOT / metadata["seed"]).resolve()
    if not seed_path.is_relative_to(ROOT) or not seed_path.is_file():
        raise RuntimeError("endpoint seed path is unavailable or external")
    if sha256(seed_path) != metadata["seed_sha256"]:
        raise RuntimeError("endpoint seed hash mismatch")
    seed_metadata, seed = refine.read_seed(seed_path)
    if refine.normalization_from(seed_metadata) != (1, 4, 2):
        raise RuntimeError("endpoint and seed normalizations disagree")

    point = np.array(
        [values[name] for name in prepare.ROOT_NAMES], dtype=complex
    )
    metrics = refine.metrics(point, (1, 4, 2))
    if not refine.accepted(point, metrics):
        raise RuntimeError("independent Python candidate gates failed")
    recorded_residual = float(metadata["coefficient_residual"])
    if not math.isfinite(recorded_residual) or recorded_residual >= 1e-10:
        raise RuntimeError("recorded Julia coefficient residual failed")
    recorded_separation = float(metadata["minimum_chordal_separation"])
    if not math.isclose(
        recorded_separation,
        metrics["minimum_chordal_separation"],
        rel_tol=2e-13,
        abs_tol=1e-15,
    ):
        raise RuntimeError("Julia/Python minimum separation mismatch")

    seed_saturations = strong_saturation_values(seed)
    endpoint_saturations = strong_saturation_values(point)
    if np.any(endpoint_saturations == 0):
        raise RuntimeError("endpoint has a zero saturation factor")
    expected_inverses = seed_saturations / endpoint_saturations
    actual_inverses = np.array(
        [values[name] for name in INVERSE_NAMES], dtype=complex
    )
    if not np.allclose(
        actual_inverses, expected_inverses, rtol=5e-12, atol=5e-13
    ):
        raise RuntimeError("strong saturation inverse equations failed")
    return metrics


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} ENDPOINT.tsv")
    path = Path(sys.argv[1])
    metrics = check(path)
    print(
        "verified certified nondegenerate endpoint: "
        f"relative_residual={metrics['relative_residual']:.6g} "
        f"minimum_separation={metrics['minimum_chordal_separation']:.6g}"
    )


if __name__ == "__main__":
    main()
