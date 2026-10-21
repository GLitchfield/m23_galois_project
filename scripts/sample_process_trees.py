#!/usr/bin/env python3
"""Record bounded system and descendant-process resource samples."""
from __future__ import annotations

import argparse
import os
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ProcessRecord:
    parent: int
    rss_kib: int


def read_processes(proc: Path = Path("/proc")) -> dict[int, ProcessRecord]:
    page_kib = os.sysconf("SC_PAGE_SIZE") // 1024
    result: dict[int, ProcessRecord] = {}
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            stat = (entry / "stat").read_text()
            remainder = stat[stat.rfind(")") + 2:].split()
            # Remainder begins at proc(5) field 3: state, ppid, ... rss.
            result[int(entry.name)] = ProcessRecord(
                parent=int(remainder[1]), rss_kib=int(remainder[21]) * page_kib
            )
        except (FileNotFoundError, IndexError, PermissionError, ValueError):
            continue
    return result


def tree_totals(processes: dict[int, ProcessRecord],
                roots: list[int]) -> list[tuple[int, int]]:
    members: list[set[int]] = [{root} if root in processes else set()
                               for root in roots]
    changed = True
    while changed:
        changed = False
        for pid, record in processes.items():
            for tree in members:
                if pid not in tree and record.parent in tree:
                    tree.add(pid)
                    changed = True
                    break
    return [(len(tree), sum(processes[pid].rss_kib for pid in tree))
            for tree in members]


def memory_fields(proc: Path = Path("/proc")) -> tuple[int, int]:
    fields: dict[str, int] = {}
    for line in (proc / "meminfo").read_text().splitlines():
        parts = line.replace(":", "").split()
        if len(parts) >= 2:
            fields[parts[0]] = int(parts[1])
    return fields.get("MemAvailable", 0), fields.get("SwapFree", 0)


def sample(output: Path, roots: list[int], labels: list[str],
           interval: float, proc: Path = Path("/proc")) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", buffering=1) as stream:
        columns = ["timestamp"]
        for label in labels:
            columns.extend((f"{label}_processes", f"{label}_rss_kib"))
        columns.extend(("mem_available_kib", "swap_free_kib"))
        stream.write("\t".join(columns) + "\n")
        while True:
            processes = read_processes(proc)
            totals = tree_totals(processes, roots)
            available, swap = memory_fields(proc)
            row: list[int] = [int(time.time())]
            for count, rss in totals:
                row.extend((count, rss))
            row.extend((available, swap))
            stream.write("\t".join(map(str, row)) + "\n")
            active = any(count for count, _ in totals)
            if not active:
                return
            time.sleep(interval)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="sample RSS for one or more process trees"
    )
    parser.add_argument("output", type=Path)
    parser.add_argument("roots", type=int, nargs="+")
    parser.add_argument("--labels", nargs="+")
    parser.add_argument("--interval", type=float, default=5.0)
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("interval must be positive")
    labels = args.labels or [f"tree{index}" for index in range(1, len(args.roots) + 1)]
    if len(labels) != len(args.roots):
        parser.error("label count must equal root count")
    sample(args.output, args.roots, labels, args.interval)


if __name__ == "__main__":
    main()
