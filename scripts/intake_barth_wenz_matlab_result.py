#!/usr/bin/env python3
"""Validate and compact a Barth--Wenz MATLAB Online result."""

from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import math
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import barth_wenz_preprocess as bw  # noqa: E402
import prepare_barth_wenz_matlab as prepare  # noqa: E402


ACCURACY_MAX = 1e-7
CYCLE_SPREAD_MAX = 1e-12
SEPARATION_RATIO_MIN = 1_000.0
FIBRES = ("zeros", "ones", "poles")
MATLAB_VERSION = re.compile(r"^MATLAB Version: (.+)$", re.MULTILINE)
MATLAB_LICENSE = re.compile(r"^MATLAB License Number: (.+)$", re.MULTILINE)
OPERATING_SYSTEM = re.compile(r"^Operating System: (.+)$", re.MULTILINE)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_key_values(path: Path) -> dict[str, str]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle, delimiter="\t"))
    if not rows or rows[0] != ["key", "value"]:
        raise RuntimeError(f"{path.name}: expected key/value header")
    values: dict[str, str] = {}
    for row in rows[1:]:
        if len(row) != 2 or row[0] in values:
            raise RuntimeError(f"{path.name}: malformed or duplicate key")
        values[row[0]] = row[1]
    return values


def require_keys(
    actual: dict[str, str],
    expected: dict[str, str],
    source: str,
) -> None:
    for key, value in expected.items():
        if actual.get(key) != value:
            raise RuntimeError(
                f"{source}: expected {key}={value!r}, "
                f"found {actual.get(key)!r}"
            )


def read_coordinates(path: Path, degree: int) -> list[complex]:
    coordinates: list[complex] = []
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.reader(handle):
            if len(row) != 2:
                raise RuntimeError(f"{path.name}: expected two columns")
            value = complex(float(row[0]), float(row[1]))
            if not math.isfinite(value.real) or not math.isfinite(value.imag):
                raise RuntimeError(f"{path.name}: nonfinite coordinate")
            coordinates.append(value)
    if len(coordinates) != degree:
        raise RuntimeError(
            f"{path.name}: expected {degree} rows, found {len(coordinates)}"
        )
    return coordinates


def git_revision() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def cycle_data() -> dict[str, tuple[tuple[int, ...], ...]]:
    x, y, _, _ = bw.m23_target(1)
    z = bw.inverse_product(x, y)
    return {
        "zeros": x.cycles(),
        "ones": y.cycles(),
        "poles": z.cycles(),
    }


def environment_value(pattern: re.Pattern[str], text: str, name: str) -> str:
    match = pattern.search(text)
    if match is None:
        raise RuntimeError(f"environment record lacks {name}")
    return match.group(1).strip()


def representative(
    coordinates: list[complex],
    cycle: tuple[int, ...],
) -> tuple[complex, float]:
    values = [coordinates[sheet] for sheet in cycle]
    mean = sum(values, 0j) / len(values)
    return mean, max(abs(value - mean) for value in values)


def validate(
    result_dir: Path,
    environment: Path,
    result_archive: Path,
    domain_index: int = 1,
) -> tuple[dict[str, str], list[tuple[str, int, tuple[int, ...], complex]]]:
    if domain_index not in (1, 2):
        raise ValueError("domain index must be 1 or 2")
    domain_label = str(domain_index)
    required = [
        "bundle_manifest.tsv",
        "matlab_input.m",
        "run_class1.m",
        "matlab_summary.tsv",
        "matlab_transcript.txt",
        "m23_class1_dessin.mat",
        *(f"{fibre}_dessin.csv" for fibre in FIBRES),
    ]
    for basename in required:
        if not (result_dir / basename).is_file():
            raise RuntimeError(f"missing result file: {basename}")
    if (result_dir / "matlab_failure.txt").exists():
        raise RuntimeError("result directory contains matlab_failure.txt")

    manifest = read_key_values(result_dir / "bundle_manifest.tsv")
    require_keys(
        manifest,
        {
            "format": "m23-barth-wenz-matlab-bundle-v1",
            "target_class": "1",
            "domain_index": domain_label,
            "matlab_input_sha256": prepare.sha256(prepare.MATLAB_INPUT),
            "project_driver_sha256": prepare.sha256(prepare.MATLAB_DRIVER),
            "barth_wenz_code_url": prepare.CODE_URL,
            "barth_wenz_code_sha256": prepare.CODE_SHA256,
            "sc_toolbox_version": prepare.SC_VERSION,
            "sc_toolbox_commit": prepare.SC_COMMIT,
            "sc_toolbox_url": prepare.SC_URL,
            "sc_toolbox_archive_sha256": prepare.SC_SHA256,
        },
        "bundle manifest",
    )
    if not re.fullmatch(r"[0-9a-f]{40}", manifest["project_revision"]):
        raise RuntimeError("bundle manifest has invalid project revision")
    if sha256(result_dir / "matlab_input.m") != manifest["matlab_input_sha256"]:
        raise RuntimeError("returned MATLAB input hash mismatch")
    if sha256(result_dir / "run_class1.m") != manifest["project_driver_sha256"]:
        raise RuntimeError("returned MATLAB driver hash mismatch")

    summary = read_key_values(result_dir / "matlab_summary.tsv")
    require_keys(
        summary,
        {
            "status": "completed",
            "degree": "23",
            "domain_index": domain_label,
            "finite_output": "1",
            "zero_count": "23",
            "one_count": "23",
            "pole_count": "23",
        },
        "MATLAB summary",
    )
    accuracy = float(summary["sc_map_accuracy"])
    if not math.isfinite(accuracy) or accuracy <= 0 or accuracy > ACCURACY_MAX:
        raise RuntimeError(f"SC-map accuracy does not pass gate: {accuracy}")

    transcript = (result_dir / "matlab_transcript.txt").read_text(
        encoding="utf-8", errors="replace"
    )
    if "M23_BARTH_WENZ_STAGE=completed" not in transcript:
        raise RuntimeError("transcript lacks completed marker")
    if "M23_BARTH_WENZ_STAGE=failed" in transcript:
        raise RuntimeError("transcript contains failed marker")

    coordinates = {
        fibre: read_coordinates(result_dir / f"{fibre}_dessin.csv", 23)
        for fibre in FIBRES
    }
    cycles = cycle_data()
    roots: list[tuple[str, int, tuple[int, ...], complex]] = []
    maximum_spread = 0.0
    representatives: dict[str, list[complex]] = {}
    for fibre in FIBRES:
        representatives[fibre] = []
        for cycle_index, cycle in enumerate(cycles[fibre], start=1):
            mean, spread = representative(coordinates[fibre], cycle)
            maximum_spread = max(maximum_spread, spread)
            representatives[fibre].append(mean)
            roots.append((fibre, cycle_index, cycle, mean))
    if maximum_spread > CYCLE_SPREAD_MAX:
        raise RuntimeError(
            f"cycle-coordinate spread does not pass gate: {maximum_spread}"
        )

    within_separations = [
        abs(left - right)
        for fibre in FIBRES
        for left, right in itertools.combinations(representatives[fibre], 2)
    ]
    cross_separations = [
        abs(left - right)
        for first, second in itertools.combinations(FIBRES, 2)
        for left in representatives[first]
        for right in representatives[second]
    ]
    minimum_within = min(within_separations)
    minimum_cross = min(cross_separations)
    minimum_separation = min(minimum_within, minimum_cross)
    separation_ratio = minimum_separation / accuracy
    if separation_ratio < SEPARATION_RATIO_MIN:
        raise RuntimeError(
            "coordinate separation is too small relative to SC-map accuracy: "
            f"{separation_ratio}"
        )

    environment_text = environment.read_text(encoding="utf-8")
    matlab_version = environment_value(
        MATLAB_VERSION, environment_text, "MATLAB version"
    )
    matlab_license = environment_value(
        MATLAB_LICENSE, environment_text, "MATLAB license"
    )
    operating_system = environment_value(
        OPERATING_SYSTEM, environment_text, "operating system"
    )

    output_hashes = {
        basename: sha256(result_dir / basename)
        for basename in (
            "matlab_summary.tsv",
            "matlab_transcript.txt",
            "m23_class1_dessin.mat",
            "zeros_dessin.csv",
            "ones_dessin.csv",
            "poles_dessin.csv",
        )
    }
    metadata = {
        "format": "m23_8a_barth_wenz_dessin_seed_v1",
        "status": "numerical_seed_only",
        "code_revision": git_revision(),
        "source_bundle_project_revision": manifest["project_revision"],
        "domain_index": domain_label,
        "result_archive_sha256": sha256(result_archive),
        "environment_sha256": sha256(environment),
        "matlab_version": matlab_version,
        "matlab_license": matlab_license,
        "operating_system": operating_system,
        "sc_toolbox_version": manifest["sc_toolbox_version"],
        "sc_toolbox_commit": manifest["sc_toolbox_commit"],
        "barth_wenz_code_sha256": manifest["barth_wenz_code_sha256"],
        "matlab_input_sha256": manifest["matlab_input_sha256"],
        "project_driver_sha256": manifest["project_driver_sha256"],
        **{
            f"{basename.replace('.', '_')}_sha256": digest
            for basename, digest in output_hashes.items()
        },
        "sc_map_accuracy": format(accuracy, ".17g"),
        "maximum_cycle_spread": format(maximum_spread, ".17g"),
        "minimum_within_fibre_separation": format(minimum_within, ".17g"),
        "minimum_cross_fibre_separation": format(minimum_cross, ".17g"),
        "minimum_separation_to_accuracy_ratio": format(
            separation_ratio, ".17g"
        ),
        "accuracy_gate_max": format(ACCURACY_MAX, ".17g"),
        "cycle_spread_gate_max": format(CYCLE_SPREAD_MAX, ".17g"),
        "separation_ratio_gate_min": format(SEPARATION_RATIO_MIN, ".17g"),
        "interpretation": (
            "nondegenerate numerical dessin seed; not a Belyi map"
        ),
    }
    return metadata, roots


def write_output(
    output: Path,
    metadata: dict[str, str],
    roots: list[tuple[str, int, tuple[int, ...], complex]],
) -> None:
    with output.open("x", encoding="utf-8", newline="") as handle:
        for key, value in metadata.items():
            handle.write(f"# {key}\t{value}\n")
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(
            (
                "fibre",
                "cycle_index",
                "ramification",
                "sheets",
                "real",
                "imaginary",
            )
        )
        for fibre, cycle_index, cycle, root in roots:
            writer.writerow(
                (
                    fibre,
                    cycle_index,
                    len(cycle),
                    ",".join(str(sheet + 1) for sheet in cycle),
                    format(root.real, ".17g"),
                    format(root.imag, ".17g"),
                )
            )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("result_dir", type=Path)
    parser.add_argument("--environment", type=Path, required=True)
    parser.add_argument("--result-archive", type=Path, required=True)
    parser.add_argument(
        "--domain-index", type=int, choices=(1, 2), default=1
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    metadata, roots = validate(
        args.result_dir,
        args.environment,
        args.result_archive,
        args.domain_index,
    )
    write_output(args.output, metadata, roots)
    print(
        f"accepted domain-{args.domain_index} numerical dessin seed with "
        f"{len(roots)} "
        f"distinct ramification points"
    )


if __name__ == "__main__":
    main()
