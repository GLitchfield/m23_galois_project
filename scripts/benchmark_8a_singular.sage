#!/usr/bin/env sage
"""Run one deliberately bounded Singular Gröbner-basis benchmark."""

import argparse
import time
from pathlib import Path

from sage.all import GF, PolynomialRing, QQ, is_prime


VARIABLES = (
    "alpha", "a0", "a1", "b0", "b1", "c4", "c2", "c1",
    *(f"u{i}" for i in range(8)),
    *(f"v{i}" for i in range(7)),
)


def load_system(path):
    namespace = {"PolynomialRing": PolynomialRing, "QQ": QQ}
    code = compile(path.read_text(encoding="utf-8"), str(path), "exec")
    exec(code, namespace)
    return namespace


def reduce_coefficients(equation, ring):
    variable_count = ring.ngens()
    coefficients = {
        tuple(exponents[:variable_count]): ring.base_ring()(coefficient)
        for exponents, coefficient in equation.dict().items()
    }
    return ring(coefficients)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prime", type=int, default=13)
    parser.add_argument(
        "--presentation",
        choices=("full", "reduced"),
        default="reduced",
    )
    parser.add_argument(
        "--system",
        type=Path,
        default=Path("data/derived/m23_8a_belyi_normalized_system.sage"),
    )
    args = parser.parse_args()

    if not is_prime(args.prime):
        parser.error(f"--prime must be prime, got {args.prime}")

    namespace = load_system(args.system)
    if args.presentation == "full":
        variable_names = VARIABLES
        equations = namespace["full_equations"]
    else:
        variable_names = VARIABLES[:16]
        equations = namespace["reduced_equations"]

    ring = PolynomialRing(
        GF(args.prime),
        names=variable_names,
        order="degrevlex",
    )
    modular_equations = [
        reduce_coefficients(equation, ring) for equation in equations
    ]
    term_count = sum(len(equation.monomials()) for equation in modular_equations)
    max_degree = max(equation.total_degree() for equation in modular_equations)
    print(
        f"phase=constructed presentation={args.presentation} prime={args.prime} "
        f"variables={len(variable_names)} equations={len(modular_equations)} "
        f"terms={term_count} max_degree={max_degree}",
        flush=True,
    )

    started = time.monotonic()
    basis = ring.ideal(modular_equations).groebner_basis(
        algorithm="singular:groebner"
    )
    elapsed = time.monotonic() - started
    print(
        f"phase=completed basis_size={len(basis)} "
        f"elapsed_seconds={elapsed:.6f}",
        flush=True,
    )


if __name__ == "__main__":
    main()
