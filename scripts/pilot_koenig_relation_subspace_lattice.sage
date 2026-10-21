#!/usr/bin/env sage
"""Pilot simultaneous denominator recovery for König's relation chart."""

from __future__ import annotations

import argparse
import hashlib
import math
import runpy
import subprocess
from collections import defaultdict
from pathlib import Path

import numpy as np

from sage.all import ZZ, gcd, matrix
from sage.env import SAGE_VERSION

PRIME = 19
ENTRIES = 1704
SUBSET_SIZES = (6, 8, 10, 12)
SUBSET_OFFSETS = (0, 11, 37, 101)
SUBSET_STEP = 97
DENOMINATOR_WEIGHTS = (1, 4, 16, 64, 256)
SCHEMAS = {
    9: "m23-koenig-a-relation-subspace-lattice-pilot-v1",
    10: "m23-koenig-a-relation-subspace-lattice-pilot-v2",
}
UNRESOLVED_COUNTS = {9: 718, 10: 723}
PLANTED_DENOMINATOR = 12347
MINIMUM_CREDIBLE_SUPPORT = 2
MINIMUM_CREDIBLE_STABLE = math.ceil(0.9 * ENTRIES)


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


def canonical_denominator(value, modulus):
    residue = abs(int(value)) % modulus
    if residue == 0:
        return None
    return min(residue, modulus - residue)


def candidate_denominators(residues, modulus, weight):
    width = len(residues)
    basis = matrix(ZZ, width + 1, width + 1)
    basis[0, 0] = weight
    for column, residue in enumerate(residues, start=1):
        basis[0, column] = int(residue)
        basis[column, column] = modulus
    reduced = basis.LLL(delta=0.99)
    candidates = set()
    for row in reduced.rows():
        leading = int(row[0])
        if leading == 0 or leading % weight:
            continue
        denominator = canonical_denominator(leading // weight, modulus)
        if denominator is None or gcd(denominator, modulus) != 1:
            continue
        candidates.add(denominator)
    return candidates


def score_candidate(denominator, charts, bounds):
    current_digits = max(charts)
    current_modulus = charts[current_digits]["modulus"]
    current = centered(
        (
            charts[current_digits]["chart"].astype(np.uint64)
            * denominator
        )
        % current_modulus,
        current_modulus,
    ).reshape(-1)
    previous = centered(
        (
            charts[current_digits - 1]["chart"].astype(np.uint64)
            * denominator
        )
        % charts[current_digits - 1]["modulus"],
        charts[current_digits - 1]["modulus"],
    ).reshape(-1)
    two_back = centered(
        (
            charts[current_digits - 2]["chart"].astype(np.uint64)
            * denominator
        )
        % charts[current_digits - 2]["modulus"],
        charts[current_digits - 2]["modulus"],
    ).reshape(-1)
    return {
        "denominator": denominator,
        "maximum_absolute_numerator": int(np.max(np.abs(current))),
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


def self_test():
    modulus = PRIME**6
    numerators = [101 + 37 * index for index in range(12)]
    inverse = pow(PLANTED_DENOMINATOR, -1, modulus)
    residues = [
        (numerator * inverse) % modulus for numerator in numerators
    ]
    recovered = candidate_denominators(residues, modulus, 1)
    assert PLANTED_DENOMINATOR in recovered
    print(
        "simultaneous lattice pilot self-test passed: "
        f"recovered denominator {PLANTED_DENOMINATOR}"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--maximum-digits", type=int, choices=tuple(SCHEMAS), default=9
    )
    for digits in range(8, max(SCHEMAS) + 1):
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
    reconstruct_chart = reconstruction["reconstruct_chart"]

    current_digits = args.maximum_digits
    charts = {}
    input_paths = {}
    for digits in range(current_digits - 2, current_digits + 1):
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
        if digits >= 8:
            summary = getattr(args, f"summary{digits}")
            reduced = getattr(args, f"reduced{digits}")
        actual_digits, chart = load_chart(summary, reduced)
        assert actual_digits == digits
        charts[digits] = chart
        input_paths[digits] = (summary, reduced)
    assert all(chart["chart"].size == ENTRIES for chart in charts.values())

    bounds = {
        digits: math.isqrt((chart["modulus"] - 1) // 2)
        for digits, chart in charts.items()
    }
    successes, _ = reconstruct_chart(
        charts[current_digits]["chart"], charts[current_digits]["modulus"]
    )
    unresolved = tuple(
        index for index in range(ENTRIES) if index not in successes
    )
    assert len(unresolved) == UNRESOLVED_COUNTS[current_digits]

    proposals = defaultdict(set)
    flat = charts[current_digits]["chart"].reshape(-1)
    for subset_size in SUBSET_SIZES:
        for offset in SUBSET_OFFSETS:
            indices = tuple(
                unresolved[
                    (offset + SUBSET_STEP * position) % len(unresolved)
                ]
                for position in range(subset_size)
            )
            assert len(set(indices)) == subset_size
            residues = [int(flat[index]) for index in indices]
            for weight in DENOMINATOR_WEIGHTS:
                configuration = (
                    f"size={subset_size},offset={offset},weight={weight}"
                )
                for denominator in candidate_denominators(
                    residues, charts[current_digits]["modulus"], weight
                ):
                    proposals[denominator].add(configuration)

    scores = []
    for denominator, configurations in proposals.items():
        score = score_candidate(denominator, charts, bounds)
        score["support"] = len(configurations)
        score["configurations"] = ";".join(sorted(configurations))
        scores.append(score)
    scores.sort(
        key=lambda score: (
            -score["stable_previous"],
            -score["stable_two_back"],
            score["maximum_absolute_numerator"],
            -score["support"],
            score["denominator"],
        )
    )
    credible = [
        score
        for score in scores
        if score["support"] >= MINIMUM_CREDIBLE_SUPPORT
        and score["stable_previous"] >= MINIMUM_CREDIBLE_STABLE
    ]

    lines = [
        f"# schema\t{SCHEMAS[current_digits]}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        "# status\t"
        + (
            "credible_shared_denominator_candidate"
            if credible
            else "no_credible_shared_denominator_candidate"
        ),
        f"# chart_entries\t{ENTRIES}",
        f"# unresolved_scalar_entries\t{len(unresolved)}",
        f"# current_modulus\t{charts[current_digits]['modulus']}",
        f"# previous_modulus\t{charts[current_digits - 1]['modulus']}",
        f"# two_back_modulus\t{charts[current_digits - 2]['modulus']}",
        f"# current_symmetric_bound\t{bounds[current_digits]}",
        f"# planted_denominator\t{PLANTED_DENOMINATOR}",
        "# planted_denominator_recovered\t1",
        "# subset_sizes\t" + ",".join(map(str, SUBSET_SIZES)),
        "# subset_offsets\t" + ",".join(map(str, SUBSET_OFFSETS)),
        f"# subset_step\t{SUBSET_STEP}",
        "# denominator_weights\t"
        + ",".join(map(str, DENOMINATOR_WEIGHTS)),
        f"# distinct_candidates\t{len(scores)}",
        f"# credible_minimum_support\t{MINIMUM_CREDIBLE_SUPPORT}",
        f"# credible_minimum_stable_previous\t{MINIMUM_CREDIBLE_STABLE}",
        f"# credible_candidates\t{len(credible)}",
        f"# summary{current_digits - 1}_sha256\t"
        f"{sha256(input_paths[current_digits - 1][0])}",
        f"# reduced{current_digits - 1}_sha256\t"
        f"{sha256(input_paths[current_digits - 1][1])}",
        f"# summary{current_digits}_sha256\t"
        f"{sha256(input_paths[current_digits][0])}",
        f"# reduced{current_digits}_sha256\t"
        f"{sha256(input_paths[current_digits][1])}",
        (
            "rank\tdenominator\tsupport\tmaximum_absolute_numerator\t"
            "squared_norm\twithin_symmetric_bound\tstable_previous\t"
            "stable_two_back\tconfigurations"
        ),
    ]
    for rank, score in enumerate(scores[:25], start=1):
        lines.append(
            f"{rank}\t{score['denominator']}\t{score['support']}\t"
            f"{score['maximum_absolute_numerator']}\t"
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
