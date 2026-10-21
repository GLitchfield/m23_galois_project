#!/usr/bin/env python3
"""Run archive-independent checks on König's mod-19 passport point."""

from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FAMILY = ROOT / "data/derived/m23_koenig_f19_family.tsv"
GLOBAL = ROOT / "data/derived/m23_koenig_f19_global_certificate.tsv"
PASSPORT = ROOT / "data/derived/m23_koenig_f19_passport_point.tsv"
SCHEMA = "m23-koenig-f19-passport-point-v1"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    metadata = {}
    values = {}
    for line in PASSPORT.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            key, value = line.split("\t", 1)
            values[key] = value

    assert metadata["schema"] == SCHEMA
    assert metadata["family"] == FAMILY.name
    assert metadata["family_sha256"] == sha256(FAMILY)
    assert metadata["global_certificate"] == GLOBAL.name
    assert metadata["global_certificate_sha256"] == sha256(GLOBAL)
    assert metadata["field"] == "GF(19)"
    assert metadata["coordinates"] == "u=alpha-7,v=beta-14"
    expected = {
        "point_u": "2",
        "point_v": "11",
        "point_alpha": "9",
        "point_beta": "6",
        "common_denominator": "6",
        "branch_parameter_a": "1",
        "branch_square_root_lambda": "1",
        "cover_constant_C": "12",
        "factor_f1_low_to_high": "8,4,6,18,15,6,1",
        "factor_f2_low_to_high": "15,18,17,0,9,1",
        "factor_g1_low_to_high": "11,6,13,1",
        "factor_g2_low_to_high": "9,11,9,1",
        "residual_degree": "16",
        "residual_split_at_4": "8",
        "residual_split_at_6": "8",
        "fiber_0_partition": "3^6.1^5",
        "fiber_4_partition": "2^8.1^7",
        "fiber_6_partition": "2^8.1^7",
        "fiber_infinity_partition": "5^4.1^3",
        "cover_degree": "23",
        "riemann_hurwitz_excess": "44",
        "derivative_factorization": "1",
        "global_critical_value_identity": "1",
    }
    for key, value in expected.items():
        assert values[key] == value
    resultant_keys = [
        key
        for key in values
        if key.startswith("separability_resultant_")
        or key.startswith("pair_resultant_")
    ]
    assert len(resultant_keys) == 10
    assert all(int(values[key]) % 19 for key in resultant_keys)
    assert int(values["residual_separability_resultant"]) % 19
    print(
        "verified König passport point structure: "
        "(2^8.1^7,2^8.1^7,3^6.1^5,5^4.1^3)"
    )


if __name__ == "__main__":
    main()
