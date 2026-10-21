#!/usr/bin/env python3
from __future__ import annotations

import os
import json
import tempfile
import time
import unittest
from pathlib import Path

from m23_dashboard import discover_runs, tail_text
from m23_run_status import collect_run_status, native_progress, parse_detail, read_events


class RunMonitorTests(unittest.TestCase):
    def test_status_uses_latest_invocation_and_completed_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary) / "sample"
            run.mkdir()
            (run / "progress.tsv").write_text(
                "100\tshell\trun\tall\tstart\tclass=4,shards=2,jobs=1\n"
                "101\tshell\tshard\t1\tdone\told\n"
                "malformed\n"
                "200\tshell\trun\tall\tstart\tclass=5,shards=4,jobs=2\n"
                "201\tgap\tverify_representatives\t1\tdone\tok\n"
                "202\tgap\tverify_deep\t1\tdone\tok\n"
            )
            (run / "shard-1-of-4.g").write_text("checkpoint")
            (run / "certificate.tsv").write_text("certificate")
            (run / "result.tsv").write_text("result")
            status = collect_run_status(run)
            self.assertEqual(status["config"]["class"], "5")
            self.assertEqual(status["event_count"], 3)
            self.assertEqual(status["progress"]["expected_shards"], 4)
            self.assertEqual(status["progress"]["checkpoints"], 1)
            self.assertEqual(status["progress"]["representative_verification"], 4)
            self.assertEqual(status["progress"]["deep_recount"], 4)
            self.assertEqual(status["overall_state"], "complete")

    def test_discovery_and_bounded_log_tail(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = root / "nested" / "first"
            second = root / "second"
            first.mkdir(parents=True)
            second.mkdir()
            (first / "progress.tsv").write_text("")
            (second / "result.tsv").write_text("complete")
            (first / "runner.log").write_text("one\ntwo\nthree\nfour\n")
            self.assertEqual(discover_runs([root]), [first.resolve(), second.resolve()])
            self.assertEqual(tail_text(first / "runner.log", 2), "three\nfour")
            self.assertEqual(tail_text(root / "missing.log", 20), "")

    def test_detail_parser_ignores_free_text(self) -> None:
        self.assertEqual(parse_detail("class=4,shards=8,plain text"),
                         {"class": "4", "shards": "8"})

    def test_native_progress_uses_latest_complete_runner_row(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "runner.log").write_text(
                "progress\t1\t16\t42\t0.25\t2\t300\n"
                "partial\n"
                "progress\t2\t16\t84\t1.5\t3\t900\tadded=1,hits=0\n"
            )
            self.assertEqual(native_progress(run), {
                "completed_blocks": 2,
                "total_blocks": 16,
                "latest_ordinal": 84,
                "latest_block_seconds": 1.5,
                "certificates": 3,
                "owned_vertices": 900,
            })

    def test_event_reader_ignores_invalid_timestamps(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "progress.tsv").write_text(
                "nope\tshell\trun\tall\tstart\tdetail\n"
                "123\tshell\tshard\t1\tdone\tpath\n"
            )
            self.assertEqual(len(read_events(run)), 1)

    def test_event_reader_incrementally_observes_appends(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            progress = run / "progress.tsv"
            progress.write_text(
                "123\tshell\tphase\t1\tstart\tone\n"
            )
            self.assertEqual(len(read_events(run)), 1)
            with progress.open("a") as stream:
                stream.write("124\tshell\tphase\t1\tprogress\ttwo\n")
            events = read_events(run)
            self.assertEqual(len(events), 2)
            self.assertEqual(events[-1]["detail"], "two")

    def test_compact_event_reader_bounds_high_volume_status_history(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            progress = run / "progress.tsv"
            rows = [
                "100\tgap\tquotient_db_scan\t2-1001\tstart\t"
                "budget=1000,prior_blocks=0,worker=worker-1\n"
            ]
            for scanned in range(1, 1001):
                rows.append(
                    f"{100 + scanned}\tgap\tquotient_db_scan\t2-1001\t"
                    f"progress\tscanned={scanned},generating={scanned},"
                    f"hits={scanned - 1},ledger={scanned}\n"
                )
                rows.append(
                    f"{100 + scanned}\tgap\tquotient_db_scan\t2-1001\t"
                    f"certificate\tid={scanned},status=linked\n"
                )
            progress.write_text("".join(rows))
            events = read_events(run, compact=True)
            self.assertLess(len(events), 40)
            self.assertEqual(events[0]["state"], "start")
            status = collect_run_status(run, compact_events=True)
            self.assertEqual(status["quotient_progress"]["scanned_blocks"], 1000)
            with progress.open("a") as stream:
                stream.write(
                    "1200\tgap\tquotient_db_scan\t2-1001\tprogress\t"
                    "scanned=1001,generating=1001,hits=1000,ledger=1001\n"
                )
            status = collect_run_status(run, compact_events=True)
            self.assertEqual(status["quotient_progress"]["scanned_blocks"], 1001)

    def test_completed_quotient_scan_is_complete_without_result_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "progress.tsv").write_text(
                "123\tgap\tquotient_scan\t1-10\tdone\tscanned=10\n"
            )
            status = collect_run_status(run)
            self.assertEqual(status["overall_state"], "complete")
            self.assertFalse(status["artifacts"]["merge_complete"])

    def test_budgeted_quotient_scan_is_paused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "progress.tsv").write_text(
                "123\tgap\tquotient_scan\t2-99\tpaused\tscanned=10\n"
                "124\tgap\tverify_quotient_scan\tall\tdone\tblocks=10\n"
            )
            self.assertEqual(collect_run_status(run)["overall_state"], "paused")

    def test_terminal_scan_event_overrides_reused_pid(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "progress.tsv").write_text(
                "123\tgap\tquotient_db_scan\t2-99\tpaused\tscanned=10\n"
            )
            (run / "runner.pid").write_text(str(os.getpid()))
            status = collect_run_status(run)
            self.assertEqual(status["overall_state"], "paused")
            self.assertEqual(status["process"]["state"], "stopped")
            self.assertIn("ignoring stale pid", status["process"]["label"])

    def test_active_verification_after_pause_is_running(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "progress.tsv").write_text(
                "123\tgap\tquotient_db_scan\t2-99\tpaused\tscanned=10\n"
                "124\tgap\tverify_quotient_db\tall\tstart\tcertificates=3\n"
            )
            (run / "runner.pid").write_text(str(os.getpid()))
            status = collect_run_status(run)
            self.assertEqual(status["overall_state"], "running")
            self.assertEqual(status["process"]["state"], "running")

    def test_fresh_unmanaged_verification_after_scan_is_running(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            now = int(time.time())
            (run / "progress.tsv").write_text(
                f"{now - 2}\tgap\tquotient_db_scan\t2-99\tdone\tscanned=10\n"
                f"{now}\tgap\tverify_quotient_certificate_segment\t1-of-4\t"
                "progress\tplan=abc,certificate=2\n"
            )
            status = collect_run_status(run)
            self.assertEqual(status["overall_state"], "running")
            self.assertEqual(status["process"]["state"], "active")

    def test_fresh_unmanaged_scan_events_are_running(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            now = int(time.time())
            (run / "progress.tsv").write_text(
                f"{now - 2}\tgap\tquotient_db_scan\t2-99\tstart\tworker=worker-1\n"
                f"{now}\tgap\tquotient_db_scan\t2-99\tprogress\tscanned=10\n"
            )
            status = collect_run_status(run)
            self.assertEqual(status["overall_state"], "running")
            self.assertEqual(status["process"]["state"], "active")
            self.assertEqual(status["process"]["label"],
                             "active events (unmanaged)")

    def test_quotient_progress_separates_verified_and_speculative_work(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            now = int(time.time())
            (run / "shards.json").write_text(json.dumps({
                "base_counts": {"blocks": 100},
                "target_blocks": 150,
            }))
            (run / "progress.tsv").write_text(
                f"{now - 20}\tgap\tquotient_db_scan\t2-1001\tstart\t"
                "budget=200,prior_blocks=150,worker=worker-1\n"
                f"{now - 10}\tgap\tquotient_db_scan\t2-1001\tprogress\t"
                "scanned=175,pending=80,generating=50,certificates=20,"
                "hits=15,ledger=900\n"
                f"{now - 9}\tgap\tverify_quotient_certificate_segment\t"
                "1-of-4\tdone\tplan=abc\n"
                f"{now - 8}\tgap\tverify_quotient_certificate_segment\t"
                "2-of-4\tstart\tplan=abc\n"
                f"{now - 7}\tgap\tverify_quotient_block_segment\t"
                "1-of-2\tdone\tplan=abc\n"
            )
            progress = collect_run_status(run)["quotient_progress"]
            self.assertIsNotNone(progress)
            assert progress is not None
            self.assertEqual(progress["total_blocks"], 1000)
            self.assertEqual(progress["verified_blocks"], 100)
            self.assertEqual(progress["checkpoint_blocks"], 100)
            self.assertEqual(progress["scanned_blocks"], 175)
            self.assertEqual(progress["wave_target_blocks"], 200)
            self.assertEqual(progress["reuse_percent"], 30.0)
            self.assertEqual(progress["replay"]["certificate_done"], 1)
            self.assertEqual(progress["replay"]["certificate_total"], 4)
            self.assertEqual(progress["replay"]["block_done"], 1)
            self.assertEqual(progress["replay"]["block_total"], 2)


if __name__ == "__main__":
    unittest.main()
