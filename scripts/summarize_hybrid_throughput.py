#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_measurement(path: Path) -> list[dict[str, float | int | str]]:
    rows = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if fields == ["backend", "workers", "completed_units", "elapsed_seconds"]:
            continue
        if len(fields) != 4 or fields[0] not in {"cpu", "gpu"}:
            raise ValueError(f"invalid throughput row {path}:{number}")
        workers, units = map(int, fields[1:3])
        elapsed = float(fields[3])
        if workers < 1 or units < 0 or elapsed <= 0:
            raise ValueError(f"invalid throughput values {path}:{number}")
        rows.append({"backend": fields[0], "workers": workers,
                     "units": units, "elapsed": elapsed})
    if not rows:
        raise ValueError(f"empty throughput measurement: {path}")
    return rows


def summarize(baseline_path: Path, hybrid_path: Path) -> dict[str, object]:
    baseline = read_measurement(baseline_path)
    hybrid = read_measurement(hybrid_path)
    if {row["backend"] for row in baseline} != {"cpu"} or \
            {row["backend"] for row in hybrid} != {"cpu", "gpu"}:
        raise ValueError("baseline must be CPU-only and hybrid must contain CPU and GPU")

    def wall(rows: list[dict[str, object]]) -> float:
        return max(float(row["elapsed"]) for row in rows)

    def units(rows: list[dict[str, object]]) -> int:
        return sum(int(row["units"]) for row in rows)

    def backend_rate(rows: list[dict[str, object]], backend: str) -> float:
        selected = [row for row in rows if row["backend"] == backend]
        return units(selected) / wall(selected)

    baseline_rate = units(baseline) / wall(baseline)
    hybrid_rate = units(hybrid) / wall(hybrid)
    baseline_cpu_workers = sum(int(row["workers"]) for row in baseline)
    hybrid_cpu = [row for row in hybrid if row["backend"] == "cpu"]
    hybrid_cpu_workers = sum(int(row["workers"]) for row in hybrid_cpu)
    baseline_cpu_per_worker = baseline_rate / baseline_cpu_workers
    hybrid_cpu_per_worker = backend_rate(hybrid, "cpu") / hybrid_cpu_workers
    gain = 100 * (hybrid_rate / baseline_rate - 1)
    slowdown = 100 * (1 - hybrid_cpu_per_worker / baseline_cpu_per_worker)
    return {
        "schema": "m23-hybrid-throughput-summary-v1",
        "baseline_units_per_second": round(baseline_rate, 6),
        "hybrid_units_per_second": round(hybrid_rate, 6),
        "hybrid_gain_percent": round(gain, 3),
        "hybrid_cpu_slowdown_percent": round(slowdown, 3),
        "gpu_units_per_second": round(backend_rate(hybrid, "gpu"), 6),
        "additive_improvement": gain > 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="compare CPU-only and simultaneous CPU/GPU throughput"
    )
    parser.add_argument("baseline", type=Path)
    parser.add_argument("hybrid", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.baseline, args.hybrid), sort_keys=True))


if __name__ == "__main__":
    main()
