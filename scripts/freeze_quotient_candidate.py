#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from snapshot_quotient_ledger import database_counts, sha256


def freeze(source: Path, progress: Path, shards: Path,
           destination: Path, expected_blocks: int) -> dict[str, object]:
    source = source.resolve()
    destination = destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    database = destination / "ledger.sqlite3"
    candidate = destination / "candidate.json"
    destination_progress = destination / "progress.tsv"
    destination_shards = destination / "shards.json"
    if any(path.exists() for path in (
        database, candidate, destination_progress, destination_shards
    )):
        raise FileExistsError("candidate destination must be new")
    shard_record = json.loads(shards.read_text())
    if int(shard_record["target_blocks"]) != expected_blocks:
        raise ValueError("source shard target differs from candidate boundary")

    source_db = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    counts = database_counts(source_db)
    if counts["blocks"] != expected_blocks:
        raise ValueError("source ledger has not reached the candidate boundary")
    if source_db.execute("SELECT COUNT(*) FROM leases").fetchone()[0]:
        raise ValueError("cannot freeze a candidate with active leases")
    fd, temporary_name = tempfile.mkstemp(
        prefix=".candidate.", dir=destination
    )
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        frozen = sqlite3.connect(temporary)
        source_db.backup(frozen)
        if database_counts(frozen) != counts:
            raise ValueError("candidate backup count mismatch")
        if frozen.execute("PRAGMA quick_check").fetchone()[0] != "ok":
            raise ValueError("candidate quick_check failed")
        if frozen.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("candidate foreign-key check failed")
        frozen.close()
        source_db.close()
        os.replace(temporary, database)
        database.chmod(0o444)
        shutil.copyfile(progress, destination_progress)
        destination_shards.write_text(
            json.dumps(shard_record, indent=2, sort_keys=True) + "\n"
        )
        record: dict[str, object] = {
            "schema_version": 1,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "status": "verification_pending",
            "database": database.name,
            "sha256": sha256(database),
            "bytes": database.stat().st_size,
            "counts": counts,
            "shard_plan": shard_record,
        }
        candidate.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
        return record
    except Exception:
        source_db.close()
        temporary.unlink(missing_ok=True)
        for path in (database, candidate, destination_progress, destination_shards):
            path.unlink(missing_ok=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description="freeze an unverified quotient wave")
    parser.add_argument("source", type=Path)
    parser.add_argument("progress", type=Path)
    parser.add_argument("shards", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("expected_blocks", type=int)
    args = parser.parse_args()
    print(json.dumps(freeze(
        args.source, args.progress, args.shards,
        args.destination, args.expected_blocks
    ), sort_keys=True))


if __name__ == "__main__":
    main()
