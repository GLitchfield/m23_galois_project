#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPONENT_PATH = ROOT / "data/derived/m23_seguin_3a_component_reconciliation.tsv"
TOTAL_PATH = ROOT / "data/derived/m23_3a_inner_nielsen_total.tsv"
COMPONENT_SOURCES = (
    "scripts/gap/reconcile_seguin_3a_components.g",
    "src/gap/nielsen.g",
)
TOTAL_SOURCES = (
    "scripts/gap/certify_3a_inner_nielsen_total.g",
    "scripts/gap/generate_homogeneous_pair_orbits.g",
    "src/gap/m23_homogeneous_macroblocks.g",
    "src/gap/m23_homogeneous_bridge.g",
    "src/gap/m23_maximal_subgroup_masks.g",
    "src/gap/nielsen.g",
)


def read_blocks(path: Path) -> tuple[dict[str, str], list[list[dict[str, str]]]]:
    raw_lines = path.read_text().splitlines()
    metadata = {
        key: value
        for key, value in (
            line[2:].split("\t", 1) for line in raw_lines if line.startswith("# ")
        )
    }
    blocks: list[list[str]] = []
    current: list[str] = []
    for line in raw_lines:
        if line.startswith("#"):
            continue
        if line:
            current.append(line)
        elif current:
            blocks.append(current)
            current = []
    if current:
        blocks.append(current)
    return metadata, [
        list(csv.DictReader(block, delimiter="\t"))
        for block in blocks
    ]


def assert_provenance(metadata: dict[str, str], sources: tuple[str, ...]) -> None:
    revision = metadata["code_revision"]
    assert re.fullmatch(r"[0-9a-f]{40}", revision)
    expected = subprocess.run(
        ("git", "log", "-1", "--format=%H", "--", *sources),
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()
    assert revision == expected
    for staged in (False, True):
        command = ["git", "diff"]
        if staged:
            command.append("--cached")
        command.extend(("--quiet", "--", *sources))
        assert subprocess.run(command, cwd=ROOT, check=False).returncode == 0
    assert metadata["gap_version"] == "4.12.1"
    assert metadata["atlasrep_version"] == "2.1.8"
    assert metadata["ctbllib_version"] == "1.3.7"
    assert metadata["transgrp_version"] == "3.6.5"
    assert int(metadata["group_order"]) == 10_200_960


def cycle_data(shape: str) -> tuple[int, int]:
    pieces = [tuple(map(int, part.split("^"))) for part in shape.split()]
    return (
        sum(length * count for length, count in pieces),
        sum(count for _, count in pieces),
    )


def verify_components() -> dict[int, int]:
    metadata, blocks = read_blocks(COMPONENT_PATH)
    assert_provenance(metadata, COMPONENT_SOURCES)
    assert metadata["generated_by"] == (
        "scripts/gap/reconcile_seguin_3a_components.g"
    )
    assert len(blocks) == 2
    properties = {row["property"]: row["value"] for row in blocks[0]}
    assert properties == {
        "class_size": "56672",
        "fixed_first_centralizer_order": "180",
        "fixed_first_second_generator_orbits": "356",
        "computed_two_component_size_sum": "37296",
        "generating_inverse_pair_orbits": "40",
        "generating_inverse_pair_elements": "7200",
        "nongenerating_second_generator_orbits": "316",
        "nongenerating_second_generator_elements": "49472",
        "both_full_braid_components_contain_inverse_pairs": "true",
    }

    rows = blocks[1]
    assert len(rows) == 2
    expected = {
        "seguin_printed_h": (28_980, 1_206, 28, 5_040),
        "other_component": (8_316, 325, 12, 2_160),
    }
    genera_by_size: dict[int, int] = {}
    for row in rows:
        size, genus, pair_orbits, pair_elements = expected[row["component"]]
        assert int(row["inner_full_braid_size"]) == size
        assert int(row["marked_full_braid_size"]) == size * 10_200_960
        assert int(row["computed_symmetric_genus"]) == genus
        assert int(row["inverse_pair_centralizer_orbits"]) == pair_orbits
        assert int(row["inverse_pair_elements"]) == pair_elements
        cycle_counts = []
        for name in ("beta3_cycle_shape", "eta23_cycle_shape", "eta234_cycle_shape"):
            degree, count = cycle_data(row[name])
            assert degree == size
            cycle_counts.append(count)
        assert 1 - size + (3 * size - sum(cycle_counts)) // 2 == genus
        genera_by_size[size] = genus
    assert sum(genera_by_size) == 37_296
    return genera_by_size


def verify_total(genera_by_size: dict[int, int]) -> None:
    metadata, blocks = read_blocks(TOTAL_PATH)
    assert_provenance(metadata, TOTAL_SOURCES)
    assert metadata["generated_by"] == (
        "scripts/gap/certify_3a_inner_nielsen_total.g"
    )
    assert re.fullmatch(r"[0-9a-f]{64}", metadata["source_pair_checkpoint_sha256"])
    assert len(blocks) == 2
    properties = {row["property"]: row["value"] for row in blocks[0]}
    assert properties["pair_orbit_count"] == "356"
    assert properties["pair_orbit_coverage_weight"] == "3211715584"
    assert properties["macroblock_count"] == "11474"
    assert properties["materialized_inner_class_count"] == "156693"
    assert properties["character_table_product_one_tuple_count"] == "1588404402816"
    assert properties["weighted_inner_orbit_mass"] == "2335669/15"
    assert properties["generating_inner_nielsen_count"] == "37296"
    assert properties["nongenerating_inner_class_count"] == "119397"
    assert properties["fixed_first_maximal_subgroups"] == "62"
    assert properties["generation_mask_disagreements"] == "0"

    rows = blocks[1]
    assert {int(row["pair_product_order"]) for row in rows} == {
        1, 2, 3, 4, 5, 6, 7, 8, 11, 14, 15, 23,
    }
    inner = sum(int(row["inner_classes"]) for row in rows)
    generating = sum(int(row["generating_inner_classes"]) for row in rows)
    nongenerating = sum(int(row["nongenerating_inner_classes"]) for row in rows)
    assert inner == int(properties["materialized_inner_class_count"])
    assert generating == int(properties["generating_inner_nielsen_count"])
    assert nongenerating == int(properties["nongenerating_inner_class_count"])
    assert inner == generating + nongenerating
    assert sum(genera_by_size) == generating

    _, reference_blocks = read_blocks(ROOT / "data/reference/hafner_2022_braid_orbits.tsv")
    reference_rows = [
        row for row in reference_blocks[0]
        if row["class_vector"] == "3A,3A,3A,3A"
        and row["action"] == "symmetric"
    ]
    published = {
        int(row["orbit_size"]): int(row["genus"])
        for row in reference_rows
    }
    assert published == genera_by_size


def main() -> None:
    genera_by_size = verify_components()
    verify_total(genera_by_size)
    print(
        "verified structural, arithmetic, reference, and provenance checks for "
        "both exhaustive Seguin 3A certificates"
    )


if __name__ == "__main__":
    main()
