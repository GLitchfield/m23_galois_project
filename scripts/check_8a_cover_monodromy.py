#!/usr/bin/env python3
"""Check numerical cover monodromy against the certified M23 class ledger."""

from __future__ import annotations

import csv
from decimal import Decimal
import hashlib
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from barth_wenz_preprocess import Permutation, parse_images  # noqa: E402


CLASSES = ROOT / "data/derived/m23_8a_8a_2a_inner_classes.tsv"
CLASSES_SHA256 = (
    "dc6089e7b9bcf9cb890e01306d286327266c0bf6ba7a7a8e48abb5ca52b3f3e8"
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_CYCLES = {
    "zero": (8, 8, 4, 2, 1),
    "one": (8, 8, 4, 2, 1),
    "infinity": (2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_result(
    path: Path,
) -> tuple[dict[str, str], dict[str, dict[str, str]]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("\t", 1)
            metadata[key] = value
        else:
            data_lines.append(line)
    rows = list(csv.DictReader(data_lines, delimiter="\t"))
    by_loop = {row["loop"]: row for row in rows}
    if set(by_loop) != set(EXPECTED_CYCLES) or len(rows) != 3:
        raise RuntimeError("monodromy result must contain three loops")
    return metadata, by_loop


def permutation(row: dict[str, str]) -> Permutation:
    return Permutation(
        tuple(int(value) - 1 for value in row["images"].split(","))
    )


def inverse_product(left: Permutation, right: Permutation) -> Permutation:
    return left.then(right).inverse()


def simultaneous_conjugator(
    first: Permutation,
    second: Permutation,
    target_first: Permutation,
    target_second: Permutation,
) -> tuple[int, ...] | None:
    generators = (
        (first, target_first),
        (second, target_second),
        (first.inverse(), target_first.inverse()),
        (second.inverse(), target_second.inverse()),
    )
    for initial_image in range(first.degree):
        mapping = {0: initial_image}
        frontier = [0]
        consistent = True
        while frontier and consistent:
            point = frontier.pop()
            for source, target in generators:
                next_point = source(point)
                next_image = target(mapping[point])
                if (
                    next_point in mapping
                    and mapping[next_point] != next_image
                ):
                    consistent = False
                    break
                if next_point not in mapping:
                    mapping[next_point] = next_image
                    frontier.append(next_point)
        if (
            consistent
            and len(mapping) == first.degree
            and len(set(mapping.values())) == first.degree
        ):
            return tuple(mapping[index] for index in range(first.degree))
    return None


def matching_classes(
    first: Permutation, second: Permutation
) -> list[tuple[int, tuple[int, ...]]]:
    if sha256(CLASSES) != CLASSES_SHA256:
        raise RuntimeError("M23 class-ledger hash changed")
    lines = [
        line for line in CLASSES.read_text(encoding="utf-8").splitlines()
        if not line.startswith("#")
    ]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    matches = []
    for row in rows:
        conjugator = simultaneous_conjugator(
            first,
            second,
            parse_images(row["first_images"]),
            parse_images(row["second_images"]),
        )
        if conjugator is not None:
            matches.append((int(row["class_id"]), conjugator))
    return matches


def gap_group(first: Permutation, second: Permutation) -> tuple[int, str, int]:
    first_images = ",".join(str(value + 1) for value in first.images)
    second_images = ",".join(str(value + 1) for value in second.images)
    script = (
        f"s0:=PermList([{first_images}]);;"
        f"s1:=PermList([{second_images}]);;"
        "g:=Group(s0,s1);;"
        "c:=Centralizer(SymmetricGroup(23),g);;"
        'Print(Size(g),"\\t",StructureDescription(g),"\\t",Size(c),"\\n");'
        "QUIT;"
    )
    result = subprocess.run(
        ["gap", "-q", "-c", script],
        check=True,
        capture_output=True,
        text=True,
    )
    size, structure, centralizer_size = result.stdout.strip().split("\t")
    return int(size), structure, int(centralizer_size)


def check(path: Path) -> tuple[int, tuple[int, ...]]:
    metadata, rows = read_result(path)
    expected_metadata = {
        "format": "m23_8a_cover_monodromy_v1",
        "permutations_stable": "true",
        "basepoint": "0.5",
    }
    for key, expected in expected_metadata.items():
        if metadata.get(key) != expected:
            raise RuntimeError(f"unexpected monodromy metadata: {key}")
    if not SHA256.fullmatch(metadata.get("source_sha256", "")):
        raise RuntimeError("invalid monodromy source hash")
    source = (ROOT / metadata["source"]).resolve()
    if not source.is_relative_to(ROOT) or not source.is_file():
        raise RuntimeError("monodromy coefficient source is unavailable")
    if sha256(source) != metadata["source_sha256"]:
        raise RuntimeError("monodromy coefficient-source hash mismatch")
    coarse = int(metadata["coarse_steps_per_loop"])
    fine = int(metadata["fine_steps_per_loop"])
    if coarse < 64 or fine != 2 * coarse:
        raise RuntimeError("invalid monodromy mesh-doubling record")

    permutations = {
        label: permutation(row) for label, row in rows.items()
    }
    for label, expected in EXPECTED_CYCLES.items():
        recorded = tuple(
            int(value) for value in rows[label]["cycle_lengths"].split(",")
        )
        actual = tuple(
            sorted(
                (len(cycle) for cycle in permutations[label].cycles()),
                reverse=True,
            )
        )
        if recorded != expected or actual != expected:
            raise RuntimeError(f"{label} cycle partition mismatch")
    if inverse_product(
        permutations["zero"], permutations["one"]
    ) != permutations["infinity"]:
        raise RuntimeError("monodromy permutations do not satisfy product one")

    for label in ("zero", "one"):
        row = rows[label]
        if Decimal(row["maximum_residual"]) >= Decimal("1e-40"):
            raise RuntimeError(f"{label} loop residual is too large")
        if Decimal(row["minimum_root_separation"]) <= Decimal("1e-4"):
            raise RuntimeError(f"{label} loop roots are too close")
        if Decimal(row["minimum_derivative"]) <= 0:
            raise RuntimeError(f"{label} loop contains a critical point")
        if Decimal(row["matching_error"]) >= Decimal("1e-40"):
            raise RuntimeError(f"{label} endpoint matching is ambiguous")

    size, structure, centralizer_size = gap_group(
        permutations["zero"], permutations["one"]
    )
    if (size, structure) != (10_200_960, "M23"):
        raise RuntimeError(
            f"unexpected monodromy group: size={size} structure={structure}"
        )
    if centralizer_size != 1:
        raise RuntimeError(
            f"unexpected cover-automorphism centralizer: {centralizer_size}"
        )
    matches = matching_classes(
        permutations["zero"], permutations["one"]
    )
    if len(matches) != 1 or matches[0][0] != 1:
        raise RuntimeError(f"unexpected M23 inner-class matches: {matches}")
    return matches[0]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} MONODROMY.tsv")
    class_id, conjugator = check(Path(sys.argv[1]))
    print(
        f"verified M23 cover monodromy and inner class {class_id}; "
        "conjugator="
        + ",".join(str(value + 1) for value in conjugator)
    )


if __name__ == "__main__":
    main()
