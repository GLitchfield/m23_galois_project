#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from finalize_parallel_quotient_verification import finalize
from m23_quotient_ledger import Ledger
from plan_quotient_certificate_segments import plan as plan_segments
from snapshot_quotient_ledger import sha256
from test_quotient_ledger import CONFIG


class ParallelQuotientVerificationTests(unittest.TestCase):
    def test_streaming_planner_balances_contiguous_certificates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "ledger.sqlite3"
            ledger = Ledger(database)
            ledger.initialize(CONFIG)
            for certificate, weight in enumerate((1, 9, 1, 9, 1), 1):
                ledger.add_certificate({
                    "status": "closed", "walk_status": "closed",
                    "linked_certificate": None,
                    "seed_ordinal": certificate + 10,
                    "seed_twist": 1,
                    "checked_vertices": weight,
                    "discovered_vertices": 1,
                    "discovered_classes": 1,
                }, [(certificate + 10, 1)])
            ledger.close()

            result = plan_segments(database, 0, 3)
            segments = result["segments"]
            self.assertEqual(len(segments), 3)
            self.assertEqual(segments[0]["first_certificate"], 1)
            self.assertEqual(segments[-1]["last_certificate"], 5)
            self.assertEqual(sum(segment["weight"] for segment in segments), 26)
            for left, right in zip(segments, segments[1:]):
                self.assertEqual(
                    left["last_certificate"] + 1,
                    right["first_certificate"],
                )

    def test_composes_certificate_and_block_segments(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base = root / "base.sqlite3"
            ledger = Ledger(base)
            ledger.initialize(CONFIG)
            ledger.next_block()
            ledger.add_certificate({
                "status": "closed", "walk_status": "closed",
                "linked_certificate": None, "seed_ordinal": 10,
                "seed_twist": 1, "checked_vertices": 1,
                "discovered_vertices": 1, "discovered_classes": 1,
            }, [(10, 1)])
            ledger.finish_block(10, "ordinal", 1, 1)
            ledger.close()
            database = root / "run.sqlite3"
            shutil.copyfile(base, database)
            ledger = Ledger(database)
            ledger.initialize(CONFIG)
            self.assertEqual(ledger.next_block(), (11, "ordinal"))
            ledger.add_certificate({
                "status": "linked", "walk_status": "linked",
                "linked_certificate": 1, "seed_ordinal": 11,
                "seed_twist": 1, "checked_vertices": 1,
                "discovered_vertices": 1, "discovered_classes": 1,
            }, [(11, 1)])
            ledger.finish_block(11, "ordinal", 1, 1)
            ledger.close()
            plan = root / "plan.json"
            plan.write_text(json.dumps({
                "plan_id": "test-plan",
                "database_sha256": sha256(database),
                "segments": [{
                    "index": 1, "count": 1,
                    "first_certificate": 2, "last_certificate": 2,
                }],
            }))
            progress = root / "progress.tsv"
            progress.write_text(
                "1\tgap\tverify_quotient_certificate_segment\t1-of-1\tdone\t"
                "plan=test-plan,first=2,last=2,certificates=1,closed=0,"
                "overflow=0,linked=1,vertices=1\n"
                "2\tgap\tverify_quotient_block_segment\t1-of-1\tdone\t"
                "plan=test-plan,blocks=1,refined=1,generating=1,hits=0\n"
            )
            planned = plan_segments(database, 1, 1, 1)
            self.assertEqual(planned["base_blocks"], 1)
            self.assertEqual(planned["segments"][0]["first_certificate"], 2)
            result = finalize(database, base, plan, progress, 1)
            self.assertTrue(result["exact_parallel_replay"])
            self.assertIn("verify_quotient_db_delta_parallel", progress.read_text())


if __name__ == "__main__":
    unittest.main()
