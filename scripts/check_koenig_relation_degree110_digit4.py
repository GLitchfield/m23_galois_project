#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUMMARY = ROOT / "data/derived/m23_koenig_a_relation_degree110_digit4.tsv"
PROFILES = ROOT / "data/derived/m23_koenig_a_relation_degree110_profiles.tsv"
BASIS = ROOT / "data/derived/m23_koenig_f19_a_relation_basis.npz"
SEED_SUMMARY = (
    ROOT / "data/derived/m23_koenig_a_relation_ambient_digits4.tsv"
)
SEED_COEFFICIENTS = (
    ROOT / "data/derived/m23_koenig_a_relation_coefficients_mod6859.tsv"
)
FAMILY = ROOT / "data/derived/m23_koenig_19adic_family_16384.tsv"
REJECTED_COEFFICIENTS = (
    ROOT
    / "data/derived/m23_koenig_a_relation_degree110_coefficients_mod130321.tsv"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def digest_indices(indices: list[int]) -> str:
    return hashlib.sha256(
        ("\n".join(map(str, indices)) + "\n").encode()
    ).hexdigest()


def main() -> None:
    summary = metadata(SUMMARY)
    assert summary["schema"] == "m23-koenig-a-degree110-digit4-v1"
    assert summary["basis_sha256"] == sha256(BASIS)
    assert summary["seed_summary_sha256"] == sha256(SEED_SUMMARY)
    assert summary["seed_coefficients_sha256"] == sha256(SEED_COEFFICIENTS)
    assert summary["family_certificate_sha256"] == sha256(FAMILY)
    assert int(summary["prime"]) == 19
    assert int(summary["seed_digits"]) == 3
    assert int(summary["target_digits"]) == 4
    assert int(summary["modulus"]) == 130321
    assert summary["status"] == "degree110_digit4_rejected"
    assert int(summary["series_precision"]) == 16384
    assert int(summary["training_terms"]) == 16000
    assert int(summary["holdout_terms"]) == 384
    assert int(summary["denominator_cutoff"]) == 110
    assert int(summary["normalized_unknowns"]) == 15721
    assert summary["normalization"] == "P[0,1]=1"
    assert int(summary["normalized_rank"]) == 15151
    assert int(summary["gauge_dimension"]) == 570
    assert int(summary["zero_coordinate_corrections"]) == 4077
    assert int(summary["nonzero_coordinate_corrections"]) == 10281
    assert int(summary["high_denominator_nonzero_corrections"]) == 378
    assert int(summary["final_nonzero_coefficients"]) == 15329
    assert SUMMARY.read_text().splitlines()[-1] == "799\t368"

    profile_metadata = metadata(PROFILES)
    assert profile_metadata["schema"] == (
        "m23-koenig-a-degree110-profiles-v1"
    )
    rank = int(profile_metadata["rank"])
    assert rank == int(summary["normalized_rank"])
    rows: list[int] = []
    columns: list[int] = []
    for line in PROFILES.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, position, index = line.split("\t")
        target = rows if kind == "row" else columns
        assert kind in {"row", "column"}
        assert int(position) == len(target)
        target.append(int(index))
    assert len(rows) == len(columns) == rank
    assert len(set(rows)) == len(rows)
    assert len(set(columns)) == len(columns)
    assert all(0 <= index < 16000 for index in rows)
    assert all(0 <= index < 15721 for index in columns)
    assert digest_indices(rows) == summary["pivot_rows_sha256"]
    assert digest_indices(columns) == summary["pivot_columns_sha256"]
    profile_indices = (
        "\n".join(
            [f"row:{index}" for index in rows]
            + [f"column:{index}" for index in columns]
        )
        + "\n"
    )
    assert hashlib.sha256(profile_indices.encode()).hexdigest() == (
        summary["profile_indices_sha256"]
    )

    # A rejected pivot-fitted vector is diagnostic, not a valid relation.
    assert not REJECTED_COEFFICIENTS.exists()
    print(
        "verified König degree-110 fixed-seed gate: rank 15151, "
        "all digit-4 corrections rejected on 799 fitting "
        "and 368 holdout rows"
    )


if __name__ == "__main__":
    main()
