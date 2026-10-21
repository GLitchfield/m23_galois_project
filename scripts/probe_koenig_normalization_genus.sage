#!/usr/bin/env sage
"""Run one bounded external-archive probe for König's normalization genus."""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import time
from pathlib import Path

from sage.all import Curve, FunctionField, GF, PolynomialRing, QQ


def load_verifier():
    path = Path(__file__).with_name("verify_koenig_hurwitz_curve.sage")
    loader = importlib.machinery.SourceFileLoader(
        "koenig_curve_verifier", str(path)
    )
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König curve verifier")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def plane_genus(polynomial, field):
    curve = Curve(polynomial.change_ring(field)).projective_closure()
    print(
        f"degree={curve.degree()} arithmetic_genus={curve.arithmetic_genus()}",
        flush=True,
    )
    return curve.genus()


def function_field_genus(polynomial):
    base = FunctionField(QQ, "t")
    t = base.gen()
    ring = PolynomialRing(base, "x")
    x = ring.gen()
    defining = ring.zero()
    for (t_degree, x_degree), coefficient in polynomial.dict().items():
        defining += base(coefficient) * t**t_degree * x**x_degree
    print(f"function_field_degree={defining.degree()}", flush=True)
    extension = base.extension(defining, "y")
    return extension.genus()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument(
        "--method",
        choices=("plane-qq", "plane-mod-p", "function-field"),
        required=True,
    )
    parser.add_argument("--prime", type=int, default=11)
    args = parser.parse_args()

    verifier = load_verifier()
    _, _, _, polynomial = verifier.load_polynomial(args.archive)
    started = time.monotonic()
    if args.method == "plane-qq":
        genus = plane_genus(polynomial, QQ)
    elif args.method == "plane-mod-p":
        genus = plane_genus(polynomial, GF(args.prime))
    else:
        genus = function_field_genus(polynomial)
    print(f"geometric_genus={genus}")
    print(f"elapsed_seconds={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
