#!/usr/bin/env sage
"""Audit singular branches and bounded nonintegral 2-adic charts."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import zipfile
from pathlib import Path

from sage.all import PolynomialRing, QQ, gcd, lcm, sage_eval, valuation
from sage.env import SAGE_VERSION


SCHEMA = "m23-m24-genus11-boundary-gate-v1"
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


def homogeneous_part(polynomial, degree):
    ring = polynomial.parent()
    t, x = ring.gens()
    return ring(
        sum(
            coefficient * t ** exponent[0] * x ** exponent[1]
            for exponent, coefficient in polynomial.dict().items()
            if sum(exponent) == degree
        )
    )


def multiplicity_at(polynomial, t_value, x_value):
    ring = polynomial.parent()
    t, x = ring.gens()
    translated = ring(
        polynomial(t=t_value + t, x=x_value + x)
    )
    degree = min(sum(exponent) for exponent in translated.dict())
    return translated, degree, homogeneous_part(translated, degree)


def lower_newton_hull(polynomial):
    points = [
        (exponent, valuation(coefficient, 2))
        for exponent, coefficient in enumerate(polynomial.list())
        if coefficient
    ]
    hull = []
    for point in points:
        while len(hull) >= 2:
            left, middle = hull[-2], hull[-1]
            old_slope = QQ(middle[1] - left[1]) / (
                middle[0] - left[0]
            )
            new_slope = QQ(point[1] - middle[1]) / (
                point[0] - middle[0]
            )
            if old_slope < new_slope:
                break
            hull.pop()
        hull.append(point)
    slopes = [
        QQ(right[1] - left[1]) / (right[0] - left[0])
        for left, right in zip(hull, hull[1:])
    ]
    return hull, slopes


def rational_mod(value, modulus):
    return (
        int(value.numerator())
        * pow(int(value.denominator()), -1, modulus)
    ) % modulus


def unit_root_counts(polynomial, root_valuation, depth):
    variable = polynomial.parent().gen()
    scaled = polynomial((QQ(2) ** root_valuation) * variable)
    minimum = min(
        valuation(coefficient, 2)
        for coefficient in scaled.list()
        if coefficient
    )
    scaled *= QQ(2) ** (-minimum)
    assert all(
        coefficient.denominator() % 2 == 1
        for coefficient in scaled.list()
    )

    def evaluate_mod(residue, modulus):
        value = 0
        for coefficient in reversed(scaled.list()):
            value = (
                value * residue + rational_mod(coefficient, modulus)
            ) % modulus
        return value

    active = [1]
    counts = []
    for exponent in range(1, depth + 1):
        modulus = 1 << exponent
        active = [
            residue + bit * (modulus // 2)
            for residue in active
            for bit in (0, 1)
            if evaluate_mod(
                residue + bit * (modulus // 2),
                modulus,
            )
            == 0
        ]
        counts.append(len(active))
        if not active:
            break
    return minimum, counts


def nonlinear_boundary_gates(polynomial):
    ring = polynomial.parent()
    t, x = ring.gens()
    x_leading = sum(
        coefficient * t ** exponent[0]
        for exponent, coefficient in polynomial.dict().items()
        if exponent[1] == polynomial.degree(x)
    ).univariate_polynomial()
    boundaries = (
        ("t_zero", polynomial(t=0).univariate_polynomial()),
        ("x_zero", polynomial(x=0).univariate_polynomial()),
        ("x_infinity", x_leading),
    )
    results = []
    for label, boundary in boundaries:
        signature = []
        for factor, multiplicity in boundary.factor():
            if factor.degree() <= 0:
                continue
            signature.append((factor.degree(), multiplicity))
            if factor.degree() == 1:
                continue
            hull, slopes = lower_newton_hull(factor)
            candidates = sorted(
                {
                    int(-slope)
                    for slope in slopes
                    if (-slope).denominator() == 1
                }
            )
            gates = [
                (
                    root_valuation,
                    *unit_root_counts(factor, root_valuation, 24),
                )
                for root_valuation in candidates
            ]
            results.append(
                {
                    "label": label,
                    "degree": factor.degree(),
                    "multiplicity": multiplicity,
                    "hull": hull,
                    "gates": gates,
                }
            )
        results.append(
            {
                "label": label,
                "signature": signature,
            }
        )
    return results


def normalize_two_adic(polynomial):
    content = gcd([int(value) for value in polynomial.coefficients()])
    exponent = valuation(content, 2)
    return polynomial.parent()(polynomial / (2**exponent)), exponent


def two_adic_chart_audit(polynomial, depth):
    ring = polynomial.parent()
    t, x = ring.gens()
    active = [polynomial]
    simple = 0
    levels = []
    for level in range(depth):
        next_active = []
        dead = 0
        for chart in active:
            derivative_t = chart.derivative(t)
            derivative_x = chart.derivative(x)
            roots = []
            for t_value in (0, 1):
                for x_value in (0, 1):
                    if int(chart(t=t_value, x=x_value)) % 2:
                        continue
                    gradient = (
                        int(derivative_t(t=t_value, x=x_value)) % 2,
                        int(derivative_x(t=t_value, x=x_value)) % 2,
                    )
                    roots.append((t_value, x_value, gradient))
            if not roots:
                dead += 1
            for t_value, x_value, gradient in roots:
                if gradient != (0, 0):
                    simple += 1
                    continue
                child = chart(
                    t=t_value + 2 * t,
                    x=x_value + 2 * x,
                )
                child, _ = normalize_two_adic(child)
                next_active.append(child)
        levels.append(
            {
                "level": level,
                "input": len(active),
                "dead": dead,
                "simple": simple,
                "unresolved": len(next_active),
            }
        )
        active = next_active
        if simple or not active:
            break
    status = "simple" if simple else ("unresolved" if active else "dead")
    return status, levels


def scaled_unit_chart(polynomial, t_valuation, x_valuation):
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
    if int(chart(t=1, x=1)) % 2:
        return "dead", [], 0
    gradient = (
        int(chart.derivative(t)(t=1, x=1)) % 2,
        int(chart.derivative(x)(t=1, x=1)) % 2,
    )
    if gradient != (0, 0):
        return "simple", [], 0
    child = chart(t=1 + 2 * t, x=1 + 2 * x)
    child, _ = normalize_two_adic(child)
    status, levels = two_adic_chart_audit(child, 8)
    unresolved = levels[-1]["unresolved"] if levels else 0
    return status, levels, unresolved


def tropical_candidates(polynomial):
    terms = [
        (
            exponent[0],
            exponent[1],
            valuation(coefficient, 2),
        )
        for exponent, coefficient in polynomial.dict().items()
    ]
    candidates = []
    for t_valuation in range(-40, 0):
        for x_valuation in range(-40, 13):
            values = [
                coefficient_valuation
                + t_degree * t_valuation
                + x_degree * x_valuation
                for t_degree, x_degree, coefficient_valuation in terms
            ]
            minimum = min(values)
            if sum(value == minimum for value in values) % 2 == 0:
                candidates.append((t_valuation, x_valuation))
    return candidates


def expected_tropical_candidates():
    diagonal = [
        pair
        for t_valuation in range(-40, -3, 2)
        for pair in (
            (t_valuation, t_valuation // 2 + 1),
            (t_valuation, t_valuation // 2 + 3),
        )
    ]
    t_minus_three = [(-3, value) for value in range(2, 13)]
    t_minus_two = [
        (-2, value)
        for value in list(range(-40, 1)) + list(range(3, 13))
    ]
    return diagonal + t_minus_three + t_minus_two


def format_pairs(pairs):
    return ";".join(f"{left},{right}" for left, right in pairs)


def self_test():
    ring = PolynomialRing(QQ, names=("z",))
    z = ring.gen()
    hull, slopes = lower_newton_hull(z**4 + 16 * z**3 + 512)
    assert hull == [(0, 9), (4, 0)]
    assert slopes == [QQ(-9) / 4]

    minimum, counts = unit_root_counts(z**2 + 1, 0, 8)
    assert minimum == 0
    assert counts == [1, 0]

    minimum, counts = unit_root_counts(z - 1, 0, 4)
    assert minimum == 0
    assert counts == [1, 1, 1, 1]

    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    status, levels = two_adic_chart_audit(x**2 + 1, 4)
    assert status == "dead"
    assert levels[-1]["unresolved"] == 0
    print(
        "M24 genus-11 boundary audit self-test passed: Newton hull, "
        "unit-root extinction/persistence, and chart extinction fixtures"
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

    ring, polynomial = load_model(args.archive)
    t, x = ring.gens()

    point_data = {}
    for point in ((0, 0), (0, -2), (QQ(1) / 4, 0)):
        point_data[point] = multiplicity_at(polynomial, *point)

    _, multiplicity_zero, tangent_zero = point_data[(0, 0)]
    tangent_factors = [
        factor
        for factor, _ in tangent_zero.factor()
        if factor.total_degree() > 0
    ]
    tangent_valuations = sorted(
        tuple(
            valuation(coefficient, 2)
            for coefficient in factor(t=1).univariate_polynomial().list()
        )
        for factor in tangent_factors
    )
    assert tangent_valuations == [
        (9, 8, 5, 4, 0),
        (9, 8, 5, 5, 0),
    ]

    _, multiplicity_minus_two, tangent_minus_two = point_data[(0, -2)]
    assert tangent_minus_two.monomial_coefficient(t**2)
    ratio = (
        -tangent_minus_two.monomial_coefficient(t**2)
        / tangent_minus_two.monomial_coefficient(x**2)
    )
    assert ratio == 8

    translated_quarter, multiplicity_quarter, _ = point_data[
        (QQ(1) / 4, 0)
    ]
    weight_four = ring(
        sum(
            coefficient * t ** exponent[0] * x ** exponent[1]
            for exponent, coefficient in translated_quarter.dict().items()
            if 2 * exponent[0] + exponent[1] == 4
        )
    )
    assert weight_four == 2**22 * t**2 + 2**8 * x**4

    boundary_results = nonlinear_boundary_gates(polynomial)
    signatures = {
        result["label"]: result["signature"]
        for result in boundary_results
        if "signature" in result
    }
    gates = [
        result
        for result in boundary_results
        if "gates" in result
    ]
    assert signatures == {
        "t_zero": [(1, 2), (1, 8), (2, 1), (6, 2)],
        "x_zero": [(1, 2), (1, 8), (10, 1), (12, 1)],
        "x_infinity": [(2, 2), (4, 4)],
    }
    assert all(
        counts and counts[-1] == 0
        for result in gates
        for _, _, counts in result["gates"]
    )

    candidates = tropical_candidates(polynomial)
    assert candidates == sorted(expected_tropical_candidates())
    audits = {}
    for candidate in candidates:
        audits[candidate] = scaled_unit_chart(polynomial, *candidate)
    simple = [
        candidate
        for candidate, (status, _, _) in audits.items()
        if status == "simple"
    ]
    dead = [
        candidate
        for candidate, (status, _, _) in audits.items()
        if status == "dead"
    ]
    unresolved = [
        candidate
        for candidate, (status, _, _) in audits.items()
        if status == "unresolved"
    ]
    terminal_histogram = {}
    for candidate in dead:
        levels = audits[candidate][1]
        level = levels[-1]["level"] if levels else -1
        terminal_histogram[level] = terminal_histogram.get(level, 0) + 1
    unresolved_counts = [
        (candidate, audits[candidate][2])
        for candidate in unresolved
    ]

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        "# source\tKönig dissertation Theorem 5.2 and Appendix 5.1.12",
        f"# archive_sha256\t{ARCHIVE_SHA256}",
        f"# model_member\t{MODEL_MEMBER}",
        f"# model_sha256\t{MODEL_SHA256}",
        "# status\texact_boundary_branches_excluded_bounded_nonintegral_gate_unresolved",
        f"point_0_0_multiplicity\t{multiplicity_zero}",
        "point_0_0_tangent_quartic_v2\t"
        + ";".join(
            ",".join(str(value) for value in row)
            for row in tangent_valuations
        ),
        "point_0_0_q2_branch_gate\t"
        "no_tangent_root_quartic_newton_slope_-9/4",
        f"point_0_-2_multiplicity\t{multiplicity_minus_two}",
        f"point_0_-2_tangent_ratio_x2_over_t2\t{ratio}",
        "point_0_-2_q2_branch_gate\t"
        "no_tangent_root_v2_8_is_3",
        f"point_1/4_0_multiplicity\t{multiplicity_quarter}",
        "point_1/4_0_weight_2_1_initial\t"
        "4194304*t^2+256*x^4",
        "point_1/4_0_q2_branch_gate\t"
        "no_second_order_root_(128c)^2=-1",
        "t_zero_factor_signature\t"
        + ",".join(
            f"{degree}^{multiplicity}"
            for degree, multiplicity in signatures["t_zero"]
        ),
        "x_zero_factor_signature\t"
        + ",".join(
            f"{degree}^{multiplicity}"
            for degree, multiplicity in signatures["x_zero"]
        ),
        "x_infinity_factor_signature\t"
        + ",".join(
            f"{degree}^{multiplicity}"
            for degree, multiplicity in signatures["x_infinity"]
        ),
        "t_infinity_finite_x_gate\tleading_t32_coefficient_nonzero_constant",
    ]
    for result in gates:
        for root_valuation, minimum, counts in result["gates"]:
            lines.append(
                f"{result['label']}_degree_{result['degree']}_root_gate\t"
                f"multiplicity:{result['multiplicity']}"
                f",valuation:{root_valuation}"
                f",scaled_minimum:{minimum}"
                ",unit_counts:"
                + ",".join(str(count) for count in counts)
            )
    lines.extend(
        [
            "tropical_window\tt:-40:-1,x:-40:12",
            f"tropical_candidate_count\t{len(candidates)}",
            f"tropical_dead_count_depth_8\t{len(dead)}",
            f"tropical_simple_count_depth_8\t{len(simple)}",
            f"tropical_unresolved_count_depth_8\t{len(unresolved)}",
            "tropical_dead_terminal_levels\t"
            + ",".join(
                f"{level}:{count}"
                for level, count in sorted(terminal_histogram.items())
            ),
            "tropical_unresolved_depth_8\t"
            + ";".join(
                f"{candidate[0]},{candidate[1]}:{count}"
                for candidate, count in unresolved_counts
            ),
        ]
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
