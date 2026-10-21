#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path

from import_native_ledger_batch import import_transcript, parse_transcript
from verify_native_ledger_fixture import verify


TRANSCRIPT = """# schema\tm23-native-ledger-batch-v1
# coordinate_convention\tnative-v1
# target_order\t5
# source_checkpoint_sha256\tdeadbeef
# source_git_revision\t0123456789abcdef
# gap_version\t4.12.1
# start_block\t10
# block_count\t3
# macroblock_count\t20
# proof_limit\t30400
# walk_limit\t30400
C\t1\tclosed\tclosed\t0\t10\t1\t2\t2\t2
V\t1\t1\t10\t1
V\t1\t2\t11\t1
B\t10\tordinal\t2\t1\t1\t0
C\t2\tlinked\tlinked\t1\t12\t1\t1\t1\t1
V\t2\t1\t12\t1
B\t12\tordinal\t1\t1\t1\t0
B\t11\tfrontier\t1\t1\t0\t1
"""

FIXTURE = """# schema\tm23-native-bounded-walk-fixture-v1
# source_checkpoint_sha256\tdeadbeef
# limit\t30400
# status\tclosed
# checked_vertex_count\t2
# discovered_vertex_count\t2
# discovered_class_count\t2
vertex\t1\t10\t1\t1
vertex\t2\t11\t1\t1
"""

STRATIFIED = """# schema\tm23-native-ledger-stratified-v1
# coordinate_convention\tnative-v1
# target_order\t5
# source_checkpoint_sha256\tdeadbeef
# source_git_revision\t0123456789abcdef
# gap_version\t4.12.1
# start_block\t10
# block_count\t2
# macroblock_count\t20
# proof_limit\t30400
# walk_limit\t30400
# samples_per_segment\t1
# identity_block_excluded\t1
# cache_reset_certificates\t100
S\t2\t2\t10\t1\t10
S\t3\t3\t9\t1\t20
C\t1\tclosed\tclosed\t0\t10\t1\t1\t1\t1
V\t1\t1\t10\t1
B\t10\tordinal\t1\t1\t1\t0
T\t10\t1.0\t0.1\t0.1\t0.8\t1\t1
B\t20\tordinal\t1\t0\t0\t0
T\t20\t0.1\t0.05\t0.05\t0.0\t0\t0
"""


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        transcript = root / "batch.tsv"
        fixture = root / "fixture.tsv"
        database = root / "ledger.sqlite3"
        transcript.write_text(TRANSCRIPT)
        fixture.write_text(FIXTURE)
        metadata, records = parse_transcript(transcript)
        assert metadata["coordinate_convention"] == "native-v1"
        assert len(records) == 5
        result = import_transcript(transcript, database)
        assert result["counts"] == {"blocks": 3, "certificates": 2, "vertices": 3}
        db = sqlite3.connect(database)
        assert db.execute("PRAGMA quick_check").fetchone()[0] == "ok"
        assert db.execute("PRAGMA foreign_key_check").fetchall() == []
        assert db.execute(
            "SELECT status,walk_status,linked_certificate FROM certificates "
            "ORDER BY id"
        ).fetchall() == [("closed", "closed", None), ("linked", "linked", 1)]
        assert db.execute(
            "SELECT ordinal,new_certificates,ledger_hits FROM blocks "
            "ORDER BY sequence"
        ).fetchall() == [(10, 1, 0), (12, 1, 0), (11, 0, 1)]
        db.close()
        audit = verify(database, fixture, 1)
        assert audit["ordered_gap_fixture_match"] is True
        bad = root / "bad.tsv"
        bad.write_text(TRANSCRIPT.replace(
            "B\t11\tfrontier\t1\t1\t0\t1",
            "B\t20\tfrontier\t1\t1\t0\t1",
        ))
        try:
            parse_transcript(bad)
        except ValueError as error:
            assert "declared batch" in str(error)
        else:
            raise AssertionError("out-of-batch native block was accepted")
        stratified = root / "stratified.tsv"
        stratified_db = root / "stratified.sqlite3"
        stratified.write_text(STRATIFIED)
        result = import_transcript(stratified, stratified_db)
        assert result["selection"] == "stratified"
        assert result["counts"] == {
            "blocks": 2, "certificates": 1, "vertices": 1,
        }
    print("native ledger transcript importer verified")


if __name__ == "__main__":
    main()
