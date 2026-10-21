#!/usr/bin/env python3
"""Summarize a completed native mixed scan/replay wave."""

from __future__ import annotations

import argparse
import csv
import json
import re
import statistics
from collections import defaultdict
from pathlib import Path


COUNTERS = re.compile(r"^added=(\d+),hits=(\d+)$")


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        raise ValueError("cannot take a percentile of no values")
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (
        position - lower
    )


def read_plan(path: Path) -> tuple[dict[str, str], dict[int, dict[str, int]]]:
    metadata: dict[str, str] = {}
    rows: dict[int, dict[str, int]] = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        fields = line.split("\t")
        if fields[0].startswith("# ") and len(fields) == 2:
            metadata[fields[0][2:]] = fields[1]
        elif fields[0] == "S" and len(fields) == 6:
            segment, class_index, segment_blocks, sample, ordinal = map(
                int, fields[1:]
            )
            if ordinal in rows:
                raise ValueError(f"duplicate plan ordinal at line {number}")
            rows[ordinal] = {
                "segment": segment,
                "class_index": class_index,
                "segment_blocks": segment_blocks,
                "sample": sample,
            }
    if metadata.get("schema") != "m23-native-ledger-stratified-v1" or \
            len(rows) != int(metadata.get("block_count", "0")):
        raise ValueError("mixed-wave plan is incomplete")
    return metadata, rows


def read_scan(run_dir: Path, plan: dict[int, dict[str, int]]) \
        -> dict[int, dict[str, float | int]]:
    rows: dict[int, dict[str, float | int]] = {}
    paths = sorted(run_dir.glob("scan*/worker-*.log"))
    for path in paths:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            fields = line.split("\t")
            if not fields or fields[0] != "progress":
                continue
            if len(fields) != 8:
                raise ValueError(f"invalid scan progress at {path}:{number}")
            ordinal = int(fields[3])
            match = COUNTERS.fullmatch(fields[7])
            if ordinal not in plan or ordinal in rows or match is None:
                raise ValueError(f"inconsistent scan progress at {path}:{number}")
            rows[ordinal] = {
                "seconds": float(fields[4]),
                "added": int(match.group(1)),
                "hits": int(match.group(2)),
            }
    if set(rows) != set(plan):
        raise ValueError("scan logs do not cover the complete mixed-wave plan")
    return rows


def read_replay(run_dir: Path) -> list[dict[str, float | int]]:
    rows = []
    for path in sorted((run_dir / "final-replay").glob("replay-*.log")):
        planned = None
        complete = None
        for line in path.read_text().splitlines():
            fields = line.split("\t")
            if fields[0] == "range" and len(fields) == 5:
                planned = tuple(map(int, fields[1:]))
            elif fields[0] == "complete" and len(fields) == 5:
                complete = (
                    int(fields[1]), int(fields[2]), int(fields[3]),
                    float(fields[4]),
                )
        if planned is None or complete is None or \
                planned[1:3] != complete[0:2]:
            raise ValueError(f"incomplete replay log: {path}")
        rows.append({
            "shard": planned[0], "first_certificate": planned[1],
            "last_certificate": planned[2], "modeled_work": planned[3],
            "vertices": complete[2], "seconds": round(complete[3], 6),
        })
    if not rows:
        raise ValueError("mixed wave has no final replay logs")
    return rows


def read_resources(path: Path) -> dict[str, int]:
    rows = list(csv.DictReader(path.open(), delimiter="\t"))
    if not rows:
        raise ValueError("mixed wave has no resource samples")
    peak = max(rows, key=lambda row: int(row["mixed_rss_kib"]))
    low = min(rows, key=lambda row: int(row["mem_available_kib"]))
    return {
        "samples": len(rows),
        "peak_processes": int(peak["mixed_processes"]),
        "peak_rss_kib": int(peak["mixed_rss_kib"]),
        "minimum_available_kib": int(low["mem_available_kib"]),
        "minimum_swap_free_kib": min(int(row["swap_free_kib"])
                                     for row in rows),
        "maximum_swap_free_kib": max(int(row["swap_free_kib"])
                                     for row in rows),
    }


def summarize(run_dir: Path, projected_vertices: int) -> dict[str, object]:
    result = json.loads((run_dir / "result.json").read_text())
    metadata, plan = read_plan(run_dir / "plan.tsv")
    scan = read_scan(run_dir, plan)
    replay = read_replay(run_dir)
    resources = read_resources(run_dir / "resource-samples.tsv")
    scan_paths = sorted(run_dir.glob("scan*/worker-*.log"))
    strata: dict[int, list[int]] = defaultdict(list)
    for ordinal, row in plan.items():
        strata[row["segment"]].append(ordinal)
    stratum_rows = []
    for segment in sorted(strata):
        ordinals = strata[segment]
        seconds = [float(scan[ordinal]["seconds"]) for ordinal in ordinals]
        first = plan[ordinals[0]]
        stratum_rows.append({
            "segment": segment,
            "class_index": first["class_index"],
            "represented_blocks": first["segment_blocks"],
            "sampled_blocks": len(ordinals),
            "mean_seconds": round(statistics.fmean(seconds), 6),
            "median_seconds": round(statistics.median(seconds), 6),
            "p95_seconds": round(percentile(seconds, 0.95), 6),
            "max_seconds": round(max(seconds), 6),
            "added_certificates": sum(int(scan[ordinal]["added"])
                                      for ordinal in ordinals),
            "ledger_hits": sum(int(scan[ordinal]["hits"])
                               for ordinal in ordinals),
        })
    represented = sum(row["represented_blocks"] for row in stratum_rows)
    if represented != int(metadata["macroblock_count"]) - 1:
        raise ValueError("mixed-wave strata do not represent the nonidentity space")
    total_added = sum(int(row["added"]) for row in scan.values())
    if total_added != int(result["certificates"]):
        raise ValueError("scan certificate accounting differs from final ledger")
    replay_wall = int(result["final_replay_seconds"])
    vertices = int(result["vertices"])
    database_bytes = (run_dir / "ledger.sqlite3").stat().st_size
    projected_replay = replay_wall * projected_vertices / vertices
    result_shards = result.get("shards", [])
    scan_workers = len(result_shards) if result_shards else max(
        len(list(path.parent.glob("worker-*.log"))) for path in scan_paths
    )
    return {
        "schema": "m23-native-mixed-wave-summary-v1",
        "result_schema": result["schema"],
        "plan_sha256": result["metadata"]["native_work_plan_sha256"],
        "database_sha256": result["database_sha256"],
        "source_checkpoint_sha256": metadata["source_checkpoint_sha256"],
        "blocks": int(result["blocks"]),
        "represented_nonidentity_blocks": represented,
        "scan_workers": scan_workers,
        "writer_mode": result.get("writer_mode", "direct"),
        "scan_wall_seconds": int(result["scan_seconds"]),
        "scan_block_cpu_seconds": round(sum(
            float(row["seconds"]) for row in scan.values()), 6),
        "certificates": int(result["certificates"]),
        "vertices": vertices,
        "statuses": result["statuses"],
        "final_replay_wall_seconds": replay_wall,
        "replay_vertices_per_wall_second": round(vertices / replay_wall, 3),
        "projected_vertices": projected_vertices,
        "linear_projected_replay_seconds": round(projected_replay),
        "linear_projected_replay_hours": round(projected_replay / 3600, 3),
        "database_bytes": database_bytes,
        "database_bytes_per_vertex": round(database_bytes / vertices, 3),
        "linear_projected_database_bytes": round(
            database_bytes / vertices * projected_vertices
        ),
        "resources": resources,
        "replay_shards": replay,
        "strata": stratum_rows,
        "interpretation": (
            "the systematic blocks characterize live persistence and tail "
            "costs; raw sampled blocks/second must not be multiplied across "
            "the full macroblock census because component traversal is "
            "amortized globally; replay and database projections are linear "
            "in owned vertices and remain provisional until a larger wave"
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="summarize a native mixed wave")
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("--projected-vertices", type=int, default=255_977_929)
    args = parser.parse_args()
    if args.projected_vertices <= 0:
        parser.error("projected vertices must be positive")
    print(json.dumps(
        summarize(args.run_dir, args.projected_vertices),
        indent=2, sort_keys=True,
    ))


if __name__ == "__main__":
    main()
