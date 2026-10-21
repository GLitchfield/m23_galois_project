#!/usr/bin/env python3
"""Validate the committed bounded exact-algebra benchmark summary."""

from __future__ import annotations

import csv
from pathlib import Path


EXPECTED = {
    ("provenance", "prime"): "13",
    ("provenance", "sage_version"): "10.9",
    ("provenance", "msolve_version"): "0.10.1",
    ("full", "variables"): "23",
    ("full", "equations"): "23",
    ("full", "terms"): "1843",
    ("full", "max_degree"): "15",
    ("full", "input_sha256"):
        "b939b652aa9769c021298df76ae283f874b1681a62543ccc02cfbe11a8089599",
    ("reduced", "variables"): "16",
    ("reduced", "equations"): "16",
    ("reduced", "terms"): "404461",
    ("reduced", "max_degree"): "16",
    ("reduced", "input_sha256"):
        "43e7850667152ef9186445ab4b85bf34700fda34436d82e15332000fecd19cb7",
    ("msolve", "exit_status"): "124",
    ("msolve", "completed"): "no",
    ("msolve", "last_completed_f4_degree"): "11",
    ("singular", "exit_status"): "124",
    ("singular", "completed"): "no",
}


def main() -> None:
    path = Path("data/derived/m23_8a_exact_algebra_benchmark.tsv")
    with path.open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    observed = {(row["category"], row["metric"]): row["value"] for row in rows}
    if len(observed) != len(rows):
        raise SystemExit("duplicate benchmark category/metric")
    for key, expected in EXPECTED.items():
        actual = observed.get(key)
        if actual != expected:
            raise SystemExit(f"{key}: expected {expected!r}, got {actual!r}")
    if int(observed[("reduced", "terms")]) <= 100 * int(
        observed[("full", "terms")]
    ):
        raise SystemExit("the recorded sparse/dense presentation gate was lost")
    print("verified bounded 8A Sage/msolve/Singular benchmark summary")


if __name__ == "__main__":
    main()
