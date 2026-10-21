#!/usr/bin/env python3
"""Summarize the latest cumulative GAP quotient profile for each worker."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


PHASES = ("claim_ms", "refine_ms", "seed_ms", "walk_ms", "commit_ms", "finish_ms")


def parse_detail(detail: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for item in detail.split(","):
        key, value = item.split("=", 1)
        fields[key] = value
    return fields


def read_latest_profiles(path: Path) -> dict[str, dict[str, str]]:
    latest: dict[str, dict[str, str]] = {}
    with path.open(encoding="utf-8") as source:
        for row in csv.reader(source, delimiter="\t"):
            if len(row) < 6 or row[2] != "quotient_db_scan" or row[4] != "profile":
                continue
            fields = parse_detail(row[5])
            latest[fields["worker"]] = fields
    return latest


def summarize(path: Path) -> list[dict[str, int | float | str]]:
    rows = []
    for worker, fields in sorted(read_latest_profiles(path).items()):
        phase_values = {phase: int(fields[phase]) for phase in PHASES}
        total_ms = sum(phase_values.values())
        row: dict[str, int | float | str] = {
            "worker": worker,
            "blocks": int(fields["blocks"]),
            "traversals": int(fields["traversals"]),
            "profiled_ms": total_ms,
        }
        for phase, value in phase_values.items():
            row[phase] = value
            row[phase.removesuffix("_ms") + "_percent"] = (
                round(100.0 * value / total_ms, 2) if total_ms else 0.0
            )
        rows.append(row)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("progress", type=Path)
    args = parser.parse_args()
    rows = summarize(args.progress)
    if not rows:
        raise SystemExit("no quotient profile events found")
    columns = ["worker", "blocks", "traversals", "profiled_ms"]
    for phase in PHASES:
        columns.extend((phase, phase.removesuffix("_ms") + "_percent"))
    print("\t".join(columns))
    for row in rows:
        print("\t".join(str(row[column]) for column in columns))


if __name__ == "__main__":
    main()
