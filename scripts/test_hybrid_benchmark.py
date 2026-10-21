#!/usr/bin/env python3
from __future__ import annotations

import tempfile
from pathlib import Path

from plan_hybrid_shards import plan
from summarize_hybrid_throughput import summarize


def main() -> None:
    shard_plan = plan(2, 101, 3, 2)
    assert shard_plan["shard_count"] == 5
    shards = shard_plan["shards"]
    assert sum(int(row["owned_ordinals"]) for row in shards) == 100
    owners = {}
    for row in shards:
        for ordinal in range(int(row["first_ordinal"]), 102, int(row["stride"])):
            assert ordinal not in owners
            owners[ordinal] = row["backend"]
    assert set(owners) == set(range(2, 102))
    assert set(owners.values()) == {"cpu", "gpu"}

    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        baseline = root / "baseline.tsv"
        hybrid = root / "hybrid.tsv"
        baseline.write_text(
            "backend\tworkers\tcompleted_units\telapsed_seconds\n"
            "cpu\t8\t800\t100\n"
        )
        hybrid.write_text(
            "backend\tworkers\tcompleted_units\telapsed_seconds\n"
            "cpu\t8\t760\t100\n"
            "gpu\t1\t200\t100\n"
        )
        result = summarize(baseline, hybrid)
        assert result["baseline_units_per_second"] == 8.0
        assert result["hybrid_units_per_second"] == 9.6
        assert result["hybrid_gain_percent"] == 20.0
        assert result["hybrid_cpu_slowdown_percent"] == 5.0
        assert result["gpu_units_per_second"] == 2.0
        assert result["additive_improvement"] is True
    print("deterministic hybrid shard and additive-throughput harness verified")


if __name__ == "__main__":
    main()
