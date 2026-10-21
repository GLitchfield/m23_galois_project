#!/usr/bin/env python3
"""Check the compact M24 genus-11 boundary and nonintegral certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-m24-genus11-boundary-gate-v1"
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)
MODEL_SHA256 = (
    "8fc3f13944653c89e0de309632f5f11aaccd18aaed41cbf794db036fd57d31a2"
)
DEFAULT_PATH = Path(
    "data/derived/m24_koenig_genus11_boundary_gate.tsv"
)


def parse(path: Path):
    metadata = {}
    values = {}
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            key, value = line.split("\t", 1)
            values[key] = value
    return metadata, values


def parse_unresolved(value: str):
    result = {}
    for item in value.split(";"):
        pair, count = item.split(":")
        result[tuple(int(entry) for entry in pair.split(","))] = int(count)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=DEFAULT_PATH)
    args = parser.parse_args()
    metadata, values = parse(args.summary)

    assert metadata["schema"] == SCHEMA
    assert len(metadata["code_revision"]) == 40
    assert metadata["sage_version"] == "10.9"
    assert metadata["archive_sha256"] == ARCHIVE_SHA256
    assert metadata["model_sha256"] == MODEL_SHA256
    assert metadata["status"] == (
        "exact_boundary_branches_excluded_"
        "bounded_nonintegral_gate_unresolved"
    )

    assert values["point_0_0_multiplicity"] == "8"
    assert values["point_0_0_tangent_quartic_v2"] == (
        "9,8,5,4,0;9,8,5,5,0"
    )
    assert values["point_0_0_q2_branch_gate"].endswith(
        "newton_slope_-9/4"
    )
    assert values["point_0_-2_multiplicity"] == "2"
    assert values["point_0_-2_tangent_ratio_x2_over_t2"] == "8"
    assert values["point_1/4_0_multiplicity"] == "2"
    assert values["point_1/4_0_weight_2_1_initial"] == (
        "4194304*t^2+256*x^4"
    )
    assert values["point_1/4_0_q2_branch_gate"].endswith(
        "(128c)^2=-1"
    )

    assert values["t_zero_factor_signature"] == "1^2,1^8,2^1,6^2"
    assert values["x_zero_factor_signature"] == "1^2,1^8,10^1,12^1"
    assert values["x_infinity_factor_signature"] == "2^2,4^4"
    assert values["t_infinity_finite_x_gate"] == (
        "leading_t32_coefficient_nonzero_constant"
    )
    root_gates = {
        key: value
        for key, value in values.items()
        if key.endswith("_root_gate")
    }
    assert len(root_gates) == 6
    assert all(
        int(value.rsplit(":", 1)[1].split(",")[-1]) == 0
        for value in root_gates.values()
    )

    assert values["tropical_window"] == "t:-40:-1,x:-40:12"
    assert values["tropical_candidate_count"] == "100"
    assert values["tropical_dead_count_depth_8"] == "92"
    assert values["tropical_simple_count_depth_8"] == "0"
    assert values["tropical_unresolved_count_depth_8"] == "8"
    assert values["tropical_dead_terminal_levels"] == (
        "0:52,2:20,3:18,5:1,7:1"
    )
    assert parse_unresolved(values["tropical_unresolved_depth_8"]) == {
        (-6, 0): 16,
        (-2, 0): 84,
        (-2, 7): 256,
        (-2, 8): 256,
        (-2, 9): 256,
        (-2, 10): 256,
        (-2, 11): 256,
        (-2, 12): 256,
    }

    print(
        "verified König M24 exact singular/boundary exclusions and bounded "
        "nonintegral gate: 92/100 candidate valuation charts die by depth "
        "8, with no simple root and eight unresolved charts"
    )


if __name__ == "__main__":
    main()
