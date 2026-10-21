#!/usr/bin/env python3
"""Partition immutable certificate IDs by a deterministic replay-cost model."""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path
from typing import Iterable


def partition_rows(
    rows: Iterable[tuple[int, int]], workers: int
) -> list[tuple[int, int, int]]:
    values = list(rows)
    if workers <= 0:
        raise ValueError("worker count must be positive")
    if len(values) < workers:
        raise ValueError("replay workers exceed the nonempty certificate ledger")
    if any(weight <= 0 for _, weight in values):
        raise ValueError("certificate replay weights must be positive")
    ids = [certificate_id for certificate_id, _ in values]
    if ids != list(range(1, len(values) + 1)):
        raise ValueError("certificate IDs are not the contiguous immutable prefix")

    total = sum(weight for _, weight in values)
    result: list[tuple[int, int, int]] = []
    first_index = 0
    prefix = 0
    for shard in range(1, workers):
        target = total * shard / workers
        maximum = len(values) - (workers - shard)
        last_index = first_index
        while last_index + 1 < maximum:
            next_prefix = prefix + values[last_index][1]
            if next_prefix >= target:
                without = abs(target - prefix)
                with_current = abs(next_prefix - target)
                if with_current <= without or last_index == first_index:
                    prefix = next_prefix
                    last_index += 1
                break
            prefix = next_prefix
            last_index += 1
        if last_index == first_index:
            prefix += values[last_index][1]
            last_index += 1
        work = sum(weight for _, weight in values[first_index:last_index])
        result.append((values[first_index][0], values[last_index - 1][0], work))
        first_index = last_index

    work = sum(weight for _, weight in values[first_index:])
    result.append((values[first_index][0], values[-1][0], work))
    return result


def partition_ledger(
    path: Path, workers: int, certificate_overhead: int
) -> list[tuple[int, int, int]]:
    if certificate_overhead < 0:
        raise ValueError("certificate overhead must be nonnegative")
    database = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        rows = database.execute(
            "SELECT id, discovered_vertices + ? FROM certificates ORDER BY id",
            (certificate_overhead,),
        ).fetchall()
    finally:
        database.close()
    return partition_rows(rows, workers)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="partition native certificate replay by deterministic cost"
    )
    parser.add_argument("ledger", type=Path)
    parser.add_argument("workers", type=int)
    parser.add_argument(
        "--certificate-overhead",
        type=int,
        default=96,
        help="fixed replay cost in discovered-vertex equivalents (default: 96)",
    )
    args = parser.parse_args()
    for shard, (first, last, work) in enumerate(
        partition_ledger(args.ledger, args.workers, args.certificate_overhead),
        start=1,
    ):
        print(f"{shard}\t{first}\t{last}\t{work}")


if __name__ == "__main__":
    main()
