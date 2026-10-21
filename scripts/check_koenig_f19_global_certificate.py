#!/usr/bin/env python3
"""Run archive-independent structural checks on the König F_19 certificate."""

from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FAMILY = ROOT / "data/derived/m23_koenig_f19_family.tsv"
CERTIFICATE = (
    ROOT / "data/derived/m23_koenig_f19_global_certificate.tsv"
)
SCHEMA = "m23-koenig-f19-global-certificate-v1"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    metadata = {}
    rows = []
    for line in CERTIFICATE.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line and not line.startswith("index\t"):
            index, unit, zero, encoded = line.split("\t")
            coefficients = tuple(int(value) for value in encoded.split(","))
            rows.append((int(index), int(unit), int(zero), coefficients))

    assert metadata["schema"] == SCHEMA
    assert metadata["family"] == FAMILY.name
    assert metadata["family_sha256"] == sha256(FAMILY)
    assert metadata["field"] == "GF(19)"
    assert metadata["coordinates"] == "u=alpha-7,v=beta-14"
    assert metadata["plane_weight"] == "2,1"
    assert int(metadata["plane_weight_degree"]) == 194
    bound = int(metadata["pseudo_remainder_v_degree_bound"])
    assert bound == 28539
    modulus_degree = int(metadata["modulus_degree"])
    assert modulus_degree == 128
    assert [row[0] for row in rows] == list(range(len(rows)))
    assert len(rows) == int(metadata["modulus_count"])
    assert all(unit == 1 and zero == 1 for _, unit, zero, _ in rows)
    assert len(rows) == int(metadata["valid_modulus_count"])
    for _, _, _, coefficients in rows:
        assert len(coefficients) == modulus_degree + 1
        assert coefficients[-1] == 1
        assert all(0 <= value < 19 for value in coefficients)
    assert len({coefficients for _, _, _, coefficients in rows}) == len(rows)
    certified_degree = modulus_degree * len(rows)
    assert certified_degree == int(
        metadata["certified_modulus_degree_sum"]
    )
    assert certified_degree > bound
    print(
        "verified König global certificate structure: "
        f"{len(rows)} moduli, degree {certified_degree} > {bound}"
    )


if __name__ == "__main__":
    main()
