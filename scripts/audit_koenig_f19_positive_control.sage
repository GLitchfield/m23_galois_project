#!/usr/bin/env sage
"""Audit the bounded König F_19 solver positive-control gate."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
from pathlib import Path

from sage.all import GF, PolynomialRing
from sage.env import SAGE_VERSION


SCHEMA = "m23-koenig-f19-positive-control-v1"
BENCHMARK_SCHEMA = "m23-koenig-f19-positive-control-benchmark-v1"
EXPECTED_INPUT_SHA256 = (
    "e7d00cb330e140f57a987570cc396477a41b0d0317de8254858c96d1e5c5f3c9"
)
FACTOR_DEGREES = {
    "f1": 6,
    "f2": 5,
    "f3": 8,
    "f5": 8,
}
KNOWN = {
    "f1": (15, 5, 7, 7, 2, 14),
    "f2": (7, 15, 4, 18, 7),
    "f3": (18, 5, 1, 12, 12, 11, 6, 9),
    "f4": (17, 9, 8, 14, 1, 8, 12),
    "f5": (0, 8, 8, 0, 7, 6, 1, 1),
    "f6": (17, 15, 4, 18, 17, 11, 9),
    "g1": (6, 15),
    "g2": (2, 3),
}


def load_exporter():
    path = Path(__file__).with_name(
        "export_koenig_second_prime_msolve.sage"
    )
    loader = importlib.machinery.SourceFileLoader(
        "koenig_f19_positive_control_audit_exporter",
        str(path),
    )
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König msolve exporter")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def variable_name(spec):
    name, exponent = spec
    return name if name == "constant" else f"{name}_{exponent}"


def known_value(spec, scaled=False):
    name, exponent = spec
    if name == "constant":
        return 14
    if name in ("h4", "h6"):
        assert scaled
        return 14 * KNOWN[f"f{name[1:]}"][exponent]
    return KNOWN[name][exponent]


def known_solution_zeros(ring, specs, equations, scaled=False):
    field = ring.base_ring()
    values = {
        variable_name(spec): field(known_value(spec, scaled))
        for spec in specs
    }
    return sum(equation(**values) == 0 for equation in equations)


def remainder_presentations():
    field = GF(19)
    fixed = {
        ("f1", 5): field(14),
        ("f2", 4): field(7),
    }
    specs = []
    for name, degree in FACTOR_DEGREES.items():
        specs.extend((name, exponent) for exponent in range(degree))
    specs.extend(("g1", exponent) for exponent in range(2))
    specs.extend(("g2", exponent) for exponent in range(2))
    specs.append(("constant", 0))
    free_specs = [spec for spec in specs if spec not in fixed]
    ring = PolynomialRing(
        field,
        names=[variable_name(spec) for spec in free_specs],
        order="degrevlex",
    )
    values = dict(zip(free_specs, ring.gens()))
    values.update(fixed)
    y_ring = PolynomialRing(ring, "Y")
    Y = y_ring.gen()

    def monic_factor(name, degree):
        return Y**degree + sum(
            values[(name, exponent)] * Y**exponent
            for exponent in range(degree)
        )

    f1 = monic_factor("f1", 6)
    f2 = monic_factor("f2", 5)
    f3 = monic_factor("f3", 8)
    f5 = monic_factor("f5", 8)
    g1 = (
        Y**3
        + ring(field(1) / 3) * Y**2
        + values[("g1", 1)] * Y
        + values[("g1", 0)]
    )
    g2 = (
        Y**3
        - ring(field(1) / 2) * Y**2
        + values[("g2", 1)] * Y
        + values[("g2", 0)]
    )
    constant = values[("constant", 0)]
    F1 = f1**3 * f2
    denominator = g1**5 * g2
    quarter = ring(field(1) / 4)
    branch_label = ring(field(9))
    P3 = constant * F1 - (quarter + branch_label) * denominator
    P5 = constant * F1 + (branch_label - quarter) * denominator
    _, square_remainder3 = P3.quo_rem(f3**2)
    _, square_remainder5 = P5.quo_rem(f5**2)
    square_equations = [
        square_remainder3[index] for index in range(16)
    ]
    square_equations.extend(
        square_remainder5[index] for index in range(16)
    )
    gcd_equations = [(P3 % f3)[index] for index in range(8)]
    gcd_equations.extend(
        (P3.derivative() % f3)[index] for index in range(8)
    )
    gcd_equations.extend((P5 % f5)[index] for index in range(8))
    gcd_equations.extend(
        (P5.derivative() % f5)[index] for index in range(8)
    )
    return ring, free_specs, square_equations, gcd_equations


def presentation_row(name, exporter, ring, specs, equations, scaled):
    text = exporter.msolve_text(ring, equations)
    return {
        "name": name,
        "variables": ring.ngens(),
        "equations": len(equations),
        "terms": sum(len(equation.dict()) for equation in equations),
        "max_degree": max(
            equation.total_degree() for equation in equations
        ),
        "bytes": len(text.encode()),
        "sha256": hashlib.sha256(text.encode()).hexdigest(),
        "known_zero_equations": known_solution_zeros(
            ring,
            specs,
            equations,
            scaled,
        ),
    }


def presentation_rows():
    exporter = load_exporter()
    rows = []
    for variable_order in ("standard", "simple-first", "simple-last"):
        ring, specs, equations = exporter.fixed_system(
            19,
            7,
            14,
            9,
            "scaled",
            variable_order,
        )
        rows.append(
            presentation_row(
                f"scaled-{variable_order}",
                exporter,
                ring,
                specs,
                equations,
                True,
            )
        )
    ring, specs, square_equations, gcd_equations = (
        remainder_presentations()
    )
    rows.append(
        presentation_row(
            "square-remainder",
            exporter,
            ring,
            specs,
            square_equations,
            False,
        )
    )
    rows.append(
        presentation_row(
            "gcd-remainder",
            exporter,
            ring,
            specs,
            gcd_equations,
            False,
        )
    )
    assert all(
        row["known_zero_equations"] == row["equations"] for row in rows
    )
    assert rows[1]["sha256"] == EXPECTED_INPUT_SHA256
    return rows


def parse_benchmark(path):
    metadata = {}
    values = {}
    for line in path.read_text().splitlines():
        if not line:
            continue
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        else:
            key, value = line.split("\t", 1)
            values[key] = value
    required = {
        "wall_limit_seconds",
        "threads",
        "vmem_limit_kib",
        "max_pairs_per_matrix",
        "msolve_version",
        "input_sha256",
        "exit_status",
        "outcome",
        "output_bytes",
        "maximum_rss_kib",
        "highest_f4_degree",
        "maximum_f4_rows",
        "maximum_f4_columns",
        "maximum_pair_frontier",
    }
    if set(values) != required:
        raise ValueError("unexpected benchmark fields")
    if metadata["schema"] != BENCHMARK_SCHEMA:
        raise ValueError("unexpected benchmark schema")
    return metadata, values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--benchmark-summary", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    rows = presentation_rows()
    if args.self_test:
        print(
            "F_19 positive-control presentation self-test passed: "
            "the known cover satisfies all five exact systems"
        )
        if args.benchmark_summary is None:
            return
    if args.benchmark_summary is None:
        parser.error("--benchmark-summary is required outside --self-test")
    benchmark_metadata, benchmark = parse_benchmark(
        args.benchmark_summary
    )
    if benchmark["input_sha256"] != EXPECTED_INPUT_SHA256:
        raise ValueError("benchmark input hash mismatch")
    recovered = (
        benchmark["exit_status"] == "0"
        and int(benchmark["output_bytes"]) > 0
    )
    if recovered:
        raise RuntimeError(
            "completed solver output requires explicit candidate verification"
        )
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# solver_code_revision\t{benchmark_metadata['code_revision']}",
        f"# sage_version\t{SAGE_VERSION}",
        "# status\tknown_f19_positive_control_not_recovered",
        "# prime\t19",
        "# alpha\t7",
        "# beta\t14",
        "# branch_label\t9",
        "# selected_presentation\tscaled-simple-first",
        f"# selected_input_sha256\t{EXPECTED_INPUT_SHA256}",
        "# positive_control_recovered\t0",
    ]
    lines.extend(
        f"# benchmark_{key}\t{value}"
        for key, value in benchmark.items()
    )
    header = (
        "presentation\tvariables\tequations\tterms\tmax_degree\tbytes\t"
        "sha256\tknown_zero_equations"
    )
    lines.append(header)
    lines.extend(
        f"{row['name']}\t{row['variables']}\t{row['equations']}\t"
        f"{row['terms']}\t{row['max_degree']}\t{row['bytes']}\t"
        f"{row['sha256']}\t{row['known_zero_equations']}"
        for row in rows
    )
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.check_summary is not None:
        ignored_prefixes = (
            "# code_revision\t",
            "# solver_code_revision\t",
            "# benchmark_exit_status\t",
            "# benchmark_outcome\t",
            "# benchmark_output_bytes\t",
            "# benchmark_maximum_rss_kib\t",
            "# benchmark_highest_f4_degree\t",
            "# benchmark_maximum_f4_rows\t",
            "# benchmark_maximum_f4_columns\t",
            "# benchmark_maximum_pair_frontier\t",
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
