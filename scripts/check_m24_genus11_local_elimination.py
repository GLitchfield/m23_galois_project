#!/usr/bin/env python3
"""Check the compact exact M24 genus-11 local-elimination certificate."""

from __future__ import annotations

import argparse
from pathlib import Path


SCHEMA = "m23-m24-genus11-local-elimination-v1"
DEFAULT_PATH = Path(
    "data/derived/m24_koenig_genus11_local_elimination.tsv"
)
ARCHIVE_SHA256 = (
    "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
)
MODEL_SHA256 = (
    "8fc3f13944653c89e0de309632f5f11aaccd18aaed41cbf794db036fd57d31a2"
)


def parse(path: Path):
    metadata = {}
    values = {}
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        elif line:
            key, value = line.split("\t", 1)
            values[key] = value
    return metadata, values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, default=DEFAULT_PATH)
    args = parser.parse_args()
    metadata, values = parse(args.summary)

    assert metadata["schema"] == SCHEMA
    assert len(metadata["code_revision"]) == 40
    assert metadata["sage_version"] == "10.9"
    assert metadata["archive_sha256"] == ARCHIVE_SHA256
    assert metadata["model_sha256"] == MODEL_SHA256
    assert metadata["status"] == (
        "exact_singular_nonsquare_normalization_excluded"
    )

    assert values["resultant_degree"] == "1216"
    assert values["resultant_sha256"] == (
        "9254495767e5e3630e00b1e4bdba002c47a3682a27776d28"
        "10fa663fe2685f75"
    )
    assert values["resultant_factorization"] == (
        "1^64,1^210,2^4,4^4,34^1,442^2"
    )
    assert values["repeated_degree"] == "732"
    assert values["repeated_factorization"] == (
        "1^63,1^209,2^3,4^3,442^1"
    )
    assert values["singular_factor_degree"] == "442"
    assert values["singular_factor_sha256"] == (
        "5ada50c757ea28f65febe14f3eeee02f0a335b9dcc1bbc3c0"
        "47bd669c76d90ac"
    )
    assert values["fx_first_nonzero_subresultant_index"] == "1"
    assert values["ft_first_nonzero_subresultant_index"] == "1"
    assert values["fx_witness_degree"] == "1"
    assert values["ft_witness_degree"] == "1"
    assert values["fx_witness_lead_sha256"] == (
        "783519480b4303b27d9bc29aa33ae756042191482944a1300"
        "360877c4dd1d7b6"
    )
    assert values["fx_witness_constant_sha256"] == (
        "73f8168857f24e50ed0a980949406338d579f0010264b95b4"
        "b5bfa850800610b"
    )
    assert values["ft_witness_lead_sha256"] == (
        "4ced1d1a69c9c6ab4bc3765afd9739886809ae42277793375"
        "b40b9bc0b52f573"
    )
    assert values["ft_witness_constant_sha256"] == (
        "ff807cc394008b8b83a7ea574b3048e819e6cbe3388e31bd"
        "bc368969d7292c5d"
    )
    assert values["witness_proportional_mod_singular_factor"] == (
        "true"
    )
    assert values["hensel_center_count"] == "8"
    assert values["hensel_factor_valuations"] == (
        "23,24,23,25,23,24,23,29"
    )
    assert values["hensel_derivative_valuations"] == (
        "0,0,0,0,0,0,0,0"
    )
    assert values["hensel_common_residue_modulus"] == str(2**23)
    assert values["local_t_mod_2^64"] == "789384892621102101"
    assert values["local_x_mod_2^64"] == "17587692204416159151"
    assert values["local_hessian_discriminant"] == "8,7,nonsquare"
    assert values["minus6_status"] == (
        "exact_ordinary_double_point_no_Q2_branches"
    )

    print(
        "verified exact König M24 (-6,0) elimination: the unique "
        "Q_2 cluster is an ordinary double point with nonsquare "
        "tangent discriminant and no Q_2 normalization branch"
    )


if __name__ == "__main__":
    main()
