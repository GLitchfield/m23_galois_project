#!/usr/bin/env python3

import json
import sqlite3
import tempfile
from pathlib import Path

from summarize_native_mixed_wave import percentile, summarize


def main() -> None:
    assert percentile([1.0, 2.0, 3.0], 0.0) == 1.0
    assert percentile([1.0, 2.0, 3.0], 0.5) == 2.0
    assert percentile([1.0, 2.0, 3.0], 1.0) == 3.0
    assert percentile([1.0, 3.0], 0.5) == 2.0
    with tempfile.TemporaryDirectory() as temporary:
        run = Path(temporary)
        (run / "scan-wave-1").mkdir()
        (run / "final-replay").mkdir()
        (run / "plan.tsv").write_text(
            "# schema\tm23-native-ledger-stratified-v1\n"
            "# source_checkpoint_sha256\tdeadbeef\n"
            "# macroblock_count\t3\n"
            "# block_count\t2\n"
            "S\t2\t2\t1\t1\t10\n"
            "S\t3\t3\t1\t1\t20\n"
        )
        (run / "scan-wave-1" / "worker-1.log").write_text(
            "progress\t1\t2\t10\t1.25\t0\t0\tadded=1,hits=0\n"
            "progress\t2\t2\t20\t2.75\t1\t3\tadded=2,hits=1\n"
        )
        (run / "final-replay" / "replay-1.log").write_text(
            "range\t1\t1\t3\t10\ncomplete\t1\t3\t10\t2.0\n"
        )
        (run / "resource-samples.tsv").write_text(
            "timestamp\tmixed_processes\tmixed_rss_kib\tmem_available_kib\t"
            "swap_free_kib\n1\t2\t100\t1000\t500\n"
        )
        (run / "result.json").write_text(json.dumps({
            "schema": "m23-native-mixed-wave-v1",
            "blocks": 2,
            "certificates": 3,
            "vertices": 10,
            "statuses": {"linked": 3},
            "metadata": {"native_work_plan_sha256": "plan"},
            "database_sha256": "database",
            "scan_seconds": 5,
            "final_replay_seconds": 2,
            "shards": [[1, 1], [2, 1]],
            "writer_mode": "queued",
        }))
        database = sqlite3.connect(run / "ledger.sqlite3")
        database.execute("CREATE TABLE fixture(value INTEGER)")
        database.close()
        result = summarize(run, 100)
        assert result["scan_workers"] == 2
        assert result["writer_mode"] == "queued"
        assert result["scan_block_cpu_seconds"] == 4.0
        assert result["linear_projected_replay_seconds"] == 20
        assert result["resources"]["peak_rss_kib"] == 100
    print("native mixed-wave summary helpers verified")


if __name__ == "__main__":
    main()
