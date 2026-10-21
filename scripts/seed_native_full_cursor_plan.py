#!/usr/bin/env python3
"""Seed a compact, deterministic full-macroblock work plan."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path

from seed_native_stratified_frontier import initialize_ledger, read_plan


SCHEMA = "m23-native-full-cursor-plan-v1"
OWNERSHIP = "ordinal-modulo-v1"


def descriptor(metadata: dict[str, str], shards: int,
               start_ordinal: int) -> dict[str, int | str]:
    return {
        "schema": SCHEMA,
        "ownership": OWNERSHIP,
        "source_checkpoint_sha256": metadata["source_checkpoint_sha256"],
        "macroblock_count": int(metadata["macroblock_count"]),
        "shards": shards,
        "start_ordinal": start_ordinal,
    }


def descriptor_sha256(value: dict[str, int | str]) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def seed(database: Path, metadata_plan: Path, shards: int,
         start_ordinal: int | None = None) -> dict[str, object]:
    metadata, _ = read_plan(metadata_plan)
    macroblocks = int(metadata["macroblock_count"])
    if not 0 < shards <= macroblocks:
        raise ValueError(
            "native full-cursor shard count must be within the block census"
        )
    start = start_ordinal or int(metadata["proof_limit"])
    value = descriptor(metadata, shards, start)
    digest = descriptor_sha256(value)
    initialize_ledger(database, metadata, start)
    connection = sqlite3.connect(database)
    try:
        counts = connection.execute(
            "SELECT (SELECT COUNT(*) FROM blocks),"
            "(SELECT COUNT(*) FROM certificates),"
            "(SELECT COUNT(*) FROM vertices),"
            "(SELECT COUNT(*) FROM leases),"
            "(SELECT COUNT(*) FROM frontier),"
            "(SELECT COUNT(*) FROM planned_work)"
        ).fetchone()
        if counts != (0, 0, 0, 0, 0, 0):
            raise ValueError("full-cursor plan requires a fresh native ledger")
        with connection:
            connection.executemany(
                "INSERT INTO meta(key,value) VALUES(?,?)",
                (("native_work_plan_schema", SCHEMA),
                 ("native_work_plan_sha256", digest),
                 ("native_work_plan_blocks", metadata["macroblock_count"]),
                 ("native_work_plan_shards", str(shards)),
                 ("native_work_plan_ownership", OWNERSHIP)),
            )
    finally:
        connection.close()
    return {
        **value,
        "plan_sha256": digest,
        "shard_blocks": [
            (macroblocks + shards - shard) // shards
            for shard in range(1, shards + 1)
        ],
        "materialized_plan_rows": 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="seed a compact deterministic full native work plan"
    )
    parser.add_argument("database", type=Path)
    parser.add_argument("metadata_plan", type=Path)
    parser.add_argument("--shards", type=int, required=True)
    parser.add_argument("--start-ordinal", type=int)
    args = parser.parse_args()
    print(json.dumps(seed(
        args.database, args.metadata_plan, args.shards, args.start_ordinal
    ), sort_keys=True))


if __name__ == "__main__":
    main()
