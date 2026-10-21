#!/usr/bin/env python3
"""Refine a certified root endpoint in the exact coefficient presentation."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
from pathlib import Path
import subprocess

from sage.all import (
    ComplexField,
    PolynomialRing,
    QQ,
    matrix,
    vector,
)
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]
ROOT_NAMES = (
    "alpha", "ar1", "ar2", "br1", "br2", "cr4", "cr2", "cr1",
    *(f"ur{index}" for index in range(1, 9)),
    *(f"vr{index}" for index in range(1, 8)),
)
COEFFICIENT_NAMES = (
    "alpha", "a0", "a1", "b0", "b1", "c4", "c2", "c1",
    *(f"u{index}" for index in range(8)),
    *(f"v{index}" for index in range(7)),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_revision() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path.resolve())


def read_endpoint(
    path: Path,
) -> tuple[dict[str, str], dict[str, tuple[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("=", 1)
            metadata[key] = value
        else:
            data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    values = {
        row["name"]: (row["real"], row["imag"])
        for row in rows
        if row["name"] in ROOT_NAMES
    }
    if metadata.get("format") != "m23_8a_root_saturated_endpoint_v2":
        raise RuntimeError("unexpected endpoint format")
    if metadata.get("return_code") != "success":
        raise RuntimeError("endpoint path did not reach success")
    if metadata.get("certified") != "true":
        raise RuntimeError("endpoint is not interval-certified")
    if set(values) != set(ROOT_NAMES):
        raise RuntimeError("endpoint root variables are incomplete")
    return metadata, values


def multiply(left: list, right: list) -> list:
    result = [0] * (len(left) + len(right) - 1)
    for left_index, left_value in enumerate(left):
        for right_index, right_value in enumerate(right):
            result[left_index + right_index] += left_value * right_value
    return result


def monic_from_roots(roots: list) -> list:
    coefficients = [1]
    for root in roots:
        coefficients = multiply(coefficients, [-root, 1])
    return coefficients


def root_to_coefficient_point(values: dict[str, tuple[str, str]], field):
    roots = {
        name: field(real, imaginary)
        for name, (real, imaginary) in values.items()
    }
    a = monic_from_roots([roots["ar1"], roots["ar2"]])
    b = monic_from_roots([roots["br1"], roots["br2"]])
    u = monic_from_roots([roots[f"ur{index}"] for index in range(1, 9)])
    v = monic_from_roots([roots[f"vr{index}"] for index in range(1, 8)])
    point = [
        roots["alpha"],
        a[0], a[1],
        b[0], b[1],
        roots["cr4"], roots["cr2"], roots["cr1"],
        *u[:8],
        *v[:7],
    ]
    if len(point) != 23:
        raise AssertionError("coefficient point has the wrong size")
    return vector(field, point)


def coefficient_system(normalization: tuple[int, int, int]):
    if tuple(sorted(normalization)) != (1, 2, 4):
        raise ValueError("normalization must permute (4,2,1)")
    names = tuple(COEFFICIENT_NAMES)
    ring = PolynomialRing(QQ, names=names, order="degrevlex")
    (
        alpha, a0, a1, b0, b1, c4, c2, c1,
        u0, u1, u2, u3, u4, u5, u6, u7,
        v0, v1, v2, v3, v4, v5, v6,
    ) = ring.gens()
    polynomial_ring = PolynomialRing(ring, names=("x",))
    x = polynomial_ring.gen()
    a = x**2 + a1*x + a0
    b = x**2 + b1*x + b0
    p = (
        alpha
        * a**8
        * x**normalization[0]
        * (x - 1)**normalization[1]
    )
    f = b**8 * (x - c4)**4 * (x - c2)**2 * (x - c1)
    u = (
        x**8 + u7*x**7 + u6*x**6 + u5*x**5 + u4*x**4
        + u3*x**3 + u2*x**2 + u1*x + u0
    )
    v = (
        x**7 + v6*x**6 + v5*x**5 + v4*x**4
        + v3*x**3 + v2*x**2 + v1*x + v0
    )
    q = u**2 * v
    equations = [(p + f - q)[index] for index in range(23)]
    jacobian = [
        [equation.derivative(variable) for variable in ring.gens()]
        for equation in equations
    ]
    return ring, equations, jacobian


def evaluate(polynomial, point):
    return polynomial(*point)


def refine(
    point,
    equations,
    jacobian,
    maximum_iterations: int,
    target_bits: int,
):
    field = point.base_ring()
    target = field(2) ** (-(target_bits - 32))
    history: list[tuple[int, object, object]] = []
    for iteration in range(maximum_iterations + 1):
        residual = vector(
            field, [evaluate(equation, point) for equation in equations]
        )
        residual_max = max(abs(value) for value in residual)
        history.append((iteration, residual_max, field(0)))
        if residual_max < target:
            return point, history
        if iteration == maximum_iterations:
            break
        numerical_jacobian = matrix(
            field,
            [
                [evaluate(entry, point) for entry in row]
                for row in jacobian
            ],
        )
        delta = numerical_jacobian.solve_right(-residual)
        history[-1] = (iteration, residual_max, max(abs(value) for value in delta))
        point += delta
    raise RuntimeError(
        f"high-precision Newton did not reach its target: {history[-1][1]}"
    )


def write_output(
    path: Path,
    source: Path,
    source_metadata: dict[str, str],
    normalization: tuple[int, int, int],
    bits: int,
    point,
    history,
) -> None:
    digits = math.floor(bits * math.log10(2)) - 12
    metadata = [
        "# format\tm23_8a_belyi_high_precision_coefficients_v1",
        f"# code_revision\t{git_revision()}",
        f"# source\t{display_path(source)}",
        f"# source_sha256\t{sha256(source)}",
        f"# source_code_revision\t{source_metadata['code_revision']}",
        f"# normalization\t{','.join(map(str, normalization))}",
        f"# precision_bits\t{bits}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# iterations\t{history[-1][0]}",
        f"# final_residual_max\t{format(history[-1][1], f'.{digits}g')}",
        "# interpretation\thigh-precision numerical coefficients; not exact recognition",
        "name\treal\timaginary",
    ]
    rows = [
        "\t".join(
            (
                name,
                format(value.real(), f".{digits}g"),
                format(value.imag(), f".{digits}g"),
            )
        )
        for name, value in zip(COEFFICIENT_NAMES, point)
    ]
    path.write_text("\n".join([*metadata, *rows, ""]), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("endpoint", type=Path)
    parser.add_argument("--precision-bits", type=int, default=512)
    parser.add_argument("--maximum-iterations", type=int, default=20)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.precision_bits < 128:
        parser.error("--precision-bits must be at least 128")
    if args.maximum_iterations <= 0:
        parser.error("--maximum-iterations must be positive")
    metadata, values = read_endpoint(args.endpoint)
    normalization = tuple(
        int(value) for value in metadata["normalization"].split(",")
    )
    field = ComplexField(args.precision_bits)
    point = root_to_coefficient_point(values, field)
    _, equations, jacobian = coefficient_system(normalization)
    refined, history = refine(
        point,
        equations,
        jacobian,
        args.maximum_iterations,
        args.precision_bits,
    )
    write_output(
        args.output,
        args.endpoint,
        metadata,
        normalization,
        args.precision_bits,
        refined,
        history,
    )
    print(
        f"refined coefficients in {history[-1][0]} Newton steps: "
        f"residual_max={history[-1][1]}"
    )


if __name__ == "__main__":
    main()
