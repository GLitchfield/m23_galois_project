#!/usr/bin/env python3

from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path

from audit_native_full_cursor_plan import audit
from benchmark_native_work_plan_storage import benchmark
from seed_native_full_cursor_plan import seed


PLAN = """# schema\tm23-native-ledger-stratified-v1
# coordinate_convention\tnative-v1
# target_order\t5
# source_checkpoint_sha256\tdeadbeef
# source_git_revision\t1234567
# gap_version\t4.12.1
# start_block\t10
# block_count\t2
# macroblock_count\t10
# proof_limit\t2
# walk_limit\t3
# samples_per_segment\t2
# identity_block_excluded\t1
S\t2\t2\t5\t1\t2
S\t2\t2\t5\t2\t4
"""


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        plan = root / "plan.tsv"
        ledger = root / "ledger.sqlite3"
        plan.write_text(PLAN)
        result = seed(ledger, plan, 3, start_ordinal=2)
        assert result["materialized_plan_rows"] == 0
        assert result["shard_blocks"] == [4, 3, 3]
        initial = audit(ledger)
        assert initial["valid"] is True and initial["complete"] is False
        database = sqlite3.connect(ledger)
        with database:
            database.executemany(
                "INSERT INTO blocks(ordinal,source,refined_vertices,"
                "generating_vertices,new_certificates,ledger_hits,worker,"
                "shard_index,shard_count) VALUES(?,?,?,?,?,?,?,?,?)",
                ((ordinal, "ordinal", 0, 0, 0, 0, "fixture",
                  1 + (ordinal - 1) % 3, 3) for ordinal in range(1, 11)),
            )
        database.close()
        complete = audit(ledger, require_complete=True)
        assert complete["complete"] is True
        assert complete["actual_shard_blocks"] == [[1, 4], [2, 3], [3, 3]]
        storage = root / "storage"
        storage.mkdir()
        measured = benchmark(storage, 1000, 10_000, 3)
        assert measured["marginal_explicit_bytes"] > 0
        assert measured["linear_projected_full_bytes"] > \
            measured["marginal_explicit_bytes"]
    print("native compact full-cursor plan verified")


if __name__ == "__main__":
    main()
