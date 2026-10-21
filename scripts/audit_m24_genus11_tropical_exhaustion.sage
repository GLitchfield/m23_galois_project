#!/usr/bin/env sage
"""Exhaust the 2-adic valuation space of the M24 genus-11 model."""

from __future__ import annotations

import argparse
import importlib.util
import subprocess
from importlib.machinery import SourceFileLoader
from pathlib import Path

from sage.all import Polyhedron, PolynomialRing, QQ, gcd, vector, valuation
from sage.env import SAGE_VERSION


SCHEMA = "m23-m24-genus11-tropical-exhaustion-v1"
LOCAL_ELIMINATION = Path(
    "data/derived/m24_koenig_genus11_local_elimination.tsv"
)
MINUS_TWO_CLUSTERS = Path(
    "data/derived/m24_koenig_genus11_minus2_clusters.tsv"
)


def load_module(filename, name):
    path = Path(__file__).with_name(filename)
    loader = SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


boundary = load_module(
    "audit_m24_genus11_boundary.sage",
    "m24_genus11_boundary_tropical_exhaustion",
)
unit = load_module(
    "audit_m24_genus11_unit_charts.sage",
    "m24_genus11_unit_tropical_exhaustion",
)


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def parse_summary(path):
    metadata = {}
    values = {}
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            key, value = line.split("\t", 1)
            values[key] = value
    return metadata, values


def support_points(polynomial):
    return sorted(
        {
            (
                exponent[0],
                exponent[1],
                int(valuation(coefficient, 2)),
            )
            for exponent, coefficient in polynomial.dict().items()
        }
    )


def difference(left, right):
    return (
        right[2] - left[2],
        right[0] - left[0],
        right[1] - left[1],
    )


def minimum_signature(points, point):
    values = [
        item[2] + item[0] * point[0] + item[1] * point[1]
        for item in points
    ]
    minimum = min(values)
    return tuple(
        item
        for item, value in zip(points, values)
        if value == minimum
    )


def tropical_complex(polynomial):
    points = support_points(polynomial)
    newton = Polyhedron(vertices=points)
    lower_facets = [
        item
        for item in newton.inequality_generator()
        if item.A()[2] > 0
    ]
    lower_points = sorted(
        point
        for point in points
        if any(
            facet.eval(vector(point)) == 0
            for facet in lower_facets
        )
    )
    regions = {}
    for left_index, left in enumerate(lower_points):
        for right in lower_points[left_index + 1 :]:
            region = Polyhedron(
                ieqs=[
                    difference(left, point)
                    for point in lower_points
                ],
                eqns=[difference(left, right)],
            )
            if region.is_empty():
                continue
            key = (
                tuple(
                    sorted(tuple(vertex) for vertex in region.vertices())
                ),
                tuple(sorted(tuple(ray) for ray in region.rays())),
                tuple(sorted(tuple(line) for line in region.lines())),
            )
            regions[key] = region
    vertices = sorted(
        {
            (
                QQ(facet.A()[0]) / facet.A()[2],
                QQ(facet.A()[1]) / facet.A()[2],
            )
            for facet in lower_facets
        }
    )
    return {
        "points": points,
        "lower_facets": lower_facets,
        "lower_points": lower_points,
        "regions": regions,
        "vertices": vertices,
    }


def primitive_direction(raw):
    denominator = raw.denominator()
    entries = [int(value * denominator) for value in raw]
    divisor = gcd(entries)
    return vector(QQ, [value // divisor for value in entries])


def strict_lattice_ray(region, points):
    origin = vector(QQ, region.vertices()[0])
    direction = primitive_direction(vector(QQ, region.rays()[0]))
    normal = vector(QQ, [-direction[1], direction[0]])
    constant = normal * origin
    if constant.denominator() != 1:
        return None

    bound = abs(int(constant)) + 20
    lattice_point = None
    for left in range(-bound, bound + 1):
        for right in range(-bound, bound + 1):
            candidate = vector(QQ, [left, right])
            if normal * candidate == constant:
                lattice_point = candidate
                break
        if lattice_point is not None:
            break
    assert lattice_point is not None

    coordinate = 0 if direction[0] else 1
    parameter = (
        (lattice_point[coordinate] - origin[coordinate])
        / direction[coordinate]
    )
    while parameter < 0:
        lattice_point += direction
        parameter += 1
    while parameter >= 1:
        lattice_point -= direction
        parameter -= 1
    if parameter == 0:
        lattice_point += direction
    assert (
        (lattice_point[coordinate] - origin[coordinate])
        / direction[coordinate]
        > 0
    )
    signature = minimum_signature(points, lattice_point)
    assert len(signature) % 2 == 0
    return tuple(lattice_point), tuple(direction)


def original_tropical_certificate(polynomial):
    complex_data = tropical_complex(polynomial)
    assert len(complex_data["points"]) == 633
    assert len(complex_data["lower_facets"]) == 12
    assert len(complex_data["lower_points"]) == 21
    assert len(complex_data["regions"]) == 32

    rays = []
    for region in complex_data["regions"].values():
        if not region.rays():
            continue
        descriptor = strict_lattice_ray(
            region,
            complex_data["points"],
        )
        if descriptor is not None:
            rays.append(descriptor)
    rays.sort()
    expected_rays = sorted(
        [
            ((0, 1), (1, 0)),
            ((-4, -1), (-2, -1)),
            ((-4, 1), (-2, -1)),
            ((-3, 2), (0, 1)),
            ((-2, -1), (0, -1)),
            ((-2, 3), (0, 1)),
        ]
    )
    assert rays == expected_rays

    integral_vertices = []
    for point in complex_data["vertices"]:
        if any(value.denominator() != 1 for value in point):
            continue
        signature = minimum_signature(
            complex_data["points"],
            point,
        )
        if len(signature) % 2 == 0:
            integral_vertices.append(tuple(point))
    assert integral_vertices == [(-2, 0)]

    compact_candidates = set()
    for region in complex_data["regions"].values():
        if region.rays() or region.dim() != 1:
            continue
        for point in region.integral_points():
            signature = minimum_signature(
                complex_data["points"],
                point,
            )
            if len(signature) % 2 == 0:
                compact_candidates.add(tuple(point))
    assert compact_candidates == {(-2, 0)}
    return {
        "lower_facets": len(complex_data["lower_facets"]),
        "lower_points": len(complex_data["lower_points"]),
        "curve_regions": sum(
            region.dim() == 1
            for region in complex_data["regions"].values()
        ),
        "unbounded_regions": sum(
            bool(region.rays())
            for region in complex_data["regions"].values()
        ),
        "rays": rays,
        "vertices": integral_vertices,
    }


def normalize_two_adic(polynomial):
    exponent = min(
        valuation(coefficient, 2)
        for coefficient in polynomial.coefficients()
    )
    return (
        polynomial.parent()(polynomial * QQ(2) ** (-exponent)),
        int(exponent),
    )


def face_audit_budget(polynomial, depth=12):
    ring = polynomial.parent()
    t, x = ring.gens()
    initial, exponent = normalize_two_adic(
        polynomial(t=1 + 2 * t, x=1 + 2 * x)
    )
    active = [(initial, exponent)]
    maximum_budget = exponent
    levels = []
    for _ in range(depth):
        next_active = []
        dead = 0
        for chart, budget in active:
            roots = []
            for t_value in (0, 1):
                for x_value in (0, 1):
                    if int(chart(t=t_value, x=x_value)) % 2 == 0:
                        roots.append((t_value, x_value))
            if not roots:
                dead += 1
            for t_value, x_value in roots:
                child, child_exponent = normalize_two_adic(
                    chart(
                        t=t_value + 2 * t,
                        x=x_value + 2 * x,
                    )
                )
                child_budget = budget + child_exponent
                maximum_budget = max(maximum_budget, child_budget)
                next_active.append((child, child_budget))
        levels.append((len(active), dead, len(next_active)))
        active = next_active
        if not active:
            break
    assert not active
    return levels, maximum_budget


def stable_face_certificate(
    polynomial,
    start,
    direction,
    expected_margin,
    expected_budget,
    expected_levels,
):
    ring = polynomial.parent()
    t, x = ring.gens()
    raw = ring(
        polynomial(
            t=(QQ(2) ** start[0]) * t,
            x=(QQ(2) ** start[1]) * x,
        )
    )
    minimum = min(
        valuation(coefficient, 2)
        for coefficient in raw.coefficients()
    )
    chart = ring(raw * QQ(2) ** (-minimum))
    minimum_slope = min(
        exponent[0] * direction[0]
        + exponent[1] * direction[1]
        for exponent, coefficient in chart.dict().items()
        if valuation(coefficient, 2) == 0
    )
    face = ring(
        sum(
            coefficient
            * t**exponent[0]
            * x**exponent[1]
            for exponent, coefficient in chart.dict().items()
            if (
                exponent[0] * direction[0]
                + exponent[1] * direction[1]
                == minimum_slope
            )
        )
    )
    off_face = [
        (
            valuation(coefficient, 2),
            exponent[0] * direction[0]
            + exponent[1] * direction[1]
            - minimum_slope,
        )
        for exponent, coefficient in chart.dict().items()
        if (
            exponent[0] * direction[0]
            + exponent[1] * direction[1]
            > minimum_slope
        )
    ]
    assert off_face
    assert all(slope > 0 for _, slope in off_face)
    margin = int(min(value for value, _ in off_face))
    levels, budget = face_audit_budget(face)
    assert margin == expected_margin
    assert budget == expected_budget
    assert levels == expected_levels
    assert margin > budget
    return {
        "start": start,
        "direction": direction,
        "margin": margin,
        "budget": budget,
        "levels": levels,
    }


def nonnegative_on_polyhedron(polyhedron, affine):
    constant, left, right = affine
    assert all(
        left * ray[0] + right * ray[1] >= 0
        for ray in polyhedron.rays()
    )
    return min(
        constant + left * vertex[0] + right * vertex[1]
        for vertex in polyhedron.vertices()
    )


def center_minus_two_tail(polynomial):
    ring = polynomial.parent()
    t, y = ring.gens()
    translated = ring(polynomial(t=t, x=-2 + y))
    terms = [
        (
            exponent[0],
            exponent[1],
            int(valuation(coefficient, 2)),
        )
        for exponent, coefficient in translated.dict().items()
    ]
    t_square = next(
        value for left, right, value in terms
        if (left, right) == (2, 0)
    )
    y_square = next(
        value for left, right, value in terms
        if (left, right) == (0, 2)
    )
    assert (t_square, y_square) == (32, 29)

    # Coordinates are (v_2(t), v_2(y)). Since v_2(x)=1 forces
    # y=x+2 to have valuation at least two, these two cones cover the
    # integral tail v_2(t)>=8.
    t_minimal = Polyhedron(
        ieqs=[
            (-8, 1, 0),
            (-2, 0, 1),
            (y_square - t_square, -2, 2),
        ]
    )
    y_minimal = Polyhedron(
        ieqs=[
            (-8, 1, 0),
            (-2, 0, 1),
            (t_square - y_square, 2, -2),
        ]
    )
    t_margins = []
    y_margins = []
    for left, right, value in terms:
        if (left, right) != (2, 0):
            t_margins.append(
                nonnegative_on_polyhedron(
                    t_minimal,
                    (value - t_square, left - 2, right),
                )
            )
        if (left, right) != (0, 2):
            y_margins.append(
                nonnegative_on_polyhedron(
                    y_minimal,
                    (value - y_square, left, right - 2),
                )
            )
    assert min(t_margins) == 0
    assert min(value for value in t_margins if value) == 9
    assert min(y_margins) == 0
    assert min(value for value in y_margins if value) == 1
    # Equality of the two leading valuations would require
    # v_2(y)=v_2(t)+3/2, impossible for integer valuations.
    return {
        "leading_valuations": (t_square, y_square),
        "t_margin": 9,
        "y_margin": 1,
    }


def quarter_local_complex(translated):
    complex_data = tropical_complex(translated)
    assert len(complex_data["lower_facets"]) == 10
    assert len(complex_data["lower_points"]) == 28
    assert len(complex_data["regions"]) == 30
    domain = Polyhedron(ieqs=[(1, 1, 0), (-7, 0, 1)])
    relevant = []
    for region in complex_data["regions"].values():
        if region.dim() != 1:
            continue
        interior = (
            vector(region.vertices()[0])
            + (
                QQ(1) / 3 * vector(region.rays()[0])
                if region.rays()
                else QQ(1) / 2
                * (
                    vector(region.vertices()[-1])
                    - vector(region.vertices()[0])
                )
            )
        )
        if len(minimum_signature(
            complex_data["points"], interior
        )) % 2:
            continue
        intersection = region.intersection(domain)
        if intersection.is_empty():
            continue
        if not intersection.rays():
            continue
        origin = tuple(intersection.vertices()[0])
        if (
            all(value.denominator() == 1 for value in origin)
            and len(minimum_signature(
                complex_data["points"], origin
            )) % 2 == 0
        ):
            descriptor = (
                origin,
                tuple(primitive_direction(
                    vector(QQ, intersection.rays()[0])
                )),
            )
        else:
            descriptor = strict_lattice_ray(
                intersection,
                complex_data["points"],
            )
        if descriptor is not None:
            relevant.append(descriptor)
    relevant.sort()
    assert relevant == sorted(
        [
            ((-1, 7), (0, 1)),
            ((7, 7), (2, 1)),
        ]
    )
    return relevant


def quarter_weighted_tail(polynomial):
    ring = polynomial.parent()
    t, x = ring.gens()
    translated = ring(polynomial(t=QQ(1) / 4 + t, x=x))
    relevant = quarter_local_complex(translated)

    delta_ray = stable_face_certificate(
        translated,
        (-1, 7),
        (0, 1),
        6,
        1,
        [(1, 1, 0)],
    )

    terms = [
        (
            exponent[0],
            exponent[1],
            int(valuation(coefficient, 2)),
        )
        for exponent, coefficient in translated.dict().items()
    ]
    delta_square = next(
        value for left, right, value in terms
        if (left, right) == (2, 0)
    )
    x_fourth = next(
        value for left, right, value in terms
        if (left, right) == (0, 4)
    )
    assert (delta_square, x_fourth) == (22, 8)
    delta_minimal = Polyhedron(
        ieqs=[
            (-7, 1, 0),
            (-7, 0, 1),
            (-7, -1, 2),
        ]
    )
    x_minimal = Polyhedron(
        ieqs=[
            (-7, 1, 0),
            (-7, 0, 1),
            (7, 1, -2),
        ]
    )
    delta_margins = []
    x_margins = []
    for left, right, value in terms:
        if (left, right) != (2, 0):
            delta_margins.append(
                nonnegative_on_polyhedron(
                    delta_minimal,
                    (value - 22, left - 2, right),
                )
            )
        if (left, right) != (0, 4):
            x_margins.append(
                nonnegative_on_polyhedron(
                    x_minimal,
                    (value - 8, left, right - 4),
                )
            )
    assert min(delta_margins) == 0
    assert min(value for value in delta_margins if value) == 6
    assert min(x_margins) == 0
    assert min(value for value in x_margins if value) == 6
    # On the equality ray d=2k-7, division by 2^(4k+8)
    # leaves c^2+X^4 modulo 8; both units are odd.
    return {
        "relevant_rays": relevant,
        "delta_ray": delta_ray,
        "leading_valuations": (22, 8),
        "remainder_margin": 6,
        "mod_8_value": 2,
    }


def finite_audits(polynomial):
    candidates = boundary.tropical_candidates(polynomial)
    audits = {
        candidate: boundary.scaled_unit_chart(
            polynomial, *candidate
        )
        for candidate in candidates
    }
    dead = [
        candidate
        for candidate, result in audits.items()
        if result[0] == "dead"
    ]
    unresolved = [
        candidate
        for candidate, result in audits.items()
        if result[0] == "unresolved"
    ]
    assert len(candidates) == 100
    assert len(dead) == 92
    assert unresolved == [
        (-6, 0),
        (-2, 0),
        (-2, 7),
        (-2, 8),
        (-2, 9),
        (-2, 10),
        (-2, 11),
        (-2, 12),
    ]

    integral_levels = []
    for t_valuation in range(8):
        status, levels, _ = boundary.scaled_unit_chart(
            polynomial,
            t_valuation,
            1,
        )
        assert status == "dead"
        integral_levels.append(len(levels))
    assert integral_levels == list(range(1, 9))
    return {
        "candidate_count": len(candidates),
        "dead_count": len(dead),
        "unresolved": unresolved,
        "integral_levels": integral_levels,
    }


def summary_text(
    tropical,
    finite,
    tails,
    center_tail,
    quarter_tail,
):
    ray_text = ";".join(
        f"{start[0]},{start[1]}:{direction[0]},{direction[1]}"
        for start, direction in tropical["rays"]
    )
    tail_text = ";".join(
        f"{item['start'][0]},{item['start'][1]}:"
        f"{item['direction'][0]},{item['direction'][1]}:"
        f"{item['margin']},{item['budget']}"
        for item in tails
    )
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        "# source\tKönig dissertation Theorem 5.2 and Appendix 5.1.12",
        f"# archive_sha256\t{boundary.ARCHIVE_SHA256}",
        f"# model_sha256\t{boundary.MODEL_SHA256}",
        "# status\tcomplete_Q2_normalization_obstruction",
        "newton_support_count\t633",
        f"newton_lower_facet_count\t{tropical['lower_facets']}",
        f"newton_lower_support_count\t{tropical['lower_points']}",
        f"newton_curve_region_count\t{tropical['curve_regions']}",
        f"newton_unbounded_region_count\t{tropical['unbounded_regions']}",
        f"integer_candidate_rays\t{ray_text}",
        "integer_candidate_vertex\t-2,0",
        "bounded_window\tt:-40:-1,x:-40:12",
        f"bounded_candidate_count\t{finite['candidate_count']}",
        f"bounded_dead_count\t{finite['dead_count']}",
        "bounded_resolved_minus6\tTest0149:no_Q2_normalization_branch",
        "bounded_resolved_minus2\tTest0150:all_4356_boxes_excluded",
        "negative_tail_face_certificates\t" + tail_text,
        "quarter_local_candidate_rays\td=-1,k>=7;d=2k-7,k>=7",
        "quarter_delta_minus1_face_margin_budget\t"
        + f"{quarter_tail['delta_ray']['margin']},"
        + f"{quarter_tail['delta_ray']['budget']}",
        "quarter_weighted_leading_valuations\t22,8",
        "quarter_weighted_remainder_margin\t"
        + str(quarter_tail["remainder_margin"]),
        "quarter_weighted_unit_sum_mod_8\t"
        + str(quarter_tail["mod_8_value"]),
        "quarter_tail_status\tno_Q2_point_for_v2_x_at_least_7",
        "integral_ray_finite_dead_levels\t"
        + ",".join(str(value) for value in finite["integral_levels"]),
        "center_0_-2_tangent_leading_valuations\t"
        + ",".join(
            str(value) for value in center_tail["leading_valuations"]
        ),
        "center_0_-2_tail_competing_margins\t"
        + f"{center_tail['t_margin']},{center_tail['y_margin']}",
        "center_0_-2_balance\tv2(y)=v2(t)+3/2_impossible",
        "integral_tail_status\tno_Q2_point_for_v2_t_at_least_8",
        "boundary_status\tTest0147:all_coordinate_boundaries_excluded",
        "affine_nonzero_status\tall_integer_valuation_pairs_excluded",
        "normalization_Q2_points\t0",
        "koenig_genus11_Q_points\t0_by_Q_embedding_into_Q2",
    ]
    return "\n".join(lines) + "\n"


def self_test():
    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    polynomial = 1 + t + x + 2 * t * x
    data = tropical_complex(polynomial)
    assert len(data["points"]) == 4
    assert len(data["lower_points"]) == 4
    assert all(
        len(minimum_signature(data["points"], point)) >= 2
        for point in data["vertices"]
    )
    print(
        "M24 genus-11 tropical-exhaustion self-test passed: "
        "exact lower complex and minimum signatures"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument(
        "--local-elimination",
        type=Path,
        default=LOCAL_ELIMINATION,
    )
    parser.add_argument(
        "--minus-two-clusters",
        type=Path,
        default=MINUS_TWO_CLUSTERS,
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        if args.archive is None:
            return
    if args.archive is None:
        parser.error("archive is required outside --self-test")

    local_metadata, local_values = parse_summary(
        args.local_elimination
    )
    assert local_metadata["status"] == (
        "exact_singular_nonsquare_normalization_excluded"
    )
    assert local_values["minus6_status"] == (
        "exact_ordinary_double_point_no_Q2_branches"
    )
    cluster_metadata, cluster_values = parse_summary(
        args.minus_two_clusters
    )
    assert cluster_metadata["status"] == (
        "all_frontier_clusters_exactly_excluded"
    )
    assert cluster_values["minus2_frontier_status"] == (
        "all_4356_boxes_excluded"
    )

    _, polynomial = boundary.load_model(args.archive)
    tropical = original_tropical_certificate(polynomial)
    finite = finite_audits(polynomial)
    tails = [
        stable_face_certificate(
            polynomial,
            (-42, -20),
            (-2, -1),
            23,
            5,
            [(1, 0, 2), (2, 0, 4), (4, 4, 0)],
        ),
        stable_face_certificate(
            polynomial,
            (-42, -18),
            (-2, -1),
            22,
            7,
            [
                (1, 0, 2),
                (2, 0, 4),
                (4, 0, 8),
                (8, 8, 0),
            ],
        ),
        stable_face_certificate(
            polynomial,
            (-3, 13),
            (0, 1),
            14,
            2,
            [(1, 1, 0)],
        ),
        stable_face_certificate(
            polynomial,
            (-2, -41),
            (0, -1),
            43,
            8,
            [(1, 1, 0)],
        ),
    ]
    center_tail = center_minus_two_tail(polynomial)
    quarter_tail = quarter_weighted_tail(polynomial)
    text = summary_text(
        tropical,
        finite,
        tails,
        center_tail,
        quarter_tail,
    )
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
