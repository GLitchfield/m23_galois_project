#!/usr/bin/env python3
"""Create and validate a consistent read-only replay snapshot."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path


def snapshot(source: Path, destination: Path) -> dict[str, int | str]:
    if destination.exists():
        raise FileExistsError(f"refusing to overwrite snapshot: {destination}")
    source_db = sqlite3.connect(f"file:{source}?mode=ro", uri=True, timeout=300)
    destination_db = sqlite3.connect(destination)
    try:
        source_db.execute("PRAGMA busy_timeout=300000")
        source_db.backup(destination_db, pages=4096, sleep=0.05)
        quick = destination_db.execute("PRAGMA quick_check").fetchone()[0]
        foreign = destination_db.execute("PRAGMA foreign_key_check").fetchall()
        blocks, certificates, vertices = destination_db.execute(
            "SELECT (SELECT COUNT(*) FROM blocks),"
            "(SELECT COUNT(*) FROM certificates),"
            "(SELECT COUNT(*) FROM vertices)"
        ).fetchone()
        if quick != "ok" or foreign:
            raise ValueError(
                f"invalid SQLite snapshot quick={quick} foreign={len(foreign)}"
            )
    except Exception:
        destination_db.close()
        source_db.close()
        destination.unlink(missing_ok=True)
        raise
    destination_db.close()
    source_db.close()
    return {
        "schema": "m23-native-sqlite-snapshot-v1",
        "blocks": int(blocks),
        "certificates": int(certificates),
        "vertices": int(vertices),
        "quick_check": "ok",
        "foreign_key_violations": 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="snapshot a live native SQLite ledger for replay"
    )
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(json.dumps(snapshot(args.source, args.destination), sort_keys=True))


if __name__ == "__main__":
    main()
