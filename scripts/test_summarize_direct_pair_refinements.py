#!/usr/bin/env python3

import tempfile
from pathlib import Path

from summarize_direct_pair_refinements import summarize


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        profile = Path(directory) / "profile.tsv"
        profile.write_text(
            "# schema\tm23-direct-pair-refinement-benchmark-v1\n"
            "# target_order\t5\n"
            "# macroblock_count\t4\n"
            "# locator_ms\t123\n"
            "segment\tclass_index\tproduct_order\tsegment_blocks\tsample\t"
            "ordinal\trefined_vertices\tgenerating_vertices\trefine_ms\t"
            "generation_ms\n"
            "1\t1\t1\t1\t1\t1\t2\t1\t10\t20\n"
            "2\t2\t2\t3\t1\t2\t3\t1\t20\t10\n"
            "2\t2\t2\t3\t2\t4\t5\t3\t40\t10\n",
            encoding="utf-8",
        )
        row = summarize(profile)

    assert row["target_order"] == 5
    assert row["macroblocks"] == 4
    assert row["samples"] == 3
    assert row["locator_ms"] == 123
    assert row["refine_ms_per_block"] == 25.0
    assert row["generation_ms_per_block"] == 12.5
    assert row["kernel_ms_per_block"] == 37.5
    assert row["refined_vertices_per_block"] == 3.5
    assert row["generating_vertices_per_block"] == 1.75
    assert row["estimated_generating_vertices"] == 7.0
    print("direct-pair refinement summary test passed")


if __name__ == "__main__":
    main()
