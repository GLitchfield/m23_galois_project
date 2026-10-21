#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path

from m23_quotient_ledger import Ledger
from seed_native_stratified_frontier import read_plan, seed


PLAN = """# schema\tm23-native-ledger-stratified-v1
# coordinate_convention\tnative-v1
# target_order\t5
# source_checkpoint_sha256\tdeadbeef
# source_git_revision\t1234567
# gap_version\t4.12.1
# proof_limit\t10
# walk_limit\t20
# block_count\t2
# macroblock_count\t100
# identity_block_excluded\t1
S\t2\t2\t40\t1\t20
S\t3\t3\t59\t1\t80
"""


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        database = root / "ledger.sqlite3"
        plan = root / "plan.tsv"
        plan.write_text(PLAN)
        ledger = Ledger(database)
        ledger.initialize({
            "target_order": 5, "pair_schema": 2, "macroblock_count": 100,
            "first_ordinal": 1, "last_ordinal": 100, "proof_limit": 10,
            "walk_limit": 20, "schedule": "frontier", "start_ordinal": 10,
            "traversal_order": "native-v1",
        })
        with ledger.db:
            ledger._set_meta("native_source_checkpoint_sha256", "deadbeef")
        ledger.close()
        metadata, ordinals = read_plan(plan)
        assert metadata["macroblock_count"] == "100"
        assert ordinals == [20, 80]
        result = seed(database, plan, 2)
        assert result["blocks"] == 2
        assert result["shards"] == 2
        assert result["shard_blocks"] == [1, 1]
        db = sqlite3.connect(database)
        assert db.execute(
            "SELECT ordinal FROM frontier ORDER BY sequence"
        ).fetchall() == [(20,), (80,)]
        assert db.execute(
            "SELECT ordinal,shard_index,shard_count FROM planned_work "
            "ORDER BY sequence"
        ).fetchall() == [(20, 1, 2), (80, 2, 2)]
        assert db.execute(
            "SELECT value FROM meta WHERE key='native_work_plan_blocks'"
        ).fetchone() == ("2",)
        assert db.execute(
            "SELECT value FROM meta WHERE key='native_work_plan_shards'"
        ).fetchone() == ("2",)
        db.close()
        try:
            seed(database, plan, 2)
        except ValueError as error:
            assert "fresh native ledger" in str(error)
        else:
            raise AssertionError("nonfresh native ledger accepted a work plan")

        initialized = root / "initialized.sqlite3"
        result = seed(initialized, plan, 2, initialize=True,
                      start_ordinal=11)
        assert result["shard_blocks"] == [1, 1]
        db = sqlite3.connect(initialized)
        stored = dict(db.execute(
            "SELECT key,value FROM meta WHERE key IN "
            "('config_start_ordinal','native_source_git_revision',"
            "'native_gap_version','native_work_plan_blocks')"
        ))
        assert stored == {
            "config_start_ordinal": "11",
            "native_source_git_revision": "1234567",
            "native_gap_version": "4.12.1",
            "native_work_plan_blocks": "2",
        }
        db.close()
    print("native stratified frontier seeding verified")


if __name__ == "__main__":
    main()
