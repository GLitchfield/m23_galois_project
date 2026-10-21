#!/usr/bin/env python3
"""Compose sparse independent GAP certificate-audit segments."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

from plan_independent_native_gap_audit import file_sha256


def read_plan(path: Path) -> tuple[
        dict[str, str], list[tuple[int, int, str, str]],
        list[tuple[int, int, str]]]:
    metadata: dict[str, str] = {}
    certificate_rows = []
    block_rows = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        fields = line.split("\t")
        if fields[0].startswith("# ") and len(fields) == 2:
            metadata[fields[0][2:]] = fields[1]
        elif fields[0] == "C" and len(fields) == 5:
            certificate_rows.append(
                (int(fields[1]), int(fields[2]), fields[3], fields[4])
            )
        elif fields[0] == "B" and len(fields) == 4:
            block_rows.append((int(fields[1]), int(fields[2]), fields[3]))
        else:
            raise ValueError(f"invalid audit plan row at line {number}")
    if [row[0] for row in certificate_rows] != \
            list(range(1, len(certificate_rows) + 1)) or \
            len(certificate_rows) != int(metadata["selected_certificates"]) or \
            [row[0] for row in block_rows] != \
            list(range(1, len(block_rows) + 1)) or \
            len(block_rows) != int(metadata["selected_blocks"]):
        raise ValueError("independent GAP audit plan is incomplete")
    canonical_metadata = {
        key: value for key, value in metadata.items() if key != "plan_sha256"
    }
    canonical = json.dumps(
        {"metadata": canonical_metadata,
         "certificate_rows": certificate_rows, "block_rows": block_rows},
        sort_keys=True, separators=(",", ":"),
    )
    import hashlib
    if hashlib.sha256(canonical.encode()).hexdigest() != metadata["plan_sha256"]:
        raise ValueError("independent GAP audit plan hash differs")
    return metadata, certificate_rows, block_rows


def finalize(ledger: Path, plan_path: Path, result_paths: list[Path]) \
        -> dict[str, object]:
    metadata, planned, planned_blocks = read_plan(plan_path)
    plan_id = metadata["plan_sha256"]
    jobs = len(result_paths)
    verified: dict[int, tuple[int, str, int, int, int]] = {}
    verified_blocks: dict[int, tuple[int, int, int, int, int]] = {}
    segment_summaries = []
    for segment, path in enumerate(result_paths, 1):
        lines = [line.split("\t") for line in path.read_text().splitlines()]
        segment_plan = planned[segment - 1::jobs]
        segment_block_plan = planned_blocks[segment - 1::jobs]
        if not lines or lines[0] != [
                "M", plan_id, str(segment), str(jobs), str(len(segment_plan)),
                str(len(segment_block_plan))]:
            raise ValueError(f"invalid independent GAP segment header: {path}")
        if len(lines[-1]) != 12 or lines[-1][:4] != [
                "R", plan_id, str(segment), str(jobs)]:
            raise ValueError(f"invalid independent GAP segment footer: {path}")
        for fields in lines[1:-1]:
            if len(fields) == 7 and fields[0] == "V":
                index, certificate = map(int, fields[1:3])
                if index in verified:
                    raise ValueError("duplicate independent GAP audit result")
                verified[index] = (
                    certificate, fields[3], int(fields[4]), int(fields[5]),
                    int(fields[6]),
                )
            elif len(fields) == 7 and fields[0] == "B":
                index, ordinal = map(int, fields[1:3])
                if index in verified_blocks:
                    raise ValueError("duplicate independent GAP block result")
                verified_blocks[index] = (
                    ordinal, int(fields[3]), int(fields[4]), int(fields[5]),
                    int(fields[6]),
                )
            else:
                raise ValueError(f"invalid independent GAP result row: {path}")
        footer = tuple(map(int, lines[-1][4:]))
        segment_rows = [verified[row[0]] for row in segment_plan]
        segment_block_rows = [
            verified_blocks[row[0]] for row in segment_block_plan
        ]
        statuses = [row[1] for row in segment_rows]
        expected_footer = (
            len(segment_rows), statuses.count("closed"),
            statuses.count("overflow"), statuses.count("linked"),
            sum(row[2] for row in segment_rows),
            len(segment_block_rows),
            sum(row[1] for row in segment_block_rows),
            sum(row[2] for row in segment_block_rows),
        )
        if footer != expected_footer:
            raise ValueError(f"independent GAP segment totals differ: {path}")
        segment_summaries.append({
            "segment": segment,
            "certificates": footer[0],
            "closed": footer[1],
            "overflow": footer[2],
            "linked": footer[3],
            "vertices": footer[4],
            "blocks": footer[5],
            "refined_vertices": footer[6],
            "generating_vertices": footer[7],
        })
    if set(verified) != {row[0] for row in planned}:
        raise ValueError("independent GAP audit segments do not cover the plan")
    for index, certificate, status, _ in planned:
        if verified[index][:2] != (certificate, status):
            raise ValueError("independent GAP result differs from planned row")
    if set(verified_blocks) != {row[0] for row in planned_blocks}:
        raise ValueError("independent GAP block segments do not cover the plan")
    for index, ordinal, _ in planned_blocks:
        if verified_blocks[index][0] != ordinal:
            raise ValueError("independent GAP block result differs from plan")
    if file_sha256(ledger) != metadata["database_sha256"]:
        raise ValueError("native ledger changed during independent GAP audit")
    database = sqlite3.connect(f"file:{ledger.resolve()}?mode=ro", uri=True)
    try:
        quick = database.execute("PRAGMA quick_check").fetchone()[0]
        foreign = database.execute("PRAGMA foreign_key_check").fetchall()
        leases = database.execute("SELECT COUNT(*) FROM leases").fetchone()[0]
    finally:
        database.close()
    if quick != "ok" or foreign or leases:
        raise ValueError("native ledger failed final independent audit integrity")
    statuses = [row[2] for row in planned]
    return {
        "schema": "m23-independent-native-gap-audit-result-v1",
        "plan_sha256": plan_id,
        "database_sha256": metadata["database_sha256"],
        "pair_checkpoint_sha256": metadata["pair_checkpoint_sha256"],
        "native_work_plan_sha256": metadata["native_work_plan_sha256"],
        "jobs": jobs,
        "verified_certificates": len(planned),
        "verified_closed": statuses.count("closed"),
        "verified_overflow": statuses.count("overflow"),
        "verified_linked": statuses.count("linked"),
        "verified_vertices": sum(row[2] for row in verified.values()),
        "verified_blocks": len(planned_blocks),
        "verified_refined_vertices": sum(
            row[1] for row in verified_blocks.values()
        ),
        "verified_generating_vertices": sum(
            row[2] for row in verified_blocks.values()
        ),
        "all_planned_certificates_verified": True,
        "all_planned_blocks_verified": True,
        "direct_gap_generation": True,
        "all_sampled_generating_vertices_owned": True,
        "gap_orbit_membership_native_id_translation": True,
        "strict_prefix_ownership": True,
        "quick_check": "ok",
        "foreign_key_violations": 0,
        "live_leases": 0,
        "segments": segment_summaries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="finalize independent GAP audit segments"
    )
    parser.add_argument("ledger", type=Path)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("results", type=Path, nargs="+")
    args = parser.parse_args()
    result = finalize(args.ledger, args.plan, args.results)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
