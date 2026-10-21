#!/usr/bin/env sage
"""Verify a recovered rational expression for a on König's F_19 branch."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import time
from pathlib import Path

from sage.all import PolynomialRing
from sage.env import SAGE_VERSION


DEFAULT_PRECISION = 4096


def load_lifter():
    path = Path(__file__).with_name("lift_koenig_f19_newton.sage")
    loader = importlib.machinery.SourceFileLoader("koenig_lifter", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König Newton lifter")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def parse_candidate(path, field):
    metadata = {}
    terms = {"P": [], "Q": []}
    for line in path.read_text().splitlines():
        if not line:
            continue
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
            continue
        label, i, j, coefficient = line.split("\t")
        if label not in terms:
            raise ValueError(f"unexpected term label: {label}")
        terms[label].append((int(i), int(j), field(coefficient)))
    return metadata, terms


def evaluate(lifter, terms, u_powers, v_powers, precision):
    result = lifter.SERIES_RING.zero()
    for index, (i, j, coefficient) in enumerate(terms, 1):
        result += coefficient * u_powers[i] * v_powers[j]
        if index % 128 == 0:
            result = lifter.truncate(result, precision)
    return lifter.truncate(result, precision)


def validation_lines(
    candidate_path,
    candidate_digest,
    metadata,
    precision,
    numerator,
    denominator,
):
    fit_precision = int(metadata["fit_precision"])
    return (
        "# schema\tm23-koenig-f19-a-validation-v1",
        f"# candidate\t{candidate_path.name}",
        f"# candidate_sha256\t{candidate_digest}",
        f"# archive_sha256\t{metadata['archive_sha256']}",
        f"# verifier_revision\t{metadata['code_revision']}",
        f"# sage_version\t{SAGE_VERSION}",
        f"validated_precision\t{precision}",
        f"unseen_tail_terms\t{max(0, precision - fit_precision)}",
        f"numerator_valuation\t{numerator.valuation()}",
        f"denominator_valuation\t{denominator.valuation()}",
        "relation_residual\t0",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--precision", type=int, default=DEFAULT_PRECISION)
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument("--output", type=Path)
    output_group.add_argument("--check-summary", type=Path)
    args = parser.parse_args()
    if args.precision < 2 or args.precision & (args.precision - 1):
        raise ValueError("precision must be a power of two")

    lifter = load_lifter()
    metadata, terms = parse_candidate(args.candidate, lifter.FIELD)
    assert metadata["schema"] == "m23-koenig-f19-a-relation-v1"
    assert metadata["field"] == "GF(19)"
    assert metadata["parameter"] == "s=lambda-9"
    assert metadata["target"] == "a=lambda^2"
    assert metadata["coordinates"] == "u=alpha-7,v=beta-14"

    polynomial_ring = PolynomialRing(lifter.FIELD, names=("u", "v"))
    polynomial_u, polynomial_v = polynomial_ring.gens()
    polynomials = {}
    for label in ("P", "Q"):
        polynomials[label] = sum(
            coefficient * polynomial_u**i * polynomial_v**j
            for i, j, coefficient in terms[label]
        )
    assert polynomials["P"].gcd(polynomials["Q"]).total_degree() == 0
    assert polynomials["P"].total_degree() == int(
        metadata["numerator_total_degree"]
    )
    assert polynomials["Q"].total_degree() == int(
        metadata["denominator_total_degree"]
    )
    assert len(polynomials["P"].dict()) == int(metadata["numerator_terms"])
    assert len(polynomials["Q"].dict()) == int(metadata["denominator_terms"])

    started = time.monotonic()

    def report(precision):
        print(
            f"lift_precision={precision} "
            f"elapsed={time.monotonic() - started:.3f}",
            flush=True,
        )

    values, branch_label = lifter.lift_formal_family(
        args.precision, progress=report
    )
    alpha = values[lifter.SPECS.index(("f2", 4))]
    beta = values[lifter.SPECS.index(("f1", 5))]
    u = alpha - 7
    v = beta - 14
    maximum_degree = max(
        max(i, j) for entries in terms.values() for i, j, _ in entries
    )
    u_powers = [lifter.SERIES_RING.one()]
    v_powers = [lifter.SERIES_RING.one()]
    for _ in range(maximum_degree):
        u_powers.append(
            lifter.truncate(u_powers[-1] * u, args.precision)
        )
        v_powers.append(
            lifter.truncate(v_powers[-1] * v, args.precision)
        )
    numerator = evaluate(
        lifter, terms["P"], u_powers, v_powers, args.precision
    )
    denominator = evaluate(
        lifter, terms["Q"], u_powers, v_powers, args.precision
    )
    residual = lifter.truncate(
        numerator - branch_label**2 * denominator, args.precision
    )
    assert denominator != 0
    assert residual == 0

    candidate_digest = hashlib.sha256(
        args.candidate.read_bytes()
    ).hexdigest()
    lines = validation_lines(
        args.candidate,
        candidate_digest,
        metadata,
        args.precision,
        numerator,
        denominator,
    )
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("\n".join(lines) + "\n")
        print(f"wrote={args.output}")
    if args.check_summary is not None:
        expected = args.check_summary.read_text().splitlines()
        assert list(lines) == expected
        print(f"verified={args.check_summary}")
    print(f"candidate_sha256={candidate_digest}")
    print(f"numerator_valuation={numerator.valuation()}")
    print(f"denominator_valuation={denominator.valuation()}")
    print(f"validated_precision={args.precision}")
    print(
        f"unseen_tail_terms="
        f"{max(0, args.precision - int(metadata['fit_precision']))}"
    )
    print(f"elapsed={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
