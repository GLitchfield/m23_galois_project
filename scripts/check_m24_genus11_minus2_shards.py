#!/usr/bin/env python3
"""Check the compact M24 genus-11 (-2,0) shard certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-m24-genus11-minus2-shards-v1"
DEFAULT_PATH = Path(
    "data/derived/m24_koenig_genus11_minus2_shards.tsv"
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
    assert metadata["status"] == "sharded_continuation_unresolved"

    assert values["base_depth"] == "13"
    assert values["base_modulus"] == str(2**14)
    assert values["base_terminal_count"] == "580"
    assert values["base_terminal_sha256"] == (
        "44b32a42fe1714cfeb76457fb275c6d0476327574f1c54177"
        "8cf62e9cbfa0797"
    )
    assert values["shard_count"] == "4"
    assert values["prefix_bits"] == "4"
    assert values["shard_owned_counts"] == "144,148,144,144"
    assert values["completed_base_boxes"] == "580"
    assert values["extra_depth"] == "4"
    assert values["level_inputs"] == "580,1156,1156,2308"
    assert values["level_dead_parents"] == "2,642,2,258"
    assert values["level_simple_totals"] == "0,0,0,0"
    assert values["level_unresolved"] == "1156,1156,2308,4356"
    assert values["final_modulus"] == str(2**18)
    assert values["final_terminal_count"] == "4356"
    assert values["final_terminal_sha256"] == (
        "a354bee670ec4936d552384a0bdb8f792c069faa1c8cbbf2"
        "c00929bde8ff506d"
    )
    assert values["simple_count"] == "0"
    assert values["strong_hensel_count"] == "0"
    assert values["exact_singular_center_count"] == "0"
    assert values["checkpoint_transcript_sha256"] == (
        "4e8ac4163cd97a439a0e436090aea98344149566fcfb4f8e2"
        "247cef12ae5983e"
    )

    print(
        "verified deterministic four-shard König M24 (-2,0) "
        "continuation: all 580 base boxes completed and resumed, "
        "leaving 4,356 unresolved boxes modulo 2^18"
    )


if __name__ == "__main__":
    main()
