#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import tempfile
from pathlib import Path

from checkpoint_sqlite_ledger import checkpoint
from finalize_independent_native_gap_audit import finalize, read_plan
from m23_quotient_ledger import Ledger
from plan_independent_native_gap_audit import balanced_round_robin, plan


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        pair = root / "pairs.g"
        pair.write_text("fixture\n")
        pair_sha = hashlib.sha256(pair.read_bytes()).hexdigest()
        ledger_path = root / "ledger.sqlite3"
        ledger = Ledger(ledger_path)
        ledger.initialize({
            "target_order": 5,
            "pair_schema": 2,
            "macroblock_count": 10,
            "first_ordinal": 1,
            "last_ordinal": 10,
            "proof_limit": 5,
            "walk_limit": 5,
            "schedule": "frontier",
            "start_ordinal": 2,
            "traversal_order": "native-v1",
        })
        with ledger.db:
            ledger._set_meta("native_source_checkpoint_sha256", pair_sha)
            ledger._set_meta(
                "native_work_plan_schema", "m23-native-full-cursor-plan-v1"
            )
            ledger._set_meta("native_work_plan_sha256", "work-plan")
        for certificate, status in enumerate(
                ("closed", "overflow", "linked", "linked"), 1):
            ledger.add_certificate({
                "status": status,
                "walk_status": status,
                "linked_certificate": 1 if status == "linked" else None,
                "seed_ordinal": certificate,
                "seed_twist": 1,
                "checked_vertices": 1,
                "discovered_vertices": 1,
                "discovered_classes": 1,
            }, [(certificate, 1)])
        with ledger.db:
            ledger.db.executemany(
                "INSERT INTO blocks(ordinal,source,refined_vertices,"
                "generating_vertices,new_certificates,ledger_hits) "
                "VALUES(?,?,?,?,?,?)",
                ((5, "ordinal", 0, 0, 0, 0),
                 (6, "ordinal", 0, 0, 0, 0)),
            )
        ledger.close()
        checkpoint(ledger_path)
        plan_tsv = root / "plan.tsv"
        plan_json = root / "plan.json"
        planned_result = plan(
            ledger_path, pair, plan_tsv, plan_json, 2, 2,
            require_full_cursor=True,
            jobs=2,
        )
        assert planned_result["selected_certificates"] == "4"
        assert planned_result["selected_blocks"] == "2"
        assert planned_result["audit_jobs"] == "2"
        assert planned_result["certificate_segment_estimated_costs"] == [194, 194]
        metadata, rows, blocks = read_plan(plan_tsv)
        assert [row[1] for row in rows] == [1, 2, 3, 4]
        assert [row[1] for row in blocks] == [5, 6]
        results = []
        for segment in (1, 2):
            selected = rows[segment - 1::2]
            selected_blocks = blocks[segment - 1::2]
            path = root / f"segment-{segment}.tsv"
            lines = [
                f"M\t{metadata['plan_sha256']}\t{segment}\t2\t"
                f"{len(selected)}\t{len(selected_blocks)}"
            ]
            for index, certificate, status, _ in selected:
                linked = 1 if status == "linked" else 0
                lines.append(
                    f"V\t{index}\t{certificate}\t{status}\t1\t1\t{linked}"
                )
            for index, ordinal, _ in selected_blocks:
                lines.append(f"B\t{index}\t{ordinal}\t0\t0\t0\t0")
            statuses = [row[2] for row in selected]
            lines.append(
                f"R\t{metadata['plan_sha256']}\t{segment}\t2\t"
                f"{len(selected)}\t{statuses.count('closed')}\t"
                f"{statuses.count('overflow')}\t{statuses.count('linked')}\t"
                f"{len(selected)}\t{len(selected_blocks)}\t0\t0"
            )
            path.write_text("\n".join(lines) + "\n")
            results.append(path)
        final = finalize(ledger_path, plan_tsv, results)
        assert final["verified_certificates"] == 4
        assert final["verified_closed"] == 1
        assert final["verified_overflow"] == 1
        assert final["verified_linked"] == 2
        assert final["verified_blocks"] == 2
        assert final["all_planned_certificates_verified"] is True
        assert final["all_planned_blocks_verified"] is True
        assert json.loads(plan_json.read_text())["plan_sha256"] == \
            metadata["plan_sha256"]
        ordered, costs = balanced_round_robin(
            [(1, 7000), (2, 100), (3, 100), (4, 100),
             (5, 7000), (6, 100), (7, 100), (8, 100)],
            4,
        )
        segments = [ordered[index::4] for index in range(4)]
        assert all(len(segment) == 2 for segment in segments)
        assert not any({1, 5} <= set(segment) for segment in segments)
        assert sorted(costs) == [200, 200, 7100, 7100]
    print("independent native GAP audit planning and composition verified")


if __name__ == "__main__":
    main()
