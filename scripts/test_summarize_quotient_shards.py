#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from summarize_quotient_shards import summarize


class SummarizeQuotientShardsTests(unittest.TestCase):
    def test_scan_replay_and_tail_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "shards.json").write_text(json.dumps({
                "base_counts": {"blocks": 100},
                "target_blocks": 110,
                "shard_count": 4,
            }))
            (run / "progress.tsv").write_text(
                "10\tgap\tquotient_db_scan\t2-999\tstart\tprior_blocks=100\n"
                "18\tgap\tquotient_db_scan\t2-999\tdone\tscanned=109\n"
                "20\tgap\tquotient_db_scan\t2-999\tdone\tscanned=110\n"
                "21\tgap\tverify_quotient_db_delta\tall\tstart\tblocks=110\n"
                "26\tgap\tverify_quotient_db_delta\tall\tdone\tblocks=110\n"
                "30\tgap\tverify_quotient_certificate_segment\t1-of-1\tstart\t"
                "plan=abc,first=1,last=2\n"
                "34\tpython\tverify_quotient_db_delta_parallel\tall\tdone\t"
                "plan=abc,blocks=110\n"
            )
            result = summarize(run)
            self.assertEqual(result["scan_seconds"], 10)
            self.assertEqual(result["blocks_per_second"], 1.0)
            self.assertEqual(result["completion_tail_seconds"], 2)
            self.assertEqual(result["delta_replay_seconds"], 5)
            self.assertEqual(result["parallel_replay_seconds"], 4)
            self.assertFalse(result["audit_complete"])


if __name__ == "__main__":
    unittest.main()
