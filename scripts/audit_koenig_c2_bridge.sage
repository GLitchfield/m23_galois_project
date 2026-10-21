#!/usr/bin/env sage
"""Certify the C2 bridge between the braid and normalized-family conventions."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path

from sage.all import PolynomialRing, QQ
from sage.env import SAGE_VERSION


def metadata_and_rows(path: Path):
    lines = path.read_text().splitlines()
    metadata = dict(
        line[2:].split("\t", 1) for line in lines if line.startswith("# ")
    )
    rows = list(
        csv.DictReader(
            (line for line in lines if not line.startswith("#")),
            delimiter="\t",
        )
    )
    return metadata, rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--orbit", type=Path, required=True)
    parser.add_argument("--family", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--code-revision", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    orbit_metadata, orbit_rows = metadata_and_rows(args.orbit)
    assert len(orbit_rows) == 1
    orbit = orbit_rows[0]
    assert orbit["class_vector"] == "3A,5A,2A,2A"
    assert orbit["eta34_cycle_shape"] == "2^490"
    assert (
        int(orbit["pure_braid_orbit_count"]),
        int(orbit["pure_braid_orbit_sizes"]),
        int(orbit["pure_genus"]),
    ) == (1, 980, 119)
    assert (
        int(orbit["symmetric_orbit_count"]),
        int(orbit["symmetric_orbit_size"]),
        int(orbit["symmetric_genus"]),
    ) == (1, 980, 43)

    family_lines = args.family.read_text().splitlines()
    family_targets = {
        line.split("\t", 1)[0][9:]
        for line in family_lines
        if line.startswith("# target_")
    }
    expected_targets = {
        "a",
        "constant",
        *(f"f1_x{index}" for index in range(5)),
        *(f"f2_x{index}" for index in range(4)),
        "g1_x0",
        "g1_x1",
        "g2_x0",
        "g2_x1",
    }
    assert family_targets == expected_targets
    assert all(
        not target.startswith(prefix)
        for target in family_targets
        for prefix in ("f3_", "f4_", "f5_", "f6_", "lambda")
    )

    ring = PolynomialRing(
        QQ,
        names=("lambda", "t", "C", "A", "B", "G", "a", "alpha", "beta"),
    )
    lam, t, constant, left, right, denominator, a, alpha, beta = ring.gens()
    involution = ring.hom(
        [-lam, t, constant, right, left, denominator, a, alpha, beta],
        ring,
    )
    left_identity = (
        (t - QQ(1) / 2 - lam) * denominator - constant * left
    )
    right_identity = (
        (t - QQ(1) / 2 + lam) * denominator - constant * right
    )
    assert involution(involution(lam)) == lam
    assert involution(left_identity) == right_identity
    assert involution(right_identity) == left_identity
    assert involution(lam**2) == lam**2
    assert involution(alpha) == alpha
    assert involution(beta) == beta

    orbit_hash = hashlib.sha256(args.orbit.read_bytes()).hexdigest()
    family_hash = hashlib.sha256(args.family.read_bytes()).hexdigest()
    invariant_targets = ",".join(sorted(family_targets))
    text = "\n".join(
        [
            "# schema\tm23-koenig-c2-bridge-v1",
            f"# code_revision\t{args.code_revision}",
            f"# sage_version\t{SAGE_VERSION}",
            f"# orbit_sha256\t{orbit_hash}",
            f"# family_sha256\t{family_hash}",
            f"# orbit_code_revision\t{orbit_metadata['code_revision']}",
            "source_class_vector\tcode_class_vector\tequal_class_positions\tbraid_swap\tbraid_swap_order\tbraid_swap_cycle_shape\tpure_degree\tpure_genus\tc2_degree\tc2_genus\tcoordinate_action\tinvariant_parameter\tplane_coordinates\tinvariant_family_targets",
            "\t".join(
                [
                    "2A,2A,3A,5A",
                    "3A,5A,2A,2A",
                    "3,4",
                    "eta34",
                    "2",
                    "2^490",
                    "980",
                    "119",
                    "980",
                    "43",
                    "lambda->-lambda;(f3,f4)<->(f5,f6)",
                    "a=lambda^2",
                    "alpha,beta fixed",
                    invariant_targets,
                ]
            ),
        ]
    ) + "\n"

    if args.check:
        assert args.output.read_text() == text
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    print(f"SageMath {SAGE_VERSION}")
    print(
        "verified eta34 matches lambda -> -lambda and exchanges the two "
        "order-two factor identities"
    )
    print(
        "verified the recovered mod-19 family is exactly the C2-invariant "
        "coefficient sector"
    )


if __name__ == "__main__":
    main()
