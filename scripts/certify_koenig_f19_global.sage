#!/usr/bin/env sage
"""Certify König's recovered F_19 family by modular exact division.

The direct polynomial remainder over F_19[u,v]/(h) is prohibitively large.
Instead, this program specializes v modulo deterministic irreducible
polynomials.  A weighted-degree bound makes sufficiently many zero
specialized remainders a deterministic certificate of the global identity.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
import time
from pathlib import Path

from sage.all import GF, PolynomialRing
from sage.env import SAGE_VERSION


SCHEMA = "m23-koenig-f19-global-shard-v1"
FIELD_ORDER = 19
PLANE_U_WEIGHT = 2
PLANE_V_WEIGHT = 1
EXPECTED_PLANE_WEIGHT = 194
EXPECTED_REMAINDER_BOUND = 28539
NEGATIVE_INFINITY = -10**9


def load_module(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError(f"could not load {path}")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def polynomial_weight(polynomial):
    return max(
        PLANE_U_WEIGHT * i + PLANE_V_WEIGHT * j
        for (i, j), coefficient in polynomial.dict().items()
        if coefficient
    )


def maxplus_product(left, right):
    result = [NEGATIVE_INFINITY] * (len(left) + len(right) - 1)
    for i, a in enumerate(left):
        for j, b in enumerate(right):
            result[i + j] = max(result[i + j], a + b)
    return result


def maxplus_power(value, exponent):
    result = [0]
    for _ in range(exponent):
        result = maxplus_product(result, value)
    return result


def maxplus_sum(*values):
    size = max(map(len, values))
    return [
        max(
            value[index] if index < len(value) else NEGATIVE_INFINITY
            for value in values
        )
        for index in range(size)
    ]


def derivative_bounds(value):
    return value[1:]


def pseudo_remainder_weight_bound(denominator, numerators):
    """Bound v-degrees after reducing the pseudo-remainder modulo h.

    The translated plane relation is monic up to a field unit in u and every
    one of its terms has weight at most 194 for wt(u)=2, wt(v)=1.  Reduction
    modulo h therefore cannot increase this weight.  The max-plus calculation
    mirrors the cleared factor products and all 31 pseudo-division steps.
    """
    d = polynomial_weight(denominator)
    f1 = [polynomial_weight(numerators[f"f1_x{i}"]) for i in range(5)]
    f1.extend((d + 1, d))
    f2 = [polynomial_weight(numerators[f"f2_x{i}"]) for i in range(4)]
    f2.extend((d + 2, d))
    g1 = [
        polynomial_weight(numerators["g1_x0"]),
        polynomial_weight(numerators["g1_x1"]),
        d,
        d,
    ]
    g2 = [
        polynomial_weight(numerators["g2_x0"]),
        polynomial_weight(numerators["g2_x1"]),
        d,
        d,
    ]

    numerator_product = maxplus_product(maxplus_power(f1, 3), f2)
    denominator_product = maxplus_product(maxplus_power(g1, 5), g2)
    shifted_numerator = [
        value + polynomial_weight(numerators["constant"]) + d
        for value in numerator_product
    ]
    centered_cover = maxplus_sum(
        shifted_numerator, denominator_product
    )
    branch_equation = maxplus_sum(
        [value + d for value in maxplus_product(centered_cover, centered_cover)],
        [
            value + polynomial_weight(numerators["a"])
            for value in maxplus_product(
                denominator_product, denominator_product
            )
        ],
    )
    critical_factor = maxplus_sum(
        maxplus_product(
            maxplus_product(derivative_bounds(f1), f2),
            maxplus_product(g1, g2),
        ),
        maxplus_product(
            maxplus_product(f1, derivative_bounds(f2)),
            maxplus_product(g1, g2),
        ),
        maxplus_product(
            maxplus_product(f1, f2),
            maxplus_product(derivative_bounds(g1), g2),
        ),
        maxplus_product(
            maxplus_product(f1, f2),
            maxplus_product(g1, derivative_bounds(g2)),
        ),
    )
    assert len(branch_equation) - 1 == 46
    assert len(critical_factor) - 1 == 16

    current = branch_equation[:]
    leading_bound = critical_factor[-1]
    for degree in range(46, 15, -1):
        current_lead = current[degree]
        current = [value + leading_bound for value in current]
        shift = degree - 16
        for index, value in enumerate(critical_factor):
            current[index + shift] = max(
                current[index + shift], current_lead + value
            )
        current[degree] = NEGATIVE_INFINITY
    return max(current[:16])


def deterministic_modulus(ring, degree, index):
    """Return a reproducible monic irreducible polynomial."""
    attempt = 0
    while True:
        coefficients = []
        block = 0
        while len(coefficients) < degree:
            payload = (
                f"m23-koenig-f19-global-v1:{degree}:{index}:"
                f"{attempt}:{block}"
            ).encode("ascii")
            coefficients.extend(
                byte % FIELD_ORDER for byte in hashlib.sha256(payload).digest()
            )
            block += 1
        candidate = ring(coefficients[:degree] + [1])
        if candidate.is_irreducible():
            return candidate
        attempt += 1


def parse_polynomials(family_path, family_module, field):
    metadata, denominator_terms, numerator_terms = family_module.parse_family(
        family_path, field
    )
    ring = PolynomialRing(field, names=("u", "v"))
    u, v = ring.gens()

    def build(terms):
        return sum(coefficient * u**i * v**j for i, j, coefficient in terms)

    denominator = build(denominator_terms)
    numerators = {
        label: build(terms) for label, terms in numerator_terms.items()
    }
    return metadata, ring, denominator, numerators


def translated_plane(archive, curve_module, field, target_ring):
    _, alpha, beta, relation = curve_module.load_polynomial(archive)
    reduced = relation.change_ring(field)
    reduced_alpha, reduced_beta = reduced.parent().gens()
    u, v = target_ring.gens()
    return target_ring(
        reduced(
            **{
                str(reduced_alpha): u + 7,
                str(reduced_beta): v + 14,
            }
        )
    )


def specialize(polynomial, extension, z, target_ring, z_powers):
    source_u, _ = polynomial.parent().gens()
    coefficients = [extension.zero()] * (polynomial.degree(source_u) + 1)
    for (i, j), coefficient in polynomial.dict().items():
        coefficients[i] += extension(coefficient) * z_powers[j]
    return target_ring(coefficients)


def exact_specialized_division(
    plane,
    denominator,
    numerators,
    modulus,
):
    degree = modulus.degree()
    extension = GF(FIELD_ORDER**degree, name="z", modulus=modulus)
    z = extension.gen()
    u_ring = PolynomialRing(extension, "U")
    U = u_ring.gen()
    _, source_v = plane.parent().gens()
    maximum_v_degree = max(
        polynomial.degree(source_v)
        for polynomial in [plane, denominator, *numerators.values()]
    )
    z_powers = [extension.one()]
    for _ in range(maximum_v_degree):
        z_powers.append(z_powers[-1] * z)

    specialized_plane = specialize(
        plane, extension, z, u_ring, z_powers
    )
    assert specialized_plane.degree() == 97
    quotient = u_ring.quotient(specialized_plane, "ubar")
    ubar = quotient.gen()

    def evaluate(polynomial):
        return quotient(
            specialize(polynomial, extension, z, u_ring, z_powers)
        )

    D = evaluate(denominator)
    N = {label: evaluate(value) for label, value in numerators.items()}
    x_ring = PolynomialRing(quotient, "X")
    X = x_ring.gen()
    f1 = (
        D * X**6
        + D * (z + 14) * X**5
        + sum(N[f"f1_x{i}"] * X**i for i in range(5))
    )
    f2 = (
        D * X**5
        + D * (ubar + 7) * X**4
        + sum(N[f"f2_x{i}"] * X**i for i in range(4))
    )
    g1 = (
        D * X**3
        + extension(13) * D * X**2
        + N["g1_x1"] * X
        + N["g1_x0"]
    )
    g2 = (
        D * X**3
        + extension(9) * D * X**2
        + N["g2_x1"] * X
        + N["g2_x0"]
    )
    numerator_product = f1**3 * f2
    denominator_product = g1**5 * g2
    centered_cover = (
        N["constant"] * D * numerator_product
        - extension(5) * denominator_product
    )
    branch_equation = (
        D * centered_cover**2
        - N["a"] * denominator_product**2
    )
    critical_factor = (
        (3 * f1.derivative() * f2 + f1 * f2.derivative()) * g1 * g2
        - f1
        * f2
        * (
            5 * g1.derivative() * g2
            + g1 * g2.derivative()
        )
    )
    assert branch_equation.degree() == 46
    assert critical_factor.degree() == 16

    leading_lift = critical_factor.leading_coefficient().lift()
    gcd, inverse, _ = leading_lift.xgcd(specialized_plane)
    if not gcd.is_one():
        return False, False
    monic_critical = quotient(inverse) * critical_factor
    assert monic_critical.leading_coefficient().is_one()
    remainder = branch_equation
    for degree in range(46, 15, -1):
        coefficient = remainder[degree]
        if coefficient:
            remainder -= (
                coefficient * X ** (degree - 16) * monic_critical
            )
        assert remainder.degree() < degree
    return True, remainder == 0


def header_lines(
    family_path,
    archive_path,
    metadata,
    revision,
    modulus_degree,
    start_index,
    count,
):
    return [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{revision}",
        f"# family\t{family_path.name}",
        f"# family_sha256\t{sha256(family_path)}",
        f"# archive_sha256\t{sha256(archive_path)}",
        f"# source_family_revision\t{metadata['code_revision']}",
        f"# sage_version\t{SAGE_VERSION}",
        f"# field\tGF({FIELD_ORDER})",
        "# coordinates\tu=alpha-7,v=beta-14",
        f"# plane_weight\t{PLANE_U_WEIGHT},{PLANE_V_WEIGHT}",
        f"# plane_weight_degree\t{EXPECTED_PLANE_WEIGHT}",
        f"# pseudo_remainder_v_degree_bound\t{EXPECTED_REMAINDER_BOUND}",
        f"# modulus_degree\t{modulus_degree}",
        f"# start_index\t{start_index}",
        f"# count\t{count}",
        "index\tunit_leading_coefficient\tzero_remainder\t"
        "modulus_coefficients_low_to_high",
    ]


def read_rows(path):
    if not path.exists():
        return {}, []
    lines = path.read_text().splitlines()
    rows = {}
    for line in lines:
        if not line or line.startswith("#") or line.startswith("index\t"):
            continue
        index, unit, zero, coefficients = line.split("\t")
        rows[int(index)] = (int(unit), int(zero), coefficients)
    return rows, lines


def write_checkpoint(path, headers, rows):
    lines = headers[:]
    for index in sorted(rows):
        unit, zero, coefficients = rows[index]
        lines.append(f"{index}\t{unit}\t{zero}\t{coefficients}")
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text("\n".join(lines) + "\n")
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("family", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--modulus-degree", type=int, default=128)
    parser.add_argument("--start-index", type=int, required=True)
    parser.add_argument("--count", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.modulus_degree < 2:
        raise ValueError("modulus degree must be at least two")
    if args.start_index < 0 or args.count < 1:
        raise ValueError("invalid index range")

    repository = Path(__file__).resolve().parents[1]
    family_module = load_module(
        "koenig_family_verifier",
        repository / "scripts/verify_koenig_f19_family.sage",
    )
    curve_module = load_module(
        "koenig_curve_verifier",
        repository / "scripts/verify_koenig_hurwitz_curve.sage",
    )
    field = GF(FIELD_ORDER)
    metadata, ring, denominator, numerators = parse_polynomials(
        args.family, family_module, field
    )
    assert metadata["schema"] == family_module.SCHEMA
    assert sha256(args.archive) == metadata["archive_sha256"]
    plane = translated_plane(args.archive, curve_module, field, ring)
    u, _ = ring.gens()
    assert plane.degree(u) == 97
    assert plane.polynomial(u).leading_coefficient().is_constant()
    assert denominator.polynomial(u) % plane.polynomial(u)
    plane_factors = tuple(plane.factor())
    assert len(plane_factors) == 1 and plane_factors[0][1] == 1
    assert polynomial_weight(plane) == EXPECTED_PLANE_WEIGHT
    bound = pseudo_remainder_weight_bound(denominator, numerators)
    assert bound == EXPECTED_REMAINDER_BOUND

    revision = git_revision()
    headers = header_lines(
        args.family,
        args.archive,
        metadata,
        revision,
        args.modulus_degree,
        args.start_index,
        args.count,
    )
    existing, existing_lines = read_rows(args.output)
    if existing_lines:
        expected_headers = headers
        actual_headers = [
            line
            for line in existing_lines
            if line.startswith("#") or line.startswith("index\t")
        ]
        if actual_headers != expected_headers:
            raise ValueError("checkpoint metadata does not match this run")
    rows = dict(existing)
    modulus_ring = PolynomialRing(field, "z0")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    stop_index = args.start_index + args.count
    for index in range(args.start_index, stop_index):
        modulus = deterministic_modulus(
            modulus_ring, args.modulus_degree, index
        )
        encoded = ",".join(str(int(value)) for value in modulus.list())
        if index in rows:
            if rows[index][2] != encoded:
                raise ValueError(f"checkpoint modulus mismatch at {index}")
            print(f"already_complete={index}", flush=True)
            continue
        row_started = time.monotonic()
        unit, zero = exact_specialized_division(
            plane, denominator, numerators, modulus
        )
        if unit and not zero:
            raise AssertionError(f"nonzero remainder at modulus {index}")
        rows[index] = (int(unit), int(zero), encoded)
        write_checkpoint(args.output, headers, rows)
        print(
            f"index={index} unit={int(unit)} zero={int(zero)} "
            f"elapsed={time.monotonic() - row_started:.3f} "
            f"total_elapsed={time.monotonic() - started:.3f}",
            flush=True,
        )
    print(f"wrote={args.output}")
    print(f"rows={len(rows)}")
    print(f"elapsed={time.monotonic() - started:.3f}")


if __name__ == "__main__":
    main()
