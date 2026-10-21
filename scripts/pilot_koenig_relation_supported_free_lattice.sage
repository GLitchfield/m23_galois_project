#!/usr/bin/env sage
"""Pilot short-vector recovery in König's supported free relation module."""

from __future__ import annotations

import argparse
import hashlib
import math
import subprocess
from collections import defaultdict
from pathlib import Path

import numpy as np

from sage.all import GF, ZZ, Zmod, diagonal_matrix, gcd, matrix
from sage.env import SAGE_VERSION

PRIME = 19
DIMENSION = 7
CHART_COLUMNS = 7559
WIDTH = DIMENSION + CHART_COLUMNS
EFFECTIVE_DIGITS = (8, 9, 10)
SUBSET_SIZES = (8, 12, 16, 20)
SUBSET_OFFSETS = (0, 101, 1009, 3001)
SUBSET_STEP = 997
LEADING_WEIGHTS = (1, 4, 16, 64, 256)
MINIMUM_CREDIBLE_SUPPORT = 2
MINIMUM_CREDIBLE_STABLE = math.ceil(0.9 * WIDTH)
SCHEMA = "m23-koenig-a-relation-supported-free-lattice-pilot-v1"
CHART_SCHEMA = (
    "m23-koenig-a-relation-supported-free-quotient-chart-v1"
)
SUMMARY_SCHEMA = "m23-koenig-a-relation-supported-free-quotient-v1"


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path):
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


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


def candidate_coefficients(chart_subset, modulus, weight):
    chart_subset = np.asarray(chart_subset, dtype=np.uint64)
    assert chart_subset.shape[0] == DIMENSION
    subset_size = chart_subset.shape[1]
    basis = matrix(
        ZZ,
        DIMENSION + subset_size,
        DIMENSION + subset_size,
    )
    for row in range(DIMENSION):
        basis[row, row] = weight
        for column in range(subset_size):
            basis[row, DIMENSION + column] = int(
                chart_subset[row, column]
            )
    for row in range(subset_size):
        basis[DIMENSION + row, DIMENSION + row] = modulus

    candidates = set()
    for row in basis.LLL(delta=0.99).rows():
        leading = tuple(map(int, row[:DIMENSION]))
        if not any(leading) or any(value % weight for value in leading):
            continue
        candidate = canonical_coefficients(
            (value // weight for value in leading), modulus
        )
        if candidate is not None:
            candidates.add(candidate)
    return candidates


def exact_row_product(coefficients, chart, modulus):
    residues = tuple(int(value) % modulus for value in coefficients)
    chart = np.asarray(chart, dtype=np.uint64)
    assert chart.shape == (DIMENSION, CHART_COLUMNS)
    return np.fromiter(
        (
            sum(
                residues[row] * int(chart[row, column])
                for row in range(DIMENSION)
            )
            % modulus
            for column in range(CHART_COLUMNS)
        ),
        dtype=np.uint64,
        count=CHART_COLUMNS,
    )


def module_vector(chart, coefficients):
    modulus = int(chart["modulus"])
    leading = centered(
        np.asarray(coefficients, dtype=np.int64) % modulus, modulus
    )
    tail = centered(
        exact_row_product(coefficients, chart["chart"], modulus),
        modulus,
    )
    return np.concatenate((leading, tail))


def score_candidate(coefficients, charts, bound):
    current = module_vector(charts[10], coefficients)
    previous = module_vector(charts[9], coefficients)
    two_back = module_vector(charts[8], coefficients)
    return {
        "leading_coefficients": coefficients,
        "maximum_absolute_coefficient": int(np.max(np.abs(current))),
        "squared_norm": sum(int(value) ** 2 for value in current),
        "within_symmetric_bound": int(
            np.count_nonzero(np.abs(current) <= bound)
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


def synthetic_chart(modulus, columns):
    global CHART_COLUMNS
    original_columns = CHART_COLUMNS
    CHART_COLUMNS = columns
    try:
        unitriangular = matrix.identity(ZZ, DIMENSION)
        for row in range(DIMENSION):
            for column in range(row + 1, DIMENSION):
                unitriangular[row, column] = (
                    (3 * row + 5 * column + 1) % 7
                ) - 3
        scales = diagonal_matrix(ZZ, [2, 3, 5, 7, 11, 13, 17])
        transform = unitriangular * scales
        assert abs(transform.det()) > 1
        assert gcd(transform.det(), modulus) == 1
        tail = matrix(
            ZZ,
            [
                [
                    (
                        11 * row
                        + 7 * column
                        + 3 * row * column
                        + column * column
                    )
                    % 29
                    - 14
                    for column in range(columns)
                ]
                for row in range(DIMENSION)
            ],
        )
        inverse = matrix(Zmod(modulus), transform).inverse()
        chart = inverse * matrix(Zmod(modulus), tail)
        values = np.asarray(
            [[int(value) for value in row] for row in chart.rows()],
            dtype=np.uint64,
        )
        return values, transform, tail
    finally:
        CHART_COLUMNS = original_columns


def self_test():
    global CHART_COLUMNS
    columns = 64
    modulus = PRIME**10
    chart, transform, tail = synthetic_chart(modulus, columns)
    original_columns = CHART_COLUMNS
    CHART_COLUMNS = columns
    try:
        proposals = defaultdict(set)
        for subset_size in (12, 16, 20):
            for offset in (0, 7, 19, 31):
                indices = tuple(
                    (offset + 13 * position) % columns
                    for position in range(subset_size)
                )
                for weight in LEADING_WEIGHTS:
                    configuration = (
                        f"size={subset_size},offset={offset},weight={weight}"
                    )
                    for coefficients in candidate_coefficients(
                        chart[:, list(indices)], modulus, weight
                    ):
                        proposals[coefficients].add(configuration)
        synthetic = {
            "modulus": modulus,
            "chart": chart,
        }
        short = []
        for coefficients, configurations in proposals.items():
            if len(configurations) < MINIMUM_CREDIBLE_SUPPORT:
                continue
            vector = module_vector(synthetic, coefficients)
            if int(np.max(np.abs(vector))) <= 1000:
                short.append(coefficients)
        rank = matrix(
            GF(PRIME),
            [
                [value % PRIME for value in coefficients]
                for coefficients in short
            ],
        ).rank()
        assert rank == DIMENSION
        expected = {
            canonical_coefficients(row, modulus)
            for row in transform.rows()
        }
        for row, coefficients in zip(
            tail.rows(),
            (
                canonical_coefficients(values, modulus)
                for values in transform.rows()
            ),
        ):
            assert np.array_equal(
                module_vector(synthetic, coefficients)[DIMENSION:],
                np.asarray(list(map(int, row)), dtype=np.int64),
            )
        assert max(abs(int(value)) for value in tail.list()) <= 14
    finally:
        CHART_COLUMNS = original_columns
    print(
        "supported free-lattice self-test passed: "
        f"recovered planted rank seven from {len(short)} short vectors; "
        f"{len(expected & set(short))}/7 planted basis rows explicit"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "free_quotient_digits10.tsv"
        ),
    )
    parser.add_argument(
        "--chart",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "free_quotient_chart_digits10.npz"
        ),
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return

    certificate = metadata(args.summary)
    assert certificate["schema"] == SUMMARY_SCHEMA
    assert certificate["status"] == (
        "coherent_free_quotient_incomplete_reconstruction"
    )
    assert int(certificate["prime"]) == PRIME
    assert int(certificate["quotient_dimension"]) == DIMENSION
    assert int(certificate["chart_columns"]) == CHART_COLUMNS
    assert int(certificate["maximum_effective_digits"]) == 10
    assert int(certificate["total_transition_mismatches"]) == 0

    with np.load(args.chart) as stored:
        assert str(stored["schema"]) == CHART_SCHEMA
        assert int(stored["prime"]) == PRIME
        assert int(stored["maximum_stage_digits"]) == 13
        pivots = np.asarray(stored["pivot_columns"], dtype=np.int32)
        nonpivots = np.asarray(
            stored["nonpivot_columns"], dtype=np.int32
        )
        selected = np.asarray(
            stored["selected_numerator_positions"], dtype=np.int32
        )
        charts = {
            digits: {
                "modulus": PRIME**digits,
                "chart": np.asarray(
                    stored[f"chart_effective_digits{digits}"],
                    dtype=np.uint64,
                ),
            }
            for digits in EFFECTIVE_DIGITS
        }
    assert pivots.shape == (DIMENSION,)
    assert nonpivots.shape == (CHART_COLUMNS,)
    assert selected.shape == (WIDTH,)
    assert all(
        chart["chart"].shape == (DIMENSION, CHART_COLUMNS)
        for chart in charts.values()
    )
    assert all(
        np.array_equal(
            charts[digits]["chart"] % PRIME ** (digits - 1),
            charts[digits - 1]["chart"],
        )
        for digits in (9, 10)
    )

    current = charts[10]
    proposals = defaultdict(set)
    for subset_size in SUBSET_SIZES:
        for offset in SUBSET_OFFSETS:
            indices = tuple(
                (offset + SUBSET_STEP * position) % CHART_COLUMNS
                for position in range(subset_size)
            )
            assert len(set(indices)) == subset_size
            subset = current["chart"][:, list(indices)]
            for weight in LEADING_WEIGHTS:
                configuration = (
                    f"size={subset_size},offset={offset},weight={weight}"
                )
                for coefficients in candidate_coefficients(
                    subset, current["modulus"], weight
                ):
                    proposals[coefficients].add(configuration)

    recurrent = {
        coefficients: configurations
        for coefficients, configurations in proposals.items()
        if len(configurations) >= MINIMUM_CREDIBLE_SUPPORT
    }
    bound = math.isqrt((current["modulus"] - 1) // 2)
    scores = []
    for coefficients, configurations in recurrent.items():
        score = score_candidate(coefficients, charts, bound)
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
        if score["stable_previous"] >= MINIMUM_CREDIBLE_STABLE
    ]
    credible_rank = candidate_rank(credible)

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        "# status\t"
        + (
            "credible_rank_seven_short_module"
            if credible_rank == DIMENSION
            else "no_credible_rank_seven_short_module"
        ),
        f"# module_dimension\t{DIMENSION}",
        f"# chart_columns\t{CHART_COLUMNS}",
        f"# module_width\t{WIDTH}",
        f"# current_modulus\t{charts[10]['modulus']}",
        f"# previous_modulus\t{charts[9]['modulus']}",
        f"# two_back_modulus\t{charts[8]['modulus']}",
        f"# current_symmetric_bound\t{bound}",
        "# planted_gl7_module_recovered\t1",
        "# subset_sizes\t" + ",".join(map(str, SUBSET_SIZES)),
        "# subset_offsets\t" + ",".join(map(str, SUBSET_OFFSETS)),
        f"# subset_step\t{SUBSET_STEP}",
        "# leading_weights\t" + ",".join(map(str, LEADING_WEIGHTS)),
        f"# distinct_candidates\t{len(proposals)}",
        f"# recurrent_minimum_support\t{MINIMUM_CREDIBLE_SUPPORT}",
        f"# recurrent_candidates\t{len(recurrent)}",
        f"# credible_minimum_stable_previous\t{MINIMUM_CREDIBLE_STABLE}",
        f"# credible_candidates\t{len(credible)}",
        f"# credible_leading_rank\t{credible_rank}",
        f"# summary_sha256\t{sha256(args.summary)}",
        f"# chart_sha256\t{sha256(args.chart)}",
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
