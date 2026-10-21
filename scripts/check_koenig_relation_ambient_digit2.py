#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SUMMARY = ROOT / "data/derived/m23_koenig_a_relation_ambient_digit2.tsv"
COEFFICIENTS = ROOT / "data/derived/m23_koenig_a_relation_coefficients_mod361.tsv"
CANDIDATE = ROOT / "data/derived/m23_koenig_f19_a_relation.tsv"
BASIS = ROOT / "data/derived/m23_koenig_f19_a_relation_basis.npz"


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def main() -> None:
    summary = metadata(SUMMARY)
    assert summary["schema"] == "m23-koenig-a-ambient-digit2-v1"
    assert summary["status"] == "ambient_digit2_verified"
    assert int(summary["modulus"]) == 361
    assert int(summary["normalized_unknowns"]) == 15176
    assert int(summary["normalized_rank"]) == 15091
    assert int(summary["gauge_dimension"]) == 85
    assert int(summary["plane_multiple_dimension"]) == 36
    assert int(summary["dormant_nonzero_corrections"]) == 645
    assert int(summary["support_nonzero_corrections"]) == 9942
    assert SUMMARY.read_text().splitlines()[-1] == "0\t0"

    coefficient_metadata = metadata(COEFFICIENTS)
    assert coefficient_metadata["schema"] == (
        "m23-koenig-a-ambient-digit2-coefficients-v1"
    )
    assert coefficient_metadata["summary_sha256"] == hashlib.sha256(
        SUMMARY.read_bytes()
    ).hexdigest()
    coefficients = {}
    for line in COEFFICIENTS.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, i, j, value = line.split("\t")
        term = (kind, int(i), int(j))
        assert term not in coefficients
        coefficients[term] = int(value)
    assert len(coefficients) == 11218
    assert all(0 < value < 361 for value in coefficients.values())

    candidate = {}
    for line in CANDIDATE.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        kind, i, j, value = line.split("\t")
        candidate[(kind, int(i), int(j))] = int(value)
    with np.load(BASIS) as stored:
        cutoff = int(stored["selected_cutoff"])
        numerator_specs = [(int(i), int(j)) for i, j in stored["numerator_specs"]]
        denominator_specs = [
            (int(i), int(j))
            for i, j in stored["denominator_specs"]
            if int(i) + int(j) <= cutoff
        ]
    terms = [("P", i, j) for i, j in numerator_specs] + [
        ("Q", i, j) for i, j in denominator_specs
    ]
    terms.remove(("P", 0, 1))
    dormant_nonzero = 0
    canonical = []
    for term in terms:
        value = coefficients.get(term, 0)
        assert value % 19 == candidate.get(term, 0)
        if candidate.get(term, 0) == 0 and value:
            dormant_nonzero += 1
        canonical.append(f"{term[0]}:{term[1]}:{term[2]}:{value}")
    assert dormant_nonzero == 645
    digest = hashlib.sha256(("\n".join(canonical) + "\n").encode()).hexdigest()
    assert digest == summary["coefficients_sha256"]
    print(
        "verified ambient König digit-2 lift: rank 15091, "
        "645 dormant corrections, and zero fitting/holdout residuals"
    )


if __name__ == "__main__":
    main()
