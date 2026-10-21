#!/usr/bin/env python3
"""Independently validate the König numerator-filtration audit."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

PRIME = 19
RELATION_DIMENSION = 568
NUMERATOR_RANK = 477
PLANE_CONTROLS = 91
NUMERATOR_COLUMNS = 9506
SCHEMA = "m23-koenig-a-relation-numerator-filtration-v1"
FILTRATIONS = {
    "alpha_degree": lambda i, j: i,
    "beta_degree": lambda i, j: j,
    "total_degree": lambda i, j: i + j,
    "square_degree": lambda i, j: max(i, j),
}
BOUNDARIES = {
    "alpha_degree": (76, 77),
    "beta_degree": (76, 77),
    "total_degree": (104, 105),
    "square_degree": (84, 85),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def result_rows(path: Path) -> list[dict[str, int | str]]:
    lines = [
        line
        for line in path.read_text().splitlines()
        if line and not line.startswith("#")
    ]
    header = lines[0].split("\t")
    result = []
    for line in lines[1:]:
        fields: dict[str, int | str] = dict(
            zip(header, line.split("\t"), strict=True)
        )
        for name in header[1:]:
            fields[name] = int(fields[name])
        result.append(fields)
    return result


def rank_mod19(values: np.ndarray) -> int:
    """Compute rank with a NumPy elimination independent of Sage."""
    work = np.asarray(values, dtype=np.int64).copy() % PRIME
    rank = 0
    for column in range(work.shape[1]):
        candidates = np.flatnonzero(work[rank:, column])
        if not len(candidates):
            continue
        selected = rank + int(candidates[0])
        work[[rank, selected]] = work[[selected, rank]]
        pivot = work[rank, column:]
        pivot = (
            pivot * pow(int(pivot[0]), -1, PRIME)
        ) % PRIME
        work[rank, column:] = pivot
        factors = work[rank + 1 :, column].copy()
        work[rank + 1 :, column:] = (
            work[rank + 1 :, column:]
            - factors[:, None] * pivot[None, :]
        ) % PRIME
        rank += 1
        if rank == work.shape[0]:
            break
    return rank


def self_test() -> None:
    values = np.array(
        [
            [1, 2, 3, 4],
            [2, 4, 6, 8],
            [0, 1, 0, 1],
            [1, 0, 1, 0],
        ],
        dtype=np.int64,
    )
    assert rank_mod19(values) == 3
    assert rank_mod19(values[:, :2]) == 2
    assert rank_mod19(np.zeros((4, 0), dtype=np.int64)) == 0
    print("independent numerator-filtration rank self-test passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_numerator_filtration.tsv"
        ),
    )
    parser.add_argument(
        "--basis",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation_basis.npz"),
    )
    parser.add_argument(
        "--reduced",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_homogeneous_degree110_"
            "digits10_reduced.npz"
        ),
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    certificate = metadata(args.summary)
    assert certificate["schema"] == SCHEMA
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["relation_dimension"]) == RELATION_DIMENSION
    assert int(certificate["numerator_image_rank"]) == NUMERATOR_RANK
    assert int(certificate["plane_control_dimension"]) == PLANE_CONTROLS
    assert int(certificate["numerator_columns"]) == NUMERATOR_COLUMNS
    assert certificate["basis_sha256"] == sha256(args.basis)
    assert certificate["reduced_sha256"] == sha256(args.reduced)

    with np.load(args.basis) as stored:
        specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
    assert specs == [(i, j) for i in range(97) for j in range(98)]

    rows = result_rows(args.summary)
    by_key = {
        (str(row["filtration"]), int(row["cutoff"])): row
        for row in rows
    }
    assert len(by_key) == len(rows)
    expected_rows = sum(
        max(function(i, j) for i, j in specs) + 1
        for function in FILTRATIONS.values()
    )
    assert len(rows) == expected_rows

    for name, function in FILTRATIONS.items():
        values = [function(i, j) for i, j in specs]
        previous_dimension = -1
        for cutoff in range(max(values) + 1):
            row = by_key[name, cutoff]
            selected = sum(value <= cutoff for value in values)
            assert int(row["selected_columns"]) == selected
            complement_rank = int(row["complement_rank"])
            supported = int(row["supported_dimension"])
            assert 0 <= complement_rank <= NUMERATOR_RANK
            assert supported == NUMERATOR_RANK - complement_rank
            assert supported >= previous_dimension
            previous_dimension = supported
        assert previous_dimension == NUMERATOR_RANK

    with np.load(args.reduced) as stored:
        projected = np.asarray(stored["projected_all"], dtype=np.int64)
        numerator_map = np.asarray(
            stored["numerator_map"], dtype=np.int64
        )
    assert projected.shape == (RELATION_DIMENSION, 571)
    assert numerator_map.shape == (NUMERATOR_COLUMNS, 571)
    image = (projected @ numerator_map.transpose()) % PRIME
    assert rank_mod19(image) == NUMERATOR_RANK

    for name, cutoffs in BOUNDARIES.items():
        function = FILTRATIONS[name]
        values = np.array(
            [function(i, j) for i, j in specs], dtype=np.int64
        )
        for cutoff in cutoffs:
            complement = image[:, values > cutoff]
            complement_rank = rank_mod19(complement)
            row = by_key[name, cutoff]
            assert int(row["complement_rank"]) == complement_rank
            assert int(row["supported_dimension"]) == (
                NUMERATOR_RANK - complement_rank
            )

    first_blocks = {
        name: next(
            (
                int(row["cutoff"]),
                int(row["supported_dimension"]),
            )
            for row in rows
            if row["filtration"] == name
            and int(row["supported_dimension"]) > 0
        )
        for name in FILTRATIONS
    }
    print(
        "verified numerator-filtration boundaries: "
        + ", ".join(
            f"{name}={cutoff} (dimension {dimension})"
            for name, (cutoff, dimension) in first_blocks.items()
        )
    )


if __name__ == "__main__":
    main()
