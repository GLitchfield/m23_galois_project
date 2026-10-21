#!/usr/bin/env sage
"""Audit degree filtrations of König's numerator relation image modulo 19."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
from collections import defaultdict
from pathlib import Path

import numpy as np

from sage.all import GF, matrix
from sage.env import SAGE_VERSION

PRIME = 19
EXPECTED_RELATION_DIMENSION = 568
EXPECTED_NUMERATOR_RANK = 477
EXPECTED_PLANE_CONTROLS = 91
EXPECTED_NUMERATOR_COLUMNS = 9506
SCHEMA = "m23-koenig-a-relation-numerator-filtration-v1"


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def filtration_rows(name, values, numerator_basis):
    rank = numerator_basis.nrows()
    groups = defaultdict(list)
    for column, value in enumerate(values):
        groups[int(value)].append(column)
    maximum = max(groups)
    assert set(groups) == set(range(maximum + 1))

    field = numerator_basis.base_ring()
    complement_basis = matrix(field, 0, rank)
    selected_columns = len(values)
    answer = []
    for cutoff in range(maximum, -1, -1):
        complement_rank = complement_basis.nrows()
        answer.append(
            {
                "filtration": name,
                "cutoff": cutoff,
                "selected_columns": selected_columns,
                "complement_rank": complement_rank,
                "supported_dimension": rank - complement_rank,
            }
        )
        group = groups[cutoff]
        selected_columns -= len(group)
        new_rows = (
            numerator_basis.matrix_from_columns(group).transpose()
        )
        complement_basis = (
            complement_basis.stack(new_rows).row_space().basis_matrix()
        )
    assert selected_columns == 0
    answer.reverse()
    return answer


def self_test():
    field = GF(PRIME)
    basis = matrix(
        field,
        [
            [1, 0, 1, 0, 1, 0],
            [0, 1, 1, 0, 0, 1],
            [0, 0, 0, 1, 1, 1],
        ],
    )
    assert basis.rank() == 3
    values = [0, 0, 1, 1, 2, 2]
    rows = filtration_rows("synthetic", values, basis)
    for row in rows:
        cutoff = row["cutoff"]
        complement = [
            column
            for column, value in enumerate(values)
            if value > cutoff
        ]
        complement_rank = (
            basis.matrix_from_columns(complement).rank()
            if complement
            else 0
        )
        assert row["selected_columns"] == sum(
            value <= cutoff for value in values
        )
        assert row["complement_rank"] == complement_rank
        assert row["supported_dimension"] == 3 - complement_rank
    print("numerator-filtration synthetic self-test passed")


def main():
    parser = argparse.ArgumentParser()
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
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    with np.load(args.basis) as stored:
        numerator_specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
    assert len(numerator_specs) == EXPECTED_NUMERATOR_COLUMNS
    assert numerator_specs == [
        (i, j) for i in range(97) for j in range(98)
    ]

    with np.load(args.reduced) as stored:
        projected = np.asarray(stored["projected_all"], dtype=np.uint8)
        numerator_map = np.asarray(
            stored["numerator_map"], dtype=np.uint8
        )
    assert projected.shape == (EXPECTED_RELATION_DIMENSION, 571)
    assert numerator_map.shape == (EXPECTED_NUMERATOR_COLUMNS, 571)

    field = GF(PRIME)
    projected_matrix = matrix(field, projected)
    numerator_matrix = matrix(field, numerator_map)
    assert projected_matrix.rank() == EXPECTED_RELATION_DIMENSION
    assert numerator_matrix.rank() == 480
    numerator_image = projected_matrix * numerator_matrix.transpose()
    numerator_basis = numerator_image.row_space().basis_matrix()
    assert numerator_basis.nrows() == EXPECTED_NUMERATOR_RANK
    assert (
        EXPECTED_RELATION_DIMENSION - EXPECTED_NUMERATOR_RANK
        == EXPECTED_PLANE_CONTROLS
    )

    filtrations = {
        "alpha_degree": [i for i, _ in numerator_specs],
        "beta_degree": [j for _, j in numerator_specs],
        "total_degree": [i + j for i, j in numerator_specs],
        "square_degree": [max(i, j) for i, j in numerator_specs],
    }
    rows = []
    for name, values in filtrations.items():
        rows.extend(filtration_rows(name, values, numerator_basis))

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        f"# relation_dimension\t{EXPECTED_RELATION_DIMENSION}",
        f"# numerator_image_rank\t{EXPECTED_NUMERATOR_RANK}",
        f"# plane_control_dimension\t{EXPECTED_PLANE_CONTROLS}",
        f"# numerator_columns\t{EXPECTED_NUMERATOR_COLUMNS}",
        f"# basis_sha256\t{sha256(args.basis)}",
        f"# reduced_sha256\t{sha256(args.reduced)}",
        (
            "filtration\tcutoff\tselected_columns\tcomplement_rank\t"
            "supported_dimension"
        ),
    ]
    for row in rows:
        lines.append(
            f"{row['filtration']}\t{row['cutoff']}\t"
            f"{row['selected_columns']}\t{row['complement_rank']}\t"
            f"{row['supported_dimension']}"
        )
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.check_summary is not None:
        expected = [
            line
            for line in args.check_summary.read_text().splitlines()
            if not line.startswith("# code_revision\t")
        ]
        actual = [
            line
            for line in text.splitlines()
            if not line.startswith("# code_revision\t")
        ]
        assert actual == expected
    if not args.quiet:
        print(text, end="")
    elif args.check_summary is not None:
        print(
            "verified numerator-filtration summary: "
            f"{len(rows)} cutoff rows"
        )


if __name__ == "__main__":
    main()
