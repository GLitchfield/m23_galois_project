#!/usr/bin/env python3
"""Assemble deterministic König F_19 global-identity shards."""

from __future__ import annotations

import argparse
from pathlib import Path


SHARD_SCHEMA = "m23-koenig-f19-global-shard-v1"
CERTIFICATE_SCHEMA = "m23-koenig-f19-global-certificate-v1"


def parse_shard(path):
    metadata = {}
    rows = {}
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line and not line.startswith("index\t"):
            index, unit, zero, coefficients = line.split("\t")
            rows[int(index)] = (int(unit), int(zero), coefficients)
    if metadata.get("schema") != SHARD_SCHEMA:
        raise ValueError(f"unexpected schema in {path}")
    return metadata, rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("shards", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    all_rows = {}
    common = None
    common_keys = (
        "code_revision",
        "family",
        "family_sha256",
        "archive_sha256",
        "source_family_revision",
        "sage_version",
        "field",
        "coordinates",
        "plane_weight",
        "plane_weight_degree",
        "pseudo_remainder_v_degree_bound",
        "modulus_degree",
    )
    for path in sorted(args.shards):
        metadata, rows = parse_shard(path)
        selected = {key: metadata[key] for key in common_keys}
        if common is None:
            common = selected
        elif selected != common:
            raise ValueError(f"inconsistent metadata in {path}")
        overlap = set(all_rows).intersection(rows)
        if overlap:
            raise ValueError(f"duplicate indices {sorted(overlap)}")
        all_rows.update(rows)
    if common is None or not all_rows:
        raise ValueError("no shard rows")
    if sorted(all_rows) != list(range(len(all_rows))):
        raise ValueError("certificate indices must be contiguous from zero")

    modulus_degree = int(common["modulus_degree"])
    bound = int(common["pseudo_remainder_v_degree_bound"])
    valid_rows = [
        index
        for index, (unit, zero, _) in all_rows.items()
        if unit == 1 and zero == 1
    ]
    certified_degree = modulus_degree * len(valid_rows)
    if certified_degree <= bound:
        raise ValueError(
            f"degree coverage {certified_degree} does not exceed {bound}"
        )

    lines = [f"# schema\t{CERTIFICATE_SCHEMA}"]
    lines.extend(f"# {key}\t{common[key]}" for key in common_keys)
    lines.extend(
        (
            f"# modulus_count\t{len(all_rows)}",
            f"# valid_modulus_count\t{len(valid_rows)}",
            f"# certified_modulus_degree_sum\t{certified_degree}",
            "index\tunit_leading_coefficient\tzero_remainder\t"
            "modulus_coefficients_low_to_high",
        )
    )
    for index in sorted(all_rows):
        unit, zero, coefficients = all_rows[index]
        lines.append(f"{index}\t{unit}\t{zero}\t{coefficients}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")
    print(f"wrote={args.output}")
    print(f"modulus_count={len(all_rows)}")
    print(f"valid_modulus_count={len(valid_rows)}")
    print(f"certified_modulus_degree_sum={certified_degree}")
    print(f"pseudo_remainder_v_degree_bound={bound}")


if __name__ == "__main__":
    main()
