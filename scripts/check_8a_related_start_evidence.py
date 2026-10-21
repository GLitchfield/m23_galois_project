#!/usr/bin/env python3
"""Independently check the exact 8A related-start evidence tables."""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DERIVED = ROOT / "data" / "derived"
TARGET = DERIVED / "m23_8a_8a_2a_inner_classes.tsv"
SUMMARY = DERIVED / "m23_8a_related_start_boundaries.tsv"
COVERAGE = DERIVED / "m23_8a_related_start_target_coverage.tsv"
SOURCES = DERIVED / "m23_4a_3a_8a_inner_classes.tsv"
LINKS = DERIVED / "m23_8a_related_start_links.tsv"

Permutation = tuple[int, ...]
IDENTITY = tuple(range(23))


def read_table(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    lines = path.read_text().splitlines()
    metadata: dict[str, str] = {}
    body = []
    for line in lines:
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            body.append(line)
    return metadata, list(csv.DictReader(body, delimiter="\t"))


def parse_images(value: str) -> Permutation:
    images = tuple(int(entry) - 1 for entry in value.split(","))
    assert len(images) == 23 and set(images) == set(range(23))
    return images


def product(left: Permutation, right: Permutation) -> Permutation:
    """GAP right-action product: point^(left*right)."""
    return tuple(right[left[point]] for point in range(23))


def cycle_lengths(permutation: Permutation) -> tuple[int, ...]:
    seen: set[int] = set()
    result = []
    for start in range(23):
        if start in seen:
            continue
        point = start
        length = 0
        while point not in seen:
            seen.add(point)
            length += 1
            point = permutation[point]
        result.append(length)
    return tuple(sorted(result, reverse=True))


PASSPORTS = {
    "2A": (2,) * 8 + (1,) * 7,
    "3A": (3,) * 6 + (1,) * 5,
    "4A": (4,) * 4 + (2,) * 2 + (1,) * 3,
    "8A": (8, 8, 4, 2, 1),
}


def triple(row: dict[str, str], columns: tuple[str, str, str]) -> tuple[Permutation, ...]:
    return tuple(parse_images(row[column]) for column in columns)


def assert_passport(entries: tuple[Permutation, ...], names: tuple[str, ...]) -> None:
    assert tuple(cycle_lengths(entry) for entry in entries) == tuple(
        PASSPORTS[name] for name in names
    )
    value = IDENTITY
    for entry in entries:
        value = product(value, entry)
    assert value == IDENTITY


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", type=Path, default=TARGET)
    parser.add_argument("--summary", type=Path, default=SUMMARY)
    parser.add_argument("--coverage", type=Path, default=COVERAGE)
    parser.add_argument("--sources", type=Path, default=SOURCES)
    parser.add_argument("--links", type=Path, default=LINKS)
    args = parser.parse_args()

    target_bytes = args.target.read_bytes()
    target_sha = hashlib.sha256(target_bytes).hexdigest()
    _, target_rows = read_table(args.target)
    summary_meta, summary_rows = read_table(args.summary)
    coverage_meta, coverage_rows = read_table(args.coverage)
    source_meta, source_rows = read_table(args.sources)
    link_meta, link_rows = read_table(args.links)

    revisions = {
        metadata["code_revision"]
        for metadata in (summary_meta, coverage_meta, source_meta, link_meta)
    }
    assert len(revisions) == 1
    assert re.fullmatch(r"[0-9a-f]{40}", revisions.pop())
    for metadata in (summary_meta, coverage_meta, source_meta, link_meta):
        assert metadata["target_source_sha256"] == target_sha
        assert metadata["gap_version"]
        assert metadata["group_construction"] == "MathieuGroup(23)"

    assert len(target_rows) == 28
    targets: dict[int, tuple[Permutation, ...]] = {}
    for expected_id, row in enumerate(target_rows, 1):
        assert int(row["class_id"]) == expected_id
        entries = triple(row, ("first_images", "second_images", "third_images"))
        assert_passport(entries, ("8A", "8A", "2A"))
        targets[expected_id] = entries

    assert summary_meta["four_point_class_vector"] == "2A,3A,8A,2A"
    assert int(summary_meta["factorizations_per_target"]) == 20
    assert int(summary_meta["total_boundary_lifts"]) == 560
    expected_summary = {
        ("12", "8A,8A,2A"): (0, 560, 560, 28, 28),
        ("23", "2A,2A,2A"): (-10, 16, 0, 16, 0),
        ("23", "2A,3A,2A"): (-8, 48, 0, 26, 0),
        ("23", "2A,4A,2A"): (-7, 142, 0, 28, 0),
        ("23", "2A,5A,2A"): (-6, 104, 0, 28, 0),
        ("23", "2A,6A,2A"): (-6, 250, 0, 28, 0),
        ("34", "2A,3A,8A"): (-3, 560, 0, 28, 0),
        ("41", "2A,3A,8A"): (-3, 16, 0, 16, 0),
        ("41", "3A,3A,8A"): (-1, 48, 0, 26, 0),
        ("41", "4A,3A,8A"): (0, 142, 88, 28, 26),
        ("41", "5A,3A,8A"): (1, 104, 104, 28, 28),
        ("41", "6A,3A,8A"): (1, 250, 250, 28, 28),
    }
    observed_summary = {
        (row["merged_pair"], row["boundary_class_vector"]): tuple(
            int(row[column])
            for column in (
                "riemann_hurwitz_genus", "lift_count", "generating_count",
                "target_class_coverage", "generating_target_coverage",
            )
        )
        for row in summary_rows
    }
    assert observed_summary == expected_summary

    assert len(coverage_rows) == 28
    coverage = {int(row["target_class_id"]): row for row in coverage_rows}
    assert set(coverage) == set(range(1, 29))
    assert all(int(row["factor_count"]) == 20 for row in coverage.values())
    assert sum(int(row["generating_4A_3A_8A"]) for row in coverage.values()) == 88
    assert sum(int(row["generating_5A_3A_8A"]) for row in coverage.values()) == 104
    assert sum(int(row["generating_6A_3A_8A"]) for row in coverage.values()) == 250

    assert source_meta["class_vector"] == "4A,3A,8A"
    assert int(source_meta["fixed_third_tuple_count"]) == 1764
    assert int(source_meta["inner_class_count"]) == 227
    assert int(source_meta["generating_inner_class_count"]) == 54
    assert len(source_rows) == 54
    sources: dict[int, tuple[Permutation, ...]] = {}
    source_records = []
    for expected_id, row in enumerate(source_rows, 1):
        assert int(row["source_class_id"]) == expected_id
        entries = triple(row, ("first_images", "second_images", "third_images"))
        assert_passport(entries, ("4A", "3A", "8A"))
        sources[expected_id] = entries
        source_records.append(entries)
    assert source_records == sorted(source_records)
    assert len(set(source_records)) == 54

    assert len(link_rows) == 88
    keys: set[tuple[int, int]] = set()
    derived_source_stats = {
        source_id: {"links": 0, "targets": set(), "class22": 0}
        for source_id in sources
    }
    derived_target_counts = {target_id: 0 for target_id in targets}
    for row in link_rows:
        target_id = int(row["target_class_id"])
        source_id = int(row["source_class_id"])
        factor_index = int(row["factor_index"])
        assert 1 <= factor_index <= 20
        assert (target_id, factor_index) not in keys
        keys.add((target_id, factor_index))

        four = tuple(parse_images(row[column]) for column in (
            "h_2A_images", "k_3A_images", "b_8A_images", "c_2A_images"))
        assert_passport(four, ("2A", "3A", "8A", "2A"))
        target = targets[target_id]
        assert product(four[0], four[1]) == target[0]
        assert four[2:] == target[1:]

        boundary = triple(row, (
            "source_4A_images", "source_3A_images", "source_8A_images"))
        assert boundary == (product(four[3], four[0]), four[1], four[2])
        assert_passport(boundary, ("4A", "3A", "8A"))
        canonical = triple(row, (
            "canonical_source_4A_images", "canonical_source_3A_images",
            "canonical_source_8A_images"))
        assert canonical == sources[source_id]

        stats = derived_source_stats[source_id]
        stats["links"] += 1
        stats["targets"].add(target_id)
        stats["class22"] += target_id == 22
        derived_target_counts[target_id] += 1

    assert {target_id for target_id, count in derived_target_counts.items() if count} == (
        set(range(1, 29)) - {9, 26}
    )
    assert derived_target_counts[22] == 3
    class22_source_ids = {
        int(row["source_class_id"])
        for row in link_rows if int(row["target_class_id"]) == 22
    }
    assert class22_source_ids == {8, 27, 44}
    for row in source_rows:
        source_id = int(row["source_class_id"])
        stats = derived_source_stats[source_id]
        assert int(row["boundary_link_count"]) == stats["links"]
        assert int(row["target_class_coverage"]) == len(stats["targets"])
        assert int(row["class22_link_count"]) == stats["class22"]
    for target_id, row in coverage.items():
        assert int(row["generating_4A_3A_8A"]) == derived_target_counts[target_id]

    print(
        "verified 54 generating (4A,3A,8A) source classes, 88 exact "
        "four-point boundary links, and 3 class-22 links"
    )


if __name__ == "__main__":
    main()
