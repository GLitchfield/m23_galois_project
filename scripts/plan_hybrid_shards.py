#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def plan(first: int, last: int, cpu_shards: int, gpu_shards: int) -> dict[str, object]:
    if first < 1 or last < first or cpu_shards < 1 or gpu_shards < 1:
        raise ValueError("invalid hybrid shard bounds")
    count = cpu_shards + gpu_shards
    shards = []
    for index in range(1, count + 1):
        backend = "cpu" if index <= cpu_shards else "gpu"
        owned = (last - (first + index - 1)) // count + 1 \
            if first + index - 1 <= last else 0
        shards.append({
            "index": index,
            "count": count,
            "backend": backend,
            "first_ordinal": first + index - 1,
            "stride": count,
            "owned_ordinals": owned,
        })
    return {
        "schema": "m23-hybrid-shard-plan-v1",
        "first_ordinal": first,
        "last_ordinal": last,
        "assignment": "1 + ((ordinal - first_ordinal) mod shard_count)",
        "cpu_shards": cpu_shards,
        "gpu_shards": gpu_shards,
        "shard_count": count,
        "shards": shards,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="create disjoint deterministic CPU/GPU ordinal shards"
    )
    parser.add_argument("first", type=int)
    parser.add_argument("last", type=int)
    parser.add_argument("cpu_shards", type=int)
    parser.add_argument("gpu_shards", type=int)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = plan(args.first, args.last, args.cpu_shards, args.gpu_shards)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
