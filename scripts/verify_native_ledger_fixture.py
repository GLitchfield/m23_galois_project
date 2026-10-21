#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path


def read_fixture(path: Path) -> tuple[dict[str, str], list[tuple[int, int, int]]]:
    metadata: dict[str, str] = {}
    vertices = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line:
            continue
        fields = line.split("\t")
        if fields[0].startswith("# "):
            key = fields[0][2:]
            if key in metadata:
                raise ValueError(f"duplicate fixture metadata at line {number}")
            metadata[key] = "\t".join(fields[1:])
        elif fields[0] == "vertex" and len(fields) == 5 and \
                int(fields[1]) == len(vertices) + 1:
            vertices.append(tuple(map(int, fields[2:5])))
        else:
            raise ValueError(f"invalid fixture row at line {number}")
    required = {"schema", "source_checkpoint_sha256", "limit", "status",
                "checked_vertex_count", "discovered_vertex_count",
                "discovered_class_count"}
    if not required <= set(metadata) or \
            metadata["schema"] != "m23-native-bounded-walk-fixture-v1" or \
            int(metadata["discovered_vertex_count"]) != len(vertices) or \
            sum(weight for _, _, weight in vertices) != \
                int(metadata["discovered_class_count"]):
        raise ValueError("bounded-walk fixture metadata is inconsistent")
    return metadata, vertices


def verify(database: Path, fixture: Path, certificate: int) -> dict[str, object]:
    metadata, expected = read_fixture(fixture)
    db = sqlite3.connect(f"file:{database.resolve()}?mode=ro", uri=True)
    try:
        row = db.execute(
            "SELECT status,walk_status,linked_certificate,checked_vertices,"
            "discovered_vertices,discovered_classes FROM certificates WHERE id=?",
            (certificate,),
        ).fetchone()
        if row is None:
            raise ValueError("native ledger certificate is absent")
        actual = db.execute(
            "SELECT ordinal,twist FROM certificate_vertices "
            "WHERE certificate=? ORDER BY position", (certificate,)
        ).fetchall()
        source_sha = db.execute(
            "SELECT value FROM meta WHERE key='native_source_checkpoint_sha256'"
        ).fetchone()
        if source_sha is None or source_sha[0] != metadata["source_checkpoint_sha256"]:
            raise ValueError("native ledger and GAP fixture name different sources")
        if row[0] != metadata["status"] or row[1] != metadata["status"] or \
                row[2] is not None or row[3] != int(metadata["checked_vertex_count"]) or \
                row[4] != len(expected) or \
                row[5] != int(metadata["discovered_class_count"]) or \
                actual != [(ordinal, twist) for ordinal, twist, _ in expected]:
            raise ValueError("native ledger certificate disagrees with GAP fixture")
        if db.execute("PRAGMA quick_check").fetchone()[0] != "ok" or \
                db.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("native ledger failed SQLite integrity checks")
    finally:
        db.close()
    return {
        "schema_version": 1,
        "certificate": certificate,
        "status": metadata["status"],
        "checked_vertices": int(metadata["checked_vertex_count"]),
        "discovered_vertices": len(expected),
        "discovered_classes": int(metadata["discovered_class_count"]),
        "ordered_gap_fixture_match": True,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="compare a native SQLite certificate with a GAP fixture"
    )
    parser.add_argument("database", type=Path)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("certificate", type=int, nargs="?", default=1)
    args = parser.parse_args()
    print(json.dumps(verify(args.database, args.fixture, args.certificate),
                     sort_keys=True))


if __name__ == "__main__":
    main()
