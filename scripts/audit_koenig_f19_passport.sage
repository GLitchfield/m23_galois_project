#!/usr/bin/env sage
"""Certify a nondegenerate passport fiber of König's recovered F_19 family."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
from pathlib import Path

from sage.all import GF, PolynomialRing
from sage.env import SAGE_VERSION


SCHEMA = "m23-koenig-f19-passport-point-v1"
GLOBAL_SCHEMA = "m23-koenig-f19-global-certificate-v1"
POINT_U = 2
POINT_V = 11


def load_module(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError(f"could not load {path}")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def metadata(path):
    result = {}
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            result[key] = value
    return result


def encode_polynomial(polynomial):
    return ",".join(
        str(int(polynomial[exponent]))
        for exponent in range(polynomial.degree() + 1)
    )


def geometric_multiplicities(polynomial):
    return sorted(
        multiplicity
        for factor, multiplicity in polynomial.factor()
        for _ in range(factor.degree())
    )


def encode_partition(multiplicities):
    counts = {}
    for multiplicity in multiplicities:
        counts[multiplicity] = counts.get(multiplicity, 0) + 1
    return ".".join(
        f"{multiplicity}^{counts[multiplicity]}"
        for multiplicity in sorted(counts, reverse=True)
    )


def certificate_lines(
    family_path,
    archive_path,
    global_path,
    factors,
    factor_resultants,
    pair_resultants,
    partitions,
    denominator,
    branch_parameter,
    branch_square_root,
    constant,
    residual_factor,
    split_degrees,
):
    f1, f2, g1, g2 = factors
    return [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# family\t{family_path.name}",
        f"# family_sha256\t{sha256(family_path)}",
        f"# global_certificate\t{global_path.name}",
        f"# global_certificate_sha256\t{sha256(global_path)}",
        f"# archive_sha256\t{sha256(archive_path)}",
        f"# sage_version\t{SAGE_VERSION}",
        "# field\tGF(19)",
        "# coordinates\tu=alpha-7,v=beta-14",
        f"point_u\t{POINT_U}",
        f"point_v\t{POINT_V}",
        f"point_alpha\t{(POINT_U + 7) % 19}",
        f"point_beta\t{(POINT_V + 14) % 19}",
        f"common_denominator\t{int(denominator)}",
        f"branch_parameter_a\t{int(branch_parameter)}",
        f"branch_square_root_lambda\t{int(branch_square_root)}",
        f"cover_constant_C\t{int(constant)}",
        f"factor_f1_low_to_high\t{encode_polynomial(f1)}",
        f"factor_f2_low_to_high\t{encode_polynomial(f2)}",
        f"factor_g1_low_to_high\t{encode_polynomial(g1)}",
        f"factor_g2_low_to_high\t{encode_polynomial(g2)}",
        *[
            f"separability_resultant_{label}\t{int(value)}"
            for label, value in factor_resultants
        ],
        *[
            f"pair_resultant_{left}_{right}\t{int(value)}"
            for left, right, value in pair_resultants
        ],
        f"residual_degree\t{residual_factor.degree()}",
        (
            "residual_separability_resultant\t"
            f"{int(residual_factor.resultant(residual_factor.derivative()))}"
        ),
        f"residual_split_at_4\t{split_degrees[0]}",
        f"residual_split_at_6\t{split_degrees[1]}",
        f"fiber_0_partition\t{encode_partition(partitions[0])}",
        f"fiber_4_partition\t{encode_partition(partitions[1])}",
        f"fiber_6_partition\t{encode_partition(partitions[2])}",
        f"fiber_infinity_partition\t{encode_partition(partitions[3])}",
        "cover_degree\t23",
        "riemann_hurwitz_excess\t44",
        "derivative_factorization\t1",
        "global_critical_value_identity\t1",
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("family", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("global_certificate", type=Path)
    output_group = parser.add_mutually_exclusive_group(required=True)
    output_group.add_argument("--output", type=Path)
    output_group.add_argument("--check-summary", type=Path)
    args = parser.parse_args()

    repository = Path(__file__).resolve().parents[1]
    certifier = load_module(
        "koenig_global_certifier_for_passport",
        repository / "scripts/certify_koenig_f19_global.sage",
    )
    family_module = load_module(
        "koenig_family_verifier_for_passport",
        repository / "scripts/verify_koenig_f19_family.sage",
    )
    curve_module = load_module(
        "koenig_curve_verifier_for_passport",
        repository / "scripts/verify_koenig_hurwitz_curve.sage",
    )
    global_metadata = metadata(args.global_certificate)
    assert global_metadata["schema"] == GLOBAL_SCHEMA
    assert global_metadata["family_sha256"] == sha256(args.family)
    assert global_metadata["archive_sha256"] == sha256(args.archive)
    assert int(global_metadata["certified_modulus_degree_sum"]) > int(
        global_metadata["pseudo_remainder_v_degree_bound"]
    )

    field = GF(19)
    family_metadata, ring, denominator_polynomial, numerator_polynomials = (
        certifier.parse_polynomials(
            args.family, family_module, field
        )
    )
    assert family_metadata["archive_sha256"] == sha256(args.archive)
    plane = certifier.translated_plane(
        args.archive, curve_module, field, ring
    )
    plane_factors = tuple(plane.factor())
    assert len(plane_factors) == 1 and plane_factors[0][1] == 1
    point = (field(POINT_U), field(POINT_V))
    assert plane(*point) == 0

    denominator = denominator_polynomial(*point)
    assert denominator != 0
    numerators = {
        label: polynomial(*point)
        for label, polynomial in numerator_polynomials.items()
    }
    branch_parameter = numerators["a"] / denominator
    constant = numerators["constant"] / denominator
    assert branch_parameter == 1
    assert constant == 12
    branch_square_root = field.one()
    assert branch_square_root**2 == branch_parameter

    x_ring = PolynomialRing(field, "X")
    X = x_ring.gen()
    f1 = (
        X**6
        + (point[1] + 14) * X**5
        + sum(
            numerators[f"f1_x{i}"] / denominator * X**i
            for i in range(5)
        )
    )
    f2 = (
        X**5
        + (point[0] + 7) * X**4
        + sum(
            numerators[f"f2_x{i}"] / denominator * X**i
            for i in range(4)
        )
    )
    g1 = (
        X**3
        + field(13) * X**2
        + numerators["g1_x1"] / denominator * X
        + numerators["g1_x0"] / denominator
    )
    g2 = (
        X**3
        + field(9) * X**2
        + numerators["g2_x1"] / denominator * X
        + numerators["g2_x0"] / denominator
    )
    factors = (f1, f2, g1, g2)
    labels = ("f1", "f2", "g1", "g2")
    assert tuple(factor.degree() for factor in factors) == (6, 5, 3, 3)
    assert all(factor.is_monic() for factor in factors)

    factor_resultants = tuple(
        (
            label,
            factor.resultant(factor.derivative()),
        )
        for label, factor in zip(labels, factors)
    )
    assert all(value for _, value in factor_resultants)
    pair_resultants = tuple(
        (
            labels[left],
            labels[right],
            factors[left].resultant(factors[right]),
        )
        for left in range(len(factors))
        for right in range(left + 1, len(factors))
    )
    assert all(value for _, _, value in pair_resultants)

    numerator_product = f1**3 * f2
    denominator_product = g1**5 * g2
    assert numerator_product.degree() == 23
    assert denominator_product.degree() == 18
    assert numerator_product.gcd(denominator_product).degree() == 0
    centered_cover = constant * numerator_product - 5 * denominator_product
    fibers = (
        constant * numerator_product,
        constant * numerator_product - 4 * denominator_product,
        constant * numerator_product - 6 * denominator_product,
    )
    residual_factor = (
        (3 * f1.derivative() * f2 + f1 * f2.derivative()) * g1 * g2
        - f1
        * f2
        * (5 * g1.derivative() * g2 + g1 * g2.derivative())
    )
    assert residual_factor.degree() == 16
    assert residual_factor.resultant(residual_factor.derivative()) != 0
    derivative_numerator = (
        (constant * numerator_product).derivative() * denominator_product
        - constant
        * numerator_product
        * denominator_product.derivative()
    )
    assert derivative_numerator == (
        constant * f1**2 * g1**4 * residual_factor
    )

    critical_value_equation = (
        centered_cover**2
        - branch_parameter * denominator_product**2
    )
    assert critical_value_equation == fibers[1] * fibers[2]
    assert critical_value_equation % residual_factor == 0
    split_degrees = (
        residual_factor.gcd(fibers[1]).degree(),
        residual_factor.gcd(fibers[2]).degree(),
    )
    assert split_degrees == (8, 8)

    partitions = (
        geometric_multiplicities(fibers[0]),
        geometric_multiplicities(fibers[1]),
        geometric_multiplicities(fibers[2]),
        sorted(geometric_multiplicities(denominator_product) + [5]),
    )
    assert partitions == (
        [1] * 5 + [3] * 6,
        [1] * 7 + [2] * 8,
        [1] * 7 + [2] * 8,
        [1] * 3 + [5] * 4,
    )
    assert sum(
        multiplicity - 1
        for partition in partitions
        for multiplicity in partition
    ) == 2 * 23 - 2

    lines = certificate_lines(
        args.family,
        args.archive,
        args.global_certificate,
        factors,
        factor_resultants,
        pair_resultants,
        partitions,
        denominator,
        branch_parameter,
        branch_square_root,
        constant,
        residual_factor,
        split_degrees,
    )
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("\n".join(lines) + "\n")
        print(f"wrote={args.output}")
    if args.check_summary is not None:
        assert lines == args.check_summary.read_text().splitlines()
        print(f"verified={args.check_summary}")
    print(
        "verified_passport="
        "(2^8.1^7,2^8.1^7,3^6.1^5,5^4.1^3)"
    )
    print(f"point_u={POINT_U}")
    print(f"point_v={POINT_V}")
    print(f"residual_split={split_degrees[0]}+{split_degrees[1]}")


if __name__ == "__main__":
    main()
