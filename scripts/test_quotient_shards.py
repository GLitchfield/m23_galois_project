#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from m23_quotient_ledger import Ledger
from m23_quotient_shards import audit, prepare, retarget
from snapshot_quotient_ledger import create_snapshot
from test_quotient_ledger import CONFIG


class QuotientShardTests(unittest.TestCase):
    def make_base(self, root: Path) -> tuple[Path, Path]:
        source = root / "source.sqlite3"
        ledger = Ledger(source)
        ledger.initialize(CONFIG)
        ledger.close()
        progress = root / "base-progress.tsv"
        progress.write_text(
            "1\tgap\tverify_quotient_db\tall\tdone\t"
            "certificates=0,blocks=0,vertices=0\n"
        )
        base = root / "base.sqlite3"
        manifest = root / "base.json"
        create_snapshot(source, base, manifest, progress)
        return base, manifest

    def test_prepare_and_audit_deterministic_owners(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base, manifest = self.make_base(root)
            run = root / "run"
            prepare(base, manifest, run, 2, 2)
            first = Ledger(run / "ledger.sqlite3")
            first.initialize(CONFIG)
            second = Ledger(run / "ledger.sqlite3")
            second.initialize(CONFIG)
            self.assertEqual(first.claim_block("worker-1", 60, 2, 1, 2),
                             (10, "ordinal"))
            self.assertEqual(second.claim_block("worker-2", 60, 2, 2, 2),
                             (11, "ordinal"))
            first.finish_worker_block("worker-1", 10, "ordinal", 0, 0)
            second.finish_worker_block("worker-2", 11, "ordinal", 0, 0)
            first.close()
            second.close()
            progress = run / "progress.tsv"
            progress.write_text(
                "2\tgap\tverify_quotient_db\tall\tdone\t"
                "certificates=0,blocks=2,vertices=0\n"
            )
            result = audit(base, manifest, run, progress)
            self.assertTrue(result["base_preserved"])
            self.assertEqual(result["new_blocks"], 2)

    def test_audit_rejects_changed_owner(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base, manifest = self.make_base(root)
            run = root / "run"
            prepare(base, manifest, run, 2, 1)
            record = json.loads((run / "shards.json").read_text())
            self.assertEqual(record["shard_count"], 2)
            ledger = Ledger(run / "ledger.sqlite3")
            ledger.initialize(CONFIG)
            ledger.db.execute(
                "INSERT INTO blocks(ordinal,source,refined_vertices,"
                "generating_vertices,new_certificates,ledger_hits,worker,"
                "shard_index,shard_count) VALUES(10,'ordinal',0,0,0,0,"
                "'worker-2',2,2)"
            )
            ledger.db.commit()
            ledger.close()
            progress = run / "progress.tsv"
            progress.write_text(
                "2\tgap\tverify_quotient_db\tall\tdone\t"
                "certificates=0,blocks=1,vertices=0\n"
            )
            with self.assertRaises(ValueError):
                audit(base, manifest, run, progress)

    def test_retarget_records_a_completed_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base, manifest = self.make_base(root)
            run = root / "run"
            prepare(base, manifest, run, 2, 1)
            ledger = Ledger(run / "ledger.sqlite3")
            ledger.initialize(CONFIG)
            ledger.next_block()
            ledger.finish_block(10, "ordinal", 0, 0)
            ledger.close()
            record = retarget(base, manifest, run, 4, 1)
            self.assertEqual(record["target_blocks"], 1)
            self.assertEqual(record["shard_count"], 4)


if __name__ == "__main__":
    unittest.main()
