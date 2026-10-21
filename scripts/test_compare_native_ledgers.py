#!/usr/bin/env python3
from __future__ import annotations

import shutil
import tempfile
from pathlib import Path

from compare_native_ledgers import compare
from m23_quotient_ledger import Ledger


def make_ledger(path: Path) -> None:
    ledger = Ledger(path)
    ledger.initialize({
        "target_order": 5, "pair_schema": 2, "macroblock_count": 100,
        "first_ordinal": 1, "last_ordinal": 100, "proof_limit": 10,
        "walk_limit": 20, "schedule": "frontier", "start_ordinal": 10,
        "traversal_order": "native-v1",
    })
    with ledger.db:
        ledger._set_meta("native_source_checkpoint_sha256", "deadbeef")
    assert ledger.next_block() == (10, "ordinal")
    ledger.add_certificate({
        "status": "closed", "walk_status": "closed",
        "linked_certificate": None, "seed_ordinal": 10, "seed_twist": 1,
        "checked_vertices": 1, "discovered_vertices": 1,
        "discovered_classes": 1,
    }, [(10, 1)])
    ledger.finish_block(10, "ordinal", 1, 1)
    ledger.close()


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        actual = root / "actual.sqlite3"
        expected = root / "expected.sqlite3"
        make_ledger(actual)
        shutil.copyfile(actual, expected)
        result = compare(actual, expected)
        assert result["exact"] is True
        changed = Ledger(actual)
        with changed.db:
            changed.db.execute(
                "UPDATE blocks SET ledger_hits=ledger_hits+1"
            )
        changed.close()
        try:
            compare(actual, expected)
        except ValueError as error:
            assert "actual_only" in str(error)
        else:
            raise AssertionError("different native ledgers compared equal")
    print("native ledger exact comparison verified")


if __name__ == "__main__":
    main()
