#!/usr/bin/env sage
"""Export the blind known-answer F_19 König solver positive control."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
from pathlib import Path


PRIME = 19
ALPHA = 7
BETA = 14
BRANCH_LABEL = 9
PRESENTATION = "scaled"
VARIABLE_ORDER = "simple-first"
EXPECTED_SHA256 = (
    "e7d00cb330e140f57a987570cc396477a41b0d0317de8254858c96d1e5c5f3c9"
)


def load_exporter():
    path = Path(__file__).with_name(
        "export_koenig_second_prime_msolve.sage"
    )
    loader = importlib.machinery.SourceFileLoader(
        "koenig_f19_positive_control_exporter",
        str(path),
    )
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König msolve exporter")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def positive_control():
    exporter = load_exporter()
    ring, specs, equations = exporter.fixed_system(
        PRIME,
        ALPHA,
        BETA,
        BRANCH_LABEL,
        PRESENTATION,
        VARIABLE_ORDER,
    )
    text = exporter.msolve_text(ring, equations)
    digest = hashlib.sha256(text.encode()).hexdigest()
    if digest != EXPECTED_SHA256:
        raise AssertionError(f"unexpected positive-control input hash {digest}")
    return exporter, ring, specs, equations, text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    exporter, ring, _, equations, text = positive_control()
    if args.self_test:
        exporter.self_test()
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    if args.output is None and not args.self_test:
        parser.error("--output is required outside --self-test")
    print(
        f"prime={PRIME} alpha={ALPHA} beta={BETA} "
        f"lambda={BRANCH_LABEL} presentation={PRESENTATION} "
        f"variable_order={VARIABLE_ORDER} variables={ring.ngens()} "
        f"equations={len(equations)} "
        f"terms={sum(len(equation.dict()) for equation in equations)} "
        f"max_degree={max(equation.total_degree() for equation in equations)} "
        f"sha256={EXPECTED_SHA256}"
    )


if __name__ == "__main__":
    main()
