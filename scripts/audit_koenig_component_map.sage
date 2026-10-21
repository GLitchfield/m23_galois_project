#!/usr/bin/env sage
"""Audit König's numerical coefficient map on the complete 980-point fiber."""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import re
import time
import zipfile
from pathlib import Path

from sage.all import ComplexField, PolynomialRing, RealField


APPROXIMATION = (
    "Polynomials And Approximation Data/M23_(2,2,3,5)/"
    "m23_(2,2,3,5)_approx.txt"
)
PRECISION_BITS = 700
MODEL_TOLERANCE = "1e-190"
RELATION_TOLERANCE = "1e-155"
PAIR_SEPARATION_FLOOR = "0.02"


def load_verifier():
    path = Path(__file__).with_name("verify_koenig_hurwitz_curve.sage")
    loader = importlib.machinery.SourceFileLoader("koenig_verifier", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König curve verifier")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def extract_entries(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    depth = 0
    start = None
    entries = []
    for index, character in enumerate(text):
        if character == "[":
            depth += 1
            if depth == 2:
                start = index + 1
        elif character == "]":
            if depth == 2:
                entries.append(text[start:index])
                start = None
            depth -= 1
    if depth != 0 or start is not None:
        raise ValueError("unbalanced approximation list")
    return tuple(entries)


def parse_number(text, real_field, complex_field):
    compact = re.sub(r"\s+", "", text)
    if not compact.endswith("*I"):
        return complex_field(real_field(compact))
    body = compact[:-2]
    separator = None
    for index in range(1, len(body)):
        if body[index] in "+-" and body[index - 1] not in "Ee":
            separator = index
    if separator is None:
        return complex_field(0, real_field(body))
    return complex_field(
        real_field(body[:separator]),
        real_field(body[separator:]),
    )


def parse_entry(text, real_field, complex_field):
    return tuple(
        parse_number(part, real_field, complex_field)
        for part in text.split(",")
    )


def monic_polynomial(coefficients, ring):
    variable = ring.gen()
    degree = len(coefficients)
    return variable**degree + sum(
        coefficient * variable ** (degree - index - 1)
        for index, coefficient in enumerate(coefficients)
    )


def model_residual(values, ring, complex_field):
    # The archive ordering is f5,f6,f1,f2,f3,f4, followed by the two
    # unfixed coefficients of each g_i and the leading constant C.
    f5 = monic_polynomial(values[0:8], ring)
    f6 = monic_polynomial(values[8:15], ring)
    f1 = monic_polynomial(values[15:21], ring)
    f2 = monic_polynomial(values[21:26], ring)
    f3 = monic_polynomial(values[26:34], ring)
    f4 = monic_polynomial(values[34:41], ring)
    g1 = monic_polynomial((complex_field(1) / 3,) + values[41:43], ring)
    g2 = monic_polynomial((-complex_field(1) / 2,) + values[43:45], ring)
    constant = values[45]
    denominator = g1**5 * g2
    numerator_1 = constant * f1**3 * f2
    numerator_3 = constant * f3**2 * f4
    numerator_5 = constant * f5**2 * f6
    identities = (
        numerator_5 - numerator_1 - complex_field(1) / 4 * denominator,
        numerator_3 - numerator_1 + complex_field(3) / 4 * denominator,
    )
    scale = max(
        abs(coefficient)
        for polynomial in (
            numerator_1,
            numerator_3,
            numerator_5,
            denominator,
        )
        for coefficient in polynomial
    )
    return max(
        max(map(abs, identity)) / scale for identity in identities
    )


def relation_residual(values, relation_terms, complex_field):
    # König defines alpha as the X^4 coefficient of monic f2 and beta as the
    # X^5 coefficient of monic f1: entries 22 and 16 in one-based indexing.
    alpha = values[21]
    beta = values[15]
    alpha_powers = [complex_field(1)]
    beta_powers = [complex_field(1)]
    for _ in range(97):
        alpha_powers.append(alpha_powers[-1] * alpha)
    for _ in range(98):
        beta_powers.append(beta_powers[-1] * beta)
    terms = tuple(
        complex_field(coefficient)
        * alpha_powers[exponent[0]]
        * beta_powers[exponent[1]]
        for exponent, coefficient in relation_terms
    )
    return abs(sum(terms)) / sum(map(abs, terms))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()

    started = time.monotonic()
    verifier = load_verifier()
    _, _, _, relation = verifier.load_polynomial(args.archive)
    relation_terms = tuple(relation.dict().items())
    with zipfile.ZipFile(args.archive) as archive:
        source = archive.read(APPROXIMATION).decode("ascii")
    entry_texts = extract_entries(source)
    assert len(entry_texts) == 980

    real_field = RealField(PRECISION_BITS)
    complex_field = ComplexField(PRECISION_BITS)
    ring = PolynomialRing(complex_field, "X")
    model_max = real_field(0)
    relation_max = real_field(0)
    coefficientwise_real = 0
    pairs = []

    for index, entry_text in enumerate(entry_texts, 1):
        values = parse_entry(entry_text, real_field, complex_field)
        assert len(values) == 46
        model_max = max(
            model_max,
            model_residual(values, ring, complex_field),
        )
        relation_max = max(
            relation_max,
            relation_residual(values, relation_terms, complex_field),
        )
        pairs.append((values[21], values[15]))
        if max(abs(value.imag()) for value in values) < real_field("1e-180"):
            coefficientwise_real += 1
        if index % 200 == 0:
            print(
                f"checked={index} model_max={model_max.n(digits=6)} "
                f"relation_max={relation_max.n(digits=6)}",
                flush=True,
            )

    minimum_separation = min(
        abs(pairs[left][0] - pairs[right][0])
        + abs(pairs[left][1] - pairs[right][1])
        for left in range(len(pairs))
        for right in range(left)
    )
    assert model_max < real_field(MODEL_TOLERANCE)
    assert relation_max < real_field(RELATION_TOLERANCE)
    assert minimum_separation > real_field(PAIR_SEPARATION_FLOOR)
    assert coefficientwise_real == 30

    print(
        f"vectors={len(pairs)} coefficientwise_real={coefficientwise_real} "
        f"model_max={model_max.n(digits=8)} "
        f"relation_max={relation_max.n(digits=8)} "
        f"minimum_pair_separation={minimum_separation.n(digits=8)} "
        f"elapsed_seconds={time.monotonic() - started:.3f}"
    )
    print(
        "verified the numerical component-to-plane bridge on all 980 "
        "archived covers (advisory, not an exact algebraic certificate)"
    )


if __name__ == "__main__":
    main()
