#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path

from m23_quotient_ledger import Ledger


def read_plan(path: Path) -> tuple[dict[str, str], list[int]]:
    metadata: dict[str, str] = {}
    ordinals: list[int] = []
    with path.open() as stream:
        for number, line in enumerate(stream, 1):
            fields = line.rstrip("\n").split("\t")
            if fields[0].startswith("# ") and len(fields) == 2:
                key = fields[0][2:]
                if key in metadata:
                    raise ValueError(
                        f"duplicate plan metadata at line {number}"
                    )
                metadata[key] = fields[1]
            elif fields[0] == "S" and len(fields) == 6:
                ordinals.append(int(fields[5]))
    required = {"schema", "source_checkpoint_sha256", "block_count",
                "macroblock_count", "identity_block_excluded"}
    if not required <= set(metadata) or \
            metadata["schema"] != "m23-native-ledger-stratified-v1" or \
            metadata["identity_block_excluded"] != "1" or \
            len(ordinals) != int(metadata["block_count"]) or \
            len(ordinals) != len(set(ordinals)) or \
            any(not 1 <= ordinal <= int(metadata["macroblock_count"])
                for ordinal in ordinals):
        raise ValueError("native stratified work plan is incomplete or invalid")
    return metadata, ordinals


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def initialize_ledger(database: Path, metadata: dict[str, str],
                      start_ordinal: int | None = None) -> None:
    required = {
        "coordinate_convention", "target_order", "source_git_revision",
        "gap_version", "proof_limit", "walk_limit",
    }
    if not required <= set(metadata) or \
            metadata["coordinate_convention"] != "native-v1":
        raise ValueError("native plan lacks initialization metadata")
    start = start_ordinal or int(metadata["proof_limit"])
    macroblocks = int(metadata["macroblock_count"])
    if not 1 <= start <= macroblocks:
        raise ValueError("native ledger start ordinal is out of range")
    if database.exists():
        raise FileExistsError(f"refusing to overwrite existing ledger: {database}")
    ledger = Ledger(database)
    try:
        ledger.initialize({
            "target_order": int(metadata["target_order"]),
            "pair_schema": 2,
            "macroblock_count": macroblocks,
            "first_ordinal": 1,
            "last_ordinal": macroblocks,
            "proof_limit": int(metadata["proof_limit"]),
            "walk_limit": int(metadata["walk_limit"]),
            "schedule": "frontier",
            "start_ordinal": start,
            "traversal_order": "native-v1",
        })
        with ledger.db:
            for key in ("coordinate_convention", "source_checkpoint_sha256",
                        "source_git_revision", "gap_version"):
                ledger._set_meta("native_" + key, metadata[key])
    finally:
        ledger.close()


def seed(database: Path, plan: Path, shard_count: int = 1,
         initialize: bool = False,
         start_ordinal: int | None = None) -> dict[str, object]:
    if shard_count < 1:
        raise ValueError("native planned-work shard count must be positive")
    metadata, ordinals = read_plan(plan)
    if initialize:
        initialize_ledger(database, metadata, start_ordinal)
    digest = file_sha256(plan)
    db = sqlite3.connect(database, timeout=300)
    try:
        db.execute("PRAGMA foreign_keys=ON")
        db.execute("PRAGMA busy_timeout=300000")
        db.execute("BEGIN IMMEDIATE")
        stored = dict(db.execute(
            "SELECT key,value FROM meta WHERE key IN "
            "('config_macroblock_count','config_traversal_order',"
            "'native_source_checkpoint_sha256')"
        ))
        expected = {
            "config_macroblock_count": metadata["macroblock_count"],
            "config_traversal_order": "native-v1",
            "native_source_checkpoint_sha256":
                metadata["source_checkpoint_sha256"],
        }
        if stored != expected:
            raise ValueError("native ledger and stratified plan metadata differ")
        counts = db.execute(
            "SELECT (SELECT COUNT(*) FROM blocks),"
            "(SELECT COUNT(*) FROM certificates),"
            "(SELECT COUNT(*) FROM vertices),"
            "(SELECT COUNT(*) FROM leases),"
            "(SELECT COUNT(*) FROM frontier),"
            "(SELECT COUNT(*) FROM planned_work)"
        ).fetchone()
        if counts != (0, 0, 0, 0, 0, 0):
            raise ValueError("stratified frontier requires a fresh native ledger")
        db.executemany(
            "INSERT INTO frontier(ordinal) VALUES(?)",
            ((ordinal,) for ordinal in ordinals),
        )
        db.executemany(
            "INSERT INTO planned_work(ordinal,shard_index,shard_count) "
            "VALUES(?,?,?)",
            ((ordinal, 1 + index % shard_count, shard_count)
             for index, ordinal in enumerate(ordinals)),
        )
        db.executemany(
            "INSERT INTO meta(key,value) VALUES(?,?)",
            (("native_work_plan_schema", "m23-native-stratified-plan-v1"),
             ("native_work_plan_sha256", digest),
             ("native_work_plan_blocks", str(len(ordinals))),
             ("native_work_plan_shards", str(shard_count))),
        )
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
    return {
        "schema": "m23-native-stratified-plan-v1",
        "blocks": len(ordinals),
        "shards": shard_count,
        "shard_blocks": [
            (len(ordinals) + shard_count - index - 1) // shard_count
            for index in range(shard_count)
        ],
        "plan_sha256": digest,
        "first_planned_ordinal": ordinals[0],
        "last_planned_ordinal": ordinals[-1],
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="seed a fresh native SQLite ledger from a stratified plan"
    )
    parser.add_argument("database", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("--shards", type=int, default=1)
    parser.add_argument("--initialize", action="store_true")
    parser.add_argument("--start-ordinal", type=int)
    args = parser.parse_args()
    print(json.dumps(
        seed(args.database, args.plan, args.shards, args.initialize,
             args.start_ordinal), sort_keys=True
    ))


if __name__ == "__main__":
    main()
