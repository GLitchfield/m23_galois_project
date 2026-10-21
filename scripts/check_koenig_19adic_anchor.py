#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data" / "derived" / "m23_koenig_19adic_anchor.tsv"


def main() -> None:
    lines = PATH.read_text().splitlines()
    metadata = dict(
        line[2:].split("\t", 1) for line in lines if line.startswith("# ")
    )
    assert metadata["schema"] == "m23-koenig-19adic-anchor-v1"
    assert re.fullmatch(r"[0-9a-f]{40}", metadata["code_revision"])
    assert metadata["archive_sha256"] == (
        "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
    )
    assert metadata["sage_version"] == "10.9"
    assert int(metadata["prime"]) == 19
    assert int(metadata["digits"]) == 32
    assert int(metadata["modulus"]) == 19**32
    assert metadata["branch_label"] == "lambda=9"
    assert int(metadata["jacobian_determinant_mod19"]) != 0
    assert re.fullmatch(r"[0-9a-f]{64}", metadata["values_sha256"])

    data_lines = [line for line in lines if not line.startswith("# ")]
    assert data_lines[0] == (
        "alpha_residue\tbeta_residue\tcover_equations_zero\t"
        "plane_relation_zero"
    )
    alpha, beta, cover_zero, plane_zero = data_lines[1].split("\t")
    assert int(alpha) % 19 == 7
    assert int(beta) % 19 == 14
    assert cover_zero == plane_zero == "true"
    print(
        "verified compact 19-adic anchor certificate: "
        "32 digits, alpha=7 and beta=14 mod 19"
    )


if __name__ == "__main__":
    main()
