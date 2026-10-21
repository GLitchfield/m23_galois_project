#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
import threading
import time
from collections import deque
from pathlib import Path
from typing import Any


UNMANAGED_ACTIVITY_GRACE_SECONDS = 600
_EVENT_CACHE_LOCK = threading.Lock()
_EVENT_CACHE: dict[tuple[Path, bool], dict[str, Any]] = {}


class _CompactEvents:
    """Retain status semantics without retaining every high-volume event."""

    def __init__(self, events: list[dict[str, Any]] | None = None) -> None:
        self.sequence = 0
        self.stable: list[tuple[int, dict[str, Any]]] = []
        self.latest: dict[tuple[str, str, str],
                          tuple[int, dict[str, Any]]] = {}
        self.recent: deque[tuple[int, dict[str, Any]]] = deque(maxlen=30)
        for event in events or []:
            self.add(event)

    def add(self, event: dict[str, Any]) -> None:
        self.sequence += 1
        numbered = (self.sequence, event)
        if (event["phase"], event["item"], event["state"]) == \
                ("run", "all", "start"):
            self.stable = [numbered]
            self.latest.clear()
            self.recent.clear()
        elif event["state"] in {"start", "done", "failed", "paused"}:
            self.stable.append(numbered)
        else:
            key = (event["phase"], event["item"], event["state"])
            previous = self.latest.get(key)
            if event["phase"] == "quotient_db_scan" and \
                    event["state"] == "progress":
                detail = parse_detail(event["detail"])
                previous_detail = (parse_detail(previous[1]["detail"])
                                   if previous else {})
                scanned = int(detail.get("scanned", "-1")) \
                    if detail.get("scanned", "").isdigit() else -1
                previous_scanned = int(previous_detail.get("scanned", "-1")) \
                    if previous_detail.get("scanned", "").isdigit() else -1
                if previous and scanned < previous_scanned:
                    numbered = previous
            self.latest[key] = numbered
        self.recent.append((self.sequence, event))

    def result(self) -> list[dict[str, Any]]:
        selected = {number: event for number, event in
                    [*self.stable, *self.latest.values(), *self.recent]}
        return [selected[number] for number in sorted(selected)]


def process_status(run_dir: Path) -> dict[str, Any]:
    pid_path = run_dir / "runner.pid"
    if not pid_path.exists():
        return {"state": "unmanaged", "label": "not managed", "pid": None}
    try:
        pid = int(pid_path.read_text().strip())
    except (OSError, ValueError):
        return {"state": "invalid", "label": "invalid pid file", "pid": None}
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return {"state": "stopped", "label": "stopped", "pid": pid}
    except PermissionError:
        return {
            "state": "unknown",
            "label": f"pid {pid} (permission unknown)",
            "pid": pid,
        }
    status_path = Path(f"/proc/{pid}/status")
    if status_path.exists():
        state_line = next(
            (line for line in status_path.read_text().splitlines()
             if line.startswith("State:")),
            "",
        )
        if "Z (zombie)" in state_line:
            return {
                "state": "stopped",
                "label": f"stopped (pid {pid} is a zombie)",
                "pid": pid,
            }
    return {"state": "running", "label": f"running (pid {pid})", "pid": pid}


def process_state(run_dir: Path) -> str:
    """Backward-compatible text interface used by the CLI."""
    return str(process_status(run_dir)["label"])


def read_events(run_dir: Path, compact: bool = False) -> list[dict[str, Any]]:
    progress_path = run_dir / "progress.tsv"
    if not progress_path.exists():
        return []
    try:
        stat = progress_path.stat()
    except OSError:
        return []

    progress_path = progress_path.resolve()
    cache_key = (progress_path, compact)
    with _EVENT_CACHE_LOCK:
        cached = _EVENT_CACHE.get(cache_key)
        if (cached and cached["inode"] == stat.st_ino
                and cached["size"] == stat.st_size):
            return list(cached["events"])
        incremental = bool(
            cached and cached["inode"] == stat.st_ino
            and stat.st_size >= cached["size"]
        )
        offset = int(cached["size"]) if incremental else 0
        prefix = bytes(cached["remainder"]) if incremental else b""
        events = list(cached["events"]) if incremental else []
        try:
            with progress_path.open("rb") as stream:
                stream.seek(offset)
                if compact:
                    accumulator = _CompactEvents(events)
                    remainder = prefix
                    while data := stream.read(1024 * 1024):
                        lines = (remainder + data).split(b"\n")
                        remainder = lines.pop()
                        for raw_line in lines:
                            event = _parse_event_line(
                                raw_line.decode(errors="replace"))
                            if event is not None:
                                accumulator.add(event)
                    events = accumulator.result()
                    lines = []
                else:
                    data = prefix + stream.read()
                    lines = data.split(b"\n")
                    remainder = lines.pop()
        except OSError:
            return []
        for raw_line in lines:
            event = _parse_event_line(raw_line.decode(errors="replace"))
            if event is not None:
                events.append(event)
        if not compact:
            starts = [index for index, event in enumerate(events)
                      if (event["phase"], event["item"], event["state"]) ==
                      ("run", "all", "start")]
            if starts:
                events = events[starts[-1]:]
        _EVENT_CACHE[cache_key] = {
            "inode": stat.st_ino,
            "size": stat.st_size,
            "remainder": remainder,
            "events": events,
        }
        return list(events)


def _parse_event_line(line: str) -> dict[str, Any] | None:
    fields = line.split("\t", 5)
    if len(fields) != 6:
        return None
    try:
        timestamp = int(fields[0])
    except ValueError:
        return None
    return {
        "timestamp": timestamp,
        "source": fields[1],
        "phase": fields[2],
        "item": fields[3],
        "state": fields[4],
        "detail": fields[5],
    }


def parse_detail(detail: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for item in detail.split(","):
        if "=" in item:
            key, value = item.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def native_progress(run_dir: Path) -> dict[str, int | float] | None:
    path = run_dir / "runner.log"
    if not path.exists():
        return None
    try:
        with path.open("rb") as stream:
            stream.seek(0, 2)
            size = stream.tell()
            stream.seek(max(0, size - 65536))
            lines = stream.read().decode(errors="replace").splitlines()
    except OSError:
        return None
    for line in reversed(lines):
        fields = line.split("\t")
        if len(fields) < 7 or fields[0] != "progress":
            continue
        try:
            return {
                "completed_blocks": int(fields[1]),
                "total_blocks": int(fields[2]),
                "latest_ordinal": int(fields[3]),
                "latest_block_seconds": float(fields[4]),
                "certificates": int(fields[5]),
                "owned_vertices": int(fields[6]),
            }
        except ValueError:
            continue
    return None


def quotient_progress(run_dir: Path, events: list[dict[str, Any]],
                      now: int) -> dict[str, Any] | None:
    scan_events = [event for event in events
                   if event["phase"] == "quotient_db_scan"]
    starts = [event for event in scan_events if event["state"] == "start"]
    counted = []
    for event in scan_events:
        detail = parse_detail(event["detail"])
        if detail.get("scanned", "").isdigit():
            counted.append((int(detail["scanned"]), event, detail))
    if not starts or not counted:
        return None

    scanned, scan_event, counters = max(
        counted, key=lambda row: (row[0], row[1]["timestamp"])
    )
    latest_start = starts[-1]
    start_detail = parse_detail(latest_start["detail"])
    matching_starts = [event for event in starts
                       if parse_detail(event["detail"]).get("budget") ==
                       start_detail.get("budget")
                       and parse_detail(event["detail"]).get("prior_blocks") ==
                       start_detail.get("prior_blocks")]
    invocation_started = min(event["timestamp"] for event in matching_starts)
    prior_blocks = int(start_detail.get("prior_blocks", "0") or 0)
    wave_target = int(start_detail.get("budget", str(scanned)) or scanned)
    match = re.fullmatch(r"(\d+)-(\d+)", latest_start["item"])
    total_blocks = (int(match.group(2)) - int(match.group(1)) + 1
                    if match else None)

    verified_blocks = 0
    checkpoint_blocks = prior_blocks
    shards_path = run_dir / "shards.json"
    if shards_path.exists():
        try:
            shards = json.loads(shards_path.read_text())
            verified_blocks = int(shards.get("base_counts", {}).get("blocks", 0))
            # A candidate's target is the end of the wave, not its starting
            # checkpoint.  Using target_blocks here made replay-only runs
            # display a 0/0 current-wave bar (for example 485k/485k) even
            # though they replayed a 435k -> 485k delta.
            checkpoint_blocks = verified_blocks or prior_blocks
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            pass

    elapsed = max(0, now - invocation_started)
    advanced = max(0, scanned - prior_blocks)
    rate = advanced / elapsed if elapsed and advanced else None
    eta_seconds = ((wave_target - scanned) / rate
                   if rate and wave_target > scanned else 0 if scanned >= wave_target else None)

    def integer(name: str) -> int | None:
        value = counters.get(name)
        return int(value) if value and value.isdigit() else None

    plans = [parse_detail(event["detail"]).get("plan") for event in events
             if event["phase"] in {
                 "verify_quotient_certificate_segment",
                 "verify_quotient_block_segment",
             } and parse_detail(event["detail"]).get("plan")]
    plan = plans[-1] if plans else None
    replay = {"certificate_done": 0, "certificate_total": 0,
              "block_done": 0, "block_total": 0}
    if plan:
        for phase, prefix in (
            ("verify_quotient_certificate_segment", "certificate"),
            ("verify_quotient_block_segment", "block"),
        ):
            relevant = [event for event in events if event["phase"] == phase
                        and parse_detail(event["detail"]).get("plan") == plan]
            totals = []
            done = set()
            for event in relevant:
                item_match = re.fullmatch(r"(\d+)-of-(\d+)", event["item"])
                if not item_match:
                    continue
                totals.append(int(item_match.group(2)))
                if event["state"] == "done":
                    done.add(int(item_match.group(1)))
            replay[f"{prefix}_done"] = len(done)
            replay[f"{prefix}_total"] = max(totals, default=0)

    generating = integer("generating")
    hits = integer("hits")
    return {
        "total_blocks": total_blocks,
        "verified_blocks": verified_blocks,
        "checkpoint_blocks": checkpoint_blocks,
        "scanned_blocks": scanned,
        "wave_start_blocks": checkpoint_blocks,
        "wave_target_blocks": wave_target,
        "rate_blocks_per_second": round(rate, 3) if rate else None,
        "eta_seconds": round(eta_seconds) if eta_seconds is not None else None,
        "ledger_vertices": integer("ledger"),
        "certificates": integer("certificates"),
        "pending_frontier": integer("pending"),
        "generating_vertices": generating,
        "ledger_hits": hits,
        "reuse_percent": (round(100 * hits / generating, 1)
                          if hits is not None and generating else None),
        "replay": replay,
        "latest_scan_at": scan_event["timestamp"],
    }


def collect_run_status(run_dir: Path, recent_event_count: int = 30,
                       compact_events: bool = False) -> dict[str, Any]:
    run_dir = run_dir.resolve()
    events = read_events(run_dir, compact=compact_events)
    checkpoints = sorted(run_dir.glob("shard-*-of-*.g"))
    config = parse_detail(events[0]["detail"]) if events else {}
    expected: int | None = None
    if checkpoints:
        try:
            expected = int(checkpoints[0].stem.rsplit("-", 1)[-1])
        except ValueError:
            pass
    if expected is None and config.get("shards", "").isdigit():
        expected = int(config["shards"])

    representative_done = len({event["item"] for event in events
                               if event["phase"] == "verify_representatives"
                               and event["state"] == "done"})
    deep_done = len({event["item"] for event in events
                    if event["phase"] == "verify_deep"
                    and event["state"] == "done"})
    certificate_complete = (run_dir / "certificate.tsv").exists()
    if certificate_complete and expected is not None:
        representative_done = deep_done = expected

    now = int(time.time())
    started_at = events[0]["timestamp"] if events else None
    last_event_at = events[-1]["timestamp"] if events else None
    failures = [event for event in events if event["state"] == "failed"]
    log_path = run_dir / "runner.log"
    latest = events[-1] if events else None
    state_event = next((event for event in reversed(events)
                        if not event["phase"].startswith("verify_quotient_")),
                       latest)
    verification_active = bool(
        latest
        and latest["phase"].startswith("verify_quotient_")
        and latest["state"] in {"start", "progress"}
    )
    process = process_status(run_dir)
    terminal_scan_event = bool(
        state_event
        and state_event["state"] in {"done", "paused"}
        and state_event["phase"] in {
            "run", "quotient_scan", "quotient_walk", "quotient_db_scan"
        }
    )
    if (terminal_scan_event and not verification_active
            and process["state"] == "running"):
        pid = process["pid"]
        process = {
            "state": "stopped",
            "label": (
                f"stopped ({state_event['state']} checkpoint; "
                f"ignoring stale pid {pid})"
            ),
            "pid": pid,
        }
    stale_seconds = now - last_event_at if last_event_at is not None else None
    activity_event = latest if verification_active else state_event
    fresh_unmanaged_activity = bool(
        process["state"] == "unmanaged"
        and activity_event
        and activity_event["state"] not in {"done", "failed", "paused"}
        and stale_seconds is not None
        and stale_seconds <= UNMANAGED_ACTIVITY_GRACE_SECONDS
    )
    if fresh_unmanaged_activity:
        process = {
            "state": "active",
            "label": "active events (unmanaged)",
            "pid": None,
        }
    result_complete = (run_dir / "result.tsv").exists() or (
        run_dir / "published-result.tsv").exists()
    complete = result_complete
    if state_event and state_event["state"] == "done" and state_event["phase"] in {
        "run", "quotient_scan", "quotient_walk", "quotient_db_scan"
    }:
        complete = True
    if failures:
        overall_state = "failed"
    elif verification_active and process["state"] in {"running", "active"}:
        overall_state = "running"
    elif complete:
        overall_state = "complete"
    elif state_event and state_event["state"] == "paused":
        overall_state = "paused"
    elif process["state"] in {"running", "active"}:
        overall_state = "running"
    elif events:
        overall_state = "stopped"
    else:
        overall_state = "idle"

    return {
        "path": str(run_dir),
        "name": run_dir.name,
        "overall_state": overall_state,
        "process": process,
        "config": config,
        "started_at": started_at,
        "last_event_at": last_event_at,
        "elapsed_seconds": now - started_at if started_at is not None else None,
        "stale_seconds": stale_seconds,
        "latest_event": latest,
        "recent_events": events[-recent_event_count:],
        "event_count": len(events),
        "failures": len(failures),
        "progress": {
            "checkpoints": len(checkpoints),
            "representative_verification": representative_done,
            "deep_recount": deep_done,
            "expected_shards": expected,
        },
        "artifacts": {
            "certificate_complete": certificate_complete,
            "merge_complete": result_complete,
            "log_exists": log_path.exists(),
            "log_bytes": log_path.stat().st_size if log_path.exists() else 0,
        },
        "quotient_progress": quotient_progress(run_dir, events, now),
        "native_progress": native_progress(run_dir),
    }


def main() -> None:
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[1] != "--json"):
        raise SystemExit("usage: m23_run_status.py [--json] RUN_DIR")
    json_output = len(sys.argv) == 3
    run_dir = Path(sys.argv[-1])
    status = collect_run_status(run_dir)
    if json_output:
        print(json.dumps(status, indent=2, sort_keys=True))
        return
    expected = status["progress"]["expected_shards"]
    expected_label = expected if expected is not None else "?"
    print(f"run directory: {run_dir}")
    print(f"process: {status['process']['label']}")
    print(f"checkpoints: {status['progress']['checkpoints']}/{expected_label}")
    print("representative verification: "
          f"{status['progress']['representative_verification']}/{expected_label}")
    print(f"deep shard recount: {status['progress']['deep_recount']}/{expected_label}")
    print("certificate: " +
          ("complete" if status["artifacts"]["certificate_complete"] else "pending"))
    print("merge result: " +
          ("complete" if status["artifacts"]["merge_complete"] else "pending"))
    if status["latest_event"]:
        event = status["latest_event"]
        print("latest event: " + " | ".join(str(event[key]) for key in
              ("source", "phase", "item", "state", "detail")))
    if status["failures"]:
        print(f"failures in current invocation: {status['failures']}")
    if status["artifacts"]["log_exists"]:
        print(f"log: {run_dir / 'runner.log'} "
              f"({status['artifacts']['log_bytes']} bytes)")


if __name__ == "__main__":
    main()
