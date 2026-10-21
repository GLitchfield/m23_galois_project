#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = (
    ROOT
    / "data"
    / "derived"
    / "m23_koenig_19adic_family_16384.tsv"
)


def main() -> None:
    lines = PATH.read_text().splitlines()
    metadata = dict(
        line[2:].split("\t", 1) for line in lines if line.startswith("# ")
    )
    assert metadata["schema"] == "m23-koenig-19adic-family-v1"
    assert re.fullmatch(r"[0-9a-f]{40}", metadata["code_revision"])
    assert metadata["code_revision"] == (
        "b47dc310fe421dc29721183b2c8e2d5a47b66ce3"
    )
    assert metadata["archive_sha256"] == (
        "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
    )
    assert metadata["sage_version"] == "10.9"
    assert int(metadata["prime"]) == 19
    assert int(metadata["digits"]) == 32
    assert int(metadata["modulus"]) == 19**32
    assert int(metadata["series_precision"]) == 16384
    assert metadata["parameter"] == "lambda=9+s"
    assert int(metadata["jacobian_determinant_mod19"]) == 2
    assert metadata["values_sha256"] == (
        "b36d782e62901079e676ecfc70aee35693d3bd8cd634cc6454b9215c7475b039"
    )

    data_lines = [line for line in lines if not line.startswith("# ")]
    fields = data_lines[1].split("\t")
    assert int(fields[0]) % 19 == 7
    assert int(fields[1]) % 19 == 14
    assert fields[-3:] == ["true", "true", "true"]
    print(
        "verified high-order mixed 19-adic family certificate: "
        "32 digits, 16,384 series terms"
    )


if __name__ == "__main__":
    main()
