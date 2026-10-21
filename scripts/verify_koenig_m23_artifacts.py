#!/usr/bin/env python3
"""Validate König's externally stored M23 thesis artifact archive."""

from __future__ import annotations

import argparse
import hashlib
import re
import zipfile
from pathlib import Path

ARCHIVE_SHA256 = "62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44"
PREFIX = "Polynomials And Approximation Data/M23_(2,2,3,5)/"
APPROXIMATION = PREFIX + "m23_(2,2,3,5)_approx.txt"
CURVE = PREFIX + "(2,2,3,5)_hurwitzcurve_parametrization.txt"
EXPECTED_SIZES = {
    APPROXIMATION: 19_063_056,
    CURVE: 1_199_059,
}


def top_level_list_length(text: str) -> int:
    """Count entries in a Magma-style outer list of inner lists."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    depth = 0
    entries = 0
    for character in text:
        if character == "[":
            depth += 1
            if depth == 2:
                entries += 1
        elif character == "]":
            depth -= 1
            if depth < 0:
                raise ValueError("unbalanced closing bracket")
    if depth != 0:
        raise ValueError("unbalanced list brackets")
    return entries


def polynomial_bidegree(text: str) -> tuple[int, int]:
    """Return the largest explicit exponents of t and x."""
    normalized = re.sub(r"\\\r?\n\s*", "", text)
    t_degree = max(map(int, re.findall(r"\bt\^(\d+)", normalized)))
    x_degree = max(map(int, re.findall(r"\bx\^(\d+)", normalized)))
    return t_degree, x_degree


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_archive(path: Path) -> None:
    actual_hash = sha256(path)
    if actual_hash != ARCHIVE_SHA256:
        raise ValueError(
            f"archive SHA-256 {actual_hash} does not match {ARCHIVE_SHA256}"
        )

    with zipfile.ZipFile(path) as archive:
        members = {info.filename: info for info in archive.infolist()}
        for name, expected_size in EXPECTED_SIZES.items():
            if name not in members:
                raise ValueError(f"missing archive member: {name}")
            if members[name].file_size != expected_size:
                raise ValueError(
                    f"{name} has size {members[name].file_size}, "
                    f"expected {expected_size}"
                )

        approximation = archive.read(APPROXIMATION).decode("ascii")
        curve = archive.read(CURVE).decode("ascii")

    if "A list of length 980" not in approximation:
        raise ValueError("approximation header does not claim length 980")
    if top_level_list_length(approximation) != 980:
        raise ValueError("approximation list does not contain 980 entries")
    if "Hurwitz curve of genus 43" not in curve:
        raise ValueError("curve header does not claim genus 43")
    if polynomial_bidegree(curve) != (97, 98):
        raise ValueError("curve equation does not have bidegree (97,98)")

    print(f"verified König archive {actual_hash}")
    print("verified 980 approximations and the bidegree-(97,98), genus-43 equation")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    verify_archive(args.archive)


if __name__ == "__main__":
    main()
