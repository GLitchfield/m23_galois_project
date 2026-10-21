#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data" / "derived" / "m23_koenig_19adic_family.tsv"


def main() -> None:
    lines = PATH.read_text().splitlines()
    metadata = dict(
        line[2:].split("\t", 1) for line in lines if line.startswith("# ")
    )
    assert metadata["schema"] == "m23-koenig-19adic-family-v1"
    assert re.fullmatch(r"[0-9a-f]{40}", metadata["code_revision"])
    assert metadata["archive_sha256"] == (
        "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
    )
    assert metadata["sage_version"] == "10.9"
    assert int(metadata["prime"]) == 19
    assert int(metadata["digits"]) == 32
    assert int(metadata["modulus"]) == 19**32
    assert int(metadata["series_precision"]) == 64
    assert metadata["parameter"] == "lambda=9+s"
    assert int(metadata["jacobian_determinant_mod19"]) != 0
    assert metadata["values_sha256"] == (
        "8114415ba1d651040aa6da4e18c2e6b60e88ea16025db4afbf4c7c45eb9f73d5"
    )

    data_lines = [line for line in lines if not line.startswith("# ")]
    assert data_lines[0] == (
        "alpha_constant\tbeta_constant\talpha_linear\tbeta_linear\t"
        "cover_equations_zero\tplane_relation_zero\t"
        "mod19_family_compatible"
    )
    (
        alpha,
        beta,
        alpha_linear,
        beta_linear,
        cover_zero,
        plane_zero,
        mod19_compatible,
    ) = data_lines[1].split("\t")
    assert int(alpha) % 19 == 7
    assert int(beta) % 19 == 14
    # The plane image is singular at the anchor, so both first derivatives
    # vanish modulo 19 even though the normalized cover family is smooth.
    assert int(alpha_linear) % 19 == 0
    assert int(beta_linear) % 19 == 0
    assert cover_zero == plane_zero == mod19_compatible == "true"
    print(
        "verified compact mixed 19-adic family certificate: "
        "32 digits, 64 series terms, exact mod-19 compatibility"
    )


if __name__ == "__main__":
    main()
