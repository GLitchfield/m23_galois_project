#!/usr/bin/env python3
"""Measure the SQLite cost avoided by compact full-plan cursors."""

from __future__ import annotations

import argparse
import json
import sqlite3
import tempfile
import time
from pathlib import Path

from m23_quotient_ledger import Ledger


FULL_MACROBLOCKS = 161_177_452


def initialize(path: Path, macroblocks: int) -> None:
    ledger = Ledger(path)
    try:
        ledger.initialize({
            "target_order": 5,
            "pair_schema": 2,
            "macroblock_count": macroblocks,
            "first_ordinal": 1,
            "last_ordinal": macroblocks,
            "proof_limit": 1,
            "walk_limit": 1,
            "schedule": "frontier",
            "start_ordinal": 1,
            "traversal_order": "native-v1",
        })
    finally:
        ledger.close()


def benchmark(root: Path, rows: int, macroblocks: int,
              shards: int) -> dict[str, int | float | str]:
    if not 0 < rows <= macroblocks or shards <= 0:
        raise ValueError("invalid work-plan storage benchmark bounds")
    explicit = root / "explicit.sqlite3"
    compact = root / "compact.sqlite3"
    if explicit.exists() or compact.exists():
        raise FileExistsError("benchmark output databases must be fresh")
    initialize(explicit, macroblocks)
    initialize(compact, macroblocks)
    database = sqlite3.connect(explicit, timeout=300)
    started = time.monotonic()
    try:
        database.execute("BEGIN IMMEDIATE")
        database.executemany(
            "INSERT INTO frontier(ordinal) VALUES(?)",
            ((ordinal,) for ordinal in range(1, rows + 1)),
        )
        database.executemany(
            "INSERT INTO planned_work(ordinal,shard_index,shard_count) "
            "VALUES(?,?,?)",
            ((ordinal, 1 + (ordinal - 1) % shards, shards)
             for ordinal in range(1, rows + 1)),
        )
        database.commit()
        database.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    finally:
        database.close()
    elapsed = time.monotonic() - started
    explicit_bytes = explicit.stat().st_size
    compact_bytes = compact.stat().st_size
    marginal = explicit_bytes - compact_bytes
    return {
        "schema": "m23-native-work-plan-storage-benchmark-v1",
        "sample_rows": rows,
        "macroblock_count": macroblocks,
        "shards": shards,
        "explicit_database_bytes": explicit_bytes,
        "compact_database_bytes": compact_bytes,
        "marginal_explicit_bytes": marginal,
        "marginal_bytes_per_ordinal": round(marginal / rows, 3),
        "materialization_seconds": round(elapsed, 6),
        "linear_projected_full_bytes": round(marginal / rows * macroblocks),
        "linear_projected_full_seconds": round(elapsed / rows * macroblocks),
        "compact_materialized_plan_rows": 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="benchmark explicit versus compact native work plans"
    )
    parser.add_argument("--rows", type=int, default=1_000_000)
    parser.add_argument("--macroblocks", type=int, default=FULL_MACROBLOCKS)
    parser.add_argument("--shards", type=int, default=4)
    parser.add_argument("--directory", type=Path)
    args = parser.parse_args()
    if args.directory is None:
        with tempfile.TemporaryDirectory() as temporary:
            result = benchmark(
                Path(temporary), args.rows, args.macroblocks, args.shards
            )
    else:
        args.directory.mkdir(parents=True, exist_ok=True)
        result = benchmark(
            args.directory, args.rows, args.macroblocks, args.shards
        )
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
