#!/usr/bin/env sage
"""Verify the modular certificate for König's global F_19 family identity."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import time
from pathlib import Path

from sage.all import GF, PolynomialRing


CERTIFICATE_SCHEMA = "m23-koenig-f19-global-certificate-v1"


def load_certifier():
    path = Path(__file__).with_name("certify_koenig_f19_global.sage")
    loader = importlib.machinery.SourceFileLoader(
        "koenig_global_certifier", str(path)
    )
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not load König global certifier")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def parse_certificate(path):
    metadata = {}
    rows = []
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line and not line.startswith("index\t"):
            index, unit, zero, coefficients = line.split("\t")
            rows.append(
                (
                    int(index),
                    int(unit),
                    int(zero),
                    tuple(int(value) for value in coefficients.split(",")),
                )
            )
    return metadata, rows


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("family", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("certificate", type=Path)
    replay = parser.add_mutually_exclusive_group()
    replay.add_argument("--replay-count", type=int, default=0)
    replay.add_argument("--replay-all", action="store_true")
    args = parser.parse_args()
    if args.replay_count < 0:
        raise ValueError("replay count cannot be negative")

    certifier = load_certifier()
    metadata, rows = parse_certificate(args.certificate)
    assert metadata["schema"] == CERTIFICATE_SCHEMA
    assert metadata["family_sha256"] == sha256(args.family)
    assert metadata["archive_sha256"] == sha256(args.archive)
    assert metadata["field"] == f"GF({certifier.FIELD_ORDER})"
    assert metadata["coordinates"] == "u=alpha-7,v=beta-14"
    assert metadata["plane_weight"] == (
        f"{certifier.PLANE_U_WEIGHT},{certifier.PLANE_V_WEIGHT}"
    )

    repository = Path(__file__).resolve().parents[1]
    family_module = certifier.load_module(
        "koenig_family_verifier_global_check",
        repository / "scripts/verify_koenig_f19_family.sage",
    )
    curve_module = certifier.load_module(
        "koenig_curve_verifier_global_check",
        repository / "scripts/verify_koenig_hurwitz_curve.sage",
    )
    field = GF(certifier.FIELD_ORDER)
    family_metadata, ring, denominator, numerators = (
        certifier.parse_polynomials(
            args.family, family_module, field
        )
    )
    assert (
        metadata["source_family_revision"]
        == family_metadata["code_revision"]
    )
    plane = certifier.translated_plane(
        args.archive, curve_module, field, ring
    )
    u, _ = ring.gens()
    assert plane.degree(u) == 97
    assert plane.polynomial(u).leading_coefficient().is_constant()
    assert denominator.polynomial(u) % plane.polynomial(u)
    factors = tuple(plane.factor())
    assert len(factors) == 1 and factors[0][1] == 1
    assert certifier.polynomial_weight(plane) == int(
        metadata["plane_weight_degree"]
    )
    bound = certifier.pseudo_remainder_weight_bound(
        denominator, numerators
    )
    assert bound == int(metadata["pseudo_remainder_v_degree_bound"])

    modulus_degree = int(metadata["modulus_degree"])
    modulus_ring = PolynomialRing(field, "z0")
    assert [row[0] for row in rows] == list(range(len(rows)))
    moduli = []
    for index, unit, zero, coefficients in rows:
        assert unit == 1 and zero == 1
        modulus = modulus_ring(coefficients)
        assert modulus.degree() == modulus_degree
        assert modulus.is_monic()
        assert modulus.is_irreducible()
        moduli.append(modulus)
    assert len(set(moduli)) == len(moduli)
    assert len(rows) == int(metadata["modulus_count"])
    assert len(rows) == int(metadata["valid_modulus_count"])
    certified_degree = modulus_degree * len(rows)
    assert certified_degree == int(
        metadata["certified_modulus_degree_sum"]
    )
    assert certified_degree > bound

    replay_count = len(rows) if args.replay_all else args.replay_count
    if replay_count > len(rows):
        raise ValueError("replay count exceeds certificate size")
    started = time.monotonic()
    for index, _, _, coefficients in rows[:replay_count]:
        modulus = modulus_ring(coefficients)
        unit, zero = certifier.exact_specialized_division(
            plane, denominator, numerators, modulus
        )
        assert unit and zero
        print(
            f"replayed_index={index} "
            f"elapsed={time.monotonic() - started:.3f}",
            flush=True,
        )

    print(f"certificate_sha256={sha256(args.certificate)}")
    print(f"modulus_count={len(rows)}")
    print(f"certified_modulus_degree_sum={certified_degree}")
    print(f"pseudo_remainder_v_degree_bound={bound}")
    print(f"replayed_moduli={replay_count}")
    print(
        "verified_global_identity="
        "critical_factor_divides_quadratic_branch_equation"
    )


if __name__ == "__main__":
    main()
