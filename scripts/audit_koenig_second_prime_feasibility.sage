#!/usr/bin/env sage
"""Audit currently available routes to a second-prime König cover anchor."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
import zipfile
from pathlib import Path

from sage.all import (
    ComplexField,
    GF,
    PolynomialRing,
    QQ,
    RealField,
    binomial,
    matrix,
    vector,
)
from sage.env import SAGE_VERSION


SCHEMA = "m23-koenig-second-prime-feasibility-v1"
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)
APPROXIMATION = (
    "Polynomials And Approximation Data/M23_(2,2,3,5)/"
    "m23_(2,2,3,5)_approx.txt"
)
CANDIDATE_PRIMES = (11, 13, 17)
BASE_CENTER = 4
TARGET_CENTERS = (5, 6, 8, 10)
PRECISION_BITS = 700
DENOMINATOR_BOUND_DIGITS = 80
ACCEPT_RELATIVE_DIGITS = 160
RANK_PRIME = 1_000_003
RESIDUAL_PRIME = 1_000_000_009
REPORTED_BOUNDARY_POINTS = (
    (QQ(31) / 18, QQ(0)),
    (QQ(5) / 9, QQ(2) / 3),
    (QQ(35) / 9, QQ(2) / 3),
    (QQ(410) / 9, QQ(2) / 3),
    (QQ(295) / 288, -QQ(11) / 96),
)


def load_module(name, filename):
    path = Path(__file__).with_name(filename)
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError(f"could not load {filename}")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def plane_census(relation):
    rows = []
    for prime in CANDIDATE_PRIMES:
        field = GF(prime)
        reduced = relation.change_ring(field)
        alpha, beta = reduced.parent().gens()
        derivative_alpha = reduced.derivative(alpha)
        derivative_beta = reduced.derivative(beta)
        points = [
            (left, right)
            for left in field
            for right in field
            if reduced(left, right) == 0
        ]
        smooth = [
            point
            for point in points
            if derivative_alpha(*point) != 0
            or derivative_beta(*point) != 0
        ]
        reported_boundary = {
            (field(left), field(right))
            for left, right in REPORTED_BOUNDARY_POINTS
        }
        smooth_reported_boundary = set(smooth) & reported_boundary
        smooth_other = sorted(
            (int(left), int(right))
            for left, right in smooth
            if (left, right) not in reported_boundary
        )
        assert smooth_other
        rows.append(
            {
                "prime": prime,
                "affine": len(points),
                "smooth": len(smooth),
                "smooth_reported_boundary": len(smooth_reported_boundary),
                "smooth_other": len(smooth_other),
                "selected": smooth_other[0],
            }
        )
    return rows


def numerical_polynomial(alphas, center, complex_field):
    ring = PolynomialRing(complex_field, "z")
    z = ring.gen()
    polynomials = [z - 1 / (alpha - center) for alpha in alphas]
    while len(polynomials) > 1:
        polynomials = [
            (
                polynomials[index] * polynomials[index + 1]
                if index + 1 < len(polynomials)
                else polynomials[index]
            )
            for index in range(0, len(polynomials), 2)
        ]
    polynomial = polynomials[0]
    pivot = max(range(len(polynomial)), key=lambda index: abs(polynomial[index]))
    normalized = [
        coefficient / polynomial[pivot] for coefficient in polynomial
    ]
    return pivot, normalized


def rational_mask(coefficients, real_field):
    bound = 10**DENOMINATOR_BOUND_DIGITS
    tolerance = real_field(10) ** (-ACCEPT_RELATIVE_DIGITS)
    rationals = []
    accepted = []
    for coefficient in coefficients:
        rational = coefficient.real().nearby_rational(
            max_denominator=bound
        )
        scale = max(real_field(1), abs(coefficient.real()))
        error = abs(coefficient.real() - real_field(rational)) / scale
        rationals.append(rational)
        accepted.append(error < tolerance)
    return rationals, accepted


def cross_chart_gate(alphas):
    real_field = RealField(PRECISION_BITS)
    complex_field = ComplexField(PRECISION_BITS)
    base_pivot, base_coefficients = numerical_polynomial(
        alphas, BASE_CENTER, complex_field
    )
    base_rationals, base_mask = rational_mask(
        base_coefficients, real_field
    )
    targets = []
    for center in TARGET_CENTERS:
        pivot, coefficients = numerical_polynomial(
            alphas, center, complex_field
        )
        rationals, accepted = rational_mask(coefficients, real_field)
        targets.append(
            {
                "center": center,
                "pivot": pivot,
                "rationals": rationals,
                "accepted": accepted,
            }
        )

    unknown = [
        index for index, accepted in enumerate(base_mask) if not accepted
    ]
    unknown_columns = {
        index: column for column, index in enumerate(unknown)
    }
    scale_columns = {
        target["center"]: len(unknown) + index
        for index, target in enumerate(targets)
    }
    rows = []
    right = []
    degree = len(alphas)
    for target in targets:
        shift = target["center"] - BASE_CENTER
        for exponent, accepted in enumerate(target["accepted"]):
            if not accepted:
                continue
            row = [QQ(0)] * (len(unknown) + len(targets))
            known = QQ(0)
            for source_exponent in range(exponent + 1):
                coefficient = (
                    binomial(
                        degree - source_exponent,
                        exponent - source_exponent,
                    )
                    * shift ** (exponent - source_exponent)
                )
                if source_exponent in unknown_columns:
                    row[unknown_columns[source_exponent]] += coefficient
                else:
                    known += (
                        base_rationals[source_exponent] * coefficient
                    )
            row[scale_columns[target["center"]]] -= target["rationals"][
                exponent
            ]
            rows.append(row)
            right.append(-known)

    system = matrix(QQ, rows)
    target_vector = vector(QQ, right)
    rank_field = GF(RANK_PRIME)
    modular_rank_system = system.change_ring(rank_field)
    independent_rows = modular_rank_system.transpose().pivots()
    rank = len(independent_rows)
    assert rank == system.ncols()

    residual_field = GF(RESIDUAL_PRIME)
    square = system.matrix_from_rows(independent_rows).change_ring(
        residual_field
    )
    square_target = vector(
        residual_field,
        [target_vector[index] for index in independent_rows],
    )
    assert square.rank() == square.ncols()
    solution = square.solve_right(square_target)
    residual = (
        system.change_ring(residual_field) * solution
        - target_vector.change_ring(residual_field)
    )
    nonzero_residuals = sum(entry != 0 for entry in residual)
    assert nonzero_residuals > 0
    return {
        "base_pivot": base_pivot,
        "base_accepted": sum(base_mask),
        "targets": targets,
        "unknowns": len(unknown),
        "equations": system.nrows(),
        "columns": system.ncols(),
        "rank": rank,
        "nonzero_residuals": nonzero_residuals,
    }


def parse_benchmark(path):
    values = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        key, value = line.split("\t", 1)
        values[key] = value
    required = {
        "wall_limit_seconds",
        "threads",
        "msolve_version",
        "input_sha256",
        "exit_status",
        "outcome",
        "maximum_rss_kib",
        "highest_f4_degree",
        "maximum_f4_rows",
        "maximum_f4_columns",
    }
    if set(values) != required:
        raise ValueError("unexpected benchmark summary fields")
    return values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--benchmark-summary", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()
    if sha256(args.archive) != ARCHIVE_SHA256:
        raise ValueError("archive SHA-256 mismatch")

    verifier = load_module(
        "koenig_curve_second_prime_audit",
        "verify_koenig_hurwitz_curve.sage",
    )
    _, _, _, relation = verifier.load_polynomial(args.archive)
    plane_rows = plane_census(relation)

    component = load_module(
        "koenig_component_second_prime_audit",
        "audit_koenig_component_map.sage",
    )
    with zipfile.ZipFile(args.archive) as archive:
        source = archive.read(APPROXIMATION).decode("ascii")
    real_field = RealField(PRECISION_BITS)
    complex_field = ComplexField(PRECISION_BITS)
    entries = component.extract_entries(source)
    assert len(entries) == 980
    alphas = [
        component.parse_entry(entry, real_field, complex_field)[21]
        for entry in entries
    ]
    cross = cross_chart_gate(alphas)

    exporter = load_module(
        "koenig_second_prime_exporter_for_audit",
        "export_koenig_second_prime_msolve.sage",
    )
    selected = plane_rows[0]["selected"]
    ring, _, equations = exporter.fixed_system(
        11,
        selected[0],
        selected[1],
        1,
        "scaled",
    )
    input_text = exporter.msolve_text(ring, equations)
    input_hash = hashlib.sha256(input_text.encode()).hexdigest()
    benchmark = parse_benchmark(args.benchmark_summary)
    assert benchmark["input_sha256"] == input_hash

    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# archive_sha256\t{ARCHIVE_SHA256}",
        f"# sage_version\t{SAGE_VERSION}",
        "# status\tplane_points_exist_but_no_certified_second_prime_cover_seed",
        "# candidate_primes\t" + ",".join(map(str, CANDIDATE_PRIMES)),
        f"# numerical_fiber_vectors\t{len(alphas)}",
        f"# numerical_precision_bits\t{PRECISION_BITS}",
        f"# mobius_base_center\t{BASE_CENTER}",
        "# mobius_target_centers\t"
        + ",".join(map(str, TARGET_CENTERS)),
        f"# rational_denominator_bound_digits\t{DENOMINATOR_BOUND_DIGITS}",
        f"# rational_accept_relative_digits\t{ACCEPT_RELATIVE_DIGITS}",
        f"# base_chart_pivot\t{cross['base_pivot']}",
        f"# base_chart_accepted_coefficients\t{cross['base_accepted']}",
        "# target_chart_accepted_coefficients\t"
        + ",".join(
            f"{target['center']}:{sum(target['accepted'])}"
            for target in cross["targets"]
        ),
        f"# cross_chart_unknowns\t{cross['unknowns']}",
        f"# cross_chart_equations\t{cross['equations']}",
        f"# cross_chart_columns\t{cross['columns']}",
        f"# cross_chart_rank_mod{RANK_PRIME}\t{cross['rank']}",
        f"# cross_chart_nonzero_residuals_mod{RESIDUAL_PRIME}\t"
        f"{cross['nonzero_residuals']}",
        "# numerical_fiber_exactly_reconstructed\t0",
        f"# solver_input_sha256\t{input_hash}",
        f"# solver_variables\t{ring.ngens()}",
        f"# solver_equations\t{len(equations)}",
        f"# solver_terms\t"
        f"{sum(len(equation.dict()) for equation in equations)}",
        f"# solver_max_degree\t"
        f"{max(equation.total_degree() for equation in equations)}",
    ]
    lines.extend(
        f"# benchmark_{key}\t{value}"
        for key, value in benchmark.items()
    )
    lines.append(
        "prime\taffine_points\tsmooth_points\tsmooth_boundary_points\t"
        "smooth_nonboundary_points\tselected_alpha\tselected_beta"
    )
    lines.extend(
        f"{row['prime']}\t{row['affine']}\t{row['smooth']}\t"
        f"{row['smooth_reported_boundary']}\t{row['smooth_other']}\t"
        f"{row['selected'][0]}\t{row['selected'][1]}"
        for row in plane_rows
    )
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.check_summary is not None:
        # The v1 column labels are retained for certificate compatibility:
        # "boundary" means only reductions of the five reported points.
        # Wall-clock termination and the last matrix reached are host
        # observations, not deterministic mathematical certificate fields.
        ignored_prefixes = (
            "# code_revision\t",
            "# benchmark_exit_status\t",
            "# benchmark_outcome\t",
            "# benchmark_maximum_rss_kib\t",
            "# benchmark_highest_f4_degree\t",
            "# benchmark_maximum_f4_rows\t",
            "# benchmark_maximum_f4_columns\t",
        )
        expected = [
            line
            for line in args.check_summary.read_text().splitlines()
            if not line.startswith(ignored_prefixes)
        ]
        actual = [
            line
            for line in text.splitlines()
            if not line.startswith(ignored_prefixes)
        ]
        assert actual == expected
    print(text, end="")


if __name__ == "__main__":
    main()
