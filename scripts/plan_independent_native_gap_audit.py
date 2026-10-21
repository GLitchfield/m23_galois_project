#!/usr/bin/env python3
"""Plan an independent GAP audit of a completed native certificate ledger."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import subprocess
from pathlib import Path


SCHEMA = "m23-independent-native-gap-audit-plan-v1"
CERTIFICATE_OVERHEAD = 96


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def systematic_linked(database: sqlite3.Connection, count: int,
                      linked_count: int) -> list[int]:
    wanted = min(count, linked_count)
    if wanted == 0:
        return []
    ranks = {
        ((2 * sample + 1) * linked_count) // (2 * wanted)
        for sample in range(wanted)
    }
    selected = []
    for rank, (certificate,) in enumerate(database.execute(
            "SELECT id FROM certificates WHERE status='linked' ORDER BY id"
    )):
        if rank in ranks:
            selected.append(int(certificate))
    if len(selected) != wanted:
        raise ValueError("could not select the requested linked audit sample")
    return selected


def balanced_round_robin(
    rows: list[tuple[int, int]], jobs: int
) -> tuple[list[int], list[int]]:
    """Order IDs so index modulo jobs gives deterministic cost-balanced bins."""
    if jobs <= 0:
        raise ValueError("independent GAP audit job count must be positive")
    if any(weight <= 0 for _, weight in rows):
        raise ValueError("independent GAP audit weights must be positive")
    if len({identifier for identifier, _ in rows}) != len(rows):
        raise ValueError("independent GAP audit IDs must be unique")
    base, remainder = divmod(len(rows), jobs)
    capacities = [base + int(segment < remainder) for segment in range(jobs)]
    bins: list[list[int]] = [[] for _ in range(jobs)]
    costs = [0] * jobs
    for identifier, weight in sorted(rows, key=lambda row: (-row[1], row[0])):
        available = [
            segment for segment in range(jobs)
            if len(bins[segment]) < capacities[segment]
        ]
        segment = min(
            available,
            key=lambda candidate: (
                costs[candidate], len(bins[candidate]), candidate
            ),
        )
        bins[segment].append(identifier)
        costs[segment] += weight
    for values in bins:
        values.sort()
    ordered = [
        bins[segment][position]
        for position in range(max(capacities, default=0))
        for segment in range(jobs)
        if position < len(bins[segment])
    ]
    if any(
        ordered[index] not in bins[index % jobs]
        for index in range(len(ordered))
    ):
        raise AssertionError("balanced audit order changed segment ownership")
    return ordered, costs


def plan(ledger: Path, pair_checkpoint: Path, output_tsv: Path,
         output_json: Path, linked_samples: int, block_samples: int,
         exception_limit_per_status: int | None = None,
         require_full_cursor: bool = False, jobs: int = 1) -> dict[str, object]:
    if linked_samples < 0 or block_samples < 0 or \
            exception_limit_per_status is not None and \
            exception_limit_per_status <= 0 or jobs <= 0:
        raise ValueError("invalid independent GAP audit sample bounds")
    wal = Path(str(ledger) + "-wal")
    if wal.exists() and wal.stat().st_size:
        raise ValueError("independent GAP audit requires a checkpointed ledger")
    database = sqlite3.connect(f"file:{ledger.resolve()}?mode=ro", uri=True)
    try:
        metadata = dict(database.execute("SELECT key,value FROM meta"))
        required = {
            "config_target_order", "config_pair_schema",
            "config_macroblock_count", "config_proof_limit",
            "config_walk_limit", "config_schedule", "config_start_ordinal",
            "config_traversal_order", "native_source_checkpoint_sha256",
        }
        if not required <= set(metadata) or \
                metadata["config_target_order"] != "5" or \
                metadata["config_traversal_order"] != "native-v1":
            raise ValueError("ledger is not a native-v1 order-5 search")
        if require_full_cursor and metadata.get("native_work_plan_schema") != \
                "m23-native-full-cursor-plan-v1":
            raise ValueError("production audit requires a full-cursor ledger")
        counts = database.execute(
            "SELECT (SELECT COUNT(*) FROM blocks),"
            "(SELECT COUNT(*) FROM certificates),"
            "(SELECT COUNT(*) FROM vertices),"
            "(SELECT COUNT(*) FROM leases),"
            "(SELECT COUNT(*) FROM certificates WHERE status='closed'),"
            "(SELECT COUNT(*) FROM certificates WHERE status='overflow'),"
            "(SELECT COUNT(*) FROM certificates WHERE status='linked')"
        ).fetchone()
        if counts[3] != 0 or counts[4] + counts[5] + counts[6] != counts[1]:
            raise ValueError("native ledger is live or has invalid statuses")
        selected: dict[int, tuple[str, str]] = {}
        for status in ("closed", "overflow"):
            query = (
                "SELECT id FROM certificates WHERE status=? ORDER BY id" +
                (" LIMIT ?" if exception_limit_per_status is not None else "")
            )
            parameters: tuple[object, ...] = (status,)
            if exception_limit_per_status is not None:
                parameters += (exception_limit_per_status,)
            for (certificate,) in database.execute(query, parameters):
                selected[int(certificate)] = (status, "exceptional")
        for certificate in systematic_linked(
                database, linked_samples, int(counts[6])):
            selected[certificate] = ("linked", "systematic")
        selected_costs = [
            (int(certificate), int(discovered_vertices) + CERTIFICATE_OVERHEAD)
            for certificate, discovered_vertices in database.execute(
                "SELECT id,discovered_vertices FROM certificates ORDER BY id"
            ) if int(certificate) in selected
        ]
        ordered_certificates, segment_costs = balanced_round_robin(
            selected_costs, jobs
        )
        block_count, first_sequence, last_sequence = database.execute(
            "SELECT COUNT(*),COALESCE(MIN(sequence),0),"
            "COALESCE(MAX(sequence),0) FROM blocks"
        ).fetchone()
        if block_count and (first_sequence != 1 or last_sequence != block_count):
            raise ValueError("native block sequence is not contiguous")
        wanted_blocks = min(block_samples, int(block_count))
        block_sequences = sorted({
            1 + ((2 * sample + 1) * block_count) // (2 * wanted_blocks)
            for sample in range(wanted_blocks)
        }) if wanted_blocks else []
        block_rows = []
        for index, sequence in enumerate(block_sequences, 1):
            row = database.execute(
                "SELECT ordinal FROM blocks WHERE sequence=?", (sequence,)
            ).fetchone()
            if row is None:
                raise ValueError("systematic block audit row is absent")
            block_rows.append((index, int(row[0]), "systematic"))
        quick = database.execute("PRAGMA quick_check").fetchone()[0]
        foreign = database.execute("PRAGMA foreign_key_check").fetchall()
        if quick != "ok" or foreign:
            raise ValueError("native ledger failed integrity checks")
    finally:
        database.close()
    pair_sha = file_sha256(pair_checkpoint)
    if pair_sha != metadata["native_source_checkpoint_sha256"]:
        raise ValueError("pair checkpoint and native ledger sources differ")
    certificate_rows = [
        (index, certificate, *selected[certificate])
        for index, certificate in enumerate(ordered_certificates, 1)
    ]
    base_metadata = {
        "schema": SCHEMA,
        "database_sha256": file_sha256(ledger),
        "pair_checkpoint_sha256": pair_sha,
        "native_work_plan_schema": metadata.get(
            "native_work_plan_schema", "legacy-pilot"
        ),
        "native_work_plan_sha256": metadata.get(
            "native_work_plan_sha256", "legacy-pilot"
        ),
        "target_order": metadata["config_target_order"],
        "pair_schema": metadata["config_pair_schema"],
        "macroblock_count": metadata["config_macroblock_count"],
        "proof_limit": metadata["config_proof_limit"],
        "walk_limit": metadata["config_walk_limit"],
        "schedule": metadata["config_schedule"],
        "start_ordinal": metadata["config_start_ordinal"],
        "traversal_order": metadata["config_traversal_order"],
        "blocks": str(counts[0]),
        "certificates": str(counts[1]),
        "vertices": str(counts[2]),
        "closed": str(counts[4]),
        "overflow": str(counts[5]),
        "linked": str(counts[6]),
        "linked_samples_requested": str(linked_samples),
        "audit_jobs": str(jobs),
        "certificate_cost_model":
            f"discovered_vertices+{CERTIFICATE_OVERHEAD}",
        "certificate_segment_estimated_costs": ",".join(map(str, segment_costs)),
        "exception_limit_per_status": (
            "all" if exception_limit_per_status is None
            else str(exception_limit_per_status)
        ),
        "selected_certificates": str(len(certificate_rows)),
        "block_samples_requested": str(block_samples),
        "selected_blocks": str(len(block_rows)),
    }
    canonical = json.dumps(
        {"metadata": base_metadata, "certificate_rows": certificate_rows,
         "block_rows": block_rows},
        sort_keys=True, separators=(",", ":"),
    )
    plan_sha = hashlib.sha256(canonical.encode()).hexdigest()
    output_tsv.parent.mkdir(parents=True, exist_ok=True)
    with output_tsv.open("x") as stream:
        for key, value in base_metadata.items():
            stream.write(f"# {key}\t{value}\n")
        stream.write(f"# plan_sha256\t{plan_sha}\n")
        for index, certificate, status, selection in certificate_rows:
            stream.write(
                f"C\t{index}\t{certificate}\t{status}\t{selection}\n"
            )
        for index, ordinal, selection in block_rows:
            stream.write(f"B\t{index}\t{ordinal}\t{selection}\n")
    try:
        revision = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True
        ).strip()
        dirty = bool(subprocess.check_output(
            ["git", "status", "--short"], text=True
        ).strip())
    except (OSError, subprocess.CalledProcessError):
        revision, dirty = "unknown", True
    result: dict[str, object] = {
        **base_metadata,
        "plan_sha256": plan_sha,
        "selected": [
            {"index": index, "certificate": certificate,
             "status": status, "selection": selection}
            for index, certificate, status, selection in certificate_rows
        ],
        "selected_block_rows": [
            {"index": index, "ordinal": ordinal, "selection": selection}
            for index, ordinal, selection in block_rows
        ],
        "certificate_segment_estimated_costs": segment_costs,
        "planner_git_revision": revision,
        "planner_git_dirty": dirty,
        "quick_check": "ok",
        "foreign_key_violations": 0,
    }
    output_json.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="plan independent GAP checks of native certificates"
    )
    parser.add_argument("ledger", type=Path)
    parser.add_argument("pair_checkpoint", type=Path)
    parser.add_argument("output_tsv", type=Path)
    parser.add_argument("output_json", type=Path)
    parser.add_argument("--linked-samples", type=int, default=256)
    parser.add_argument("--block-samples", type=int, default=64)
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--exception-limit-per-status", type=int)
    parser.add_argument("--require-full-cursor", action="store_true")
    args = parser.parse_args()
    print(json.dumps(plan(
        args.ledger, args.pair_checkpoint, args.output_tsv, args.output_json,
        args.linked_samples, args.block_samples,
        args.exception_limit_per_status,
        args.require_full_cursor,
        args.jobs,
    ), sort_keys=True))


if __name__ == "__main__":
    main()
