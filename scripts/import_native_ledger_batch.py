#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from m23_quotient_ledger import Ledger


REQUIRED_METADATA = {
    "schema",
    "coordinate_convention",
    "target_order",
    "source_checkpoint_sha256",
    "source_git_revision",
    "gap_version",
    "start_block",
    "block_count",
    "macroblock_count",
    "proof_limit",
    "walk_limit",
}
STRATIFIED_METADATA = REQUIRED_METADATA | {
    "samples_per_segment",
    "identity_block_excluded",
    "cache_reset_certificates",
}


def parse_transcript(path: Path) -> tuple[dict[str, str], list[dict[str, object]]]:
    metadata: dict[str, str] = {}
    records: list[dict[str, object]] = []
    sampled_ordinals: list[int] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0
    while index < len(lines):
        fields = lines[index].split("\t")
        index += 1
        if fields[0] == "# schema":
            if len(fields) != 2 or "schema" in metadata:
                raise ValueError("invalid native transcript schema row")
            metadata["schema"] = fields[1]
        elif fields[0].startswith("# "):
            if len(fields) != 2 or fields[0][2:] in metadata:
                raise ValueError("invalid native transcript metadata row")
            metadata[fields[0][2:]] = fields[1]
        elif fields[0] == "C":
            if len(fields) != 10:
                raise ValueError("invalid native certificate row")
            values = list(map(int, fields[1:2] + fields[4:]))
            certificate = {
                "local_id": values[0],
                "status": fields[2],
                "walk_status": fields[3],
                "linked": values[1],
                "seed_ordinal": values[2],
                "seed_twist": values[3],
                "checked_vertices": values[4],
                "discovered_vertices": values[5],
                "discovered_classes": values[6],
                "vertices": [],
            }
            for position in range(1, values[5] + 1):
                if index >= len(lines):
                    raise ValueError("truncated native certificate vertices")
                vertex = lines[index].split("\t")
                index += 1
                if len(vertex) != 5 or vertex[0] != "V" or \
                        int(vertex[1]) != values[0] or int(vertex[2]) != position:
                    raise ValueError("invalid native certificate vertex row")
                certificate["vertices"].append((int(vertex[3]), int(vertex[4])))
            records.append(certificate)
        elif fields[0] == "B":
            if len(fields) != 7 or fields[2] not in {"ordinal", "frontier"}:
                raise ValueError("invalid native block row")
            records.append({
                "ordinal": int(fields[1]),
                "source": fields[2],
                "refined": int(fields[3]),
                "generating": int(fields[4]),
                "new_certificates": int(fields[5]),
                "hits": int(fields[6]),
            })
        elif fields[0] == "S" and len(fields) == 6:
            sampled_ordinals.append(int(fields[5]))
        elif fields[0] == "T" and len(fields) == 8:
            continue
        elif fields != [""]:
            raise ValueError("unknown native transcript row")
    schema = metadata.get("schema")
    expected_metadata = (REQUIRED_METADATA if
                         schema == "m23-native-ledger-batch-v1" else
                         STRATIFIED_METADATA if
                         schema == "m23-native-ledger-stratified-v1" else set())
    allowed_metadata = ({frozenset(expected_metadata)} if expected_metadata else set())
    if schema == "m23-native-ledger-stratified-v1":
        allowed_metadata.add(frozenset(STRATIFIED_METADATA - {
            "cache_reset_certificates",
        }))
    if frozenset(metadata) not in allowed_metadata or \
            metadata.get("coordinate_convention") != "native-v1":
        raise ValueError("native transcript metadata is incomplete or unsupported")
    numeric_metadata = {
        key: int(metadata[key]) for key in
        ("target_order", "start_block", "block_count", "macroblock_count",
         "proof_limit", "walk_limit")
    }
    if numeric_metadata["target_order"] < 2 or \
            numeric_metadata["start_block"] < 1 or \
            numeric_metadata["block_count"] < 1 or \
            numeric_metadata["macroblock_count"] < 1 or \
            numeric_metadata["proof_limit"] < 1 or \
            numeric_metadata["walk_limit"] < numeric_metadata["proof_limit"] or \
            numeric_metadata["start_block"] + numeric_metadata["block_count"] - 1 > \
            numeric_metadata["macroblock_count"]:
        raise ValueError("native transcript metadata bounds are invalid")
    certificate_ids = [int(row["local_id"]) for row in records
                       if "local_id" in row]
    if certificate_ids != list(range(1, len(certificate_ids) + 1)):
        raise ValueError("native certificate IDs are not contiguous")
    blocks = [row for row in records if "refined" in row]
    if len(blocks) != int(metadata["block_count"]):
        raise ValueError("native transcript block count is inconsistent")
    expected_blocks = (set(sampled_ordinals) if sampled_ordinals else
                       set(range(numeric_metadata["start_block"],
                                 numeric_metadata["start_block"] +
                                 numeric_metadata["block_count"])))
    if sampled_ordinals and (len(sampled_ordinals) != len(expected_blocks) or
                             metadata["identity_block_excluded"] != "1"):
        raise ValueError("native stratified sample plan is invalid")
    if {int(row["ordinal"]) for row in blocks} != expected_blocks:
        raise ValueError("native transcript block ordinals are not the declared batch")
    macroblock_count = numeric_metadata["macroblock_count"]
    for row in records:
        if "local_id" in row:
            if row["status"] not in {"closed", "overflow", "linked"} or \
                    row["walk_status"] not in {"closed", "overflow", "linked"}:
                raise ValueError("invalid native certificate status")
            if not 1 <= int(row["seed_ordinal"]) <= macroblock_count or \
                    int(row["seed_twist"]) < 1 or \
                    int(row["checked_vertices"]) < 0 or \
                    int(row["discovered_vertices"]) != len(row["vertices"]) or \
                    int(row["discovered_classes"]) < len(row["vertices"]):
                raise ValueError("invalid native certificate accounting")
            if any(not 1 <= ordinal <= macroblock_count or twist < 1
                   for ordinal, twist in row["vertices"]):
                raise ValueError("native certificate vertex is out of range")
        elif any(int(row[key]) < 0 for key in
                 ("refined", "generating", "new_certificates", "hits")) or \
                int(row["generating"]) > int(row["refined"]):
            raise ValueError("invalid native block accounting")
    return metadata, records


def import_transcript(transcript: Path, database: Path) -> dict[str, object]:
    if database.exists():
        raise FileExistsError(f"refusing to overwrite existing ledger: {database}")
    metadata, records = parse_transcript(transcript)
    start = int(metadata["start_block"])
    count = int(metadata["block_count"])
    ledger = Ledger(database)
    imported: dict[int, int] = {}
    try:
        ledger.initialize({
            "target_order": int(metadata["target_order"]),
            "pair_schema": 2,
            "macroblock_count": int(metadata["macroblock_count"]),
            "first_ordinal": 1,
            "last_ordinal": int(metadata["macroblock_count"]),
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
        for row in records:
            if "local_id" in row:
                local_id = int(row["local_id"])
                linked_local = int(row["linked"])
                if linked_local and linked_local not in imported:
                    raise ValueError("native certificate links forward or outside batch")
                certificate = ledger.add_certificate({
                    "status": row["status"],
                    "walk_status": row["walk_status"],
                    "linked_certificate": imported.get(linked_local),
                    "seed_ordinal": row["seed_ordinal"],
                    "seed_twist": row["seed_twist"],
                    "checked_vertices": row["checked_vertices"],
                    "discovered_vertices": row["discovered_vertices"],
                    "discovered_classes": row["discovered_classes"],
                }, list(row["vertices"]))
                if certificate != local_id:
                    raise ValueError("fresh SQLite certificate IDs changed order")
                imported[local_id] = certificate
            else:
                ordinal = int(row["ordinal"])
                actual_new = ledger.db.execute(
                    "SELECT COUNT(*) FROM certificates WHERE seed_ordinal=?",
                    (ordinal,),
                ).fetchone()[0]
                if actual_new != int(row["new_certificates"]) or \
                        int(row["hits"]) != int(row["generating"]) - actual_new:
                    raise ValueError("native block certificate accounting mismatch")
                with ledger.db:
                    ledger.db.execute(
                        "INSERT INTO blocks(ordinal,source,refined_vertices,"
                        "generating_vertices,new_certificates,ledger_hits,worker,"
                        "shard_index,shard_count) VALUES(?,?,?,?,?,?,?,?,?)",
                        (ordinal, row["source"], row["refined"], row["generating"],
                         actual_new, row["hits"], "native-import", 1, 1),
                    )
                    ledger.db.execute("DELETE FROM frontier WHERE ordinal=?", (ordinal,))
        quick_check = ledger.db.execute("PRAGMA quick_check").fetchone()[0]
        foreign_keys = ledger.db.execute("PRAGMA foreign_key_check").fetchall()
        if quick_check != "ok" or foreign_keys:
            raise ValueError("imported native ledger failed SQLite integrity checks")
        stats = ledger.stats()
    finally:
        ledger.close()
    return {
        "schema_version": 1,
        "coordinate_convention": "native-v1",
        "selection": ("stratified" if
                      metadata["schema"] == "m23-native-ledger-stratified-v1"
                      else "contiguous"),
        "source_checkpoint_sha256": metadata["source_checkpoint_sha256"],
        "counts": {key: stats[key] for key in
                   ("blocks", "certificates", "vertices")},
        "quick_check": "ok",
        "foreign_key_violations": 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="import a deterministic native quotient batch into SQLite"
    )
    parser.add_argument("transcript", type=Path)
    parser.add_argument("database", type=Path)
    args = parser.parse_args()
    print(json.dumps(import_transcript(args.transcript, args.database),
                     sort_keys=True))


if __name__ == "__main__":
    main()
