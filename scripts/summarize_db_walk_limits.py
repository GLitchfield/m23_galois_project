#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

from m23_run_status import read_events


def summarize(run_dir: Path) -> list[object]:
    database = run_dir / "ledger.sqlite3"
    db = sqlite3.connect(database)
    config = dict(db.execute(
        "SELECT substr(key,8),value FROM meta WHERE key LIKE 'config_%'"
    ))
    blocks = db.execute(
        "SELECT COUNT(*),COALESCE(SUM(source='frontier'),0),"
        "COALESCE(SUM(new_certificates=0),0),COALESCE(SUM(generating_vertices),0),"
        "COALESCE(SUM(ledger_hits),0) FROM blocks"
    ).fetchone()
    statuses = dict(db.execute(
        "SELECT status,COUNT(*) FROM certificates GROUP BY status"
    ))
    certificates = sum(statuses.values())
    vertices = db.execute("SELECT COUNT(*) FROM vertices").fetchone()[0]
    logical_bytes = (
        db.execute("PRAGMA page_count").fetchone()[0]
        * db.execute("PRAGMA page_size").fetchone()[0]
    )
    db.close()

    events = [event for event in read_events(run_dir)
              if event["phase"] == "quotient_db_scan"]
    starts = [event for event in events if event["state"] == "start"]
    terminals = [event for event in events if event["state"] in {"paused", "done"}]
    elapsed = terminals[-1]["timestamp"] - starts[-1]["timestamp"]
    return [
        int(config["proof_limit"]), int(config["walk_limit"]), blocks[0],
        blocks[1], blocks[2], blocks[3], blocks[4], certificates,
        statuses.get("closed", 0), statuses.get("overflow", 0),
        statuses.get("linked", 0), vertices, elapsed,
        round(vertices / elapsed, 3) if elapsed else 0, logical_bytes,
    ]


def main() -> None:
    parser = argparse.ArgumentParser(description="summarize database walk-limit pilots")
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    header = [
        "proof_limit", "walk_limit", "blocks", "frontier_blocks",
        "covered_blocks", "generating_vertices", "ledger_hits", "certificates",
        "closed", "overflow", "linked", "ledger_vertices", "elapsed_seconds",
        "vertices_per_second", "database_bytes",
    ]
    print("\t".join(header))
    for run_dir in sorted(args.root.glob("walk-*"), key=lambda path: int(path.name[5:])):
        if (run_dir / "ledger.sqlite3").exists():
            print("\t".join(map(str, summarize(run_dir))))


if __name__ == "__main__":
    main()
