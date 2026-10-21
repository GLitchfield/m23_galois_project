#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from m23_quotient_ledger import Ledger


CONFIG = {
    "target_order": 4, "pair_schema": 2, "macroblock_count": 100,
    "first_ordinal": 2, "last_ordinal": 100, "proof_limit": 2500,
    "walk_limit": 25000, "schedule": "frontier", "start_ordinal": 10,
}


class LedgerTests(unittest.TestCase):
    def test_special_block_can_be_queued_outside_scan_range(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ledger = Ledger(Path(temporary) / "ledger.sqlite3")
            ledger.initialize(CONFIG)
            ledger.enqueue_special_block(1)
            self.assertEqual(ledger.next_block(), (1, "frontier"))
            ledger.finish_block(1, "frontier", 3, 2)
            with self.assertRaises(ValueError):
                ledger.enqueue_special_block(1)
            with self.assertRaises(ValueError):
                ledger.enqueue_special_block(101)
            ledger.close()

    def test_frontier_priority_and_restart_lease(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            ledger = Ledger(path)
            ledger.initialize(CONFIG)
            self.assertEqual(ledger.next_block(), (10, "ordinal"))
            ledger.close()
            ledger = Ledger(path)
            ledger.initialize(CONFIG)
            self.assertEqual(ledger.next_block(), (10, "ordinal"))
            certificate = ledger.add_certificate({
                "status": "overflow", "walk_status": "overflow",
                "linked_certificate": None, "seed_ordinal": 10, "seed_twist": 1,
                "checked_vertices": 2, "discovered_vertices": 3,
                "discovered_classes": 2501,
            }, [(10, 1), (30, 2), (20, 1)])
            self.assertEqual(certificate, 1)
            ledger.finish_block(10, "ordinal", 1, 1)
            self.assertEqual(ledger.next_block(), (30, "frontier"))
            ledger.finish_block(30, "frontier", 2, 1)
            self.assertEqual(ledger.next_block(), (20, "frontier"))
            self.assertEqual(ledger.lookup(30, 2), 1)
            stats = ledger.stats()
            self.assertEqual(stats["blocks"], 2)
            self.assertEqual(stats["vertices"], 3)
            self.assertEqual(stats["pending"], 1)
            ledger.close()

    def test_duplicate_vertex_rolls_back_whole_certificate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ledger = Ledger(Path(temporary) / "ledger.sqlite3")
            ledger.initialize(CONFIG)
            data = {
                "status": "overflow", "walk_status": "overflow",
                "linked_certificate": None, "seed_ordinal": 10, "seed_twist": 1,
                "checked_vertices": 1, "discovered_vertices": 1,
                "discovered_classes": 2501,
            }
            ledger.add_certificate(data, [(10, 1)])
            with self.assertRaises(sqlite3.IntegrityError):
                ledger.add_certificate(data, [(10, 1)])
            self.assertEqual(ledger.stats()["certificates"], 1)
            ledger.close()

    def test_configuration_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ledger = Ledger(Path(temporary) / "ledger.sqlite3")
            ledger.initialize(CONFIG)
            changed = dict(CONFIG, proof_limit=999)
            with self.assertRaises(ValueError):
                ledger.initialize(changed)
            ledger.close()

    def test_traversal_order_is_versioned_and_legacy_is_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            current_path = Path(temporary) / "current.sqlite3"
            current = Ledger(current_path)
            current.initialize(dict(CONFIG, traversal_order="key-v2"))
            self.assertEqual(
                current._meta("config_traversal_order"), "key-v2"
            )
            with self.assertRaises(ValueError):
                current.initialize(dict(CONFIG, traversal_order="legacy"))
            current.close()

            legacy_path = Path(temporary) / "legacy.sqlite3"
            legacy = Ledger(legacy_path)
            legacy.initialize(CONFIG)
            legacy.initialize(dict(CONFIG, traversal_order="legacy"))
            with self.assertRaises(ValueError):
                legacy.initialize(dict(CONFIG, traversal_order="key-v2"))
            legacy.close()

    def test_readonly_ledger_lists_vertices(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            ledger = Ledger(path)
            ledger.initialize(CONFIG)
            ledger.add_certificate({
                "status": "closed", "walk_status": "closed",
                "linked_certificate": None, "seed_ordinal": 10,
                "seed_twist": 1, "checked_vertices": 1,
                "discovered_vertices": 1, "discovered_classes": 1,
            }, [(10, 1)])
            ledger.close()
            readonly = Ledger(path, readonly=True)
            readonly.initialize(CONFIG)
            self.assertEqual(readonly.vertices(), [(10, 1, 1)])
            self.assertEqual(readonly.vertices(0), [])
            self.assertEqual(readonly.vertices(1), [(10, 1, 1)])
            self.assertEqual(readonly.certificate_prefix_stats(1),
                             (1, 1, 0, 0, 1))
            self.assertEqual(readonly.seed_counts(1, 1), [(10, 1)])
            readonly.close()

    def test_prefix_lookup_and_streamed_block_segments(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            ledger = Ledger(path)
            ledger.initialize(CONFIG)
            for ordinal, linked in ((10, None), (11, 1), (12, 2)):
                self.assertEqual(ledger.next_block(), (ordinal, "ordinal"))
                certificate = ledger.add_certificate({
                    "status": "closed" if linked is None else "linked",
                    "walk_status": "closed" if linked is None else "linked",
                    "linked_certificate": linked,
                    "seed_ordinal": ordinal,
                    "seed_twist": 1,
                    "checked_vertices": 1,
                    "discovered_vertices": 1,
                    "discovered_classes": 1,
                }, [(ordinal, 1)])
                self.assertEqual(certificate, ordinal - 9)
                ledger.finish_block(ordinal, "ordinal", 1, 1)

            self.assertIsNone(ledger.lookup_before(11, 1, 1))
            self.assertEqual(ledger.lookup_before(11, 1, 2), 2)
            self.assertEqual(ledger.lookup_before(11, 1, 3), 2)
            self.assertEqual(ledger.block_segment_count(1, 1, 2), 1)
            self.assertEqual(ledger.block_segment_count(1, 2, 2), 1)
            first = list(ledger.iter_block_segment(1, 1, 1, 2))
            second = list(ledger.iter_block_segment(1, 1, 2, 2))
            self.assertEqual(first[0][0], 11)
            self.assertEqual(second[0][0], 12)
            self.assertEqual(first[0][-1], 1)
            self.assertEqual(second[0][-1], 1)
            ledger.close()

    def test_multiworker_conflict_requires_retry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            first = Ledger(path)
            first.initialize(CONFIG)
            second = Ledger(path)
            second.initialize(CONFIG)
            self.assertEqual(first.claim_block("worker-1", 60), (10, "ordinal"))
            self.assertEqual(second.claim_block("worker-2", 60), "wait")
            overflow = {
                "status": "overflow", "walk_status": "overflow",
                "linked_certificate": None, "seed_ordinal": 10, "seed_twist": 1,
                "checked_vertices": 2, "discovered_vertices": 2,
                "discovered_classes": 2501,
            }
            self.assertEqual(first.try_add_certificate(
                "worker-1", 10, overflow, [(10, 1), (50, 1)]), ("added", 1))
            self.assertEqual(second.claim_block("worker-2", 60), (50, "frontier"))
            conflicting = dict(overflow, seed_ordinal=50)
            self.assertEqual(second.try_add_certificate(
                "worker-2", 50, conflicting, [(50, 2), (50, 1)]),
                ("conflict", 1))
            linked = {
                "status": "linked", "walk_status": "linked",
                "linked_certificate": 1, "seed_ordinal": 50, "seed_twist": 2,
                "checked_vertices": 1, "discovered_vertices": 1,
                "discovered_classes": 10,
            }
            self.assertEqual(second.try_add_certificate(
                "worker-2", 50, linked, [(50, 2)]), ("added", 2))
            first.finish_worker_block("worker-1", 10, "ordinal", 1, 1)
            second.finish_worker_block("worker-2", 50, "frontier", 2, 2)
            self.assertEqual(first.stats()["linked"], 1)
            first.close()
            second.close()

    def test_existing_wal_ledger_opens_while_another_worker_writes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            first = Ledger(path)
            first.initialize(CONFIG)
            first.db.execute("BEGIN IMMEDIATE")
            try:
                # Opening a worker must not try to set WAL mode or run schema
                # DDL: either operation would wait behind this writer lock.
                second = Ledger(path)
                second.initialize(CONFIG)
                second.close()
            finally:
                first.db.rollback()
                first.close()

    def test_completed_frontier_is_pruned_and_not_reintroduced(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            ledger = Ledger(path)
            ledger.initialize(CONFIG)
            self.assertEqual(ledger.claim_block("worker", 60), (10, "ordinal"))
            ledger.finish_worker_block("worker", 10, "ordinal", 0, 0)
            self.assertIsNone(ledger.db.execute(
                "SELECT 1 FROM frontier WHERE ordinal=10"
            ).fetchone())
            ledger.add_certificate({
                "status": "linked", "walk_status": "linked",
                "linked_certificate": None, "seed_ordinal": 20,
                "seed_twist": 1, "checked_vertices": 1,
                "discovered_vertices": 2, "discovered_classes": 2,
            }, [(10, 1), (20, 1)])
            self.assertEqual(
                ledger.db.execute(
                    "SELECT ordinal FROM frontier ORDER BY sequence"
                ).fetchall(),
                [(20,)],
            )
            ledger.close()

    def test_open_migrates_historical_completed_frontier(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            ledger = Ledger(path)
            ledger.initialize(CONFIG)
            self.assertEqual(ledger.claim_block("worker", 60), (10, "ordinal"))
            ledger.finish_worker_block("worker", 10, "ordinal", 0, 0)
            with ledger.db:
                ledger.db.execute("INSERT INTO frontier(ordinal) VALUES(10)")
            ledger.close()
            migrated = Ledger(path)
            self.assertEqual(migrated.stats()["pending"], 0)
            self.assertTrue(migrated.db.execute(
                "SELECT 1 FROM sqlite_master WHERE type='index' "
                "AND name='certificates_seed_ordinal_idx'"
            ).fetchone())
            migrated.close()

    def test_expired_lease_is_reclaimed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            first = Ledger(path)
            first.initialize(CONFIG)
            self.assertEqual(first.claim_block("dead-worker", 60), (10, "ordinal"))
            first.db.execute("UPDATE leases SET expires=0")
            first.db.commit()
            second = Ledger(path)
            second.initialize(CONFIG)
            self.assertEqual(second.claim_block("replacement", 60), (10, "frontier"))
            first.close()
            second.close()

    def test_global_block_target_counts_active_leases(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            first = Ledger(path)
            first.initialize(CONFIG)
            second = Ledger(path)
            second.initialize(CONFIG)
            self.assertEqual(first.claim_block("one", 60, 1), (10, "ordinal"))
            self.assertIsNone(second.claim_block("two", 60, 1))
            first.close()
            second.close()

    def test_deterministic_shards_claim_disjoint_frontiers(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "ledger.sqlite3"
            even = Ledger(path)
            even.initialize(CONFIG)
            odd = Ledger(path)
            odd.initialize(CONFIG)
            self.assertEqual(even.claim_block("even", 60, 0, 1, 2),
                             (10, "ordinal"))
            self.assertEqual(odd.claim_block("odd", 60, 0, 2, 2),
                             (11, "ordinal"))
            even.finish_worker_block("even", 10, "ordinal", 0, 0)
            odd.finish_worker_block("odd", 11, "ordinal", 0, 0)
            with even.db:
                even.db.execute(
                    "INSERT INTO frontier(ordinal) VALUES(30),(31)"
                )
            self.assertEqual(even.claim_block("even", 60, 0, 1, 2),
                             (30, "frontier"))
            self.assertEqual(odd.claim_block("odd", 60, 0, 2, 2),
                             (31, "frontier"))
            assignments = even.db.execute(
                "SELECT ordinal,worker,shard_index,shard_count FROM blocks "
                "ORDER BY ordinal"
            ).fetchall()
            self.assertEqual(assignments, [
                (10, "even", 1, 2), (11, "odd", 2, 2)
            ])
            even.close()
            odd.close()

    def test_dynamic_workers_record_virtual_shard_owner(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ledger = Ledger(Path(temporary) / "ledger.sqlite3")
            ledger.initialize(CONFIG)
            self.assertEqual(ledger.claim_block("worker-9", 60, 0, 0, 4),
                             (10, "ordinal"))
            ledger.finish_worker_block("worker-9", 10, "ordinal", 0, 0)
            self.assertEqual(
                ledger.db.execute(
                    "SELECT worker,shard_index,shard_count FROM blocks"
                ).fetchone(),
                ("worker-9", 1, 4),
            )
            ledger.close()


if __name__ == "__main__":
    unittest.main()
