#!/usr/bin/env python3
from __future__ import annotations

import tempfile
from pathlib import Path

from summarize_native_stratified_ledger import summarize


TRANSCRIPT = """# schema\tm23-native-ledger-stratified-v1
# source_checkpoint_sha256\tdeadbeef
# macroblock_count\t11
# identity_block_excluded\t1
S\t2\t2\t4\t1\t2
S\t3\t3\t6\t1\t7
B\t2\tordinal\t2\t1\t1\t0
T\t2\t2.0\t0.2\t0.3\t1.5\t1\t3
C\t1\toverflow\toverflow\t0\t2\t1\t1\t1\t1
V\t1\t1\t2\t1
B\t7\tordinal\t4\t3\t2\t1
T\t7\t3.0\t0.4\t0.6\t2.0\t2\t5
"""


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "stratified.tsv"
        path.write_text(TRANSCRIPT)
        result = summarize(path)
        assert result["sampled_blocks"] == 2
        assert result["represented_nonidentity_blocks"] == 10
        assert result["sampled_seconds"] == 5.0
        assert result["weighted_single_worker_seconds"] == 26.0
        assert result["weighted_kernel_seconds"] == 8.0
        assert result["weighted_refined_vertices"] == 32
        assert result["weighted_generating_vertices"] == 22
        assert result["sampled_owned_vertices"] == 8
        assert result["sampled_traversal_seconds"] == 3.5
        assert result["systematic_sample_sensitivity"] == [{
            "sample": 1,
            "weighted_generating_vertices": 22,
            "amortized_single_worker_days": 0.0,
        }]
        assert result["systematic_sample_day_range"] == [0.0, 0.0]
    print("native stratified ledger summary verified")


if __name__ == "__main__":
    main()
