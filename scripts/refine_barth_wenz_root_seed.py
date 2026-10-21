#!/usr/bin/env python3
"""Run a bounded, chart-aware Newton refinement on a Barth--Wenz root seed."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
from pathlib import Path
import platform
import subprocess

import numpy as np

import census_8a_belyi_conditioning as conditioning
import pilot_8a_belyi_numeric as pilot
import prepare_barth_wenz_root_seed as prepare


ROOT = Path(__file__).resolve().parents[1]
RELATIVE_RESIDUAL_MAX = 1e-10
ROOT_SEPARATION_MIN = 1e-8
ALPHA_ABS_MIN = 1e-8
JACOBIAN_CONDITION_MAX = 1e16


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


def read_seed(path: Path) -> tuple[dict[str, str], np.ndarray]:
    metadata: dict[str, str] = {}
    values: dict[str, complex] = {}
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("# "):
                key, value = line[2:].rstrip("\n").split("=", 1)
                metadata[key] = value
                continue
            if not line.strip() or line.startswith("name\t"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 3 or fields[0] in values:
                raise RuntimeError("malformed or duplicate seed row")
            values[fields[0]] = complex(float(fields[1]), float(fields[2]))
    if metadata.get("format") != "m23_8a_barth_wenz_root_seed_v1":
        raise RuntimeError("unexpected root-seed format")
    if set(values) != set(prepare.ROOT_NAMES):
        raise RuntimeError("root seed has unexpected variable names")
    return metadata, np.array(
        [values[name] for name in prepare.ROOT_NAMES], dtype=complex
    )


def normalization_from(metadata: dict[str, str]) -> tuple[int, int, int]:
    normalization = tuple(
        int(value) for value in metadata["normalization"].split(",")
    )
    if tuple(sorted(normalization)) != (1, 2, 4):
        raise RuntimeError("invalid root-seed normalization")
    return normalization


def metrics(
    point: np.ndarray,
    normalization: tuple[int, int, int],
) -> dict[str, float]:
    residual, jacobian, parts = pilot.residual_jac(point, normalization)
    p_sep, f_sep, q_sep, pf_sep, pq_sep, fq_sep = (
        prepare.minimum_separations(point)
    )
    return {
        "absolute_residual_2norm": float(np.linalg.norm(residual)),
        "relative_residual": float(
            np.linalg.norm(residual)
            / max(np.linalg.norm(part) for part in parts)
        ),
        "equilibrated_jacobian_condition":
            conditioning.equilibrated_condition(jacobian),
        "p_chordal_separation": p_sep,
        "f_chordal_separation": f_sep,
        "q_chordal_separation": q_sep,
        "pf_chordal_separation": pf_sep,
        "pq_chordal_separation": pq_sep,
        "fq_chordal_separation": fq_sep,
        "minimum_chordal_separation": min(
            p_sep, f_sep, q_sep, pf_sep, pq_sep, fq_sep
        ),
        "alpha_abs": float(abs(point[0])),
        "maximum_root_abs": float(max(abs(value) for value in point[1:])),
    }


def accepted(point: np.ndarray, result: dict[str, float]) -> bool:
    return bool(
        np.all(np.isfinite(point.real))
        and np.all(np.isfinite(point.imag))
        and result["relative_residual"] < RELATIVE_RESIDUAL_MAX
        and result["minimum_chordal_separation"] > ROOT_SEPARATION_MIN
        and result["alpha_abs"] > ALPHA_ABS_MIN
        and result["equilibrated_jacobian_condition"]
        < JACOBIAN_CONDITION_MAX
    )


def render_summary(
    seed_path: Path,
    normalization: tuple[int, int, int],
    max_iterations: int,
    history: list[tuple[int, float, float]],
    initial: dict[str, float],
    final: dict[str, float],
    verdict: str,
) -> str:
    metadata = [
        "# format\tm23_8a_barth_wenz_newton_summary_v1",
        f"# code_revision\t{git_revision()}",
        f"# seed\t{display_path(seed_path)}",
        f"# seed_sha256\t{sha256(seed_path)}",
        f"# python_version\t{platform.python_version()}",
        f"# numpy_version\t{np.__version__}",
        f"# normalization\t{','.join(map(str, normalization))}",
        f"# maximum_iterations\t{max_iterations}",
        f"# relative_residual_gate_max\t{RELATIVE_RESIDUAL_MAX:.17g}",
        f"# root_separation_gate_min\t{ROOT_SEPARATION_MIN:.17g}",
        f"# alpha_abs_gate_min\t{ALPHA_ABS_MIN:.17g}",
        f"# jacobian_condition_gate_max\t"
        f"{JACOBIAN_CONDITION_MAX:.17g}",
        "# interpretation\tbounded numerical refinement; not exact recognition",
    ]
    row = {
        "verdict": verdict,
        "accepted_steps": len(history) - 1,
        "initial_relative_residual": initial["relative_residual"],
        "final_relative_residual": final["relative_residual"],
        "final_absolute_residual_2norm": final["absolute_residual_2norm"],
        "final_equilibrated_jacobian_condition":
            final["equilibrated_jacobian_condition"],
        "final_p_chordal_separation": final["p_chordal_separation"],
        "final_f_chordal_separation": final["f_chordal_separation"],
        "final_q_chordal_separation": final["q_chordal_separation"],
        "final_pf_chordal_separation": final["pf_chordal_separation"],
        "final_pq_chordal_separation": final["pq_chordal_separation"],
        "final_fq_chordal_separation": final["fq_chordal_separation"],
        "final_minimum_chordal_separation":
            final["minimum_chordal_separation"],
        "final_alpha_abs": final["alpha_abs"],
        "final_maximum_root_abs": final["maximum_root_abs"],
    }
    fields = list(row)
    values = [
        format(row[field], ".17g")
        if isinstance(row[field], float)
        else str(row[field])
        for field in fields
    ]
    return "\n".join([*metadata, "\t".join(fields), "\t".join(values), ""])


def render_endpoint(
    seed_path: Path,
    normalization: tuple[int, int, int],
    point: np.ndarray,
    final: dict[str, float],
) -> str:
    lines = [
        "# format=m23_8a_barth_wenz_newton_endpoint_v1",
        f"# code_revision={git_revision()}",
        f"# seed={display_path(seed_path)}",
        f"# seed_sha256={sha256(seed_path)}",
        f"# normalization={','.join(map(str, normalization))}",
        f"# relative_residual={final['relative_residual']:.17g}",
        f"# minimum_chordal_separation="
        f"{final['minimum_chordal_separation']:.17g}",
        f"# equilibrated_jacobian_condition="
        f"{final['equilibrated_jacobian_condition']:.17g}",
        "# interpretation=nondegenerate approximate candidate; not exact",
        "name\treal\timag",
    ]
    lines.extend(
        f"{name}\t{value.real:.17g}\t{value.imag:.17g}"
        for name, value in zip(prepare.ROOT_NAMES, point)
    )
    return "\n".join([*lines, ""])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("seed", type=Path)
    parser.add_argument("--maximum-iterations", type=int, default=100)
    parser.add_argument("--summary-output", type=Path, required=True)
    parser.add_argument("--endpoint-output", type=Path, required=True)
    args = parser.parse_args()
    if args.maximum_iterations <= 0:
        parser.error("--maximum-iterations must be positive")
    seed_metadata, seed = read_seed(args.seed)
    normalization = normalization_from(seed_metadata)
    initial = metrics(seed, normalization)
    endpoint, history = pilot.newton(
        seed,
        args.maximum_iterations,
        normalization=normalization,
    )
    final = metrics(endpoint, normalization)
    verdict = "accepted_numerical_candidate" if accepted(
        endpoint, final
    ) else "rejected"
    args.summary_output.write_text(
        render_summary(
            args.seed,
            normalization,
            args.maximum_iterations,
            history,
            initial,
            final,
            verdict,
        ),
        encoding="utf-8",
    )
    args.endpoint_output.write_text(
        render_endpoint(args.seed, normalization, endpoint, final),
        encoding="utf-8",
    )
    print(
        f"verdict={verdict} accepted_steps={len(history) - 1} "
        f"relative_residual={final['relative_residual']:.17g} "
        f"minimum_separation={final['minimum_chordal_separation']:.17g}"
    )


if __name__ == "__main__":
    main()
