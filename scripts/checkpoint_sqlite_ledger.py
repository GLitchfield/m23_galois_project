#!/usr/bin/env python3
"""Checkpoint and truncate a quiescent native SQLite WAL."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path


def size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def checkpoint(path: Path) -> dict[str, int | str]:
    wal = Path(str(path) + "-wal")
    before_database = size(path)
    before_wal = size(wal)
    database = sqlite3.connect(path, timeout=300)
    try:
        database.execute("PRAGMA busy_timeout=300000")
        busy, pages, checkpointed = database.execute(
            "PRAGMA wal_checkpoint(TRUNCATE)"
        ).fetchone()
        quick = database.execute("PRAGMA quick_check").fetchone()[0]
        foreign = database.execute("PRAGMA foreign_key_check").fetchall()
        if busy != 0 or pages != checkpointed or quick != "ok" or foreign:
            raise ValueError(
                "incomplete SQLite checkpoint "
                f"busy={busy} pages={pages} checkpointed={checkpointed} "
                f"quick={quick} foreign={len(foreign)}"
            )
    finally:
        database.close()
    return {
        "schema": "m23-native-sqlite-checkpoint-v1",
        "database_bytes_before": before_database,
        "wal_bytes_before": before_wal,
        "database_bytes_after": size(path),
        "wal_bytes_after": size(wal),
        "checkpoint_pages": int(checkpointed),
        "quick_check": "ok",
        "foreign_key_violations": 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="checkpoint and truncate a quiescent native SQLite WAL"
    )
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args()
    print(json.dumps(checkpoint(args.ledger), sort_keys=True))


if __name__ == "__main__":
    main()
