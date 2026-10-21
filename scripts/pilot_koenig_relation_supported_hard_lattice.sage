#!/usr/bin/env sage
"""Pilot larger q-ary lattices on the hardest supported chart columns."""

from __future__ import annotations

import argparse
import hashlib
import math
import runpy
import subprocess
from collections import defaultdict
from pathlib import Path

import numpy as np

from sage.all import GF, matrix
from sage.env import SAGE_VERSION

PRIME = 19
DIMENSION = 7
CHART_COLUMNS = 7559
WIDTH = DIMENSION + CHART_COLUMNS
EFFECTIVE_DIGITS = (8, 9, 10)
BLOCK_SIZES = (24, 32, 40)
BLOCK_OFFSETS = (0, 509, 1901, 3701)
BLOCK_STEPS = (37, 101, 211, 503)
OFFSET_STRIDE = 787
LEADING_WEIGHTS = (1, 4, 16, 64, 256)
MINIMUM_RECURRENT_BLOCKS = 2
MINIMUM_CREDIBLE_STABLE = math.ceil(0.9 * WIDTH)
SCHEMA = "m23-koenig-a-relation-supported-hard-lattice-pilot-v1"
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


def load_base_pilot():
    return runpy.run_path(
        "scripts/pilot_koenig_relation_supported_free_lattice.sage"
    )


def instability_profile(charts, centered):
    values = {
        digits: centered(
            charts[digits]["chart"], charts[digits]["modulus"]
        )
        for digits in EFFECTIVE_DIGITS
    }
    stable_all = (
        (values[10] == values[9]) & (values[10] == values[8])
    )
    stable_counts = stable_all.sum(axis=0)
    unstable_previous = (values[10] != values[9]).sum(axis=0)
    hard = np.flatnonzero(stable_counts == 0)
    order = np.lexsort((hard, -unstable_previous[hard]))
    return (
        tuple(map(int, hard[order])),
        stable_counts,
        unstable_previous,
    )


def block_specs(hard_columns):
    count = len(hard_columns)
    blocks = []
    for size_index, size in enumerate(BLOCK_SIZES):
        assert size < count
        for route, base_offset in enumerate(BLOCK_OFFSETS):
            offset = (
                base_offset + OFFSET_STRIDE * size_index
            ) % count
            step = BLOCK_STEPS[(route + size_index) % len(BLOCK_STEPS)]
            positions = tuple(
                (offset + step * position) % count
                for position in range(size)
            )
            assert len(set(positions)) == size
            columns = tuple(hard_columns[position] for position in positions)
            block_id = (
                f"size={size},route={route},offset={offset},step={step}"
            )
            blocks.append((block_id, columns))
    column_sets = [set(columns) for _, columns in blocks]
    assert all(
        not left < right and not right < left
        for index, left in enumerate(column_sets)
        for right in column_sets[index + 1 :]
    )
    return blocks


def collect_candidates(
    chart,
    modulus,
    hard_columns,
    candidate_coefficients,
):
    proposals = defaultdict(lambda: {"blocks": set(), "configs": set()})
    for block_id, columns in block_specs(hard_columns):
        subset = chart[:, list(columns)]
        for weight in LEADING_WEIGHTS:
            configuration = f"{block_id},weight={weight}"
            for coefficients in candidate_coefficients(
                subset, modulus, weight
            ):
                proposals[coefficients]["blocks"].add(block_id)
                proposals[coefficients]["configs"].add(configuration)
    return proposals


def self_test():
    pilot = load_base_pilot()
    columns = 768
    charts = {}
    transform = None
    tail = None
    for digits in EFFECTIVE_DIGITS:
        values, current_transform, current_tail = pilot[
            "synthetic_chart"
        ](PRIME**digits, columns)
        charts[digits] = {
            "modulus": PRIME**digits,
            "chart": values,
        }
        if transform is None:
            transform = current_transform
            tail = current_tail
        else:
            assert current_transform == transform
            assert current_tail == tail
    pilot_globals = pilot["module_vector"].__globals__
    original_pilot_columns = pilot_globals["CHART_COLUMNS"]
    pilot_globals["CHART_COLUMNS"] = columns
    original_columns = globals()["CHART_COLUMNS"]
    globals()["CHART_COLUMNS"] = columns
    try:
        hard, _, _ = instability_profile(charts, pilot["centered"])
        assert len(hard) >= max(BLOCK_SIZES)
        proposals = collect_candidates(
            charts[10]["chart"],
            charts[10]["modulus"],
            hard,
            pilot["candidate_coefficients"],
        )
        recurrent = {
            coefficients
            for coefficients, support in proposals.items()
            if len(support["blocks"]) >= MINIMUM_RECURRENT_BLOCKS
        }
        short = [
            coefficients
            for coefficients in recurrent
            if int(
                np.max(
                    np.abs(
                        pilot["module_vector"](
                            charts[10], coefficients
                        )
                    )
                )
            )
            <= 1000
        ]
        rank = matrix(
            GF(PRIME),
            [
                [value % PRIME for value in coefficients]
                for coefficients in short
            ],
        ).rank()
        assert rank == DIMENSION
        expected = {
            pilot["canonical_coefficients"](
                row, charts[10]["modulus"]
            )
            for row in transform.rows()
        }
        explicit = len(expected & set(short))
        assert max(abs(int(value)) for value in tail.list()) <= 14
    finally:
        pilot_globals["CHART_COLUMNS"] = original_pilot_columns
        globals()["CHART_COLUMNS"] = original_columns
    print(
        "supported hard-lattice self-test passed: "
        f"{len(hard)}/{columns} hard columns, "
        f"{len(short)} recurrent short vectors of rank seven; "
        f"{explicit}/7 planted basis rows explicit"
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
    assert all(
        chart["chart"].shape == (DIMENSION, CHART_COLUMNS)
        for chart in charts.values()
    )

    pilot = load_base_pilot()
    hard, stable_counts, unstable_previous = instability_profile(
        charts, pilot["centered"]
    )
    fully_stable = int(np.count_nonzero(stable_counts == DIMENSION))
    partially_stable = int(
        np.count_nonzero(
            (stable_counts > 0) & (stable_counts < DIMENSION)
        )
    )
    assert len(hard) + partially_stable + fully_stable == CHART_COLUMNS
    assert all(stable_counts[column] == 0 for column in hard)

    proposals = collect_candidates(
        charts[10]["chart"],
        charts[10]["modulus"],
        hard,
        pilot["candidate_coefficients"],
    )
    recurrent = {
        coefficients: support
        for coefficients, support in proposals.items()
        if len(support["blocks"]) >= MINIMUM_RECURRENT_BLOCKS
    }
    bound = math.isqrt((charts[10]["modulus"] - 1) // 2)
    scores = []
    for coefficients, support in proposals.items():
        score = pilot["score_candidate"](coefficients, charts, bound)
        score["support_blocks"] = len(support["blocks"])
        score["support_configurations"] = len(support["configs"])
        score["configurations"] = ";".join(sorted(support["configs"]))
        scores.append(score)
    scores.sort(
        key=lambda score: (
            -score["stable_previous"],
            -score["stable_two_back"],
            score["maximum_absolute_coefficient"],
            -score["support_blocks"],
            -score["support_configurations"],
            score["leading_coefficients"],
        )
    )
    credible = [
        score
        for score in scores
        if score["support_blocks"] >= MINIMUM_RECURRENT_BLOCKS
        and score["stable_previous"] >= MINIMUM_CREDIBLE_STABLE
    ]
    credible_rank = pilot["candidate_rank"](credible)
    blocks = block_specs(hard)

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# prime\t{PRIME}",
        "# status\t"
        + (
            "credible_rank_seven_hard_lattice_module"
            if credible_rank == DIMENSION
            else "no_credible_rank_seven_hard_lattice_module"
        ),
        f"# module_dimension\t{DIMENSION}",
        f"# chart_columns\t{CHART_COLUMNS}",
        f"# module_width\t{WIDTH}",
        f"# current_modulus\t{charts[10]['modulus']}",
        f"# previous_modulus\t{charts[9]['modulus']}",
        f"# two_back_modulus\t{charts[8]['modulus']}",
        f"# current_symmetric_bound\t{bound}",
        "# planted_hard_gl7_module_recovered\t1",
        f"# fully_unstable_columns\t{len(hard)}",
        f"# partially_stable_columns\t{partially_stable}",
        f"# fully_stable_columns\t{fully_stable}",
        f"# fully_unstable_previous7\t"
        f"{sum(unstable_previous[column] == DIMENSION for column in hard)}",
        "# block_sizes\t" + ",".join(map(str, BLOCK_SIZES)),
        "# block_offsets\t" + ",".join(map(str, BLOCK_OFFSETS)),
        "# block_steps\t" + ",".join(map(str, BLOCK_STEPS)),
        f"# offset_stride\t{OFFSET_STRIDE}",
        "# leading_weights\t" + ",".join(map(str, LEADING_WEIGHTS)),
        f"# lattice_blocks\t{len(blocks)}",
        f"# lattice_configurations\t{len(blocks) * len(LEADING_WEIGHTS)}",
        f"# distinct_candidates\t{len(proposals)}",
        f"# recurrent_minimum_independent_blocks\t"
        f"{MINIMUM_RECURRENT_BLOCKS}",
        f"# recurrent_candidates\t{len(recurrent)}",
        f"# evaluated_candidates\t{len(scores)}",
        f"# credible_minimum_stable_previous\t{MINIMUM_CREDIBLE_STABLE}",
        f"# credible_candidates\t{len(credible)}",
        f"# credible_leading_rank\t{credible_rank}",
        f"# summary_sha256\t{sha256(args.summary)}",
        f"# chart_sha256\t{sha256(args.chart)}",
        (
            "rank\tleading_coefficients\tsupport_blocks\t"
            "support_configurations\tmaximum_absolute_coefficient\t"
            "squared_norm\twithin_symmetric_bound\tstable_previous\t"
            "stable_two_back\tconfigurations"
        ),
    ]
    for rank, score in enumerate(scores[:25], start=1):
        leading = ",".join(map(str, score["leading_coefficients"]))
        lines.append(
            f"{rank}\t{leading}\t{score['support_blocks']}\t"
            f"{score['support_configurations']}\t"
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
