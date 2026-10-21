#!/usr/bin/env sage
"""Verify König's recovered common-denominator F_19 cover functions."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import time
from pathlib import Path

from sage.all import PolynomialRing
from sage.env import SAGE_VERSION


SCHEMA = "m23-koenig-f19-family-v1"
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


def parse_family(path, field):
    metadata = {}
    denominator = []
    numerators = {}
    for line in path.read_text().splitlines():
        if not line:
            continue
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
            continue
        pieces = line.split("\t")
        if pieces[0] == "D":
            _, i, j, coefficient = pieces
            denominator.append((int(i), int(j), field(coefficient)))
        elif pieces[0] == "N":
            _, label, i, j, coefficient = pieces
            numerators.setdefault(label, []).append(
                (int(i), int(j), field(coefficient))
            )
        else:
            raise ValueError(f"unexpected family row: {pieces[0]}")
    return metadata, denominator, numerators


def evaluate(lifter, terms, u_powers, v_powers, precision):
    result = lifter.SERIES_RING.zero()
    for index, (i, j, coefficient) in enumerate(terms, 1):
        result += coefficient * u_powers[i] * v_powers[j]
        if index % 128 == 0:
            result = lifter.truncate(result, precision)
    return lifter.truncate(result, precision)


def targets(lifter, values, branch_label, precision):
    specs = [("a", 0), ("constant", 0)]
    specs.extend(("f1", exponent) for exponent in range(5))
    specs.extend(("f2", exponent) for exponent in range(4))
    specs.extend(("g1", exponent) for exponent in range(2))
    specs.extend(("g2", exponent) for exponent in range(2))
    labels = [
        "a" if name == "a" else (
            "constant" if name == "constant" else f"{name}_x{exponent}"
        )
        for name, exponent in specs
    ]
    series = [lifter.truncate(branch_label**2, precision)]
    series.extend(
        values[lifter.SPECS.index(spec)] for spec in specs[1:]
    )
    return labels, series


def validation_lines(
    family_path,
    family_digest,
    metadata,
    precision,
    denominator,
):
    return (
        "# schema\tm23-koenig-f19-family-validation-v1",
        f"# family\t{family_path.name}",
        f"# family_sha256\t{family_digest}",
        f"# archive_sha256\t{metadata['archive_sha256']}",
        f"# verifier_revision\t{metadata['code_revision']}",
        f"# sage_version\t{SAGE_VERSION}",
        f"validated_precision\t{precision}",
        (
            f"unseen_tail_terms\t"
            f"{max(0, precision - int(metadata['fit_precision']))}"
        ),
        "target_count\t15",
        f"common_denominator_valuation\t{denominator.valuation()}",
        "relation_residuals\t0",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("family", type=Path)
    parser.add_argument("--precision", type=int, default=DEFAULT_PRECISION)
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument("--output", type=Path)
    output_group.add_argument("--check-summary", type=Path)
    args = parser.parse_args()
    if args.precision < 2 or args.precision & (args.precision - 1):
        raise ValueError("precision must be a power of two")

    lifter = load_lifter()
    metadata, denominator_terms, numerator_terms = parse_family(
        args.family, lifter.FIELD
    )
    assert metadata["schema"] == SCHEMA
    assert metadata["field"] == "GF(19)"
    assert metadata["parameter"] == "s=lambda-9"
    assert metadata["coordinates"] == "u=alpha-7,v=beta-14"

    expected_labels = ["a", "constant"]
    expected_labels.extend(f"f1_x{exponent}" for exponent in range(5))
    expected_labels.extend(f"f2_x{exponent}" for exponent in range(4))
    expected_labels.extend(f"g1_x{exponent}" for exponent in range(2))
    expected_labels.extend(f"g2_x{exponent}" for exponent in range(2))
    assert list(numerator_terms) == expected_labels

    polynomial_ring = PolynomialRing(lifter.FIELD, names=("u", "v"))
    polynomial_u, polynomial_v = polynomial_ring.gens()
    denominator_polynomial = sum(
        coefficient * polynomial_u**i * polynomial_v**j
        for i, j, coefficient in denominator_terms
    )
    assert denominator_polynomial.total_degree() == int(
        metadata["common_denominator_total_degree"]
    )
    assert len(denominator_polynomial.dict()) == int(
        metadata["common_denominator_terms"]
    )
    for label in expected_labels:
        numerator_polynomial = sum(
            coefficient * polynomial_u**i * polynomial_v**j
            for i, j, coefficient in numerator_terms[label]
        )
        target_metadata = dict(
            item.split("=", 1)
            for item in metadata[f"target_{label}"].split(",")
        )
        assert numerator_polynomial.total_degree() == int(
            target_metadata["degree"]
        )
        assert len(numerator_polynomial.dict()) == int(
            target_metadata["terms"]
        )
        assert numerator_polynomial.gcd(
            denominator_polynomial
        ).total_degree() == 0

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
        max(i, j)
        for terms in [denominator_terms, *numerator_terms.values()]
        for i, j, _ in terms
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
    denominator = evaluate(
        lifter,
        denominator_terms,
        u_powers,
        v_powers,
        args.precision,
    )
    assert denominator != 0
    labels, target_series = targets(
        lifter, values, branch_label, args.precision
    )
    for label, target in zip(labels, target_series):
        numerator = evaluate(
            lifter,
            numerator_terms[label],
            u_powers,
            v_powers,
            args.precision,
        )
        residual = lifter.truncate(
            numerator - target * denominator, args.precision
        )
        assert residual == 0
        print(f"verified_target={label}", flush=True)

    family_digest = hashlib.sha256(args.family.read_bytes()).hexdigest()
    lines = validation_lines(
        args.family,
        family_digest,
        metadata,
        args.precision,
        denominator,
    )
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("\n".join(lines) + "\n")
        print(f"wrote={args.output}")
    if args.check_summary is not None:
        assert list(lines) == args.check_summary.read_text().splitlines()
        print(f"verified={args.check_summary}")
    print(f"family_sha256={family_digest}")
    print(f"validated_precision={args.precision}")
    print(
        f"unseen_tail_terms="
        f"{max(0, args.precision - int(metadata['fit_precision']))}"
    )
    print(f"elapsed={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
