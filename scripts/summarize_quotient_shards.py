#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from m23_run_status import parse_detail, read_events


def summarize(run_dir: Path) -> dict[str, object]:
    manifest = json.loads((run_dir / "shards.json").read_text())
    events = read_events(run_dir)
    base_blocks = int(manifest["base_counts"]["blocks"])
    target = int(manifest["target_blocks"])
    starts = [event for event in events
              if event["phase"] == "quotient_db_scan"
              and event["state"] == "start"
              and parse_detail(event["detail"]).get("prior_blocks") == str(base_blocks)]
    if not starts:
        raise ValueError("run has no matching shard scan start")
    start = min(event["timestamp"] for event in starts)
    terminals: dict[int, int] = {}
    for event in events:
        if event["phase"] != "quotient_db_scan" or event["state"] not in {
            "done", "paused"
        }:
            continue
        detail = parse_detail(event["detail"])
        if detail.get("scanned", "").isdigit():
            scanned = int(detail["scanned"])
            terminals[scanned] = max(terminals.get(scanned, 0), event["timestamp"])
    if target not in terminals:
        raise ValueError("run has no terminal event at its block target")
    scan_seconds = terminals[target] - start
    replay_starts = [event["timestamp"] for event in events
                     if event["phase"] == "verify_quotient_db_delta"
                     and event["state"] == "start"]
    replay_dones = [event["timestamp"] for event in events
                    if event["phase"] == "verify_quotient_db_delta"
                    and event["state"] == "done"]
    parallel_dones = [event for event in events
                      if event["phase"] == "verify_quotient_db_delta_parallel"
                      and event["state"] == "done"]
    parallel_seconds = None
    if parallel_dones:
        parallel_done = parallel_dones[-1]
        parallel_plan = parse_detail(parallel_done["detail"]).get("plan")
        parallel_starts = [event["timestamp"] for event in events
                           if event["phase"] in {
                               "verify_quotient_certificate_segment",
                               "verify_quotient_block_segment",
                           } and event["state"] == "start"
                           and parse_detail(event["detail"]).get("plan") ==
                           parallel_plan]
        if parallel_starts:
            parallel_seconds = parallel_done["timestamp"] - min(parallel_starts)
    audit_path = run_dir / "audit.json"
    if not audit_path.exists():
        audit_path = run_dir / "audit-parallel.json"
    audit = json.loads(audit_path.read_text()) if audit_path.exists() else None
    new_blocks = target - base_blocks
    result: dict[str, object] = {
        "base_blocks": base_blocks,
        "target_blocks": target,
        "new_blocks": new_blocks,
        "shards": int(manifest["shard_count"]),
        "scan_seconds": scan_seconds,
        "blocks_per_second": round(new_blocks / scan_seconds, 3),
        "completion_tail_seconds": (
            terminals[target] - terminals[target - 1]
            if target - 1 in terminals else None
        ),
        "delta_replay_seconds": (
            max(replay_dones) - min(replay_starts)
            if replay_starts and replay_dones else None
        ),
        "parallel_replay_seconds": parallel_seconds,
        "audit_complete": audit is not None,
    }
    if audit:
        result["counts"] = audit["counts"]
        result["database_sha256"] = audit["database_sha256"]
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="summarize a quotient shard wave")
    parser.add_argument("run_dir", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.run_dir), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
