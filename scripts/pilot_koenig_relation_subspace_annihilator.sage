#!/usr/bin/env sage
"""Pilot basis-invariant reconstruction of König's rank-three annihilator."""

from __future__ import annotations

import argparse
import hashlib
import math
import runpy
import subprocess
from collections import defaultdict
from pathlib import Path

import numpy as np

from sage.all import GF, ZZ, Zmod, gcd, matrix
from sage.env import SAGE_VERSION

PRIME = 19
ROWS = 568
COLUMNS = 3
WIDTH = ROWS + COLUMNS
SUBSET_SIZES = (6, 8, 10, 12)
SUBSET_OFFSETS = (0, 11, 37, 101)
SUBSET_STEP = 53
LEADING_WEIGHTS = (1, 4, 16, 64, 256)
SCHEMA = "m23-koenig-a-relation-subspace-annihilator-pilot-v1"
MINIMUM_CREDIBLE_SUPPORT = 2
MINIMUM_CREDIBLE_STABLE = math.ceil(0.9 * WIDTH)


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def centered(values, modulus):
    values = np.asarray(values, dtype=np.uint64)
    return (
        ((values + modulus // 2) % modulus).astype(np.int64)
        - modulus // 2
    )


def canonical_coefficients(values, modulus):
    residues = np.asarray(
        [int(value) % modulus for value in values], dtype=np.uint64
    )
    signed = centered(residues, modulus)
    nonzero = np.flatnonzero(signed)
    if not len(nonzero):
        return None
    if int(signed[int(nonzero[0])]) < 0:
        signed = centered((modulus - residues) % modulus, modulus)
    result = tuple(map(int, signed))
    if gcd(modulus, gcd(result)) != 1:
        return None
    return result


def candidate_coefficients(chart_rows, modulus, weight):
    chart_rows = np.asarray(chart_rows, dtype=np.uint64)
    subset_size = chart_rows.shape[0]
    assert chart_rows.shape == (subset_size, COLUMNS)
    basis = matrix(ZZ, subset_size + COLUMNS, subset_size + COLUMNS)
    for row in range(COLUMNS):
        basis[row, row] = weight
        for column in range(subset_size):
            basis[row, COLUMNS + column] = (
                -int(chart_rows[column, row])
            ) % modulus
    for row in range(subset_size):
        basis[COLUMNS + row, COLUMNS + row] = modulus

    candidates = set()
    for row in basis.LLL(delta=0.99).rows():
        leading = tuple(map(int, row[:COLUMNS]))
        if not any(leading) or any(value % weight for value in leading):
            continue
        candidate = canonical_coefficients(
            (value // weight for value in leading), modulus
        )
        if candidate is not None:
            candidates.add(candidate)
    return candidates


def annihilator_vector(chart, coefficients):
    modulus = int(chart["modulus"])
    leading = centered(
        np.asarray(coefficients, dtype=np.int64) % modulus, modulus
    )
    residues = np.asarray(
        [int(value) % modulus for value in coefficients], dtype=np.uint64
    )
    tail = centered(
        (
            (
                (modulus - chart["chart"].astype(np.uint64))
                % modulus
            )
            @ residues
        )
        % modulus,
        modulus,
    )
    return np.concatenate((leading, tail))


def score_candidate(coefficients, charts, bounds):
    current_digits = max(charts)
    current = annihilator_vector(charts[current_digits], coefficients)
    previous = annihilator_vector(
        charts[current_digits - 1], coefficients
    )
    two_back = annihilator_vector(
        charts[current_digits - 2], coefficients
    )
    return {
        "leading_coefficients": coefficients,
        "maximum_absolute_coefficient": int(np.max(np.abs(current))),
        "squared_norm": sum(int(value) ** 2 for value in current),
        "within_symmetric_bound": int(
            np.count_nonzero(np.abs(current) <= bounds[current_digits])
        ),
        "stable_previous": int(np.count_nonzero(current == previous)),
        "stable_two_back": int(
            np.count_nonzero(
                (current == previous) & (current == two_back)
            )
        ),
    }


def candidate_rank(scores):
    if not scores:
        return 0
    return matrix(
        GF(PRIME),
        [
            [value % PRIME for value in score["leading_coefficients"]]
            for score in scores
        ],
    ).rank()


def synthetic_chart(modulus):
    transform = matrix(ZZ, [[7, 2, -1], [3, 5, 1], [2, -3, 4]])
    assert gcd(transform.det(), modulus) == 1
    tail = matrix(
        ZZ,
        [
            [
                ((11 * row + 7 * column + 3 * row * column) % 23) - 11
                for column in range(COLUMNS)
            ]
            for row in range(ROWS)
        ],
    )
    inverse = matrix(Zmod(modulus), transform).inverse()
    chart = -(matrix(Zmod(modulus), tail) * inverse)
    return (
        np.asarray(
            [[int(value) for value in row] for row in chart.rows()],
            dtype=np.uint64,
        ),
        transform,
    )


def self_test():
    modulus = PRIME**7
    chart, transform = synthetic_chart(modulus)
    candidates = set()
    for offset in SUBSET_OFFSETS:
        indices = tuple(
            (offset + SUBSET_STEP * position) % ROWS
            for position in range(12)
        )
        for weight in LEADING_WEIGHTS:
            candidates.update(
                candidate_coefficients(
                    chart[list(indices), :], modulus, weight
                )
            )
    synthetic = {
        "modulus": modulus,
        "chart": chart,
    }
    short = [
        coefficients
        for coefficients in candidates
        if int(
            np.max(np.abs(annihilator_vector(synthetic, coefficients)))
        )
        <= 100
    ]
    rank = matrix(
        GF(PRIME),
        [[value % PRIME for value in coefficients] for coefficients in short],
    ).rank()
    assert rank == COLUMNS
    expected = {
        canonical_coefficients(column, modulus)
        for column in zip(
            *[[int(value) for value in row] for row in transform.rows()]
        )
    }
    assert expected <= set(short)
    print(
        "rank-three annihilator pilot self-test passed: "
        f"recovered planted transformed subspace from {len(short)} vectors"
    )


def main():
    parser = argparse.ArgumentParser()
    for digits in (9, 10):
        parser.add_argument(
            f"--summary{digits}",
            type=Path,
            default=Path(
                "data/derived/"
                "m23_koenig_a_relation_homogeneous_degree110_"
                f"digits{digits}.tsv"
            ),
        )
        parser.add_argument(
            f"--reduced{digits}",
            type=Path,
            default=Path(
                "data/derived/"
                "m23_koenig_a_relation_homogeneous_degree110_"
                f"digits{digits}_reduced.npz"
            ),
        )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return

    reconstruction = runpy.run_path(
        "scripts/reconstruct_koenig_relation_subspace.sage"
    )
    load_chart = reconstruction["load_chart"]
    charts = {}
    input_paths = {}
    for digits in (8, 9, 10):
        summary = Path(
            "data/derived/"
            "m23_koenig_a_relation_homogeneous_degree110_"
            f"digits{digits}.tsv"
        )
        reduced = Path(
            "data/derived/"
            "m23_koenig_a_relation_homogeneous_degree110_"
            f"digits{digits}_reduced.npz"
        )
        if digits >= 9:
            summary = getattr(args, f"summary{digits}")
            reduced = getattr(args, f"reduced{digits}")
        actual_digits, chart = load_chart(summary, reduced)
        assert actual_digits == digits
        charts[digits] = chart
        input_paths[digits] = (summary, reduced)
    assert all(
        chart["chart"].shape == (ROWS, COLUMNS)
        for chart in charts.values()
    )

    bounds = {
        digits: math.isqrt((chart["modulus"] - 1) // 2)
        for digits, chart in charts.items()
    }
    current = charts[10]
    proposals = defaultdict(set)
    for subset_size in SUBSET_SIZES:
        for offset in SUBSET_OFFSETS:
            indices = tuple(
                (offset + SUBSET_STEP * position) % ROWS
                for position in range(subset_size)
            )
            assert len(set(indices)) == subset_size
            subset = current["chart"][list(indices), :]
            for weight in LEADING_WEIGHTS:
                configuration = (
                    f"size={subset_size},offset={offset},weight={weight}"
                )
                for coefficients in candidate_coefficients(
                    subset, current["modulus"], weight
                ):
                    proposals[coefficients].add(configuration)

    scores = []
    for coefficients, configurations in proposals.items():
        score = score_candidate(coefficients, charts, bounds)
        score["support"] = len(configurations)
        score["configurations"] = ";".join(sorted(configurations))
        scores.append(score)
    scores.sort(
        key=lambda score: (
            -score["stable_previous"],
            -score["stable_two_back"],
            score["maximum_absolute_coefficient"],
            -score["support"],
            score["leading_coefficients"],
        )
    )
    credible = [
        score
        for score in scores
        if score["support"] >= MINIMUM_CREDIBLE_SUPPORT
        and score["stable_previous"] >= MINIMUM_CREDIBLE_STABLE
    ]
    credible_rank = candidate_rank(credible)

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        "# status\t"
        + (
            "credible_rank_three_annihilator"
            if credible_rank == COLUMNS
            else "no_credible_rank_three_annihilator"
        ),
        f"# chart_rows\t{ROWS}",
        f"# chart_columns\t{COLUMNS}",
        f"# annihilator_width\t{WIDTH}",
        f"# current_modulus\t{charts[10]['modulus']}",
        f"# previous_modulus\t{charts[9]['modulus']}",
        f"# two_back_modulus\t{charts[8]['modulus']}",
        f"# current_symmetric_bound\t{bounds[10]}",
        "# planted_transformed_subspace_recovered\t1",
        "# subset_sizes\t" + ",".join(map(str, SUBSET_SIZES)),
        "# subset_offsets\t" + ",".join(map(str, SUBSET_OFFSETS)),
        f"# subset_step\t{SUBSET_STEP}",
        "# leading_weights\t" + ",".join(map(str, LEADING_WEIGHTS)),
        f"# distinct_candidates\t{len(scores)}",
        f"# credible_minimum_support\t{MINIMUM_CREDIBLE_SUPPORT}",
        f"# credible_minimum_stable_previous\t{MINIMUM_CREDIBLE_STABLE}",
        f"# credible_candidates\t{len(credible)}",
        f"# credible_leading_rank\t{credible_rank}",
        f"# summary9_sha256\t{sha256(input_paths[9][0])}",
        f"# reduced9_sha256\t{sha256(input_paths[9][1])}",
        f"# summary10_sha256\t{sha256(input_paths[10][0])}",
        f"# reduced10_sha256\t{sha256(input_paths[10][1])}",
        (
            "rank\tleading_coefficients\tsupport\t"
            "maximum_absolute_coefficient\tsquared_norm\t"
            "within_symmetric_bound\tstable_previous\tstable_two_back\t"
            "configurations"
        ),
    ]
    for rank, score in enumerate(scores[:25], start=1):
        leading = ",".join(map(str, score["leading_coefficients"]))
        lines.append(
            f"{rank}\t{leading}\t{score['support']}\t"
            f"{score['maximum_absolute_coefficient']}\t"
            f"{score['squared_norm']}\t"
            f"{score['within_symmetric_bound']}\t"
            f"{score['stable_previous']}\t"
            f"{score['stable_two_back']}\t"
            f"{score['configurations']}"
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
    print(text, end="")


if __name__ == "__main__":
    main()
