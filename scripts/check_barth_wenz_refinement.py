#!/usr/bin/env python3
"""Check committed normalization and refinement evidence for the MATLAB seed."""

from __future__ import annotations

import csv
import hashlib
import math
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import prepare_barth_wenz_root_seed as prepare  # noqa: E402
import refine_barth_wenz_root_seed as refine  # noqa: E402


CENSUS = ROOT / "data/derived/m23_8a_barth_wenz_root_chart_census.tsv"
SEED = ROOT / "data/derived/m23_8a_barth_wenz_root_seed.tsv"
NEWTON = ROOT / "data/derived/m23_8a_barth_wenz_newton_summary.tsv"
STRONG = (
    ROOT / "data/derived/m23_8a_barth_wenz_strong_continuation.tsv"
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def read_table(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        else:
            lines.append(line)
    return metadata, list(csv.DictReader(lines, delimiter="\t"))


def close(actual: str, expected: float, label: str) -> None:
    if not math.isclose(
        float(actual), expected, rel_tol=2e-14, abs_tol=1e-16
    ):
        raise RuntimeError(f"metric mismatch: {label}")


def check() -> None:
    census_metadata, census_rows = read_table(CENSUS)
    if census_metadata.get("format") != (
        "m23_8a_barth_wenz_root_chart_census_v1"
    ):
        raise RuntimeError("unexpected chart-census format")
    if len(census_rows) != 6:
        raise RuntimeError("chart census must contain six rows")
    if {row["normalization"] for row in census_rows} != {
        ",".join(map(str, chart)) for chart in prepare.NORMALIZATIONS
    }:
        raise RuntimeError("chart census does not cover all normalizations")
    selected = [row for row in census_rows if row["selected"] == "1"]
    if len(selected) != 1 or selected[0]["normalization"] != "1,4,2":
        raise RuntimeError("unexpected selected MATLAB-seed chart")
    if selected[0]["viable"] != "1":
        raise RuntimeError("selected MATLAB-seed chart is not viable")

    seed_metadata, seed = refine.read_seed(SEED)
    normalization = refine.normalization_from(seed_metadata)
    if normalization != (1, 4, 2):
        raise RuntimeError("committed seed has unexpected normalization")
    seed_metrics = prepare.chart_metrics(normalization, seed)
    for key in (
        "relative_residual",
        "equilibrated_jacobian_condition",
        "minimum_chordal_separation",
    ):
        close(selected[0][key], float(seed_metrics[key]), f"seed {key}")

    newton_metadata, newton_rows = read_table(NEWTON)
    if (
        newton_metadata.get("format")
        != "m23_8a_barth_wenz_newton_summary_v1"
        or len(newton_rows) != 1
    ):
        raise RuntimeError("unexpected Newton summary")
    if newton_metadata.get("seed_sha256") != hashlib.sha256(
        SEED.read_bytes()
    ).hexdigest():
        raise RuntimeError("Newton seed hash mismatch")
    newton = newton_rows[0]
    if newton["verdict"] != "rejected":
        raise RuntimeError("Newton false endpoint was not rejected")
    if float(newton["final_relative_residual"]) >= 1e-10:
        raise RuntimeError("Newton did not reach its residual diagnostic")
    if float(newton["final_fq_chordal_separation"]) >= 1e-8:
        raise RuntimeError("Newton rejection no longer exhibits F-Q collision")
    if newton["final_minimum_chordal_separation"] != (
        newton["final_fq_chordal_separation"]
    ):
        raise RuntimeError("Newton minimum separation is not the F-Q collision")

    strong_metadata, strong_rows = read_table(STRONG)
    if (
        strong_metadata.get("format")
        != "m23_8a_barth_wenz_strong_continuation_v1"
        or strong_metadata.get("saturation_mode") != "strong"
        or len(strong_rows) != 1
    ):
        raise RuntimeError("unexpected strong-continuation evidence")
    for key in ("seed_sha256", "endpoint_sha256"):
        if not SHA256.fullmatch(strong_metadata.get(key, "")):
            raise RuntimeError(f"invalid strong-continuation {key}")
    if strong_metadata["seed_sha256"] != hashlib.sha256(
        SEED.read_bytes()
    ).hexdigest():
        raise RuntimeError("strong-continuation seed hash mismatch")
    strong = strong_rows[0]
    if (
        strong["return_code"],
        strong["verdict"],
    ) != ("at_infinity", "rejected_infinity"):
        raise RuntimeError("unexpected strong-continuation verdict")
    if float(strong["fq_separation"]) >= 1e-8:
        raise RuntimeError("strong path did not reach its F-Q boundary")


def main() -> None:
    check()
    print("verified rejected domain-1 refinement and strong-continuation gates")


if __name__ == "__main__":
    main()
