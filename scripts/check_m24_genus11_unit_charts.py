#!/usr/bin/env python3
"""Check the deep M24 genus-11 canonical unit-chart certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-m24-genus11-unit-chart-gate-v1"
DEFAULT_PATH = Path(
    "data/derived/m24_koenig_genus11_unit_chart_gate.tsv"
)
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)
MODEL_SHA256 = (
    "8fc3f13944653c89e0de309632f5f11aaccd18aaed41cbf794db036fd57d31a2"
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
    assert metadata["status"] == "deep_unit_charts_unresolved"

    minus_six = [
        int(value) for value in values["minus6_levels"].split(",")
    ]
    assert minus_six[:4] == [2, 4, 8, 16]
    assert minus_six[4:] == [16] * 21
    assert values["minus6_modulus"] == str(2**26)
    assert values["minus6_terminal_count"] == "16"
    assert values["minus6_terminal_sha256"] == (
        "36762c40ab4f790ee097f73fc6a091adf2bfdc497306ba65"
        "ac177c7671dad528"
    )
    assert values["minus6_simple_count"] == "0"
    assert values["minus6_strong_hensel_count"] == "0"
    assert values["minus6_terminal_hessian_square_classes"] == "8,7"
    assert values["minus6_critical_probe_cluster_count"] == "1"
    assert values["minus6_critical_probe_min_value_v2"] == "162"
    assert values["minus6_critical_probe_min_gradient_v2"] == "162"
    assert values["minus6_critical_probe_discriminant"] == (
        "8,7,nonsquare"
    )
    assert values["minus6_critical_probe_status"].startswith(
        "bounded_200_bit"
    )

    assert values["minus2_levels"] == (
        "4,6,10,16,24,28,44,84,84,164,292,324,580"
    )
    assert values["minus2_modulus"] == str(2**14)
    assert values["minus2_terminal_count"] == "580"
    assert values["minus2_terminal_sha256"] == (
        "44b32a42fe1714cfeb76457fb275c6d0476327574f1c54177"
        "8cf62e9cbfa0797"
    )
    assert values["minus2_simple_count"] == "0"
    assert values["minus2_strong_hensel_count"] == "0"
    assert values["minus2_false_square_candidate"] == (
        "897,335:dead_by_modulus_16384"
    )

    print(
        "verified deep König M24 unit charts: (-6,0) stabilizes at 16 "
        "boxes through modulus 2^26 with one bounded nonsquare critical "
        "cluster; (-2,0) has 580 unresolved boxes modulo 2^14"
    )


if __name__ == "__main__":
    main()
