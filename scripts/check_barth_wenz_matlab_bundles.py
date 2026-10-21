#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import prepare_barth_wenz_matlab as prepare  # noqa: E402


DEFAULT_SUMMARY = (
    ROOT / "data/derived/m23_8a_barth_wenz_matlab_bundles.tsv"
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def verify(summary: Path, bundle_root: Path | None = None) -> None:
    with summary.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if [int(row["domain_index"]) for row in rows] != [1, 2]:
        raise RuntimeError("expected exactly domain indices 1 and 2")
    expected = {
        "format": "m23-barth-wenz-matlab-bundle-v1",
        "target_class": "1",
        "matlab_input_sha256": prepare.sha256(prepare.MATLAB_INPUT),
        "barth_wenz_code_sha256": prepare.CODE_SHA256,
        "sc_toolbox_version": prepare.SC_VERSION,
        "sc_toolbox_commit": prepare.SC_COMMIT,
        "sc_toolbox_archive_sha256": prepare.SC_SHA256,
    }
    for row in rows:
        for key, value in expected.items():
            if row[key] != value:
                raise RuntimeError(
                    f"domain {row['domain_index']} has unexpected {key}"
                )
        if not SHA256.fullmatch(row["bundle_sha256"]):
            raise RuntimeError("invalid bundle SHA-256")
        if not re.fullmatch(r"[0-9a-f]{40}", row["project_revision"]):
            raise RuntimeError("invalid project revision")
        expected_status = (
            "external_run_completed"
            if row["domain_index"] == "1"
            else "external_run_pending"
        )
        if row["status"] != expected_status:
            raise RuntimeError(
                f"domain {row['domain_index']} has unexpected status"
            )
        if bundle_root is not None:
            bundle = bundle_root / row["bundle_basename"]
            if prepare.sha256(bundle) != row["bundle_sha256"]:
                raise RuntimeError(f"bundle hash mismatch: {bundle}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("summary", type=Path, nargs="?", default=DEFAULT_SUMMARY)
    parser.add_argument("--bundle-root", type=Path)
    args = parser.parse_args()
    verify(args.summary, args.bundle_root)
    print("verified completed domain-1 and pending domain-2 MATLAB bundles")


if __name__ == "__main__":
    main()
