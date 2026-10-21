#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path

from snapshot_quotient_ledger import sha256


def plan(database: Path, base_certificate: int, segment_count: int,
         base_blocks: int = 0) -> dict[str, object]:
    db = sqlite3.connect(f"file:{database.resolve()}?mode=ro", uri=True)
    certificate_count, total_weight = db.execute(
        "SELECT COUNT(*),COALESCE(SUM(MAX(checked_vertices,1)"
        "+discovered_vertices),0) "
        "FROM certificates WHERE id>?",
        (base_certificate,),
    ).fetchone()
    if (certificate_count < 1 or segment_count < 1
            or segment_count > certificate_count):
        db.close()
        raise ValueError("invalid certificate delta or segment count")

    segments: list[dict[str, int]] = []
    first_certificate: int | None = None
    last_certificate = 0
    segment_weight = 0
    cumulative = 0
    rows = db.execute(
        "SELECT id,MAX(checked_vertices,1)+discovered_vertices "
        "FROM certificates "
        "WHERE id>? ORDER BY id",
        (base_certificate,),
    )
    for position, (certificate, weight) in enumerate(rows, 1):
        if first_certificate is None:
            first_certificate = certificate
        last_certificate = certificate
        segment_weight += weight
        cumulative += weight
        if len(segments) == segment_count - 1:
            continue
        next_index = len(segments) + 1
        remaining_rows = certificate_count - position
        remaining_segments = segment_count - next_index
        reached_target = cumulative * segment_count >= total_weight * next_index
        must_close = remaining_rows == remaining_segments
        if reached_target or must_close:
            segments.append({
                "index": next_index,
                "count": segment_count,
                "first_certificate": first_certificate,
                "last_certificate": last_certificate,
                "weight": segment_weight,
            })
            first_certificate = None
            segment_weight = 0
    db.close()
    if first_certificate is None:
        raise ValueError("empty final certificate segment")
    segments.append({
        "index": segment_count,
        "count": segment_count,
        "first_certificate": first_certificate,
        "last_certificate": last_certificate,
        "weight": segment_weight,
    })
    if len(segments) != segment_count:
        raise ValueError("certificate segment planning failed")
    database_hash = sha256(database)
    identity = json.dumps({
        "database_sha256": database_hash,
        "base_certificate": base_certificate,
        "base_blocks": base_blocks,
        "segments": segments,
    }, sort_keys=True).encode()
    return {
        "schema_version": 1,
        "database_sha256": database_hash,
        "base_certificate": base_certificate,
        "base_blocks": base_blocks,
        "target_certificate": last_certificate,
        "total_weight": total_weight,
        "segments": segments,
        "plan_id": hashlib.sha256(identity).hexdigest(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="balance certificate replay segments")
    parser.add_argument("database", type=Path)
    parser.add_argument("base_manifest", type=Path)
    parser.add_argument("segment_count", type=int)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    base_record = json.loads(args.base_manifest.read_text())
    record = plan(args.database,
                  int(base_record["counts"]["certificates"]),
                  args.segment_count,
                  int(base_record["counts"]["blocks"]))
    args.output.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    tsv = args.output.with_suffix(".tsv")
    lines = ["\t".join(map(str, (
        "M", record["base_blocks"], record["base_certificate"],
        record["plan_id"], len(record["segments"])
    )))]
    lines.extend("\t".join(map(str, (
        "S", segment["index"], segment["count"],
        segment["first_certificate"], segment["last_certificate"],
        segment["weight"], record["plan_id"]
    ))) for segment in record["segments"])
    tsv.write_text("\n".join(lines) + "\n")
    print(json.dumps(record, sort_keys=True))


if __name__ == "__main__":
    main()
