#!/usr/bin/env python3
"""Translate the validated Barth--Wenz dessin into normalized root seeds."""

from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import math
from pathlib import Path
import platform
import subprocess
import sys

import numpy as np

import census_8a_belyi_conditioning as conditioning
import pilot_8a_belyi_numeric as pilot


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DESSIN = (
    ROOT / "data/derived/m23_8a_barth_wenz_class1_domain1_dessin.tsv"
)
NORMALIZATIONS = tuple(itertools.permutations((4, 2, 1)))
ROOT_NAMES = (
    "alpha", "ar1", "ar2", "br1", "br2", "cr4", "cr2", "cr1",
    *(f"ur{index}" for index in range(1, 9)),
    *(f"vr{index}" for index in range(1, 8)),
)
RELATIVE_RESIDUAL_MAX = 0.25
JACOBIAN_CONDITION_MAX = 1e16
ROOT_SEPARATION_MIN = 1e-8


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


def read_dessin(
    path: Path,
) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("# "):
                key, value = line[2:].rstrip("\n").split("\t", 1)
                metadata[key] = value
            else:
                data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    if metadata.get("format") != "m23_8a_barth_wenz_dessin_seed_v1":
        raise RuntimeError("unexpected dessin format")
    if metadata.get("status") != "numerical_seed_only":
        raise RuntimeError("dessin has unexpected status")
    return metadata, rows


def grouped_roots(rows: list[dict[str, str]]) -> dict[str, dict[int, list[complex]]]:
    grouped: dict[str, dict[int, list[complex]]] = {
        fibre: {} for fibre in ("zeros", "ones", "poles")
    }
    for row in rows:
        fibre = row["fibre"]
        if fibre not in grouped:
            raise RuntimeError(f"unexpected fibre: {fibre}")
        ramification = int(row["ramification"])
        root = complex(float(row["real"]), float(row["imaginary"]))
        if not math.isfinite(root.real) or not math.isfinite(root.imag):
            raise RuntimeError("nonfinite dessin root")
        grouped[fibre].setdefault(ramification, []).append(root)
    expected = {
        "zeros": {8: 2, 4: 1, 2: 1, 1: 1},
        "ones": {2: 8, 1: 7},
        "poles": {8: 2, 4: 1, 2: 1, 1: 1},
    }
    actual = {
        fibre: {ramification: len(roots)
                for ramification, roots in values.items()}
        for fibre, values in grouped.items()
    }
    if actual != expected:
        raise RuntimeError(f"unexpected dessin root partitions: {actual}")
    return grouped


def transform_seed(
    grouped: dict[str, dict[int, list[complex]]],
    normalization: tuple[int, int, int],
) -> np.ndarray:
    if tuple(sorted(normalization)) != (1, 2, 4):
        raise ValueError("normalization must permute (4,2,1)")
    zeros = grouped["zeros"]
    z0 = zeros[normalization[0]][0]
    z1 = zeros[normalization[1]][0]
    zinf = zeros[normalization[2]][0]

    def transform(value: complex) -> complex:
        return pilot.mobius(value, z0, z1, zinf)

    ar = [transform(value) for value in zeros[8]]
    poles = grouped["poles"]
    br = [transform(value) for value in poles[8]]
    cr = [transform(poles[ramification][0])
          for ramification in (4, 2, 1)]
    ones = grouped["ones"]
    ur = [transform(value) for value in ones[2]]
    vr = [transform(value) for value in ones[1]]
    seed = np.array([1, *ar, *br, *cr, *ur, *vr], dtype=complex)
    _, _, (p_base, f_poly, q_poly) = pilot.residual_jac(
        seed, normalization)
    source = pilot.pad(p_base)[:23]
    target = (pilot.pad(q_poly) - pilot.pad(f_poly))[:23]
    seed[0] = np.vdot(source, target) / np.vdot(source, source)
    return seed


def chordal(left: complex, right: complex) -> float:
    return float(
        abs(left - right)
        / math.sqrt((1 + abs(left) ** 2) * (1 + abs(right) ** 2))
    )


def chordal_infinity(value: complex) -> float:
    return float(1 / math.sqrt(1 + abs(value) ** 2))


def minimum_separations(
    seed: np.ndarray,
) -> tuple[float, float, float, float, float, float]:
    p = [*seed[1:3], 0j, 1 + 0j]
    f = list(seed[3:8])
    q = list(seed[8:23])

    def within(roots: list[complex], include_infinity: bool = False) -> float:
        distances = [
            chordal(left, right)
            for left, right in itertools.combinations(roots, 2)
        ]
        if include_infinity:
            distances.extend(chordal_infinity(root) for root in roots)
        return min(distances)

    return (
        within(p, include_infinity=True),
        within(f),
        within(q),
        min(chordal(left, right) for left in p for right in f),
        min(chordal(left, right) for left in p for right in q),
        min(chordal(left, right) for left in f for right in q),
    )


def chart_metrics(
    normalization: tuple[int, int, int],
    seed: np.ndarray,
) -> dict[str, object]:
    residual, jacobian, parts = pilot.residual_jac(seed, normalization)
    relative_residual = float(
        np.linalg.norm(residual)
        / max(np.linalg.norm(part) for part in parts)
    )
    p_sep, f_sep, q_sep, pf_sep, pq_sep, fq_sep = minimum_separations(seed)
    minimum_separation = min(
        p_sep, f_sep, q_sep, pf_sep, pq_sep, fq_sep
    )
    condition = conditioning.equilibrated_condition(jacobian)
    finite = bool(
        np.all(np.isfinite(seed.real))
        and np.all(np.isfinite(seed.imag))
        and math.isfinite(condition)
        and math.isfinite(relative_residual)
    )
    viable = (
        finite
        and relative_residual < RELATIVE_RESIDUAL_MAX
        and condition < JACOBIAN_CONDITION_MAX
        and minimum_separation > ROOT_SEPARATION_MIN
    )
    return {
        "normalization": ",".join(map(str, normalization)),
        "finite": int(finite),
        "relative_residual": relative_residual,
        "equilibrated_jacobian_condition": condition,
        "p_chordal_separation": p_sep,
        "f_chordal_separation": f_sep,
        "q_chordal_separation": q_sep,
        "pf_chordal_separation": pf_sep,
        "pq_chordal_separation": pq_sep,
        "fq_chordal_separation": fq_sep,
        "minimum_chordal_separation": minimum_separation,
        "maximum_root_abs": float(max(abs(value) for value in seed[1:])),
        "alpha_abs": float(abs(seed[0])),
        "viable": int(viable),
    }


def rank_charts(
    grouped: dict[str, dict[int, list[complex]]],
) -> tuple[list[dict[str, object]], dict[tuple[int, int, int], np.ndarray]]:
    seeds = {
        normalization: transform_seed(grouped, normalization)
        for normalization in NORMALIZATIONS
    }
    rows = [
        chart_metrics(normalization, seeds[normalization])
        for normalization in NORMALIZATIONS
    ]
    rows.sort(key=lambda row: (
        not bool(row["viable"]),
        float(row["relative_residual"]),
        float(row["equilibrated_jacobian_condition"]),
        -float(row["minimum_chordal_separation"]),
        str(row["normalization"]),
    ))
    for rank, row in enumerate(rows, start=1):
        row["rank"] = rank
        row["selected"] = int(rank == 1 and bool(row["viable"]))
    if not bool(rows[0]["viable"]):
        raise RuntimeError("no Möbius chart passes the predeclared seed gates")
    return rows, seeds


def render_census(
    source: Path,
    source_metadata: dict[str, str],
    rows: list[dict[str, object]],
) -> str:
    metadata = [
        "# format\tm23_8a_barth_wenz_root_chart_census_v1",
        f"# code_revision\t{git_revision()}",
        f"# source\t{source.relative_to(ROOT)}",
        f"# source_sha256\t{sha256(source)}",
        f"# source_result_archive_sha256\t"
        f"{source_metadata['result_archive_sha256']}",
        f"# python_version\t{platform.python_version()}",
        f"# numpy_version\t{np.__version__}",
        "# charts\tall six permutations of (4,2,1) at (0,1,infinity)",
        f"# relative_residual_gate_max\t{RELATIVE_RESIDUAL_MAX:.17g}",
        f"# jacobian_condition_gate_max\t{JACOBIAN_CONDITION_MAX:.17g}",
        f"# root_separation_gate_min\t{ROOT_SEPARATION_MIN:.17g}",
        "# selection\tviable first, then residual, condition, separation, label",
        "# interpretation\theuristic normalized numerical seeds; not Belyi maps",
    ]
    fields = list(rows[0])
    body = ["\t".join(fields)]
    for row in rows:
        body.append("\t".join(
            format(row[field], ".17g")
            if isinstance(row[field], float)
            else str(row[field])
            for field in fields
        ))
    return "\n".join([*metadata, *body, ""])


def render_seed(
    source: Path,
    selected: dict[str, object],
    seed: np.ndarray,
) -> str:
    normalization = str(selected["normalization"])
    metadata = [
        "# format=m23_8a_barth_wenz_root_seed_v1",
        f"# code_revision={git_revision()}",
        f"# source={source.relative_to(ROOT)}",
        f"# source_sha256={sha256(source)}",
        f"# normalization={normalization}",
        f"# relative_residual={float(selected['relative_residual']):.17g}",
        "# scale_fit=complex least squares on all 23 coefficient equations",
        "# interpretation=numerical Newton seed only; not a Belyi map",
        "name\treal\timag",
    ]
    metadata.extend(
        f"{name}\t{value.real:.17g}\t{value.imag:.17g}"
        for name, value in zip(ROOT_NAMES, seed)
    )
    return "\n".join([*metadata, ""])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dessin", type=Path, default=DEFAULT_DESSIN)
    parser.add_argument("--census-output", type=Path, required=True)
    parser.add_argument("--seed-output", type=Path, required=True)
    args = parser.parse_args()
    metadata, dessin_rows = read_dessin(args.dessin)
    rows, seeds = rank_charts(grouped_roots(dessin_rows))
    selected = next(row for row in rows if row["selected"] == 1)
    normalization = tuple(
        int(value) for value in str(selected["normalization"]).split(",")
    )
    args.census_output.write_text(
        render_census(args.dessin, metadata, rows), encoding="utf-8"
    )
    args.seed_output.write_text(
        render_seed(args.dessin, selected, seeds[normalization]),
        encoding="utf-8",
    )
    print(
        "selected normalization="
        f"{selected['normalization']} "
        f"relative_residual={selected['relative_residual']:.17g} "
        f"condition={selected['equilibrated_jacobian_condition']:.17g}"
    )


if __name__ == "__main__":
    main()
