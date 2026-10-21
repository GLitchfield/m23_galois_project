#!/usr/bin/env python3
"""Audit compact full-plan metadata, ownership, and exhaustiveness."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

from seed_native_full_cursor_plan import (
    OWNERSHIP,
    SCHEMA,
    descriptor_sha256,
)


def audit(path: Path, require_complete: bool = False) -> dict[str, object]:
    database = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        metadata = dict(database.execute(
            "SELECT key,value FROM meta WHERE key LIKE 'native_work_plan_%' "
            "OR key IN ('native_source_checkpoint_sha256',"
            "'config_macroblock_count','config_start_ordinal')"
        ))
        macroblocks = int(metadata["config_macroblock_count"])
        shards = int(metadata["native_work_plan_shards"])
        value = {
            "schema": metadata["native_work_plan_schema"],
            "ownership": metadata["native_work_plan_ownership"],
            "source_checkpoint_sha256":
                metadata["native_source_checkpoint_sha256"],
            "macroblock_count": macroblocks,
            "shards": shards,
            "start_ordinal": int(metadata["config_start_ordinal"]),
        }
        rows = database.execute(
            "SELECT (SELECT COUNT(*) FROM blocks),"
            "(SELECT COUNT(*) FROM leases),"
            "(SELECT COUNT(*) FROM planned_work),"
            "(SELECT COUNT(*) FROM blocks WHERE ordinal<1 OR ordinal>?),"
            "(SELECT COUNT(*) FROM blocks WHERE shard_count<>? OR "
            " shard_index<>((ordinal-1)%?)+1)",
            (macroblocks, shards, shards),
        ).fetchone()
        actual = database.execute(
            "SELECT shard_index,COUNT(*) FROM blocks GROUP BY shard_index "
            "ORDER BY shard_index"
        ).fetchall()
        quick = database.execute("PRAGMA quick_check").fetchone()[0]
        foreign = database.execute("PRAGMA foreign_key_check").fetchall()
    finally:
        database.close()
    expected = [
        [shard, (macroblocks + shards - shard) // shards]
        for shard in range(1, shards + 1)
    ]
    complete = rows[0] == macroblocks
    valid = (
        value["schema"] == SCHEMA and value["ownership"] == OWNERSHIP and
        int(metadata["native_work_plan_blocks"]) == macroblocks and
        descriptor_sha256(value) == metadata["native_work_plan_sha256"] and
        rows[1:] == (0, 0, 0, 0) and quick == "ok" and not foreign and
        (not complete or [list(row) for row in actual] == expected)
    )
    if not valid or (require_complete and not complete):
        raise ValueError(
            f"invalid native full-cursor audit valid={valid} "
            f"complete={complete} rows={rows} actual={actual}"
        )
    return {
        "schema": "m23-native-full-cursor-audit-v1",
        "valid": True,
        "complete": complete,
        "blocks": rows[0],
        "macroblock_count": macroblocks,
        "shards": shards,
        "actual_shard_blocks": [list(row) for row in actual],
        "expected_complete_shard_blocks": expected,
        "materialized_plan_rows": rows[2],
        "plan_sha256": metadata["native_work_plan_sha256"],
        "quick_check": "ok",
        "foreign_key_violations": 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="audit a compact native full-cursor ledger"
    )
    parser.add_argument("ledger", type=Path)
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    print(json.dumps(
        audit(args.ledger, args.require_complete), indent=2, sort_keys=True
    ))


if __name__ == "__main__":
    main()
