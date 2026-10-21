#!/usr/bin/env sage
"""Deep canonical residue-box audits for two M24 genus-11 unit charts."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import subprocess
from importlib.machinery import SourceFileLoader
from pathlib import Path

from sage.all import Matrix, Qp, QQ, valuation
from sage.env import SAGE_VERSION


SCHEMA = "m23-m24-genus11-unit-chart-gate-v1"
DEFAULT_MINUS_SIX_DEPTH = 25
DEFAULT_MINUS_TWO_DEPTH = 13


def load_boundary_module():
    path = Path(__file__).with_name(
        "audit_m24_genus11_boundary.sage"
    )
    loader = SourceFileLoader("m24_genus11_boundary", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


boundary = load_boundary_module()


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def scaled_chart(polynomial, t_valuation, x_valuation):
    ring = polynomial.parent()
    t, x = ring.gens()
    chart = ring(
        polynomial(
            t=(QQ(2) ** t_valuation) * t,
            x=(QQ(2) ** x_valuation) * x,
        )
    )
    minimum = min(
        valuation(coefficient, 2)
        for coefficient in chart.coefficients()
    )
    chart = ring(chart * (QQ(2) ** (-minimum)))
    assert all(
        coefficient.denominator() == 1
        for coefficient in chart.coefficients()
    )
    return chart, minimum


def canonical_unit_audit(polynomial, t_valuation, x_valuation, depth):
    ring = polynomial.parent()
    t, x = ring.gens()
    global_chart, scale_minimum = scaled_chart(
        polynomial,
        t_valuation,
        x_valuation,
    )
    assert int(global_chart(t=1, x=1)) % 2 == 0
    initial = global_chart(t=1 + 2 * t, x=1 + 2 * x)
    initial, _ = boundary.normalize_two_adic(initial)
    active = {(1, 1): initial}
    levels = []
    simple = []
    for level in range(depth):
        next_active = {}
        dead = 0
        scale = 1 << (level + 1)
        for (t_residue, x_residue), chart in active.items():
            derivative_t = chart.derivative(t)
            derivative_x = chart.derivative(x)
            roots = []
            for t_bit in (0, 1):
                for x_bit in (0, 1):
                    if int(chart(t=t_bit, x=x_bit)) % 2:
                        continue
                    gradient = (
                        int(derivative_t(t=t_bit, x=x_bit)) % 2,
                        int(derivative_x(t=t_bit, x=x_bit)) % 2,
                    )
                    roots.append((t_bit, x_bit, gradient))
            if not roots:
                dead += 1
            for t_bit, x_bit, gradient in roots:
                residue = (
                    t_residue + t_bit * scale,
                    x_residue + x_bit * scale,
                )
                if gradient != (0, 0):
                    simple.append((level, residue, gradient))
                    continue
                child = chart(
                    t=t_bit + 2 * t,
                    x=x_bit + 2 * x,
                )
                child, _ = boundary.normalize_two_adic(child)
                assert residue not in next_active
                next_active[residue] = child
        levels.append(
            {
                "level": level,
                "input": len(active),
                "dead": dead,
                "simple_total": len(simple),
                "unresolved": len(next_active),
            }
        )
        active = next_active
        if simple or not active:
            break

    modulus = 1 << (len(levels) + 1)
    residues = sorted(active)
    for residue, chart in active.items():
        direct = global_chart(
            t=residue[0] + modulus * t,
            x=residue[1] + modulus * x,
        )
        direct, _ = boundary.normalize_two_adic(direct)
        assert direct == chart
    return {
        "global_chart": global_chart,
        "scale_minimum": scale_minimum,
        "levels": levels,
        "simple": simple,
        "modulus": modulus,
        "residues": residues,
        "active": active,
    }


def residue_digest(residues):
    payload = "".join(
        f"{left},{right}\n" for left, right in residues
    ).encode("ascii")
    return hashlib.sha256(payload).hexdigest()


def strong_hensel_witnesses(chart, residues):
    t, x = chart.parent().gens()
    derivative_t = chart.derivative(t)
    derivative_x = chart.derivative(x)
    witnesses = []
    for left, right in residues:
        value_valuation = valuation(chart(t=left, x=right), 2)
        derivative_valuations = (
            valuation(derivative_t(t=left, x=right), 2),
            valuation(derivative_x(t=left, x=right), 2),
        )
        if value_valuation > 2 * min(derivative_valuations):
            witnesses.append(
                (
                    (left, right),
                    value_valuation,
                    derivative_valuations,
                )
            )
    return witnesses


def hessian_square_classes(chart, residues):
    t, x = chart.parent().gens()
    derivative_t = chart.derivative(t)
    derivative_x = chart.derivative(x)
    discriminant = -(
        derivative_t.derivative(t) * derivative_x.derivative(x)
        - derivative_t.derivative(x) ** 2
    )
    result = set()
    for left, right in residues:
        value = discriminant(t=left, x=right)
        exponent = valuation(value, 2)
        unit = int(value / (QQ(2) ** exponent)) % 8
        result.add((exponent, unit))
    return sorted(result)


def critical_newton_probe(chart, residues, precision=200):
    ring = chart.parent()
    t, x = ring.gens()
    derivative_t = chart.derivative(t)
    derivative_x = chart.derivative(x)
    derivative_tt = derivative_t.derivative(t)
    derivative_tx = derivative_t.derivative(x)
    derivative_xx = derivative_x.derivative(x)
    field = Qp(2, precision)

    def evaluate(poly, left, right):
        return field(poly(t=left, x=right))

    results = []
    for center in residues:
        left, right = field(center[0]), field(center[1])
        for _ in range(8):
            gradient = Matrix(
                field,
                2,
                1,
                [
                    evaluate(derivative_t, left, right),
                    evaluate(derivative_x, left, right),
                ],
            )
            hessian = Matrix(
                field,
                2,
                2,
                [
                    evaluate(derivative_tt, left, right),
                    evaluate(derivative_tx, left, right),
                    evaluate(derivative_tx, left, right),
                    evaluate(derivative_xx, left, right),
                ],
            )
            correction = hessian.solve_right(gradient)
            left -= correction[0, 0]
            right -= correction[1, 0]
        hessian = Matrix(
            field,
            2,
            2,
            [
                evaluate(derivative_tt, left, right),
                evaluate(derivative_tx, left, right),
                evaluate(derivative_tx, left, right),
                evaluate(derivative_xx, left, right),
            ],
        )
        discriminant = -hessian.det()
        unit = discriminant >> discriminant.valuation()
        results.append(
            {
                "key": (
                    int(left.lift()) % (1 << 128),
                    int(right.lift()) % (1 << 128),
                ),
                "value_valuation": evaluate(chart, left, right).valuation(),
                "gradient_valuations": (
                    evaluate(derivative_t, left, right).valuation(),
                    evaluate(derivative_x, left, right).valuation(),
                ),
                "discriminant_valuation": discriminant.valuation(),
                "discriminant_unit_mod8": int(unit.lift()) % 8,
                "discriminant_square": discriminant.is_square(),
            }
        )
    return results


def self_test():
    ring = boundary.PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    result = canonical_unit_audit(t + x, 0, 0, 3)
    assert result["simple"]
    assert not result["residues"]

    result = canonical_unit_audit((t - 1) ** 2, 0, 0, 3)
    assert not result["simple"]
    assert result["residues"]
    assert residue_digest(result["residues"])
    print(
        "M24 genus-11 unit-chart audit self-test passed: canonical "
        "residue reconstruction, simple detection, and digest fixtures"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
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

    _, polynomial = boundary.load_model(args.archive)
    minus_six = canonical_unit_audit(
        polynomial,
        -6,
        0,
        DEFAULT_MINUS_SIX_DEPTH,
    )
    minus_two = canonical_unit_audit(
        polynomial,
        -2,
        0,
        DEFAULT_MINUS_TWO_DEPTH,
    )

    assert not minus_six["simple"]
    assert not minus_two["simple"]
    assert len(minus_six["residues"]) == 16
    assert len(minus_two["residues"]) == 580

    minus_six_hensel = strong_hensel_witnesses(
        minus_six["global_chart"],
        minus_six["residues"],
    )
    minus_two_hensel = strong_hensel_witnesses(
        minus_two["global_chart"],
        minus_two["residues"],
    )
    assert not minus_six_hensel
    assert not minus_two_hensel

    minus_six_square_classes = hessian_square_classes(
        minus_six["global_chart"],
        minus_six["residues"],
    )
    assert minus_six_square_classes == [(8, 7)]
    critical = critical_newton_probe(
        minus_six["global_chart"],
        minus_six["residues"],
    )
    assert len({result["key"] for result in critical}) == 1
    assert {
        (
            result["discriminant_valuation"],
            result["discriminant_unit_mod8"],
            result["discriminant_square"],
        )
        for result in critical
    } == {(8, 7, False)}

    selected = (897, 335)
    assert selected in canonical_unit_audit(
        polynomial,
        -2,
        0,
        11,
    )["residues"]
    # The next full level is already contained in the depth-13 audit.
    assert all(
        not (
            left % 4096 == selected[0]
            and right % 4096 == selected[1]
        )
        for left, right in minus_two["residues"]
    )

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        "# source\tKönig dissertation Theorem 5.2 and Appendix 5.1.12",
        f"# archive_sha256\t{boundary.ARCHIVE_SHA256}",
        f"# model_sha256\t{boundary.MODEL_SHA256}",
        "# status\tdeep_unit_charts_unresolved",
        "minus6_levels\t"
        + ",".join(
            str(level["unresolved"])
            for level in minus_six["levels"]
        ),
        f"minus6_modulus\t{minus_six['modulus']}",
        f"minus6_terminal_count\t{len(minus_six['residues'])}",
        "minus6_terminal_sha256\t"
        + residue_digest(minus_six["residues"]),
        "minus6_simple_count\t0",
        "minus6_strong_hensel_count\t0",
        "minus6_terminal_hessian_square_classes\t"
        + ";".join(
            f"{exponent},{unit}"
            for exponent, unit in minus_six_square_classes
        ),
        "minus6_critical_probe_cluster_count\t1",
        "minus6_critical_probe_min_value_v2\t"
        + str(min(result["value_valuation"] for result in critical)),
        "minus6_critical_probe_min_gradient_v2\t"
        + str(
            min(
                min(result["gradient_valuations"])
                for result in critical
            )
        ),
        "minus6_critical_probe_discriminant\t8,7,nonsquare",
        "minus6_critical_probe_status\t"
        "bounded_200_bit_not_exact_singular_ideal_certificate",
        "minus2_levels\t"
        + ",".join(
            str(level["unresolved"])
            for level in minus_two["levels"]
        ),
        f"minus2_modulus\t{minus_two['modulus']}",
        f"minus2_terminal_count\t{len(minus_two['residues'])}",
        "minus2_terminal_sha256\t"
        + residue_digest(minus_two["residues"]),
        "minus2_simple_count\t0",
        "minus2_strong_hensel_count\t0",
        "minus2_false_square_candidate\t897,335:dead_by_modulus_16384",
    ]
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
