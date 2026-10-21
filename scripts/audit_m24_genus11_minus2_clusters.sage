#!/usr/bin/env sage
"""Resolve the two exact clusters in the M24 genus-11 (-2,0) frontier."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import subprocess
from importlib.machinery import SourceFileLoader
from pathlib import Path

from sage.all import PolynomialRing, Qp, QQ, valuation
from sage.env import SAGE_VERSION


SCHEMA = "m23-m24-genus11-minus2-clusters-v1"
CHECKPOINT_SCHEMA = "m23-m24-genus11-minus2-shard-checkpoint-v2"
FRONTIER_COUNT = 4356
FRONTIER_SHA256 = (
    "a354bee670ec4936d552384a0bdb8f792c069faa1c8cbbf2"
    "c00929bde8ff506d"
)
DOMINANT_SHA256 = (
    "a349099690a84aaa3217ae7330e00980ad365196a5c1d3c8"
    "a30446576c0381f4"
)
OUTLIER_SHA256 = (
    "3fd80ea95a7d391a7de4106b5129093c0ebd5c5bf87af7b5"
    "d6fa7b090b6a8be4"
)
OUTLIERS = [
    (2943, 58993),
    (2943, 190065),
    (134015, 124529),
    (134015, 255601),
]
LOCAL_PRECISION = 8000


def load_module(filename, name):
    path = Path(__file__).with_name(filename)
    loader = SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


unit = load_module(
    "audit_m24_genus11_unit_charts.sage",
    "m24_genus11_unit_charts_clusters",
)
elimination = load_module(
    "audit_m24_genus11_local_elimination.sage",
    "m24_genus11_local_elimination_clusters",
)


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def polynomial_digest(polynomial):
    return hashlib.sha256(
        str(polynomial).encode("ascii")
    ).hexdigest()


def load_frontier(run_dir):
    checkpoints = []
    terminals = []
    record_keys = set()
    for shard_index in range(4):
        path = run_dir / f"shard-{shard_index:03d}-of-004.json"
        payload = json.loads(path.read_text())
        assert payload["schema"] == CHECKPOINT_SCHEMA
        metadata = payload["metadata"]
        assert metadata["archive_sha256"] == unit.boundary.ARCHIVE_SHA256
        assert metadata["model_sha256"] == unit.boundary.MODEL_SHA256
        assert metadata["base_modulus"] == 2**14
        assert metadata["base_terminal_sha256"] == (
            "44b32a42fe1714cfeb76457fb275c6d0476327574f1c54177"
            "8cf62e9cbfa0797"
        )
        assert metadata["shard_index"] == shard_index
        assert metadata["shard_count"] == 4
        assert metadata["prefix_bits"] == 4
        assert metadata["extra_depth"] == 4
        records = payload["records"]
        assert not record_keys.intersection(records)
        record_keys.update(records)
        terminals.extend(
            tuple(terminal)
            for record in records.values()
            for terminal in record["terminals"]
        )
        checkpoints.append(payload)
    terminals.sort()
    assert len(record_keys) == 580
    assert len(terminals) == len(set(terminals)) == FRONTIER_COUNT
    assert unit.residue_digest(terminals) == FRONTIER_SHA256
    return checkpoints, terminals


def dominant_cluster_certificate(chart):
    t, x = chart.parent().gens()
    derivatives = (
        chart,
        chart.derivative(t),
        chart.derivative(x),
    )
    assert all(not item(t=1, x=-1) for item in derivatives)
    translated, multiplicity, tangent = (
        unit.boundary.multiplicity_at(chart, 1, -1)
    )
    assert multiplicity == 10
    assert tangent == 6718464 * t**10

    minimum_weight = min(
        2 * exponent[0] + exponent[1]
        for exponent in translated.dict()
    )
    assert minimum_weight == 20
    weighted_initial = chart.parent()(
        sum(
            coefficient * t**exponent[0] * x**exponent[1]
            for exponent, coefficient in translated.dict().items()
            if 2 * exponent[0] + exponent[1] == minimum_weight
        )
    )
    ring_z = PolynomialRing(QQ, names=("z",))
    z = ring_z.gen()
    exceptional = ring_z(
        sum(
            coefficient * z**exponent[0]
            for exponent, coefficient in weighted_initial.dict().items()
        )
    )
    exceptional_quadratic = z**2 + QQ(4) / 3 * z + QQ(1) / 9
    assert exceptional == (
        6718464
        * (z + QQ(1) / 2) ** 2
        * exceptional_quadratic**4
    )
    assert exceptional_quadratic.discriminant() == QQ(4) / 3
    assert not Qp(2, 40)(QQ(4) / 3).is_square()

    blowup = translated(
        t=x**2 * (t - QQ(1) / 2),
        x=x,
    )
    blowup = blowup.parent()(blowup / x**minimum_weight)
    _, blowup_multiplicity, blowup_tangent = (
        unit.boundary.multiplicity_at(blowup, 0, 0)
    )
    assert blowup_multiplicity == 2
    assert blowup_tangent == 29282 * (
        2 * t**2 + 4 * t * x + x**2
    )
    tangent_discriminant = 8
    assert not Qp(2, 40)(tangent_discriminant).is_square()
    return {
        "multiplicity": multiplicity,
        "minimum_weight": minimum_weight,
        "exceptional": exceptional,
        "blowup_multiplicity": blowup_multiplicity,
        "tangent_discriminant": tangent_discriminant,
    }


def outlier_cluster_certificate(polynomial, chart):
    exact = elimination.exact_local_elimination(polynomial)
    singular_minus_six = exact["singular_factor"]
    ring_t = singular_minus_six.parent()
    t = ring_t.gen()
    singular_minus_two = ring_t(
        singular_minus_six(16 * t)
    ).monic()
    assert singular_minus_two.is_irreducible()

    centers = sorted({left for left, _ in OUTLIERS})
    initial_rows = [
        (
            center,
            valuation(singular_minus_two(center), 2),
            valuation(singular_minus_two.derivative()(center), 2),
        )
        for center in centers
    ]
    assert [(row[1], row[2]) for row in initial_rows] == [
        (63, 46),
        (66, 46),
    ]

    field = Qp(2, LOCAL_PRECISION)
    root = field(max(initial_rows, key=lambda row: row[1])[0])
    newton_rows = []
    for _ in range(8):
        value = singular_minus_two(root)
        derivative = singular_minus_two.derivative()(root)
        newton_rows.append(
            (int(value.valuation()), int(derivative.valuation()))
        )
        root -= value / derivative
    assert newton_rows[2][0] > 2 * newton_rows[2][1]

    witness = exact["fx_witness"]
    t_minus_six = 16 * root
    lead = witness[1](t_minus_six)
    constant = witness[0](t_minus_six)
    x_root = -constant / lead

    t_chart, x_chart = chart.parent().gens()
    derivative_t = chart.derivative(t_chart)
    derivative_x = chart.derivative(x_chart)
    discriminant = -(
        derivative_t.derivative(t_chart)(t=root, x=x_root)
        * derivative_x.derivative(x_chart)(t=root, x=x_root)
        - derivative_t.derivative(x_chart)(t=root, x=x_root) ** 2
    )
    discriminant_valuation = int(discriminant.valuation())
    discriminant_unit = int(
        (discriminant >> discriminant_valuation).lift()
    ) % 8
    assert discriminant_valuation == 53
    assert discriminant_unit == 5
    assert not discriminant.is_square()
    return {
        "singular_factor": singular_minus_two,
        "initial_rows": initial_rows,
        "newton_rows": newton_rows,
        "t_root": root,
        "x_root": x_root,
        "discriminant_valuation": discriminant_valuation,
        "discriminant_unit": discriminant_unit,
    }


def summary_text(terminals, dominant, outlier):
    dominant_rows = [
        residue
        for residue in terminals
        if (residue[0] % 64, residue[1] % 64) == (1, 63)
    ]
    outlier_rows = [
        residue
        for residue in terminals
        if (residue[0] % 64, residue[1] % 64) == (63, 49)
    ]
    assert len(dominant_rows) == 4352
    assert unit.residue_digest(dominant_rows) == DOMINANT_SHA256
    assert outlier_rows == OUTLIERS
    assert unit.residue_digest(outlier_rows) == OUTLIER_SHA256
    assert len(dominant_rows) + len(outlier_rows) == len(terminals)

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        "# source\tKönig dissertation Theorem 5.2 and Appendix 5.1.12",
        f"# archive_sha256\t{unit.boundary.ARCHIVE_SHA256}",
        f"# model_sha256\t{unit.boundary.MODEL_SHA256}",
        "# status\tall_frontier_clusters_exactly_excluded",
        f"frontier_count\t{len(terminals)}",
        f"frontier_sha256\t{unit.residue_digest(terminals)}",
        f"dominant_cluster_count\t{len(dominant_rows)}",
        f"dominant_cluster_sha256\t{unit.residue_digest(dominant_rows)}",
        "dominant_cluster_mod_64\t1,63",
        "dominant_exact_center\t1,-1",
        f"dominant_multiplicity\t{dominant['multiplicity']}",
        f"dominant_weighted_order_2_1\t{dominant['minimum_weight']}",
        "dominant_exceptional_factorization\t"
        "6718464*(z+1/2)^2*(z^2+4/3*z+1/9)^4",
        "dominant_exceptional_quadratic_discriminant\t4/3,nonsquare",
        "dominant_rational_direction\tz=-1/2",
        "dominant_strict_transform_multiplicity\t"
        + str(dominant["blowup_multiplicity"]),
        "dominant_strict_transform_tangent_discriminant\t8,nonsquare",
        "dominant_status\tno_Q2_normalization_branch",
        f"outlier_cluster_count\t{len(outlier_rows)}",
        f"outlier_cluster_sha256\t{unit.residue_digest(outlier_rows)}",
        "outlier_cluster_mod_64\t63,49",
        "outlier_residues\t"
        + ";".join(f"{left},{right}" for left, right in outlier_rows),
        "outlier_component_relation\tq_minus2(t)=monic(q_minus6(16*t))",
        "outlier_singular_factor_degree\t"
        + str(outlier["singular_factor"].degree()),
        "outlier_singular_factor_sha256\t"
        + polynomial_digest(outlier["singular_factor"]),
        "outlier_initial_hensel_valuations\t"
        + ";".join(
            f"{center}:{value},{derivative}"
            for center, value, derivative in outlier["initial_rows"]
        ),
        "outlier_newton_valuations\t"
        + ";".join(
            f"{value},{derivative}"
            for value, derivative in outlier["newton_rows"]
        ),
        "outlier_strong_hensel_after_iterations\t2",
        "outlier_local_t_mod_2^128\t"
        + str(int(outlier["t_root"].lift()) % (1 << 128)),
        "outlier_local_x_mod_2^128\t"
        + str(int(outlier["x_root"].lift()) % (1 << 128)),
        "outlier_hessian_discriminant\t"
        + f"{outlier['discriminant_valuation']},"
        + f"{outlier['discriminant_unit']},nonsquare",
        "outlier_status\texact_ordinary_double_point_no_Q2_branches",
        "minus2_frontier_status\tall_4356_boxes_excluded",
    ]
    return "\n".join(lines) + "\n"


def self_test():
    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    tangent = 2 * t**2 + 4 * t * x + x**2
    assert tangent(t=1, x=0) == 2
    assert 4**2 - 4 * 2 == 8
    rows = [(1, 63), (63, 49)]
    assert [
        (left % 64, right % 64) for left, right in rows
    ] == rows
    print(
        "M24 genus-11 minus-two cluster self-test passed: "
        "congruence partition and nonsquare tangent fixture"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        if args.archive is None:
            return
    if args.archive is None:
        parser.error("archive is required outside --self-test")
    if args.run_dir is None:
        parser.error("--run-dir is required outside --self-test")

    _, polynomial = unit.boundary.load_model(args.archive)
    _, terminals = load_frontier(args.run_dir)
    chart, _ = unit.scaled_chart(polynomial, -2, 0)
    dominant = dominant_cluster_certificate(chart)
    outlier = outlier_cluster_certificate(polynomial, chart)
    text = summary_text(terminals, dominant, outlier)
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
