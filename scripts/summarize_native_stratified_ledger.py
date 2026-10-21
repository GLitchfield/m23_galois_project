#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path


def summarize(path: Path) -> dict[str, object]:
    metadata: dict[str, str] = {}
    samples: dict[int, dict[str, int]] = {}
    blocks: dict[int, dict[str, int]] = {}
    timings: dict[int, dict[str, float | int]] = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        fields = line.split("\t")
        if fields[0].startswith("# ") and len(fields) == 2:
            metadata[fields[0][2:]] = fields[1]
        elif fields[0] == "S" and len(fields) == 6:
            segment, class_index, segment_blocks, sample, ordinal = \
                map(int, fields[1:])
            if ordinal in samples:
                raise ValueError(f"duplicate sample ordinal at line {number}")
            samples[ordinal] = {
                "segment": segment,
                "class_index": class_index,
                "segment_blocks": segment_blocks,
                "sample": sample,
            }
        elif fields[0] == "B" and len(fields) == 7:
            ordinal = int(fields[1])
            blocks[ordinal] = {
                "refined": int(fields[3]),
                "generating": int(fields[4]),
                "certificates": int(fields[5]),
                "hits": int(fields[6]),
            }
        elif fields[0] == "T" and len(fields) == 8:
            ordinal = int(fields[1])
            timings[ordinal] = {
                "seconds": float(fields[2]),
                "refinement_seconds": float(fields[3]),
                "generation_seconds": float(fields[4]),
                "traversal_seconds": float(fields[5]),
                "certificates": int(fields[6]),
                "owned_vertices": int(fields[7]),
            }
        elif fields[0] in {"C", "V"} or fields == [""]:
            continue
        elif not fields[0].startswith("#"):
            raise ValueError(f"unknown stratified transcript row at line {number}")

    if metadata.get("schema") != "m23-native-ledger-stratified-v1" or \
            metadata.get("identity_block_excluded") != "1" or not samples:
        raise ValueError("unsupported or incomplete native stratified transcript")
    if set(blocks) != set(samples) or set(timings) != set(samples):
        raise ValueError("stratified transcript has incomplete sampled blocks")

    strata: dict[int, list[int]] = defaultdict(list)
    for ordinal, row in samples.items():
        strata[row["segment"]].append(ordinal)
    weighted_seconds = 0.0
    weighted_kernel_seconds = 0.0
    weighted_refined = 0.0
    weighted_generating = 0.0
    rows = []
    for segment in sorted(strata):
        ordinals = strata[segment]
        sample = samples[ordinals[0]]
        extent = sample["segment_blocks"]
        if any(samples[ordinal]["segment_blocks"] != extent
               for ordinal in ordinals):
            raise ValueError("sampled segment extents disagree")
        elapsed = sum(float(timings[ordinal]["seconds"])
                      for ordinal in ordinals) / len(ordinals)
        kernel = sum(float(timings[ordinal]["refinement_seconds"]) +
                     float(timings[ordinal]["generation_seconds"])
                     for ordinal in ordinals) / len(ordinals)
        refined = sum(blocks[ordinal]["refined"]
                      for ordinal in ordinals) / len(ordinals)
        generating = sum(blocks[ordinal]["generating"]
                         for ordinal in ordinals) / len(ordinals)
        weighted_seconds += extent * elapsed
        weighted_kernel_seconds += extent * kernel
        weighted_refined += extent * refined
        weighted_generating += extent * generating
        rows.append({
            "segment": segment,
            "class_index": sample["class_index"],
            "segment_blocks": extent,
            "samples": len(ordinals),
            "mean_seconds": round(elapsed, 6),
            "mean_kernel_seconds": round(kernel, 6),
            "mean_refined_vertices": round(refined, 3),
            "mean_generating_vertices": round(generating, 3),
        })
    sampled_seconds = sum(float(row["seconds"]) for row in timings.values())
    traversal_seconds = sum(float(row["traversal_seconds"])
                            for row in timings.values())
    owned_vertices = sum(int(row["owned_vertices"]) for row in timings.values())
    represented_blocks = sum(row["segment_blocks"] for row in rows)
    macroblock_count = int(metadata["macroblock_count"])
    if represented_blocks != macroblock_count - 1:
        raise ValueError("stratified segments do not cover every nonidentity block")
    if traversal_seconds <= 0 or owned_vertices <= 0:
        raise ValueError("stratified transcript has no traversal throughput")
    seconds_per_owned_vertex = traversal_seconds / owned_vertices
    amortized_traversal_seconds = weighted_generating * seconds_per_owned_vertex
    amortized_single_worker_seconds = (weighted_kernel_seconds +
                                       amortized_traversal_seconds)
    sample_labels = sorted(set.intersection(*(
        {samples[ordinal]["sample"] for ordinal in ordinals}
        for ordinals in strata.values()
    )))
    sensitivity = []
    for label in sample_labels:
        column_kernel = 0.0
        column_generating = 0.0
        for segment, ordinals in strata.items():
            ordinal = next(
                ordinal for ordinal in ordinals
                if samples[ordinal]["sample"] == label
            )
            extent = samples[ordinal]["segment_blocks"]
            column_kernel += extent * (
                float(timings[ordinal]["refinement_seconds"]) +
                float(timings[ordinal]["generation_seconds"])
            )
            column_generating += extent * blocks[ordinal]["generating"]
        column_total = (column_kernel +
                        column_generating * seconds_per_owned_vertex)
        sensitivity.append({
            "sample": label,
            "weighted_generating_vertices": round(column_generating),
            "amortized_single_worker_days": round(column_total / 86400, 3),
        })
    return {
        "schema": "m23-native-stratified-summary-v1",
        "source_checkpoint_sha256": metadata["source_checkpoint_sha256"],
        "sampled_blocks": len(samples),
        "represented_nonidentity_blocks": represented_blocks,
        "sampled_seconds": round(sampled_seconds, 6),
        "observed_blocks_per_second": round(len(samples) / sampled_seconds, 6),
        "weighted_single_worker_seconds": round(weighted_seconds, 3),
        "weighted_single_worker_days": round(weighted_seconds / 86400, 3),
        "weighted_kernel_seconds": round(weighted_kernel_seconds, 3),
        "weighted_kernel_days": round(weighted_kernel_seconds / 86400, 3),
        "sampled_traversal_seconds": round(traversal_seconds, 6),
        "sampled_owned_vertices": owned_vertices,
        "traversal_vertices_per_second": round(
            owned_vertices / traversal_seconds, 3),
        "amortized_traversal_seconds": round(amortized_traversal_seconds, 3),
        "amortized_traversal_days": round(
            amortized_traversal_seconds / 86400, 3),
        "amortized_single_worker_seconds": round(
            amortized_single_worker_seconds, 3),
        "amortized_single_worker_days": round(
            amortized_single_worker_seconds / 86400, 3),
        "weighted_refined_vertices": round(weighted_refined),
        "weighted_generating_vertices": round(weighted_generating),
        "systematic_sample_sensitivity": sensitivity,
        "systematic_sample_day_range": [
            min(row["amortized_single_worker_days"] for row in sensitivity),
            max(row["amortized_single_worker_days"] for row in sensitivity),
        ],
        "strata": rows,
        "interpretation": (
            "kernel is segment-weighted; traversal is amortized once per "
            "estimated generating vertex from sparse-sample owned-vertex rate; "
            "SQLite commits, parallel contention, replay, and the exceptional "
            "identity block remain separate"
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="summarize a native class-stratified ledger transcript"
    )
    parser.add_argument("transcript", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.transcript), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
