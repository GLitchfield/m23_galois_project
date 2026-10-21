#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path


TABLES = {
    "certificates": (
        "id,status,walk_status,linked_certificate,seed_ordinal,seed_twist,"
        "checked_vertices,discovered_vertices,discovered_classes"
    ),
    "vertices": "ordinal,twist,certificate",
    "certificate_vertices": "certificate,position,ordinal,twist",
    "blocks": (
        "sequence,ordinal,refined_vertices,generating_vertices,"
        "new_certificates,ledger_hits"
    ),
}


def compare(actual: Path, expected: Path) -> dict[str, object]:
    db = sqlite3.connect(
        f"file:{actual.resolve()}?mode=ro", uri=True, timeout=300
    )
    try:
        db.execute("ATTACH DATABASE ? AS expected", (
            f"file:{expected.resolve()}?mode=ro",
        ))
        differences = {}
        for table, columns in TABLES.items():
            forward = db.execute(
                f"SELECT COUNT(*) FROM ("
                f"SELECT {columns} FROM main.{table} EXCEPT "
                f"SELECT {columns} FROM expected.{table})"
            ).fetchone()[0]
            reverse = db.execute(
                f"SELECT COUNT(*) FROM ("
                f"SELECT {columns} FROM expected.{table} EXCEPT "
                f"SELECT {columns} FROM main.{table})"
            ).fetchone()[0]
            differences[table] = {
                "actual_only": forward,
                "expected_only": reverse,
            }
        source = db.execute(
            "SELECT value FROM main.meta "
            "WHERE key='native_source_checkpoint_sha256'"
        ).fetchone()
        expected_source = db.execute(
            "SELECT value FROM expected.meta "
            "WHERE key='native_source_checkpoint_sha256'"
        ).fetchone()
        integrity = {
            "actual_quick_check":
                db.execute("PRAGMA main.quick_check").fetchone()[0],
            "actual_foreign_keys":
                len(db.execute("PRAGMA main.foreign_key_check").fetchall()),
            "expected_quick_check":
                db.execute("PRAGMA expected.quick_check").fetchone()[0],
            "expected_foreign_keys":
                len(db.execute("PRAGMA expected.foreign_key_check").fetchall()),
        }
    finally:
        db.close()
    exact = source is not None and source == expected_source and \
        all(row == {"actual_only": 0, "expected_only": 0}
            for row in differences.values()) and \
        integrity == {
            "actual_quick_check": "ok", "actual_foreign_keys": 0,
            "expected_quick_check": "ok", "expected_foreign_keys": 0,
        }
    result = {
        "schema": "m23-native-ledger-comparison-v1",
        "exact": exact,
        "source_checkpoint_sha256": source[0] if source else None,
        "differences": differences,
        "integrity": integrity,
    }
    if not exact:
        raise ValueError(json.dumps(result, sort_keys=True))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="compare native live and transcript-imported ledgers"
    )
    parser.add_argument("actual", type=Path)
    parser.add_argument("expected", type=Path)
    args = parser.parse_args()
    print(json.dumps(compare(args.actual, args.expected), sort_keys=True))


if __name__ == "__main__":
    main()
