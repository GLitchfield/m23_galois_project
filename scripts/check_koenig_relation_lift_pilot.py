#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    path = ROOT / "data/derived/m23_koenig_a_relation_lift_pilot.tsv"
    lines = path.read_text().splitlines()
    metadata = dict(
        line[2:].split("\t", 1) for line in lines if line.startswith("# ")
    )
    assert metadata["schema"] == "m23-koenig-a-relation-pilot-v2"
    assert metadata["status"] == "fixed_support_rejected"
    assert int(metadata["normalized_rank"]) == 10573
    assert int(metadata["support_columns"]) == 10574
    assert metadata["normalization"] == "P[0,1]=1"
    assert metadata["pivot_selection"] == "ffpack_row_rank_profile"
    assert int(metadata["training_terms"]) == 16000
    assert int(metadata["holdout_terms"]) == 384
    assert int(metadata["tested_digits"]) == 2
    assert int(metadata["verified_digits"]) == 1
    assert int(metadata["tested_modulus"]) == 361
    assert int(metadata["rejected_digit"]) == 2
    assert int(metadata["digit_2_fitting_nonzero_residuals"]) == 5121
    assert int(metadata["digit_2_holdout_nonzero_residuals"]) == 359
    assert lines[-1] == "5121\t359"
    print(
        "verified full-size König relation pilot: rank 10573 and "
        "fixed support rejected modulo 19^2"
    )


if __name__ == "__main__":
    main()
