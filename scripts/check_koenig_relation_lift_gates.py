#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def main() -> None:
    space = metadata(
        ROOT / "data/derived/m23_koenig_relation_lift_space.tsv"
    )
    assert space["schema"] == "m23-koenig-relation-lift-space-v1"
    assert int(space["recovered_relation_dimension"]) == 50
    assert int(space["plane_multiple_dimension"]) == 36
    assert int(space["full_cutoff_relation_dimension"]) == 86
    assert int(space["numerator_support"]) == 5252
    assert int(space["denominator_support"]) == 5322
    assert int(space["numerator_support_restricted_dimension"]) == 37
    assert int(space["full_support_restricted_dimension"]) == 1
    assert int(space["full_support_numerator_rank"]) == 1
    assert int(space["normalized_support_rank_inferred"]) == 10573
    assert space["normalization"] == "P[0,1]=1"

    probe = metadata(
        ROOT / "data/derived/m23_koenig_a_centered_lift_probe.tsv"
    )
    assert probe["schema"] == "m23-koenig-centered-relation-lift-probe-v1"
    assert int(probe["digits"]) == 4
    assert int(probe["series_precision"]) == 64
    assert int(probe["minimum_residual_19adic_valuation"]) == 1
    assert int(probe["zero_coefficients"]) == 0
    assert probe["valuation_counts"] == "1:60,2:3,3:1"
    assert probe["conclusion"] == "centered lift fails modulo 19^2"
    pilot = metadata(
        ROOT / "data/derived/m23_koenig_a_relation_lift_pilot.tsv"
    )
    assert pilot["schema"] == "m23-koenig-a-relation-pilot-v2"
    assert pilot["status"] == "fixed_support_rejected"
    assert int(pilot["normalized_rank"]) == 10573
    assert int(pilot["digit_2_fitting_nonzero_residuals"]) == 5121
    assert int(pilot["digit_2_holdout_nonzero_residuals"]) == 359
    print(
        "verified König relation-lift gates: rigid normalized support and "
        "full-size fixed-support rejection at the second 19-adic digit"
    )


if __name__ == "__main__":
    main()
