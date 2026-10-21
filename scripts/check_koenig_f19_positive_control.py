#!/usr/bin/env python3
"""Check the compact König F_19 solver positive-control certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-koenig-f19-positive-control-v1"
INPUT_SHA256 = (
    "e7d00cb330e140f57a987570cc396477a41b0d0317de8254858c96d1e5c5f3c9"
)
DEFAULT_PATH = Path(
    "data/derived/m23_koenig_f19_positive_control.tsv"
)


def parse(path: Path):
    metadata = {}
    rows = []
    header = None
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            fields = line.split("\t")
            if header is None:
                header = fields
            else:
                rows.append(dict(zip(header, fields, strict=True)))
    if header is None:
        raise ValueError("missing presentation table")
    return metadata, header, rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=DEFAULT_PATH)
    args = parser.parse_args()
    metadata, header, rows = parse(args.summary)

    assert metadata["schema"] == SCHEMA
    assert len(metadata["code_revision"]) == 40
    assert len(metadata["solver_code_revision"]) == 40
    assert metadata["sage_version"] == "10.9"
    assert metadata["status"] == (
        "known_f19_positive_control_not_recovered"
    )
    assert (
        metadata["prime"],
        metadata["alpha"],
        metadata["beta"],
        metadata["branch_label"],
    ) == ("19", "7", "14", "9")
    assert metadata["selected_presentation"] == "scaled-simple-first"
    assert metadata["selected_input_sha256"] == INPUT_SHA256
    assert metadata["positive_control_recovered"] == "0"

    assert metadata["benchmark_wall_limit_seconds"] == "7200"
    assert metadata["benchmark_threads"] == "4"
    assert metadata["benchmark_vmem_limit_kib"] == "8388608"
    assert metadata["benchmark_max_pairs_per_matrix"] == "2048"
    assert metadata["benchmark_msolve_version"] == "0.10.1"
    assert metadata["benchmark_input_sha256"] == INPUT_SHA256
    assert metadata["benchmark_exit_status"] == "139"
    assert metadata["benchmark_outcome"] == "failed"
    assert metadata["benchmark_output_bytes"] == "0"
    assert int(metadata["benchmark_maximum_rss_kib"]) == 7_372_096
    assert int(metadata["benchmark_highest_f4_degree"]) == 7
    assert int(metadata["benchmark_maximum_f4_rows"]) == 1_424_587
    assert int(metadata["benchmark_maximum_f4_columns"]) == 5_473_575
    assert int(metadata["benchmark_maximum_pair_frontier"]) == 141_284

    assert header == [
        "presentation",
        "variables",
        "equations",
        "terms",
        "max_degree",
        "bytes",
        "sha256",
        "known_zero_equations",
    ]
    expected = [
        (
            "scaled-standard",
            "44",
            "46",
            "2042",
            "6",
            "42562",
            "68b14c8a80f0fd3e9fe4a8294faaf9dc9b8d64c84724472ea4b62acd7b708df5",
            "46",
        ),
        (
            "scaled-simple-first",
            "44",
            "46",
            "2042",
            "6",
            "42562",
            INPUT_SHA256,
            "46",
        ),
        (
            "scaled-simple-last",
            "44",
            "46",
            "2042",
            "6",
            "42566",
            "80e61ca632e188ef25ebb06707224290cc93094294b8c66c8cb12f7851aa4617",
            "46",
        ),
        (
            "square-remainder",
            "30",
            "32",
            "24232",
            "10",
            "742186",
            "4ba62b63b1665dd7f12407c77a64c2111380f32b77f681f37bbfbab0a89f89b6",
            "32",
        ),
        (
            "gcd-remainder",
            "30",
            "32",
            "247384",
            "17",
            "8605974",
            "cf479777c8e928119cdf4e6838d415d6b9e773e1672fd5ea64b1245a2e83ddef",
            "32",
        ),
    ]
    assert [
        tuple(row[column] for column in header) for row in rows
    ] == expected
    for row in rows:
        assert row["known_zero_equations"] == row["equations"]

    print(
        "verified F_19 positive-control gate: all exact presentations "
        "contain the known cover, but the selected msolve run returned no "
        "output before status 139 at degree 7"
    )


if __name__ == "__main__":
    main()
