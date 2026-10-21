#!/usr/bin/env python3
"""Check the compact König second-prime feasibility certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-koenig-second-prime-feasibility-v1"
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)
EXPECTED_INPUT_SHA256 = (
    "a1585a1409aa315c1c226102b74f1d1d449b41cf323f57a309f73ff06a1a360e"
)
DEFAULT_PATH = Path(
    "data/derived/m23_koenig_second_prime_feasibility.tsv"
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
        raise ValueError("missing result table")
    return metadata, header, rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=DEFAULT_PATH)
    args = parser.parse_args()
    metadata, header, rows = parse(args.summary)

    assert metadata["schema"] == SCHEMA
    assert len(metadata["code_revision"]) == 40
    assert metadata["archive_sha256"] == ARCHIVE_SHA256
    assert metadata["sage_version"] == "10.9"
    assert (
        metadata["status"]
        == "plane_points_exist_but_no_certified_second_prime_cover_seed"
    )
    assert metadata["candidate_primes"] == "11,13,17"
    assert int(metadata["numerical_fiber_vectors"]) == 980
    assert int(metadata["numerical_precision_bits"]) == 700
    assert int(metadata["mobius_base_center"]) == 4
    assert metadata["mobius_target_centers"] == "5,6,8,10"
    assert int(metadata["rational_denominator_bound_digits"]) == 80
    assert int(metadata["rational_accept_relative_digits"]) == 160
    assert int(metadata["base_chart_pivot"]) == 812
    assert int(metadata["base_chart_accepted_coefficients"]) == 686
    assert metadata["target_chart_accepted_coefficients"] == (
        "5:708,6:721,8:748,10:762"
    )
    assert int(metadata["cross_chart_unknowns"]) == 295
    assert int(metadata["cross_chart_equations"]) == 2939
    assert int(metadata["cross_chart_columns"]) == 299
    assert int(metadata["cross_chart_rank_mod1000003"]) == 299
    assert (
        int(metadata["cross_chart_nonzero_residuals_mod1000000009"])
        == 607
    )
    assert int(metadata["numerical_fiber_exactly_reconstructed"]) == 0

    assert metadata["solver_input_sha256"] == EXPECTED_INPUT_SHA256
    assert int(metadata["solver_variables"]) == 44
    assert int(metadata["solver_equations"]) == 46
    assert int(metadata["solver_terms"]) == 1930
    assert int(metadata["solver_max_degree"]) == 6
    assert int(metadata["benchmark_wall_limit_seconds"]) == 120
    assert int(metadata["benchmark_threads"]) == 4
    assert metadata["benchmark_msolve_version"] == "0.10.1"
    assert metadata["benchmark_input_sha256"] == EXPECTED_INPUT_SHA256
    assert int(metadata["benchmark_exit_status"]) == 124
    assert metadata["benchmark_outcome"] == "timeout"
    assert int(metadata["benchmark_maximum_rss_kib"]) > 1_000_000
    assert int(metadata["benchmark_highest_f4_degree"]) >= 6
    assert int(metadata["benchmark_maximum_f4_rows"]) >= 100_000
    assert int(metadata["benchmark_maximum_f4_columns"]) >= 1_000_000

    # These v1 field names are retained for certificate compatibility.
    # "boundary" means only reductions of the five reported points; the
    # complete degeneration divisor has not been certified.
    assert header == [
        "prime",
        "affine_points",
        "smooth_points",
        "smooth_boundary_points",
        "smooth_nonboundary_points",
        "selected_alpha",
        "selected_beta",
    ]
    expected = [
        ("11", "19", "13", "3", "10", "0", "6"),
        ("13", "28", "23", "3", "20", "0", "0"),
        ("17", "32", "24", "3", "21", "0", "5"),
    ]
    assert [
        tuple(row[column] for column in header) for row in rows
    ] == expected
    for row in rows:
        assert int(row["smooth_boundary_points"]) + int(
            row["smooth_nonboundary_points"]
        ) == int(row["smooth_points"])

    print(
        "verified second-prime feasibility audit: smooth points outside the "
        "five reported boundary reductions at 11,13,17; exact solver timed "
        "out; numerical fiber cross-chart reconstruction inconsistent"
    )


if __name__ == "__main__":
    main()
