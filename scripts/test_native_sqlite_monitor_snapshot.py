#!/usr/bin/env python3

from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path

from checkpoint_sqlite_ledger import checkpoint
from m23_quotient_ledger import Ledger
from monitor_native_sqlite_ledger import read_stats
from snapshot_sqlite_ledger import snapshot


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        source = root / "source.sqlite3"
        target = root / "snapshot.sqlite3"
        ledger = Ledger(source)
        ledger.initialize({
            "target_order": 5, "pair_schema": 2, "macroblock_count": 10,
            "first_ordinal": 1, "last_ordinal": 10, "proof_limit": 2,
            "walk_limit": 3, "schedule": "frontier", "start_ordinal": 2,
            "traversal_order": "native-v1",
        })
        assert ledger.next_block() == (2, "ordinal")
        certificate = ledger.add_certificate({
            "status": "closed", "walk_status": "closed",
            "linked_certificate": None, "seed_ordinal": 2,
            "seed_twist": 1, "checked_vertices": 1,
            "discovered_vertices": 1, "discovered_classes": 1,
        }, [(2, 1)])
        assert certificate == 1
        ledger.finish_block(2, "ordinal", 1, 1)
        ledger.close()
        assert read_stats(source) == (1, 1, 1, 2)
        checkpoint_result = checkpoint(source)
        assert checkpoint_result["quick_check"] == "ok"
        assert checkpoint_result["wal_bytes_after"] == 0
        result = snapshot(source, target)
        assert result["blocks"] == 1
        assert result["certificates"] == 1
        assert result["vertices"] == 1
        copied = sqlite3.connect(target)
        assert copied.execute("PRAGMA quick_check").fetchone() == ("ok",)
        copied.close()
    print("native SQLite progress and snapshot verified")


if __name__ == "__main__":
    main()
