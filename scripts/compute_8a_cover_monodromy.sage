#!/usr/bin/env python3
"""Lift standard loops to recover a numerical Belyi cover's monodromy."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
from pathlib import Path
import subprocess

from sage.all import ComplexField, PolynomialRing, RealField
from sage.env import SAGE_VERSION


ROOT = Path(__file__).resolve().parents[1]


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


def read_coefficients(path: Path, field):
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        else:
            data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    values = {
        row["name"]: field(row["real"], row["imaginary"])
        for row in rows
    }
    if metadata.get("format") != (
        "m23_8a_belyi_high_precision_coefficients_v1"
    ):
        raise RuntimeError("unexpected coefficient format")
    expected = {
        "alpha", "a0", "a1", "b0", "b1", "c4", "c2", "c1",
        *(f"u{index}" for index in range(8)),
        *(f"v{index}" for index in range(7)),
    }
    if set(values) != expected:
        raise RuntimeError("coefficient variables are incomplete")
    return metadata, values


def polynomials(values, field):
    ring = PolynomialRing(field, names=("x",))
    x = ring.gen()
    normalization = (1, 4, 2)
    a = x**2 + values["a1"]*x + values["a0"]
    b = x**2 + values["b1"]*x + values["b0"]
    p = (
        values["alpha"]
        * a**8
        * x**normalization[0]
        * (x - 1)**normalization[1]
    )
    f = (
        b**8
        * (x - values["c4"])**4
        * (x - values["c2"])**2
        * (x - values["c1"])
    )
    u = x**8 + sum(values[f"u{index}"] * x**index for index in range(8))
    v = x**7 + sum(values[f"v{index}"] * x**index for index in range(7))
    q = u**2 * v
    return p, f, q


def cycle_lengths(images: tuple[int, ...]) -> tuple[int, ...]:
    unseen = set(range(len(images)))
    lengths = []
    while unseen:
        start = min(unseen)
        point = start
        length = 0
        while point in unseen:
            unseen.remove(point)
            length += 1
            point = images[point]
        lengths.append(length)
    return tuple(sorted(lengths, reverse=True))


def inverse_product(
    left: tuple[int, ...], right: tuple[int, ...]
) -> tuple[int, ...]:
    product = tuple(right[left[index]] for index in range(len(left)))
    inverse = [0] * len(left)
    for index, image in enumerate(product):
        inverse[image] = index
    return tuple(inverse)


def base_roots(p, q, field):
    base = field(1) / 2
    roots = (p - base*q).roots(multiplicities=False)
    if len(roots) != 23:
        raise RuntimeError(f"expected 23 base roots, found {len(roots)}")
    roots.sort(key=lambda value: (value.real(), value.imag()))
    return roots


def match_roots(final_roots, initial_roots, tolerance):
    images = []
    distances = []
    for final in final_roots:
        candidates = [
            (abs(final - initial), index)
            for index, initial in enumerate(initial_roots)
        ]
        distance, index = min(candidates)
        images.append(index)
        distances.append(distance)
    if len(set(images)) != len(initial_roots):
        raise RuntimeError("endpoint root matching is not bijective")
    if max(distances) > tolerance:
        raise RuntimeError(
            f"endpoint root matching exceeded tolerance: {max(distances)}"
        )
    return tuple(images), max(distances)


def lift_loop(p, q, initial_roots, center, start_angle, steps, field):
    roots = list(initial_roots)
    real_field = RealField(field.precision())
    derivative_p = p.derivative()
    derivative_q = q.derivative()
    maximum_residual = real_field(0)
    minimum_separation = real_field("+infinity")
    minimum_derivative = real_field("+infinity")
    maximum_correction = real_field(0)
    previous_y = center + field(1)/2 * field(
        0, start_angle
    ).exp()
    tolerance = field(2) ** (-(field.precision() - 32))
    for step in range(1, steps + 1):
        angle = start_angle + 2*real_field.pi()*step/steps
        y = center + field(1)/2 * field(0, angle).exp()
        delta_y = y - previous_y
        corrected = []
        for root in roots:
            derivative = derivative_p(root) - previous_y*derivative_q(root)
            minimum_derivative = min(minimum_derivative, abs(derivative))
            predicted = root + q(root)/derivative * delta_y
            value = predicted
            for _ in range(12):
                residual = p(value) - y*q(value)
                derivative = derivative_p(value) - y*derivative_q(value)
                minimum_derivative = min(minimum_derivative, abs(derivative))
                correction = residual / derivative
                value -= correction
                maximum_correction = max(maximum_correction, abs(correction))
                if abs(correction) < tolerance:
                    break
            residual = abs(p(value) - y*q(value))
            maximum_residual = max(maximum_residual, residual)
            if residual > field(2) ** (-(field.precision() // 2)):
                raise RuntimeError(
                    f"loop correction failed at step {step}: {residual}"
                )
            corrected.append(value)
        roots = corrected
        minimum_separation = min(
            minimum_separation,
            min(
                abs(roots[left] - roots[right])
                for left in range(len(roots))
                for right in range(left + 1, len(roots))
            ),
        )
        previous_y = y
    images, matching_error = match_roots(
        roots,
        initial_roots,
        field(2) ** (-(field.precision() // 3)),
    )
    return {
        "images": images,
        "maximum_residual": maximum_residual,
        "minimum_root_separation": minimum_separation,
        "minimum_derivative": minimum_derivative,
        "maximum_correction": maximum_correction,
        "matching_error": matching_error,
    }


def render(
    source: Path,
    source_metadata,
    precision_bits: int,
    coarse_steps: int,
    fine_steps: int,
    first,
    second,
) -> str:
    third = inverse_product(first["images"], second["images"])
    metadata = [
        "# format\tm23_8a_cover_monodromy_v1",
        f"# code_revision\t{git_revision()}",
        f"# source\t{display_path(source)}",
        f"# source_sha256\t{sha256(source)}",
        f"# source_code_revision\t{source_metadata['code_revision']}",
        f"# precision_bits\t{precision_bits}",
        f"# coarse_steps_per_loop\t{coarse_steps}",
        f"# fine_steps_per_loop\t{fine_steps}",
        "# permutations_stable\ttrue",
        f"# sage_version\t{SAGE_VERSION}",
        "# basepoint\t0.5",
        "# loops\tcounterclockwise circles of radius 0.5 around 0 and 1",
        "# interpretation\tnumerical cover monodromy; requires independent group and class checks",
    ]
    fields = (
        "loop", "images", "cycle_lengths", "maximum_residual",
        "minimum_root_separation", "minimum_derivative",
        "maximum_correction", "matching_error",
    )
    rows = []
    for label, result in (("zero", first), ("one", second)):
        rows.append((
            label,
            ",".join(str(image + 1) for image in result["images"]),
            ",".join(map(str, cycle_lengths(result["images"]))),
            str(result["maximum_residual"]),
            str(result["minimum_root_separation"]),
            str(result["minimum_derivative"]),
            str(result["maximum_correction"]),
            str(result["matching_error"]),
        ))
    rows.append((
        "infinity",
        ",".join(str(image + 1) for image in third),
        ",".join(map(str, cycle_lengths(third))),
        "", "", "", "", "",
    ))
    return "\n".join([
        *metadata,
        "\t".join(fields),
        *("\t".join(row) for row in rows),
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("coefficients", type=Path)
    parser.add_argument("--precision-bits", type=int, default=256)
    parser.add_argument("--steps-per-loop", type=int, default=512)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.precision_bits < 128:
        parser.error("--precision-bits must be at least 128")
    if args.steps_per_loop < 64:
        parser.error("--steps-per-loop must be at least 64")
    field = ComplexField(args.precision_bits)
    metadata, values = read_coefficients(args.coefficients, field)
    p, f, q = polynomials(values, field)
    identity_error = max(
        abs(coefficient)
        for coefficient in p + f - q
    )
    if identity_error > field(2) ** (-(field.precision() // 2)):
        raise RuntimeError(f"P + F - Q identity is inaccurate: {identity_error}")
    roots = base_roots(p, q, field)
    first_coarse = lift_loop(
        p, q, roots, field(0), field(0), args.steps_per_loop, field
    )
    second_coarse = lift_loop(
        p,
        q,
        roots,
        field(1),
        RealField(field.precision()).pi(),
        args.steps_per_loop,
        field,
    )
    fine_steps = 2 * args.steps_per_loop
    first = lift_loop(p, q, roots, field(0), field(0), fine_steps, field)
    second = lift_loop(
        p,
        q,
        roots,
        field(1),
        RealField(field.precision()).pi(),
        fine_steps,
        field,
    )
    if (
        first["images"] != first_coarse["images"]
        or second["images"] != second_coarse["images"]
    ):
        raise RuntimeError("loop permutations changed when the mesh doubled")
    args.output.write_text(
        render(
            args.coefficients,
            metadata,
            args.precision_bits,
            args.steps_per_loop,
            fine_steps,
            first,
            second,
        ),
        encoding="utf-8",
    )
    print(
        f"zero_cycles={cycle_lengths(first['images'])} "
        f"one_cycles={cycle_lengths(second['images'])} "
        f"infinity_cycles="
        f"{cycle_lengths(inverse_product(first['images'], second['images']))}"
    )


if __name__ == "__main__":
    main()
