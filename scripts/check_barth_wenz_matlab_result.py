#!/usr/bin/env python3
"""Check the compact committed Barth--Wenz MATLAB result."""

from __future__ import annotations

import csv
import itertools
import math
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import barth_wenz_preprocess as bw  # noqa: E402
import intake_barth_wenz_matlab_result as intake  # noqa: E402
import prepare_barth_wenz_matlab as prepare  # noqa: E402


DEFAULT_RESULT = (
    ROOT
    / "data/derived/m23_8a_barth_wenz_class1_domain1_dessin.tsv"
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def read_result(
    path: Path,
) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("# "):
                key, value = line[2:].rstrip("\n").split("\t", 1)
                if key in metadata:
                    raise RuntimeError(f"duplicate metadata key: {key}")
                metadata[key] = value
            else:
                data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    return metadata, rows


def expected_cycles() -> dict[str, tuple[tuple[int, ...], ...]]:
    x, y, _, _ = bw.m23_target(1)
    return {
        "zeros": x.cycles(),
        "ones": y.cycles(),
        "poles": bw.inverse_product(x, y).cycles(),
    }


def check(path: Path) -> None:
    metadata, rows = read_result(path)
    domain_index = metadata.get("domain_index", "1")
    if domain_index not in {"1", "2"}:
        raise RuntimeError("invalid or unsupported domain index")
    expected_metadata = {
        "format": "m23_8a_barth_wenz_dessin_seed_v1",
        "status": "numerical_seed_only",
        "source_bundle_project_revision":
            "b9cf11876c22abd158d079b196d898e7bcbe8973",
        "matlab_version": "26.1.0.3312084 (R2026a) Update 4",
        "matlab_license": "MATLAB Online (basic)",
        "sc_toolbox_version": prepare.SC_VERSION,
        "sc_toolbox_commit": prepare.SC_COMMIT,
        "barth_wenz_code_sha256": prepare.CODE_SHA256,
        "matlab_input_sha256": prepare.sha256(prepare.MATLAB_INPUT),
        "project_driver_sha256": prepare.sha256(prepare.MATLAB_DRIVER),
        "interpretation":
            "nondegenerate numerical dessin seed; not a Belyi map",
    }
    intake.require_keys(metadata, expected_metadata, "committed result")
    for key in (
        "code_revision",
        "source_bundle_project_revision",
    ):
        if not re.fullmatch(r"[0-9a-f]{40}", metadata[key]):
            raise RuntimeError(f"invalid revision: {key}")
    for key, value in metadata.items():
        if key.endswith("_sha256") and not SHA256.fullmatch(value):
            raise RuntimeError(f"invalid SHA-256: {key}")

    columns = {
        "fibre",
        "cycle_index",
        "ramification",
        "sheets",
        "real",
        "imaginary",
    }
    if not rows or set(rows[0]) != columns:
        raise RuntimeError("unexpected result columns")
    cycles = expected_cycles()
    expected_row_count = sum(len(value) for value in cycles.values())
    if len(rows) != expected_row_count:
        raise RuntimeError(
            f"expected {expected_row_count} roots, found {len(rows)}"
        )

    coordinates: dict[str, list[complex]] = {
        fibre: [] for fibre in intake.FIBRES
    }
    offset = 0
    for fibre in intake.FIBRES:
        for cycle_index, cycle in enumerate(cycles[fibre], start=1):
            row = rows[offset]
            offset += 1
            expected_sheets = ",".join(str(sheet + 1) for sheet in cycle)
            expected = {
                "fibre": fibre,
                "cycle_index": str(cycle_index),
                "ramification": str(len(cycle)),
                "sheets": expected_sheets,
            }
            intake.require_keys(row, expected, "root row")
            root = complex(float(row["real"]), float(row["imaginary"]))
            if not math.isfinite(root.real) or not math.isfinite(root.imag):
                raise RuntimeError("nonfinite committed root")
            coordinates[fibre].append(root)

    within = min(
        abs(left - right)
        for fibre in intake.FIBRES
        for left, right in itertools.combinations(coordinates[fibre], 2)
    )
    cross = min(
        abs(left - right)
        for first, second in itertools.combinations(intake.FIBRES, 2)
        for left in coordinates[first]
        for right in coordinates[second]
    )
    accuracy = float(metadata["sc_map_accuracy"])
    ratio = min(within, cross) / accuracy
    if accuracy > float(metadata["accuracy_gate_max"]):
        raise RuntimeError("committed SC-map accuracy fails its gate")
    if float(metadata["maximum_cycle_spread"]) > float(
        metadata["cycle_spread_gate_max"]
    ):
        raise RuntimeError("committed cycle spread fails its gate")
    if ratio < float(metadata["separation_ratio_gate_min"]):
        raise RuntimeError("committed separation ratio fails its gate")
    for key, actual in (
        ("minimum_within_fibre_separation", within),
        ("minimum_cross_fibre_separation", cross),
        ("minimum_separation_to_accuracy_ratio", ratio),
    ):
        recorded = float(metadata[key])
        if not math.isclose(actual, recorded, rel_tol=2e-14, abs_tol=1e-16):
            raise RuntimeError(f"recomputed metric mismatch: {key}")


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_RESULT
    check(path)
    metadata, _ = read_result(path)
    domain_index = metadata.get("domain_index", "1")
    print(
        "verified committed nondegenerate "
        f"domain-{domain_index} numerical dessin seed"
    )


if __name__ == "__main__":
    main()
