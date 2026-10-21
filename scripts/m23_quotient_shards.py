#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

from m23_quotient_ledger import Ledger
from snapshot_quotient_ledger import sha256, verified_counts


BASE_TABLE_COLUMNS = {
    "certificates": (
        "id,status,walk_status,linked_certificate,seed_ordinal,seed_twist,"
        "checked_vertices,discovered_vertices,discovered_classes"
    ),
    "vertices": "ordinal,twist,certificate",
    "certificate_vertices": "certificate,position,ordinal,twist",
    "blocks": (
        "sequence,ordinal,source,refined_vertices,generating_vertices,"
        "new_certificates,ledger_hits"
    ),
}


def read_base_manifest(path: Path, database: Path) -> dict[str, object]:
    record = json.loads(path.read_text())
    if record.get("schema_version") != 1:
        raise ValueError("unsupported base snapshot manifest")
    if record.get("sha256") != sha256(database):
        raise ValueError("base database checksum differs from its manifest")
    return record


def prepare(base: Path, base_manifest: Path, run_dir: Path,
            shard_count: int, target_blocks: int) -> dict[str, object]:
    if shard_count < 1:
        raise ValueError("shard count must be positive")
    base_record = read_base_manifest(base_manifest, base)
    base_blocks = int(base_record["counts"]["blocks"])
    meta = base_record["ledger_meta"]
    first = int(meta["config_first_ordinal"])
    last = int(meta["config_last_ordinal"])
    if target_blocks <= base_blocks or target_blocks > last - first + 1:
        raise ValueError("target must extend the base within the configured range")
    run_dir.mkdir(parents=True, exist_ok=True)
    destination = run_dir / "ledger.sqlite3"
    manifest = run_dir / "shards.json"
    if destination.exists() or manifest.exists():
        raise FileExistsError("deterministic shard run directory is not new")

    source_db = sqlite3.connect(f"file:{base.resolve()}?mode=ro", uri=True)
    destination_db = sqlite3.connect(destination)
    source_db.backup(destination_db)
    destination_db.close()
    source_db.close()
    destination.chmod(0o644)
    ledger = Ledger(destination)
    ledger.close()
    record: dict[str, object] = {
        "schema_version": 1,
        "base_sha256": base_record["sha256"],
        "base_counts": base_record["counts"],
        "first_ordinal": first,
        "last_ordinal": last,
        "shard_count": shard_count,
        "target_blocks": target_blocks,
        "assignment": "1 + ((ordinal - first_ordinal) mod shard_count)",
        "merge": "shared SQLite transactions with unique vertex ownership",
    }
    manifest.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    return record


def retarget(base: Path, base_manifest: Path, run_dir: Path,
             shard_count: int, target_blocks: int) -> dict[str, object]:
    if shard_count < 1:
        raise ValueError("shard count must be positive")
    base_record = read_base_manifest(base_manifest, base)
    meta = base_record["ledger_meta"]
    first = int(meta["config_first_ordinal"])
    last = int(meta["config_last_ordinal"])
    database = run_dir / "ledger.sqlite3"
    db = sqlite3.connect(f"file:{database.resolve()}?mode=ro", uri=True)
    blocks = db.execute("SELECT COUNT(*) FROM blocks").fetchone()[0]
    leases = db.execute("SELECT COUNT(*) FROM leases").fetchone()[0]
    db.close()
    if blocks != target_blocks or leases:
        raise ValueError("retargeting requires a completed lease-free boundary")
    if target_blocks <= int(base_record["counts"]["blocks"]):
        raise ValueError("retargeted wave must extend its verified base")
    record: dict[str, object] = {
        "schema_version": 1,
        "base_sha256": base_record["sha256"],
        "base_counts": base_record["counts"],
        "first_ordinal": first,
        "last_ordinal": last,
        "shard_count": shard_count,
        "target_blocks": target_blocks,
        "assignment": "1 + ((ordinal - first_ordinal) mod shard_count)",
        "merge": "shared SQLite transactions with unique vertex ownership",
    }
    (run_dir / "shards.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n"
    )
    return record


def _missing_base_rows(db: sqlite3.Connection, table: str, columns: str) -> int:
    query = (
        f"SELECT COUNT(*) FROM (SELECT {columns} FROM base.{table} "
        f"EXCEPT SELECT {columns} FROM main.{table})"
    )
    return int(db.execute(query).fetchone()[0])


def audit(base: Path, base_manifest: Path, run_dir: Path,
          progress: Path) -> dict[str, object]:
    base_record = read_base_manifest(base_manifest, base)
    shard_record = json.loads((run_dir / "shards.json").read_text())
    if shard_record["base_sha256"] != base_record["sha256"]:
        raise ValueError("shard run names a different base snapshot")
    database = run_dir / "ledger.sqlite3"
    db = sqlite3.connect(database)
    db.execute("PRAGMA foreign_keys=ON")
    db.execute("ATTACH DATABASE ? AS base",
               (f"file:{base.resolve()}?mode=ro",))
    if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
        raise ValueError("shard database quick_check failed")
    if db.execute("PRAGMA foreign_key_check").fetchall():
        raise ValueError("shard database foreign-key check failed")
    for table, columns in BASE_TABLE_COLUMNS.items():
        if _missing_base_rows(db, table, columns):
            raise ValueError(f"shard run does not preserve base table {table}")
    if db.execute("SELECT COUNT(*) FROM leases").fetchone()[0]:
        raise ValueError("completed shard run retains active leases")

    counts = {
        "certificates": db.execute("SELECT COUNT(*) FROM certificates").fetchone()[0],
        "blocks": db.execute("SELECT COUNT(*) FROM blocks").fetchone()[0],
        "vertices": db.execute("SELECT COUNT(*) FROM vertices").fetchone()[0],
    }
    if counts["blocks"] != int(shard_record["target_blocks"]):
        raise ValueError("shard run did not reach its declared block target")
    if counts != verified_counts(progress):
        raise ValueError("shard run lacks an exact replay of its final state")

    base_max_sequence = db.execute(
        "SELECT COALESCE(MAX(sequence),0) FROM base.blocks"
    ).fetchone()[0]
    assignments = db.execute(
        "SELECT ordinal,worker,shard_index,shard_count FROM blocks "
        "WHERE sequence>? ORDER BY sequence", (base_max_sequence,)
    )
    first = int(shard_record["first_ordinal"])
    last = int(shard_record["last_ordinal"])
    shard_count = int(shard_record["shard_count"])
    expected_new = counts["blocks"] - int(base_record["counts"]["blocks"])
    assignment_count = 0
    for ordinal, worker, shard_index, stored_count in assignments:
        assignment_count += 1
        expected_index = 1 + ((ordinal - first) % shard_count)
        if not first <= ordinal <= last:
            raise ValueError("processed block lies outside the configured range")
        if (shard_index, stored_count) != (expected_index, shard_count):
            raise ValueError(f"incorrect deterministic owner for block {ordinal}")
        if not worker or not str(worker).startswith("worker-"):
            raise ValueError(f"missing physical worker for block {ordinal}")
    if assignment_count != expected_new:
        raise ValueError("new block count differs from the frozen base delta")
    db.close()
    return {
        "schema_version": 1,
        "base_sha256": base_record["sha256"],
        "counts": counts,
        "new_blocks": expected_new,
        "shard_count": shard_count,
        "base_preserved": True,
        "deterministic_ownership": True,
        "exact_replay": True,
        "database_sha256": sha256(database),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="prepare or audit quotient shards")
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare")
    for item in (prepare_parser,):
        item.add_argument("base", type=Path)
        item.add_argument("base_manifest", type=Path)
        item.add_argument("run_dir", type=Path)
    prepare_parser.add_argument("shard_count", type=int)
    prepare_parser.add_argument("target_blocks", type=int)
    audit_parser = subparsers.add_parser("audit")
    audit_parser.add_argument("base", type=Path)
    audit_parser.add_argument("base_manifest", type=Path)
    audit_parser.add_argument("run_dir", type=Path)
    audit_parser.add_argument("progress", type=Path)
    retarget_parser = subparsers.add_parser("retarget")
    retarget_parser.add_argument("base", type=Path)
    retarget_parser.add_argument("base_manifest", type=Path)
    retarget_parser.add_argument("run_dir", type=Path)
    retarget_parser.add_argument("shard_count", type=int)
    retarget_parser.add_argument("target_blocks", type=int)
    args = parser.parse_args()
    if args.command == "prepare":
        result = prepare(args.base, args.base_manifest, args.run_dir,
                         args.shard_count, args.target_blocks)
    elif args.command == "audit":
        result = audit(args.base, args.base_manifest, args.run_dir, args.progress)
    else:
        result = retarget(args.base, args.base_manifest, args.run_dir,
                          args.shard_count, args.target_blocks)
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
