#!/usr/bin/env sage
"""Probe naive characteristic-zero lifts of König's mod-19 a-relation."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
from pathlib import Path

SCHEMA = "m23-koenig-centered-relation-lift-probe-v1"


def load_module(name, filename):
    path = Path(__file__).with_name(filename)
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError(f"could not load {filename}")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def parse_terms(path):
    terms = {"P": [], "Q": []}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        kind, i, j, coefficient = line.split("\t")
        residue = int(coefficient)
        centered = residue if residue <= 9 else residue - 19
        terms[kind].append((int(i), int(j), centered))
    return terms


def evaluate(terms, u_powers, v_powers, lifter, precision):
    result = u_powers[0].parent().zero()
    for index, (i, j, coefficient) in enumerate(terms):
        result += coefficient * u_powers[i] * v_powers[j]
        if index % 128 == 127:
            result = lifter.truncate(
                result,
                result.parent(),
                result.parent().gen(),
                precision,
            )
    return lifter.truncate(
        result,
        result.parent(),
        result.parent().gen(),
        precision,
    )


def p_valuation(value, prime, digits):
    representative = int(value)
    if representative == 0:
        return digits
    valuation = 0
    while representative % prime == 0:
        representative //= prime
        valuation += 1
    return valuation


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--candidate",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation.tsv"),
    )
    parser.add_argument("--digits", type=int, default=4)
    parser.add_argument("--precision", type=int, default=64)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()

    mixed = load_module(
        "koenig_mixed_lift_relation_probe",
        "lift_koenig_19adic_family.sage",
    )
    (
        lift,
        values,
        _,
        _,
        _,
        series_ring,
        parameter,
        _,
    ) = mixed.lift_family_digitwise(args.digits, args.precision)
    alpha = values[lift.SPECS.index(("f2", 4))]
    beta = values[lift.SPECS.index(("f1", 5))]
    u = alpha - 7
    v = beta - 14
    terms = parse_terms(args.candidate)
    maximum_u = max(i for entries in terms.values() for i, _, _ in entries)
    maximum_v = max(j for entries in terms.values() for _, j, _ in entries)
    u_powers = [series_ring.one()]
    v_powers = [series_ring.one()]
    for _ in range(maximum_u):
        u_powers.append(
            mixed.truncate(
                u_powers[-1] * u,
                series_ring,
                parameter,
                args.precision,
            )
        )
    for _ in range(maximum_v):
        v_powers.append(
            mixed.truncate(
                v_powers[-1] * v,
                series_ring,
                parameter,
                args.precision,
            )
        )
    numerator = evaluate(
        terms["P"], u_powers, v_powers, mixed, args.precision
    )
    denominator = evaluate(
        terms["Q"], u_powers, v_powers, mixed, args.precision
    )
    target = mixed.truncate(
        (series_ring(9) + parameter) ** 2,
        series_ring,
        parameter,
        args.precision,
    )
    residual = mixed.truncate(
        numerator - target * denominator,
        series_ring,
        parameter,
        args.precision,
    )
    valuations = [
        p_valuation(residual[order], 19, args.digits)
        for order in range(args.precision)
    ]
    minimum = min(valuations)
    zero_coefficients = sum(value == args.digits for value in valuations)
    counts = ",".join(
            f"{valuation}:{valuations.count(valuation)}"
            for valuation in sorted(set(valuations))
        )
    assert args.digits == 4
    assert args.precision == 64
    assert minimum == 1
    assert zero_coefficients == 0
    assert counts == "1:60,2:3,3:1"
    candidate_hash = hashlib.sha256(args.candidate.read_bytes()).hexdigest()
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# candidate_sha256\t{candidate_hash}",
        f"# prime\t19",
        f"# digits\t{args.digits}",
        f"# series_precision\t{args.precision}",
        "# coefficient_lift\tcentered residues [-9,9]",
        f"# minimum_residual_19adic_valuation\t{minimum}",
        f"# zero_coefficients\t{zero_coefficients}",
        f"# valuation_counts\t{counts}",
        "# conclusion\tcentered lift fails modulo 19^2",
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
