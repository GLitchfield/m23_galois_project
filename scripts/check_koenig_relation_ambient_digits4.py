#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUMMARY = ROOT / "data/derived/m23_koenig_a_relation_ambient_digits4.tsv"
PROFILES = ROOT / "data/derived/m23_koenig_a_relation_ambient_profiles.tsv"
DIGIT2 = ROOT / "data/derived/m23_koenig_a_relation_coefficients_mod361.tsv"
DIGIT3 = ROOT / "data/derived/m23_koenig_a_relation_coefficients_mod6859.tsv"


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def coefficients(path: Path) -> dict[tuple[str, int, int], int]:
    result = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, i, j, value = line.split("\t")
        result[(kind, int(i), int(j))] = int(value)
    return result


def main() -> None:
    summary = metadata(SUMMARY)
    assert summary["schema"] == "m23-koenig-a-ambient-digits4-v1"
    assert summary["status"] == "ambient_continuation_rejected"
    assert int(summary["normalized_rank"]) == 15091
    assert int(summary["gauge_dimension"]) == 85
    assert int(summary["digit_3_fitting_nonzero_residuals"]) == 0
    assert int(summary["digit_3_holdout_nonzero_residuals"]) == 0
    assert int(summary["digit_4_fitting_nonzero_residuals"]) == 869
    assert int(summary["digit_4_holdout_nonzero_residuals"]) == 370
    assert SUMMARY.read_text().splitlines()[-1] == "869\t370"

    profile_metadata = metadata(PROFILES)
    assert profile_metadata["schema"] == "m23-koenig-a-ambient-profiles-v1"
    assert int(profile_metadata["rank"]) == 15091
    rows = []
    columns = []
    for line in PROFILES.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, position, index = line.split("\t")
        target = rows if kind == "row" else columns
        assert int(position) == len(target)
        target.append(int(index))
    assert len(rows) == len(columns) == 15091
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

    digit3_metadata = metadata(DIGIT3)
    assert digit3_metadata["schema"] == (
        "m23-koenig-a-ambient-digit3-coefficients-v1"
    )
    assert digit3_metadata["source_summary_sha256"] == hashlib.sha256(
        SUMMARY.read_bytes()
    ).hexdigest()
    assert int(digit3_metadata["modulus"]) == 6859
    digit3 = coefficients(DIGIT3)
    assert len(digit3) == int(digit3_metadata["nonzero_coefficients"]) == 11252
    digit2 = coefficients(DIGIT2)
    for term in set(digit2) | set(digit3):
        assert digit3.get(term, 0) % 361 == digit2.get(term, 0)
    sparse_text = "\n".join(
        line
        for line in DIGIT3.read_text().splitlines()
        if line and not line.startswith("#") and not line.startswith("kind\t")
    ) + "\n"
    assert hashlib.sha256(sparse_text.encode()).hexdigest() == (
        digit3_metadata["coefficients_sha256"]
    )
    print(
        "verified König ambient continuation: digit 3 passes, "
        "cutoff-105 digit 4 requires a wider ansatz"
    )


if __name__ == "__main__":
    main()
