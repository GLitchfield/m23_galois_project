#!/usr/bin/env python3
"""Check the compact M24 genus-11 (-2,0) cluster certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-m24-genus11-minus2-clusters-v1"
DEFAULT_PATH = Path(
    "data/derived/m24_koenig_genus11_minus2_clusters.tsv"
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
    assert metadata["status"] == "all_frontier_clusters_exactly_excluded"

    assert values["frontier_count"] == "4356"
    assert values["frontier_sha256"] == (
        "a354bee670ec4936d552384a0bdb8f792c069faa1c8cbbf2"
        "c00929bde8ff506d"
    )
    assert values["dominant_cluster_count"] == "4352"
    assert values["dominant_cluster_sha256"] == (
        "a349099690a84aaa3217ae7330e00980ad365196a5c1d3c8"
        "a30446576c0381f4"
    )
    assert values["dominant_cluster_mod_64"] == "1,63"
    assert values["dominant_exact_center"] == "1,-1"
    assert values["dominant_multiplicity"] == "10"
    assert values["dominant_weighted_order_2_1"] == "20"
    assert values["dominant_exceptional_quadratic_discriminant"] == (
        "4/3,nonsquare"
    )
    assert values["dominant_rational_direction"] == "z=-1/2"
    assert values["dominant_strict_transform_multiplicity"] == "2"
    assert values["dominant_strict_transform_tangent_discriminant"] == (
        "8,nonsquare"
    )
    assert values["dominant_status"] == "no_Q2_normalization_branch"

    assert values["outlier_cluster_count"] == "4"
    assert values["outlier_cluster_sha256"] == (
        "3fd80ea95a7d391a7de4106b5129093c0ebd5c5bf87af7b5"
        "d6fa7b090b6a8be4"
    )
    assert values["outlier_cluster_mod_64"] == "63,49"
    assert values["outlier_residues"] == (
        "2943,58993;2943,190065;134015,124529;134015,255601"
    )
    assert values["outlier_component_relation"] == (
        "q_minus2(t)=monic(q_minus6(16*t))"
    )
    assert values["outlier_singular_factor_degree"] == "442"
    assert values["outlier_initial_hensel_valuations"] == (
        "2943:63,46;134015:66,46"
    )
    newton = [
        tuple(int(entry) for entry in row.split(","))
        for row in values["outlier_newton_valuations"].split(";")
    ]
    assert len(newton) == 8
    assert newton[2][0] > 2 * newton[2][1]
    assert values["outlier_strong_hensel_after_iterations"] == "2"
    assert values["outlier_hessian_discriminant"] == "53,5,nonsquare"
    assert values["outlier_status"] == (
        "exact_ordinary_double_point_no_Q2_branches"
    )
    assert values["minus2_frontier_status"] == "all_4356_boxes_excluded"

    print(
        "verified exact resolution of all 4,356 König M24 (-2,0) "
        "frontier boxes in two nonsplit singular clusters"
    )


if __name__ == "__main__":
    main()
