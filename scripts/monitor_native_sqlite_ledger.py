#!/usr/bin/env python3
"""Emit dashboard-compatible progress from a live native SQLite ledger."""

from __future__ import annotations

import argparse
import sqlite3
import time
from pathlib import Path


def read_stats(path: Path) -> tuple[int, int, int, int]:
    database = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30)
    try:
        row = database.execute(
            "SELECT (SELECT COUNT(*) FROM blocks),"
            "(SELECT COUNT(*) FROM certificates),"
            "(SELECT COUNT(*) FROM vertices),"
            "COALESCE((SELECT ordinal FROM blocks ORDER BY sequence DESC "
            "LIMIT 1),0)"
        ).fetchone()
    finally:
        database.close()
    return tuple(map(int, row))


def monitor(path: Path, target: int, interval: float) -> None:
    previous_blocks = 0
    previous_time = time.monotonic()
    while True:
        try:
            blocks, certificates, vertices, latest = read_stats(path)
        except (OSError, sqlite3.Error):
            time.sleep(interval)
            continue
        now = time.monotonic()
        elapsed_per_block = 0.0
        if blocks > previous_blocks:
            elapsed_per_block = (now - previous_time) / (blocks - previous_blocks)
            previous_blocks = blocks
            previous_time = now
        print(
            f"progress\t{blocks}\t{target}\t{latest}\t"
            f"{elapsed_per_block:.6f}\t{certificates}\t{vertices}",
            flush=True,
        )
        time.sleep(interval)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="monitor a live native SQLite ledger"
    )
    parser.add_argument("ledger", type=Path)
    parser.add_argument("target", type=int)
    parser.add_argument("--interval", type=float, default=5.0)
    args = parser.parse_args()
    if args.target <= 0 or args.interval <= 0:
        parser.error("target and interval must be positive")
    monitor(args.ledger, args.target, args.interval)


if __name__ == "__main__":
    main()
