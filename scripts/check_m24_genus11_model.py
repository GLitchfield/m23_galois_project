#!/usr/bin/env python3
"""Check the compact M24 genus-11 model and bounded 2-adic certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-m24-genus11-model-two-adic-gate-v1"
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)
MODEL_SHA256 = (
    "8fc3f13944653c89e0de309632f5f11aaccd18aaed41cbf794db036fd57d31a2"
)
DEFAULT_PATH = Path(
    "data/derived/m24_koenig_genus11_two_adic_gate.tsv"
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


def parse_level(value: str):
    return {
        key: item
        for key, item in (
            field.split(":", 1) for field in value.split(",")
        )
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=DEFAULT_PATH)
    args = parser.parse_args()
    metadata, values = parse(args.summary)

    assert metadata["schema"] == SCHEMA
    assert len(metadata["code_revision"]) == 40
    assert metadata["sage_version"] == "10.9"
    assert metadata["source"] == (
        "König dissertation Theorem 5.2 and Appendix 5.1.12"
    )
    assert metadata["archive_sha256"] == ARCHIVE_SHA256
    assert metadata["model_member"].endswith(
        "M24_(2,2,2,8)/m24_(2,2,2,8)_hurwitz_equation.txt"
    )
    assert metadata["model_sha256"] == MODEL_SHA256
    assert metadata["status"] == (
        "bounded_two_adic_affine_chart_gate_unresolved"
    )

    assert values["terms"] == "633"
    assert values["degree_t"] == "32"
    assert values["degree_x"] == "24"
    assert values["total_degree"] == "44"
    assert values["content"] == "1"
    assert values["model_mod2_values"] == (
        "0,0:0;0,1:1;1,0:0;1,1:1"
    )
    assert values["point_0_0"] == "0,0,0"
    assert values["point_0_-2"] == "0,0,0"

    levels = [
        parse_level(values[f"two_adic_chart_level_{level}"])
        for level in range(13)
    ]
    assert levels[0] == {
        "input": "1",
        "dead": "0",
        "simple_total": "0",
        "singular_children": "2",
        "content_v2": "24-24",
    }
    assert levels[1] == {
        "input": "2",
        "dead": "0",
        "simple_total": "0",
        "singular_children": "8",
        "content_v2": "6-9",
    }
    assert levels[2] == {
        "input": "8",
        "dead": "2",
        "simple_total": "0",
        "singular_children": "12",
        "content_v2": "1-8",
    }
    for level in levels[3:12]:
        assert level == {
            "input": "12",
            "dead": "6",
            "simple_total": "0",
            "singular_children": "12",
            "content_v2": "1-8",
        }
    assert levels[12] == {
        "input": "12",
        "dead": "6",
        "simple_total": "0",
        "singular_children": "12",
        "content_v2": "terminal",
    }
    assert values["two_adic_simple_samples"] == "none"

    residues = [
        tuple(int(item) for item in entry.replace(":", ",").split(","))
        for entry in values["two_adic_unresolved_residues"].split(";")
    ]
    assert len(residues) == 12
    assert all(exponent == 13 for exponent, _, _ in residues)
    origin = {(t_value, x_value) for _, t_value, x_value in residues[:8]}
    minus_two = {
        (t_value, x_value) for _, t_value, x_value in residues[8:]
    }
    assert origin == {
        (t_value, 0) for t_value in range(0, 8192, 1024)
    }
    assert minus_two == {
        (t_value, 8190) for t_value in range(0, 8192, 2048)
    }

    print(
        "verified König M24 model intake and bounded 2-adic chart gate: "
        "no simple root through depth 12; all 12 surviving classes cluster "
        "at the singular points (0,0) and (0,-2)"
    )


if __name__ == "__main__":
    main()
