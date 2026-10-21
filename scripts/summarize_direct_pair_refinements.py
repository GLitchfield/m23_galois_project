#!/usr/bin/env python3
"""Summarize stratified direct-pair refinement benchmark output."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


INTEGER_COLUMNS = (
    "segment",
    "class_index",
    "product_order",
    "segment_blocks",
    "sample",
    "ordinal",
    "refined_vertices",
    "generating_vertices",
    "refine_ms",
    "generation_ms",
)


def read_profile(path: Path) -> tuple[dict[str, str], list[dict[str, int]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    with path.open(encoding="utf-8") as source:
        for line in source:
            if line.startswith("# "):
                key, value = line[2:].rstrip("\n").split("\t", 1)
                metadata[key] = value
            elif not line.startswith("#"):
                data_lines.append(line)

    rows: list[dict[str, int]] = []
    for raw in csv.DictReader(data_lines, delimiter="\t"):
        rows.append({column: int(raw[column]) for column in INTEGER_COLUMNS})
    if not rows:
        raise ValueError(f"no benchmark rows in {path}")
    if metadata.get("schema") != "m23-direct-pair-refinement-benchmark-v1":
        raise ValueError(f"unsupported benchmark schema in {path}")
    return metadata, rows


def summarize(path: Path) -> dict[str, int | float | str]:
    metadata, rows = read_profile(path)
    groups: dict[int, list[dict[str, int]]] = defaultdict(list)
    for row in rows:
        groups[row["segment"]].append(row)

    macroblocks = int(metadata["macroblock_count"])

    def weighted_average(column: str) -> float:
        weighted_total = 0.0
        represented_blocks = 0
        for segment_rows in groups.values():
            segment_blocks = segment_rows[0]["segment_blocks"]
            if any(row["segment_blocks"] != segment_blocks for row in segment_rows):
                raise ValueError(f"inconsistent segment size in {path}")
            segment_mean = sum(row[column] for row in segment_rows) / len(segment_rows)
            weighted_total += segment_blocks * segment_mean
            represented_blocks += segment_blocks
        if represented_blocks != macroblocks:
            raise ValueError(
                f"segments represent {represented_blocks} blocks, expected {macroblocks}"
            )
        return weighted_total / macroblocks

    refine_ms = weighted_average("refine_ms")
    generation_ms = weighted_average("generation_ms")
    block_ms = refine_ms + generation_ms
    refined_per_block = weighted_average("refined_vertices")
    generating_per_block = weighted_average("generating_vertices")
    return {
        "path": str(path),
        "target_order": int(metadata["target_order"]),
        "macroblocks": macroblocks,
        "samples": len(rows),
        "locator_ms": int(metadata["locator_ms"]),
        "refine_ms_per_block": refine_ms,
        "generation_ms_per_block": generation_ms,
        "kernel_ms_per_block": block_ms,
        "kernel_blocks_per_second": 1000.0 / block_ms,
        "refined_vertices_per_block": refined_per_block,
        "generating_vertices_per_block": generating_per_block,
        "estimated_refined_vertices": refined_per_block * macroblocks,
        "estimated_generating_vertices": generating_per_block * macroblocks,
        "single_cpu_kernel_days": macroblocks * block_ms / 1000.0 / 86400.0,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("profiles", type=Path, nargs="+")
    args = parser.parse_args()

    columns = (
        "path",
        "target_order",
        "macroblocks",
        "samples",
        "locator_ms",
        "refine_ms_per_block",
        "generation_ms_per_block",
        "kernel_ms_per_block",
        "kernel_blocks_per_second",
        "refined_vertices_per_block",
        "generating_vertices_per_block",
        "estimated_refined_vertices",
        "estimated_generating_vertices",
        "single_cpu_kernel_days",
    )
    print("\t".join(columns))
    for path in args.profiles:
        row = summarize(path)
        print(
            "\t".join(
                f"{row[column]:.6f}" if isinstance(row[column], float) else str(row[column])
                for column in columns
            )
        )


if __name__ == "__main__":
    main()
