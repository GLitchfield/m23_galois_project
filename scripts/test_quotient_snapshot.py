#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from m23_quotient_ledger import Ledger
from snapshot_quotient_ledger import create_snapshot
from test_quotient_ledger import CONFIG


class QuotientSnapshotTests(unittest.TestCase):
    def test_snapshot_requires_matching_exact_replay(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "ledger.sqlite3"
            ledger = Ledger(source)
            ledger.initialize(CONFIG)
            ledger.close()
            progress = root / "progress.tsv"
            progress.write_text(
                "1\tgap\tverify_quotient_db\tall\tdone\t"
                "certificates=0,blocks=0,vertices=0\n"
            )
            record = create_snapshot(
                source, root / "base.sqlite3", root / "base.json", progress
            )
            self.assertEqual(record["counts"]["blocks"], 0)
            self.assertEqual((root / "base.sqlite3").stat().st_mode & 0o222, 0)

    def test_snapshot_rejects_stale_replay(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "ledger.sqlite3"
            ledger = Ledger(source)
            ledger.initialize(CONFIG)
            ledger.next_block()
            ledger.finish_block(10, "ordinal", 0, 0)
            ledger.close()
            progress = root / "progress.tsv"
            progress.write_text(
                "1\tgap\tverify_quotient_db\tall\tdone\t"
                "certificates=0,blocks=0,vertices=0\n"
            )
            with self.assertRaises(ValueError):
                create_snapshot(
                    source, root / "base.sqlite3", root / "base.json", progress
                )


if __name__ == "__main__":
    unittest.main()
