#!/usr/bin/env sage
"""Authenticate and probe König's exact M24 genus-11 Hurwitz model."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import zipfile
from pathlib import Path

import numpy as np
from sage.all import PolynomialRing, QQ, gcd, sage_eval, valuation
from sage.env import SAGE_VERSION


SCHEMA = "m23-m24-genus11-model-two-adic-gate-v1"
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)
MODEL_MEMBER = (
    "Polynomials And Approximation Data/M24_(2,2,2,8)/"
    "m24_(2,2,2,8)_hurwitz_equation.txt"
)
MODEL_SHA256 = (
    "8fc3f13944653c89e0de309632f5f11aaccd18aaed41cbf794db036fd57d31a2"
)


def sha256_path(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def load_model(archive):
    if sha256_path(archive) != ARCHIVE_SHA256:
        raise ValueError("unexpected König archive SHA-256")
    with zipfile.ZipFile(archive) as source:
        raw = source.read(MODEL_MEMBER)
    if hashlib.sha256(raw).hexdigest() != MODEL_SHA256:
        raise ValueError("unexpected M24 model SHA-256")
    text = raw.decode("ascii")
    expression = text.split("f:=", 1)[1].split(";\nc:=", 1)[0]
    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    polynomial = ring(
        sage_eval(
            f"({expression.replace('^', '**')})",
            locals={"t": t, "x": x},
        )
    )
    return ring, polynomial


def residue_grid(polynomial, exponent):
    modulus = 1 << exponent
    residues = np.arange(modulus, dtype=np.int64)
    coefficients = np.zeros(
        (
            polynomial.degree(polynomial.parent().gen(0)) + 1,
            polynomial.degree(polynomial.parent().gen(1)) + 1,
        ),
        dtype=np.int64,
    )
    for monomial, coefficient in polynomial.dict().items():
        coefficients[tuple(monomial)] = int(coefficient) % modulus
    in_x = np.zeros((coefficients.shape[0], modulus), dtype=np.int64)
    for t_degree in range(coefficients.shape[0]):
        value = np.zeros(modulus, dtype=np.int64)
        for x_degree in range(coefficients.shape[1] - 1, -1, -1):
            value = (
                value * residues + coefficients[t_degree, x_degree]
            ) % modulus
        in_x[t_degree] = value
    values = np.zeros((modulus, modulus), dtype=np.int64)
    for t_degree in range(coefficients.shape[0] - 1, -1, -1):
        values = (
            values * residues[:, np.newaxis]
            + in_x[t_degree][np.newaxis, :]
        ) % modulus
    locations = np.argwhere(values == 0)
    return len(locations), [
        (int(t_value), int(x_value))
        for t_value, x_value in locations[:16]
    ]


def lift_residue_pair_counts(polynomial, depth):
    counts = []
    sample = []
    for exponent in range(1, depth + 1):
        count, sample = residue_grid(polynomial, exponent)
        counts.append((exponent, count))
    return counts, sample


def normalize_two_adic(polynomial):
    content = gcd([int(value) for value in polynomial.coefficients()])
    exponent = valuation(content, 2)
    return polynomial.parent()(polynomial / (2**exponent)), exponent


def two_adic_chart_audit(polynomial, depth):
    ring = polynomial.parent()
    t, x = ring.gens()
    active = [("", polynomial)]
    levels = []
    simple = []
    for level in range(depth + 1):
        next_active = []
        dead = 0
        contents = []
        for path, chart in active:
            derivative_t = chart.derivative(t)
            derivative_x = chart.derivative(x)
            roots = []
            for t_value in (0, 1):
                for x_value in (0, 1):
                    value = int(chart(t=t_value, x=x_value)) % 2
                    if value != 0:
                        continue
                    gradient = (
                        int(derivative_t(t=t_value, x=x_value)) % 2,
                        int(derivative_x(t=t_value, x=x_value)) % 2,
                    )
                    roots.append((t_value, x_value, gradient))
            if not roots:
                dead += 1
                continue
            for t_value, x_value, gradient in roots:
                child_path = (
                    f"{path};{t_value},{x_value}"
                    if path
                    else f"{t_value},{x_value}"
                )
                if gradient != (0, 0):
                    simple.append((level, child_path, gradient))
                    continue
                if level == depth:
                    next_active.append((child_path, chart))
                    continue
                child = chart(
                    t=t_value + 2 * t,
                    x=x_value + 2 * x,
                )
                child, content_exponent = normalize_two_adic(child)
                contents.append(content_exponent)
                next_active.append((child_path, child))
        levels.append(
            {
                "level": level,
                "input_charts": len(active),
                "dead_charts": dead,
                "simple_roots_total": len(simple),
                "singular_children": len(next_active),
                "content_min": min(contents) if contents else None,
                "content_max": max(contents) if contents else None,
            }
        )
        active = next_active
        if not active:
            break
    return levels, simple, [path for path, _ in active]


def decode_chart_path(path):
    t_value = 0
    x_value = 0
    pairs = path.split(";")
    for exponent, pair in enumerate(pairs):
        t_bit, x_bit = (int(value) for value in pair.split(","))
        t_value += t_bit << exponent
        x_value += x_bit << exponent
    return len(pairs), t_value, x_value


def self_test():
    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    levels, simple, unresolved = two_adic_chart_audit(x, 2)
    assert levels[0]["simple_roots_total"] == 2
    assert len(simple) == 2
    assert not unresolved

    levels, simple, unresolved = two_adic_chart_audit(
        x**2 + x + 1,
        2,
    )
    assert levels[0]["dead_charts"] == 1
    assert not simple
    assert not unresolved

    levels, simple, unresolved = two_adic_chart_audit(x**2, 2)
    assert [level["singular_children"] for level in levels] == [2, 4, 8]
    assert not simple
    assert len(unresolved) == 8

    for exponent in range(1, 5):
        modulus = 1 << exponent
        expected = sum(
            (t_value + x_value) % modulus == 0
            for t_value in range(modulus)
            for x_value in range(modulus)
        )
        actual, _ = residue_grid(t + x, exponent)
        assert actual == expected
    print(
        "M24 genus-11 model audit self-test passed: simple, dead, "
        "persistent-singular, and grid fixtures"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument("--two-adic-depth", type=int, default=0)
    parser.add_argument("--two-adic-chart-depth", type=int, default=0)
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
    if args.two_adic_depth < 0:
        parser.error("--two-adic-depth must be nonnegative")
    if args.two_adic_depth > 12:
        parser.error("--two-adic-depth is capped at 12")
    if args.two_adic_chart_depth < 0:
        parser.error("--two-adic-chart-depth must be nonnegative")
    if args.two_adic_chart_depth > 12:
        parser.error("--two-adic-chart-depth is capped at 12")

    ring, polynomial = load_model(args.archive)
    t, x = ring.gens()
    coefficients = [int(value) for value in polynomial.coefficients()]
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        "# source\tKönig dissertation Theorem 5.2 and Appendix 5.1.12",
        f"# archive_sha256\t{ARCHIVE_SHA256}",
        f"# model_member\t{MODEL_MEMBER}",
        f"# model_sha256\t{MODEL_SHA256}",
        "# status\tbounded_two_adic_affine_chart_gate_unresolved",
        f"terms\t{len(polynomial.dict())}",
        f"degree_t\t{polynomial.degree(t)}",
        f"degree_x\t{polynomial.degree(x)}",
        f"total_degree\t{polynomial.total_degree()}",
        f"content\t{gcd(coefficients)}",
        "model_mod2_values\t"
        + ";".join(
            f"{t_value},{x_value}:"
            f"{int(polynomial(t=t_value, x=x_value)) % 2}"
            for t_value in (0, 1)
            for x_value in (0, 1)
        ),
    ]
    for point in ((0, 0), (0, -2)):
        values = (
            polynomial(t=point[0], x=point[1]),
            polynomial.derivative(t)(t=point[0], x=point[1]),
            polynomial.derivative(x)(t=point[0], x=point[1]),
        )
        lines.append(
            f"point_{point[0]}_{point[1]}\t"
            f"{','.join(str(value) for value in values)}"
        )

    if args.two_adic_depth:
        raw_counts, _ = lift_residue_pair_counts(
            polynomial,
            args.two_adic_depth,
        )
        scaled = polynomial(t=t, x=2 * x)
        scaled_content = gcd(
            [int(value) for value in scaled.coefficients()]
        )
        scaled_content_valuation = valuation(scaled_content, 2)
        scaled_primitive = ring(
            scaled / (2**scaled_content_valuation)
        )
        scaled_derivative_t = scaled_primitive.derivative(t)
        scaled_derivative_x = scaled_primitive.derivative(x)
        scaled_mod2_points = []
        for t_value in (0, 1):
            for x_value in (0, 1):
                values = (
                    int(scaled_primitive(t=t_value, x=x_value)) % 2,
                    int(scaled_derivative_t(t=t_value, x=x_value)) % 2,
                    int(scaled_derivative_x(t=t_value, x=x_value)) % 2,
                )
                if values[0] == 0:
                    scaled_mod2_points.append(
                        (
                            t_value,
                            x_value,
                            values[1],
                            values[2],
                        )
                    )
        counts, residues = lift_residue_pair_counts(
            scaled_primitive,
            args.two_adic_depth,
        )
        lines.append(
            "two_adic_raw_integral_counts\t"
            + ",".join(
                f"{depth}:{count}" for depth, count in raw_counts
            )
        )
        lines.append(
            f"x_scaled_content_v2\t{scaled_content_valuation}"
        )
        lines.append(
            "x_scaled_mod2_points\t"
            + ";".join(
                f"{t_value},{x_value},{dt_value},{dx_value}"
                for (
                    t_value,
                    x_value,
                    dt_value,
                    dx_value,
                ) in scaled_mod2_points
            )
        )
        lines.append(
            "two_adic_x_scaled_integral_counts\t"
            + ",".join(f"{depth}:{count}" for depth, count in counts)
        )
        lines.append(
            "two_adic_x_scaled_integral_final_sample\t"
            + ";".join(
                f"{t_value},{x_value}"
                for t_value, x_value in residues[:16]
            )
        )
    if args.two_adic_chart_depth:
        levels, simple, unresolved = two_adic_chart_audit(
            polynomial,
            args.two_adic_chart_depth,
        )
        for level in levels:
            lines.append(
                "two_adic_chart_level_"
                f"{level['level']}\t"
                f"input:{level['input_charts']}"
                f",dead:{level['dead_charts']}"
                f",simple_total:{level['simple_roots_total']}"
                f",singular_children:{level['singular_children']}"
                ",content_v2:"
                + (
                    "terminal"
                    if level["content_min"] is None
                    else (
                        f"{level['content_min']}-"
                        f"{level['content_max']}"
                    )
                )
            )
        lines.append(
            "two_adic_simple_samples\t"
            + (
                ";".join(
                    f"{level}:{path}:{gradient[0]},{gradient[1]}"
                    for level, path, gradient in simple[:16]
                )
                or "none"
            )
        )
        lines.append(
            "two_adic_unresolved_residues\t"
            + ";".join(
                f"{exponent}:{t_value},{x_value}"
                for exponent, t_value, x_value in (
                    decode_chart_path(path) for path in unresolved
                )
            )
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
