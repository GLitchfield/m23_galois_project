#!/usr/bin/env python3
"""Extract the globally verified mod-19^3 seed from a rejected digit-4 run."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

PRIME = 19
DIGITS = 3
MODULUS = PRIME**DIGITS


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("summary", type=Path)
    parser.add_argument("source_coefficients", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    summary = metadata(args.summary)
    assert summary["schema"] == "m23-koenig-a-ambient-digits4-v1"
    assert summary["status"] == "ambient_continuation_rejected"
    assert int(summary["digit_3_fitting_nonzero_residuals"]) == 0
    assert int(summary["digit_3_holdout_nonzero_residuals"]) == 0
    assert int(summary["digit_4_fitting_nonzero_residuals"]) > 0
    assert int(summary["digit_4_holdout_nonzero_residuals"]) > 0

    source = metadata(args.source_coefficients)
    assert source["schema"] == "m23-koenig-a-ambient-digits4-coefficients-v1"
    assert source["summary_sha256"] == hashlib.sha256(
        args.summary.read_bytes()
    ).hexdigest()
    rows = []
    for line in args.source_coefficients.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("kind\t"):
            continue
        kind, i, j, value = line.split("\t")
        reduced = int(value) % MODULUS
        if reduced:
            rows.append((kind, int(i), int(j), reduced))

    coefficient_text = "\n".join(
        f"{kind}\t{i}\t{j}\t{value}" for kind, i, j, value in rows
    ) + "\n"
    lines = [
        "# schema\tm23-koenig-a-ambient-digit3-coefficients-v1",
        f"# source_summary_sha256\t{hashlib.sha256(args.summary.read_bytes()).hexdigest()}",
        (
            "# source_coefficients_sha256\t"
            f"{hashlib.sha256(args.source_coefficients.read_bytes()).hexdigest()}"
        ),
        f"# modulus\t{MODULUS}",
        f"# nonzero_coefficients\t{len(rows)}",
        (
            "# coefficients_sha256\t"
            f"{hashlib.sha256(coefficient_text.encode()).hexdigest()}"
        ),
        "kind\ti\tj\tcoefficient",
    ]
    lines.extend(coefficient_text.rstrip().splitlines())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
