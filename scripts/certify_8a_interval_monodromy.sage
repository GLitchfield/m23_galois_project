#!/usr/bin/env python3
"""Certify cover monodromy by interval root enclosures over loop arcs."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

from sage.all import (
    ComplexField,
    ComplexBallField,
    PolynomialRing,
    QQ,
    RealBallField,
    RealIntervalField,
)
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


def read_metadata_rows(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            data_lines.append(line)
    return metadata, list(csv.DictReader(data_lines, delimiter="\t"))


def interval_element(entries, generator):
    values = entries if isinstance(entries, list) else [entries]
    result = generator.parent()(0)
    for coefficient in reversed(values):
        result = result * generator + QQ(coefficient)
    return result


def relation_element(relation: tuple[int, ...], generator):
    numerator = generator.parent()(0)
    for coefficient in reversed(relation[:-1]):
        numerator = numerator * generator + coefficient
    return -numerator / relation[-1]


def select_embedding(
    defining_polynomial,
    c2_relation: tuple[int, ...],
    c2_approximation,
    interval_field,
):
    rational_ring = PolynomialRing(QQ, "T")
    polynomial = rational_ring(defining_polynomial)
    roots = polynomial.roots(ring=interval_field, multiplicities=False)
    if len(roots) != polynomial.degree():
        raise RuntimeError("field polynomial did not return every embedding")
    comparison_field = c2_approximation.parent()
    ranked = sorted(
        (
            abs(
                comparison_field(relation_element(c2_relation, root).mid())
                - c2_approximation
            ),
            root,
        )
        for root in roots
    )
    if ranked[0][0] == ranked[1][0]:
        raise RuntimeError("field embedding selection is ambiguous")
    return ranked[0][1], ranked[0][0], ranked[1][0]


def path_interval(label: str, segment: int, steps: int, real_interval_field):
    fraction = real_interval_field(segment, segment + 1) / steps
    theta = 2 * real_interval_field.pi() * fraction
    unit = theta.cos(), theta.sin()
    if label == "zero":
        return unit[0] / 2, unit[1] / 2
    if label == "one":
        return 1 - unit[0] / 2, -unit[1] / 2
    raise ValueError(f"unknown loop: {label}")


def point_root_enclosures(numerator, denominator, parameter, interval_field):
    polynomial = numerator - interval_field(*parameter) * denominator
    roots = polynomial.roots(multiplicities=False)
    if len(roots) != 23:
        raise RuntimeError(f"point polynomial returned {len(roots)} roots")
    if any(left.overlaps(right)
           for index, left in enumerate(roots)
           for right in roots[index + 1:]):
        raise RuntimeError("point root enclosures overlap")
    return roots


def path_midpoint(label: str, segment: int, steps: int, real_ball_field):
    fraction = real_ball_field(2 * segment + 1) / (2 * steps)
    theta = 2 * real_ball_field.pi() * fraction
    unit = theta.cos(), theta.sin()
    if label == "zero":
        return unit[0] / 2, unit[1] / 2
    if label == "one":
        return 1 - unit[0] / 2, -unit[1] / 2
    raise ValueError(f"unknown loop: {label}")


def path_point(label: str, point: int, steps: int, real_ball_field):
    fraction = real_ball_field(point) / steps
    theta = 2 * real_ball_field.pi() * fraction
    unit = theta.cos(), theta.sin()
    if label == "zero":
        return unit[0] / 2, unit[1] / 2
    if label == "one":
        return 1 - unit[0] / 2, -unit[1] / 2
    raise ValueError(f"unknown loop: {label}")


def strictly_contains(outer, inner) -> bool:
    outer_real = outer.real().endpoints()
    outer_imaginary = outer.imag().endpoints()
    inner_real = inner.real().endpoints()
    inner_imaginary = inner.imag().endpoints()
    return (
        outer_real[0] < inner_real[0]
        and inner_real[1] < outer_real[1]
        and outer_imaginary[0] < inner_imaginary[0]
        and inner_imaginary[1] < outer_imaginary[1]
    )


def centered_coefficients(polynomial, center):
    original = polynomial.list()
    shifted = [original[-1]]
    for coefficient in reversed(original[:-1]):
        updated = [center.parent()(0) for _ in range(len(shifted) + 1)]
        for order, value in enumerate(shifted):
            updated[order] += center * value
            updated[order + 1] += value
        updated[0] += coefficient
        shifted = updated
    return shifted


def derivative_coefficients(coefficients):
    return [
        (order + 1) * coefficients[order + 1]
        for order in range(len(coefficients) - 1)
    ]


def centered_evaluate(coefficients, delta):
    value = coefficients[0].parent()(0)
    for coefficient in reversed(coefficients):
        value = value * delta + coefficient
    return value


def predictor_residual_coefficients(
    numerator_coefficients,
    denominator_coefficients,
    midpoint_parameter,
    slope,
):
    coefficients = []
    slope_power = slope.parent()(1)
    previous_denominator_term = slope.parent()(0)
    count = max(
        len(numerator_coefficients), len(denominator_coefficients) + 1
    )
    for order in range(count):
        numerator_coefficient = (
            numerator_coefficients[order]
            if order < len(numerator_coefficients)
            else slope.parent()(0)
        )
        denominator_coefficient = (
            denominator_coefficients[order]
            if order < len(denominator_coefficients)
            else slope.parent()(0)
        )
        coefficient = (
            numerator_coefficient
            - midpoint_parameter * denominator_coefficient
        ) * slope_power
        if order:
            coefficient -= previous_denominator_term
        coefficients.append(coefficient)
        previous_denominator_term = denominator_coefficient * slope_power
        slope_power *= slope
    return coefficients


def certified_root_tubes(
    numerator,
    denominator,
    parameter,
    midpoint,
    start_parameter,
    end_parameter,
    interval_field,
    real_ball_field,
):
    parameter_ball = interval_field(*parameter)
    midpoint_ball = interval_field(*midpoint)
    midpoint_roots = point_root_enclosures(
        numerator, denominator, midpoint, interval_field
    )
    parameter_radius = float(abs(parameter_ball - midpoint_ball).upper())
    start_boxes = []
    end_boxes = []
    tubes = []
    contraction_bounds = []
    for root_index, root in enumerate(midpoint_roots):
        center = interval_field(root.mid())
        numerator_coefficients = centered_coefficients(
            numerator, center
        )
        denominator_coefficients = centered_coefficients(
            denominator, center
        )
        numerator_derivative_coefficients = derivative_coefficients(
            numerator_coefficients
        )
        denominator_derivative_coefficients = derivative_coefficients(
            denominator_coefficients
        )
        midpoint_derivative = (
            numerator_derivative_coefficients[0]
            - midpoint_ball * denominator_derivative_coefficients[0]
        )
        if midpoint_derivative.contains_zero():
            raise RuntimeError(
                f"midpoint derivative contains zero for root {root_index}"
            )
        inverse_derivative = interval_field(
            (1 / midpoint_derivative).mid()
        )
        slope = interval_field(
            (denominator_coefficients[0] / midpoint_derivative).mid()
        )
        residual_coefficients = predictor_residual_coefficients(
            numerator_coefficients,
            denominator_coefficients,
            midpoint_ball,
            slope,
        )
        sensitivity = float(
            abs(
                denominator_coefficients[0] / midpoint_derivative
            ).upper()
        )
        radius = max(
            16.0 * float(root.rad()),
            0.01 * sensitivity * parameter_radius,
            2.0 ** (-interval_field.precision() // 3),
        )
        certified = False
        last_diagnostics = ""
        best_diagnostics = (float("inf"), "")
        for _ in range(100):
            error_box = interval_field(0).add_error(
                real_ball_field(radius)
            )
            parameter_delta = parameter_ball - midpoint_ball
            predictor_delta = slope * parameter_delta
            root_box = center + predictor_delta + error_box
            delta = root_box - center
            derivative_box = (
                centered_evaluate(
                    numerator_derivative_coefficients, delta
                )
                - parameter_ball
                * centered_evaluate(
                    denominator_derivative_coefficients, delta
                )
            )
            contraction = 1 - inverse_derivative * derivative_box
            contraction_bound = float(abs(contraction).upper())
            residual = centered_evaluate(
                residual_coefficients, parameter_delta
            )
            image = (
                -inverse_derivative * residual
                + contraction * error_box
            )
            image_offset = float(abs(image).upper())
            last_diagnostics = (
                f"radius={radius:.6g}, image_offset={image_offset:.6g}, "
                f"contraction={contraction_bound:.6g}, "
                f"sensitivity={sensitivity:.6g}, "
                f"parameter_radius={parameter_radius:.6g}"
            )
            score = image_offset / radius
            if score < best_diagnostics[0]:
                best_diagnostics = (score, last_diagnostics)
            if (
                contraction_bound < 1
                and strictly_contains(error_box, image)
            ):
                tubes.append(root_box)
                start_ball = interval_field(*start_parameter)
                end_ball = interval_field(*end_parameter)
                start_boxes.append(
                    center
                    + slope * (start_ball - midpoint_ball)
                    + error_box
                )
                end_boxes.append(
                    center
                    + slope * (end_ball - midpoint_ball)
                    + error_box
                )
                contraction_bounds.append(contraction_bound)
                certified = True
                break
            radius *= 1.2
        if not certified:
            raise RuntimeError(
                f"contraction certificate failed for root {root_index}: "
                f"best: {best_diagnostics[1]}; last: {last_diagnostics}"
            )
    if any(left.overlaps(right)
           for index, left in enumerate(tubes)
           for right in tubes[index + 1:]):
        raise RuntimeError("certified root tubes overlap within one segment")
    return (
        start_boxes,
        end_boxes,
        max(contraction_bounds),
        max(float(tube.diameter()) for tube in tubes),
    )


def unique_overlap_matching(left, right) -> list[int]:
    matching = []
    for root in left:
        overlaps = [
            index for index, candidate in enumerate(right)
            if root.overlaps(candidate)
        ]
        if len(overlaps) != 1:
            raise RuntimeError(
                f"root enclosure has {len(overlaps)} overlaps across segments"
            )
        matching.append(overlaps[0])
    if len(set(matching)) != len(matching):
        raise RuntimeError("segment overlap matching is not bijective")
    return matching


def compose_images(images: list[int], matching: list[int]) -> list[int]:
    return [matching[index] for index in images]


def cycle_lengths(images: list[int]) -> tuple[int, ...]:
    seen: set[int] = set()
    lengths = []
    for start in range(len(images)):
        if start in seen:
            continue
        current = start
        length = 0
        while current not in seen:
            seen.add(current)
            current = images[current]
            length += 1
        lengths.append(length)
    return tuple(sorted(lengths, reverse=True))


def inverse_product(left: list[int], right: list[int]) -> list[int]:
    product = [right[left[index]] for index in range(len(left))]
    inverse = [0] * len(left)
    for index, image in enumerate(product):
        inverse[image] = index
    return inverse


def render(
    candidate: Path,
    recovery: Path,
    coefficients: Path,
    precision_bits: int,
    steps_per_loop: int,
    results,
) -> str:
    infinity = inverse_product(
        results["zero"]["images"], results["one"]["images"]
    )
    metadata = [
        "# format\tm23_8a_interval_monodromy_v1",
        f"# code_revision\t{git_revision()}",
        f"# candidate\t{display_path(candidate)}",
        f"# candidate_sha256\t{sha256(candidate)}",
        f"# recovery\t{display_path(recovery)}",
        f"# recovery_sha256\t{sha256(recovery)}",
        f"# embedding_source\t{display_path(coefficients)}",
        f"# embedding_source_sha256\t{sha256(coefficients)}",
        f"# precision_bits\t{precision_bits}",
        f"# steps_per_loop\t{steps_per_loop}",
        f"# sage_version\t{SAGE_VERSION}",
        "# basepoint\t0.5",
        "# loops\tcounterclockwise circles of radius 0.5 around 0 and 1",
        "# parameter_enclosure\ttrig interval enclosure of each complete arc",
        "# root_model\taffine predictor plus complex interval error box",
        "# proof_condition\tstrict self-map and contraction bound below one",
        "# all_segments_certified\ttrue",
        "# segment_root_tubes_pairwise_disjoint\ttrue",
        "# adjacent_endpoint_matching_bijective\ttrue",
        "# interpretation\ttrig-and-coefficient interval certificate for exact cover monodromy",
    ]
    fields = (
        "loop",
        "images",
        "cycle_lengths",
        "segment_count",
        "maximum_tube_diameter",
        "maximum_contraction_bound",
    )
    rows = []
    for label in ("zero", "one"):
        result = results[label]
        rows.append((
            label,
            ",".join(str(image + 1) for image in result["images"]),
            ",".join(map(str, cycle_lengths(result["images"]))),
            str(steps_per_loop),
            f"{result['maximum_diameter']:.17g}",
            f"{result['maximum_contraction']:.17g}",
        ))
    rows.append((
        "infinity",
        ",".join(str(image + 1) for image in infinity),
        ",".join(map(str, cycle_lengths(infinity))),
        "",
        "",
        "",
    ))
    return "\n".join([
        *metadata,
        "\t".join(fields),
        *("\t".join(row) for row in rows),
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("recovery", type=Path)
    parser.add_argument("coefficients", type=Path)
    parser.add_argument("--precision-bits", type=int, default=256)
    parser.add_argument("--steps-per-loop", type=int, default=1024)
    parser.add_argument("--probe-only", action="store_true")
    parser.add_argument("--probe-segment", type=int, default=0)
    parser.add_argument(
        "--loop", choices=("both", "zero", "one"), default="both"
    )
    parser.add_argument("--progress-every", type=int, default=256)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.precision_bits < 128:
        parser.error("--precision-bits must be at least 128")
    if args.steps_per_loop < 8:
        parser.error("--steps-per-loop must be at least 8")
    if not 0 <= args.probe_segment < args.steps_per_loop:
        parser.error("--probe-segment must be smaller than --steps-per-loop")
    if args.progress_every < 0:
        parser.error("--progress-every must be nonnegative")
    if args.output is not None and args.loop != "both":
        parser.error("--output requires --loop both")

    candidate = json.loads(args.candidate.read_text(encoding="utf-8"))
    recovery_metadata, recovery_rows = read_metadata_rows(args.recovery)
    coefficient_metadata, coefficient_rows = read_metadata_rows(args.coefficients)
    if recovery_metadata.get("exact_coefficient_identity") != "true":
        raise RuntimeError("recovery artifact does not record an exact identity")
    if coefficient_metadata.get("precision_bits") not in {"8192", "16384"}:
        raise RuntimeError("embedding source precision is too low")

    c2_row = next(row for row in recovery_rows if row["name"] == "c2")
    c2_relation = tuple(
        int(entry) for entry in c2_row["relation_coefficients"].split(",")
    )
    coefficient_by_name = {row["name"]: row for row in coefficient_rows}
    comparison_field = ComplexField(512)
    c2_approximation = comparison_field(
        coefficient_by_name["c2"]["real"],
        coefficient_by_name["c2"]["imaginary"],
    )

    interval_field = ComplexBallField(args.precision_bits)
    real_ball_field = RealBallField(args.precision_bits)
    real_interval_field = RealIntervalField(args.precision_bits)
    generator, selected_distance, next_distance = select_embedding(
        candidate["field"]["defining_polynomial"],
        c2_relation,
        c2_approximation,
        interval_field,
    )
    if next_distance < comparison_field(1e-20):
        raise RuntimeError("selected field embedding is not separated")
    if (
        selected_distance != 0
        and next_distance / selected_distance < 10**20
    ):
        raise RuntimeError("selected field embedding is not strongly separated")

    polynomial_ring = PolynomialRing(interval_field, "x")
    numerator = polynomial_ring([
        interval_element(coefficient, generator)
        for coefficient in candidate["map"]["numerator"]
    ])
    denominator = polynomial_ring([
        interval_element(coefficient, generator)
        for coefficient in candidate["map"]["denominator"]
    ])

    base_roots = point_root_enclosures(
        numerator,
        denominator,
        (real_ball_field(1) / 2, real_ball_field(0)),
        interval_field,
    )
    labels = ("zero", "one") if args.loop == "both" else (args.loop,)
    if args.probe_only:
        for label in labels:
            (
                start_boxes,
                end_boxes,
                contraction_bound,
                maximum_diameter,
            ) = certified_root_tubes(
                numerator,
                denominator,
                path_interval(
                    label,
                    args.probe_segment,
                    args.steps_per_loop,
                    real_interval_field,
                ),
                path_midpoint(
                    label,
                    args.probe_segment,
                    args.steps_per_loop,
                    real_ball_field,
                ),
                path_point(
                    label,
                    args.probe_segment,
                    args.steps_per_loop,
                    real_ball_field,
                ),
                path_point(
                    label,
                    args.probe_segment + 1,
                    args.steps_per_loop,
                    real_ball_field,
                ),
                interval_field,
                real_ball_field,
            )
            print(
                f"{label}: first_segment_certified=true "
                f"maximum_box_diameter="
                f"{maximum_diameter:.6g} "
                f"maximum_contraction_bound={contraction_bound:.6g}"
            )
        return
    results = {}
    for label in labels:
        started = time.monotonic()
        images = list(range(23))
        previous = base_roots
        maximum_diameter = 0
        maximum_contraction = 0
        for segment in range(args.steps_per_loop):
            (
                current_start,
                current_end,
                contraction_bound,
                segment_diameter,
            ) = certified_root_tubes(
                numerator,
                denominator,
                path_interval(
                    label, segment, args.steps_per_loop, real_interval_field
                ),
                path_midpoint(
                    label, segment, args.steps_per_loop, real_ball_field
                ),
                path_point(
                    label,
                    segment,
                    args.steps_per_loop,
                    real_ball_field,
                ),
                path_point(
                    label,
                    segment + 1,
                    args.steps_per_loop,
                    real_ball_field,
                ),
                interval_field,
                real_ball_field,
            )
            matching = unique_overlap_matching(previous, current_start)
            images = compose_images(images, matching)
            maximum_diameter = max(
                maximum_diameter,
                segment_diameter,
            )
            maximum_contraction = max(
                maximum_contraction, contraction_bound
            )
            previous = current_end
            if (
                args.progress_every
                and (segment + 1) % args.progress_every == 0
            ):
                elapsed = time.monotonic() - started
                print(
                    f"progress loop={label} "
                    f"segments={segment + 1}/{args.steps_per_loop} "
                    f"elapsed_seconds={elapsed:.1f}",
                    file=sys.stderr,
                    flush=True,
                )
        final_matching = unique_overlap_matching(previous, base_roots)
        images = compose_images(images, final_matching)
        results[label] = {
            "images": images,
            "maximum_diameter": maximum_diameter,
            "maximum_contraction": maximum_contraction,
        }
        print(
            f"{label}: cycles={','.join(map(str, cycle_lengths(images)))} "
            f"maximum_interval_diameter={maximum_diameter:.6g} "
            f"maximum_contraction_bound={maximum_contraction:.6g} "
            f"images={','.join(str(image + 1) for image in images)}"
        )
    if args.output is not None:
        args.output.write_text(
            render(
                args.candidate,
                args.recovery,
                args.coefficients,
                args.precision_bits,
                args.steps_per_loop,
                results,
            ),
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
