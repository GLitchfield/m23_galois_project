#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verified_counts(progress: Path) -> dict[str, int]:
    result: dict[str, int] | None = None
    with progress.open(encoding="utf-8") as stream:
        for line in stream:
            fields = line.rstrip("\n").split("\t", 5)
            if (len(fields) != 6 or fields[2] not in {
                    "verify_quotient_db", "verify_quotient_db_delta",
                    "verify_quotient_db_delta_parallel",
                } or fields[3:5] != ["all", "done"]):
                continue
            values = dict(item.split("=", 1) for item in fields[5].split(","))
            result = {key: int(values[key]) for key in
                      ("certificates", "blocks", "vertices")}
    if result is None:
        raise ValueError("progress file has no completed exact database replay")
    return result


def database_counts(db: sqlite3.Connection) -> dict[str, int]:
    return {
        "certificates": db.execute("SELECT COUNT(*) FROM certificates").fetchone()[0],
        "blocks": db.execute("SELECT COUNT(*) FROM blocks").fetchone()[0],
        "vertices": db.execute("SELECT COUNT(*) FROM vertices").fetchone()[0],
    }


def create_snapshot(source: Path, destination: Path, manifest: Path,
                    progress: Path) -> dict[str, object]:
    source = source.resolve()
    destination = destination.resolve()
    manifest = manifest.resolve()
    expected = verified_counts(progress)
    destination.parent.mkdir(parents=True, exist_ok=True)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or manifest.exists():
        raise FileExistsError("snapshot destination and manifest must be new")

    source_db = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    temporary_fd, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.", dir=destination.parent
    )
    os.close(temporary_fd)
    temporary = Path(temporary_name)
    try:
        snapshot_db = sqlite3.connect(temporary)
        source_db.backup(snapshot_db)
        snapshot_db.execute("PRAGMA foreign_keys=ON")
        counts = database_counts(snapshot_db)
        if counts != expected:
            raise ValueError(
                f"database state {counts} differs from last exact replay {expected}"
            )
        if snapshot_db.execute("SELECT COUNT(*) FROM leases").fetchone()[0]:
            raise ValueError("cannot freeze a ledger with active worker leases")
        if snapshot_db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
            raise ValueError("snapshot quick_check failed")
        if snapshot_db.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("snapshot foreign-key check failed")
        meta = dict(snapshot_db.execute("SELECT key,value FROM meta ORDER BY key"))
        snapshot_db.close()
        source_db.close()
        os.replace(temporary, destination)
        destination.chmod(0o444)
        record: dict[str, object] = {
            "schema_version": 1,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "database": destination.name,
            "sha256": sha256(destination),
            "bytes": destination.stat().st_size,
            "counts": counts,
            "ledger_meta": meta,
            "verification": "exact certificate-order replay",
        }
        manifest.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
        manifest.chmod(0o444)
        return record
    except Exception:
        source_db.close()
        temporary.unlink(missing_ok=True)
        destination.unlink(missing_ok=True)
        manifest.unlink(missing_ok=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(
        description="freeze an exactly replayed quotient ledger"
    )
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("progress", type=Path)
    args = parser.parse_args()
    record = create_snapshot(
        args.source, args.destination, args.manifest, args.progress
    )
    print(json.dumps(record, sort_keys=True))


if __name__ == "__main__":
    main()
