#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sqlite3
import time
from pathlib import Path

from m23_run_status import parse_detail
from snapshot_quotient_ledger import sha256


def _database_totals(path: Path) -> dict[str, int]:
    db = sqlite3.connect(f"file:{path.resolve()}?mode=ro", uri=True)
    certificates = db.execute(
        "SELECT COUNT(*),COALESCE(SUM(status='closed'),0),"
        "COALESCE(SUM(status='overflow'),0),COALESCE(SUM(status='linked'),0) "
        "FROM certificates"
    ).fetchone()
    blocks = db.execute(
        "SELECT COUNT(*),COALESCE(SUM(refined_vertices),0),"
        "COALESCE(SUM(generating_vertices),0),COALESCE(SUM(ledger_hits),0) "
        "FROM blocks"
    ).fetchone()
    vertices = db.execute("SELECT COUNT(*) FROM vertices").fetchone()[0]
    leases = db.execute("SELECT COUNT(*) FROM leases").fetchone()[0]
    db.close()
    return dict(zip(
        ("certificates", "closed", "overflow", "linked", "blocks",
         "refined", "generating", "hits", "vertices", "leases"),
        (*certificates, *blocks, vertices, leases),
    ))


def _done_events(progress: Path, phase: str,
                 plan_id: str) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    with progress.open(encoding="utf-8") as stream:
        for line in stream:
            fields = line.rstrip("\n").split("\t", 5)
            if len(fields) != 6 or fields[2] != phase or fields[4] != "done":
                continue
            detail = parse_detail(fields[5])
            if detail.get("plan") == plan_id:
                result[fields[3]] = detail
    return result


def finalize(database: Path, base_database: Path, plan_path: Path,
             progress: Path, block_segments: int) -> dict[str, object]:
    plan = json.loads(plan_path.read_text())
    plan_id = str(plan["plan_id"])
    if sha256(database) != plan["database_sha256"]:
        raise ValueError("database changed after the parallel replay plan")
    base = _database_totals(base_database)
    target = _database_totals(database)
    if target["leases"]:
        raise ValueError("cannot finalize verification with active leases")

    certificate_events = _done_events(
        progress, "verify_quotient_certificate_segment", plan_id
    )
    if len(certificate_events) != len(plan["segments"]):
        raise ValueError("certificate replay segments are incomplete")
    certificate_sums = {key: 0 for key in
                        ("certificates", "closed", "overflow", "linked", "vertices")}
    for segment in plan["segments"]:
        item = f"{segment['index']}-of-{segment['count']}"
        detail = certificate_events.get(item)
        if detail is None or int(detail["first"]) != segment["first_certificate"] \
                or int(detail["last"]) != segment["last_certificate"]:
            raise ValueError(f"certificate segment mismatch for {item}")
        for key in certificate_sums:
            certificate_sums[key] += int(detail[key])
    for key in certificate_sums:
        if certificate_sums[key] != target[key] - base[key]:
            raise ValueError(f"certificate delta mismatch for {key}")

    block_events = _done_events(
        progress, "verify_quotient_block_segment", plan_id
    )
    if len(block_events) != block_segments:
        raise ValueError("block verification segments are incomplete")
    block_sums = {key: 0 for key in ("blocks", "refined", "generating", "hits")}
    for index in range(1, block_segments + 1):
        detail = block_events.get(f"{index}-of-{block_segments}")
        if detail is None:
            raise ValueError(f"missing block segment {index}")
        for key in block_sums:
            block_sums[key] += int(detail[key])
    for key in block_sums:
        if block_sums[key] != target[key] - base[key]:
            raise ValueError(f"block delta mismatch for {key}")

    detail = (
        f"certificates={target['certificates']},blocks={target['blocks']},"
        f"vertices={target['vertices']},base_certificates={base['certificates']},"
        f"base_blocks={base['blocks']},base_vertices={base['vertices']},"
        f"plan={plan_id}"
    )
    with progress.open("a") as stream:
        stream.write(
            f"{int(time.time())}\tpython\tverify_quotient_db_delta_parallel\t"
            f"all\tdone\t{detail}\n"
        )
    return {
        "schema_version": 1,
        "plan_id": plan_id,
        "database_sha256": plan["database_sha256"],
        "certificate_segments": len(plan["segments"]),
        "block_segments": block_segments,
        "certificate_delta": certificate_sums,
        "block_delta": block_sums,
        "counts": {key: target[key] for key in
                   ("certificates", "blocks", "vertices")},
        "exact_parallel_replay": True,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="compose parallel quotient replay")
    parser.add_argument("database", type=Path)
    parser.add_argument("base_database", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("progress", type=Path)
    parser.add_argument("block_segments", type=int)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = finalize(args.database, args.base_database, args.plan,
                      args.progress, args.block_segments)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
