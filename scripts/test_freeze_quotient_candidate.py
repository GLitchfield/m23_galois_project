#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from freeze_quotient_candidate import freeze
from m23_quotient_ledger import Ledger
from test_quotient_ledger import CONFIG


class FreezeQuotientCandidateTests(unittest.TestCase):
    def test_freezes_completed_unverified_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.sqlite3"
            ledger = Ledger(source)
            ledger.initialize(CONFIG)
            ledger.next_block()
            ledger.finish_block(10, "ordinal", 0, 0)
            ledger.close()
            progress = root / "progress.tsv"
            progress.write_text("1\tgap\tquotient_db_scan\t2-100\tdone\tscanned=1\n")
            shards = root / "shards.json"
            shards.write_text(json.dumps({"target_blocks": 1}))
            record = freeze(source, progress, shards, root / "candidate", 1)
            self.assertEqual(record["counts"]["blocks"], 1)
            self.assertEqual(record["status"], "verification_pending")
            self.assertEqual(
                (root / "candidate" / "ledger.sqlite3").stat().st_mode & 0o222,
                0,
            )


if __name__ == "__main__":
    unittest.main()
