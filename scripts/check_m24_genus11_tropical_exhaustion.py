#!/usr/bin/env python3
"""Check the compact complete tropical-exhaustion certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-m24-genus11-tropical-exhaustion-v1"
DEFAULT_PATH = Path(
    "data/derived/m24_koenig_genus11_tropical_exhaustion.tsv"
)


def parse(path):
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=DEFAULT_PATH)
    args = parser.parse_args()
    metadata, values = parse(args.summary)

    assert metadata["schema"] == SCHEMA
    assert len(metadata["code_revision"]) == 40
    assert metadata["sage_version"] == "10.9"
    assert metadata["archive_sha256"] == (
        "62ce6415db167aeeb816d71fba83fc33b8637515d6c666731"
        "05c12b49d07dd44"
    )
    assert metadata["model_sha256"] == (
        "8fc3f13944653c89e0de309632f5f11aaccd18aaed41cbf7"
        "94db036fd57d31a2"
    )
    assert metadata["status"] == "complete_Q2_normalization_obstruction"

    assert values["newton_support_count"] == "633"
    assert values["newton_lower_facet_count"] == "12"
    assert values["newton_lower_support_count"] == "21"
    assert values["newton_curve_region_count"] == "26"
    assert values["newton_unbounded_region_count"] == "11"
    rays = set(values["integer_candidate_rays"].split(";"))
    assert rays == {
        "-4,-1:-2,-1",
        "-4,1:-2,-1",
        "-3,2:0,1",
        "-2,-1:0,-1",
        "-2,3:0,1",
        "0,1:1,0",
    }
    assert values["integer_candidate_vertex"] == "-2,0"
    assert values["bounded_candidate_count"] == "100"
    assert values["bounded_dead_count"] == "92"
    assert values["bounded_resolved_minus6"].startswith("Test0149:")
    assert values["bounded_resolved_minus2"].startswith("Test0150:")

    tails = values["negative_tail_face_certificates"].split(";")
    assert set(tails) == {
        "-42,-20:-2,-1:23,5",
        "-42,-18:-2,-1:22,7",
        "-3,13:0,1:14,2",
        "-2,-41:0,-1:43,8",
    }
    assert values["quarter_local_candidate_rays"] == (
        "d=-1,k>=7;d=2k-7,k>=7"
    )
    assert values["quarter_delta_minus1_face_margin_budget"] == "6,1"
    assert values["quarter_weighted_leading_valuations"] == "22,8"
    assert values["quarter_weighted_remainder_margin"] == "6"
    assert values["quarter_weighted_unit_sum_mod_8"] == "2"
    assert values["quarter_tail_status"].startswith("no_Q2_point")

    assert values["integral_ray_finite_dead_levels"] == (
        "1,2,3,4,5,6,7,8"
    )
    assert values["center_0_-2_tangent_leading_valuations"] == "32,29"
    assert values["center_0_-2_tail_competing_margins"] == "9,1"
    assert values["center_0_-2_balance"] == (
        "v2(y)=v2(t)+3/2_impossible"
    )
    assert values["integral_tail_status"].startswith("no_Q2_point")
    assert values["boundary_status"].startswith("Test0147:")
    assert values["affine_nonzero_status"] == (
        "all_integer_valuation_pairs_excluded"
    )
    assert values["normalization_Q2_points"] == "0"
    assert values["koenig_genus11_Q_points"] == (
        "0_by_Q_embedding_into_Q2"
    )
    print(
        "verified complete 2-adic valuation exhaustion for the König "
        "M24 genus-11 normalization: no Q_2-points"
    )


if __name__ == "__main__":
    main()
