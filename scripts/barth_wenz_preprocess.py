#!/usr/bin/env python3
"""Open reimplementation of Barth--Wenz fundamental-domain preprocessing."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
M23_CLASSES = ROOT / "data/derived/m23_8a_8a_2a_inner_classes.tsv"
BARTH_WENZ_CODE_URL = (
    "https://ars.els-cdn.com/content/image/"
    "1-s2.0-S0021869320305810-mmc1.zip"
)
BARTH_WENZ_CODE_SHA256 = (
    "0e3202564229dfad668622f77c5d3c5011deac4b83d5ef10c700c3b9ced080c3"
)
BARTH_WENZ_FIXTURES_URL = (
    "https://ars.els-cdn.com/content/image/"
    "1-s2.0-S0021869320305810-mmc2.zip"
)
BARTH_WENZ_FIXTURES_SHA256 = (
    "32f7d08e6cc111685e332d997321fb7c807e403198b302c9c94dad4e193c4876"
)


@dataclass(frozen=True)
class Permutation:
    """A zero-based permutation using GAP/Magma's right-action convention."""

    images: tuple[int, ...]

    def __post_init__(self) -> None:
        if set(self.images) != set(range(len(self.images))):
            raise ValueError("images do not define a permutation")

    @property
    def degree(self) -> int:
        return len(self.images)

    def __call__(self, point: int) -> int:
        return self.images[point]

    def inverse(self) -> "Permutation":
        images = [0] * self.degree
        for point, image in enumerate(self.images):
            images[image] = point
        return Permutation(tuple(images))

    def then(self, right: "Permutation") -> "Permutation":
        """Return self*right, so point^(self*right)=(point^self)^right."""
        if self.degree != right.degree:
            raise ValueError("permutations have different degrees")
        return Permutation(tuple(right(self(point)) for point in range(self.degree)))

    def cycles(self) -> tuple[tuple[int, ...], ...]:
        seen: set[int] = set()
        result = []
        for start in range(self.degree):
            if start in seen:
                continue
            cycle = []
            point = start
            while point not in seen:
                seen.add(point)
                cycle.append(point)
                point = self(point)
            result.append(tuple(cycle))
        return tuple(result)

    def order(self) -> int:
        result = 1
        for cycle in self.cycles():
            result = math.lcm(result, len(cycle))
        return result

    def apply_power(self, point: int, exponent: int) -> int:
        permutation = self if exponent >= 0 else self.inverse()
        for _ in range(abs(exponent) % self.order()):
            point = permutation(point)
        return point


def permutation_from_cycles(
    degree: int,
    cycles: Iterable[Iterable[int]],
) -> Permutation:
    images = list(range(degree))
    for raw_cycle in cycles:
        cycle = [entry - 1 for entry in raw_cycle]
        for left, right in zip(cycle, cycle[1:] + cycle[:1]):
            images[left] = right
    return Permutation(tuple(images))


def parse_images(value: str) -> Permutation:
    return Permutation(tuple(int(entry) - 1 for entry in value.split(",")))


def inverse_product(left: Permutation, right: Permutation) -> Permutation:
    return left.then(right).inverse()


def is_transitive(*generators: Permutation) -> bool:
    degree = generators[0].degree
    inverses = tuple(generator.inverse() for generator in generators)
    reached = {0}
    frontier = [0]
    while frontier:
        point = frontier.pop()
        for generator in generators + inverses:
            image = generator(point)
            if image not in reached:
                reached.add(image)
                frontier.append(image)
    return len(reached) == degree


def calculate_word(
    word: tuple[int, ...],
    x: Permutation,
    y: Permutation,
    start: int,
) -> int:
    padded = word if len(word) % 2 == 0 else word + (0,)
    point = start
    for index in range(0, len(padded), 2):
        point = x.apply_power(point, padded[index])
        point = y.apply_power(point, padded[index + 1])
    return point


def connected_components(adjacency: dict[int, set[int]]) -> list[tuple[int, ...]]:
    unseen = set(adjacency)
    result = []
    while unseen:
        start = min(unseen)
        reached = {start}
        frontier = [start]
        unseen.remove(start)
        while frontier:
            vertex = frontier.pop()
            for neighbour in sorted(adjacency[vertex]):
                if neighbour in unseen:
                    unseen.remove(neighbour)
                    reached.add(neighbour)
                    frontier.append(neighbour)
        result.append(tuple(sorted(reached)))
    return sorted(result, key=lambda component: (-len(component), component))


def compute_fundamental_domains(
    x: Permutation,
    y: Permutation,
) -> list[tuple[int, tuple[tuple[int, ...], ...]]]:
    if x.degree != y.degree:
        raise ValueError("permutations have different degrees")
    if y.order() != 2:
        raise ValueError("the second permutation must have order two")
    if not is_transitive(x, y):
        raise ValueError("the permutations must generate a transitive group")

    x_cycles = x.cycles()
    x_orbit = {
        point: frozenset(cycle)
        for cycle in x_cycles
        for point in cycle
    }
    full_vertices = sorted(
        min(cycle) for cycle in x_cycles if len(cycle) == x.order()
    )
    adjacency = {vertex: set() for vertex in full_vertices}
    for position, left in enumerate(full_vertices):
        for right in full_vertices[position + 1:]:
            right_across_y = {y(point) for point in x_orbit[right]}
            if x_orbit[left] & right_across_y:
                adjacency[left].add(right)
                adjacency[right].add(left)

    components = connected_components(adjacency)
    starts = list(components[0]) if components else sorted(
        min(cycle) for cycle in x_cycles
    )
    domains = []
    for start in starts:
        tree: list[tuple[int, int]] = []
        if components:
            allowed = set(components[0])
            reached = {min(x_orbit[start])}
            frontier = [min(x_orbit[start])]
            while frontier:
                next_frontier = []
                for vertex in sorted(frontier):
                    for neighbour in sorted(adjacency[vertex] & allowed):
                        neighbour = min(x_orbit[neighbour])
                        if neighbour not in reached:
                            reached.add(neighbour)
                            next_frontier.append(neighbour)
                            tree.append((vertex, neighbour))
                frontier = next_frontier

        words: list[tuple[int, ...] | None] = [None] * x.degree
        for exponent in range(len(x_orbit[start])):
            words[x.apply_power(start, exponent)] = (exponent,)

        for left, right in tree:
            connector = None
            for exponent in range(len(x_orbit[left])):
                candidate = x.apply_power(left, exponent)
                if x_orbit[y(candidate)] & x_orbit[right]:
                    connector = candidate
                    break
            if connector is None:
                raise RuntimeError("petal-tree edge has no connector")
            connector_word = words[connector]
            if connector_word is None:
                raise RuntimeError("connector petal has not been assigned")
            for exponent in range(x.order()):
                point = x.apply_power(y(connector), exponent)
                if words[point] is None:
                    words[point] = connector_word + (1, exponent)

        reached = {
            calculate_word(word, x, y, start)
            for word in words
            if word is not None
        }
        while len(reached) < x.degree:
            progress = False
            missing = [point for point in range(x.degree) if point not in reached]
            for point in missing:
                across = y(point)
                if across not in reached:
                    continue
                previous = words[across]
                if previous is None:
                    raise RuntimeError("assigned point has no word")
                words[point] = (
                    previous + (1,)
                    if len(previous) % 2 == 1
                    else previous + (0, 1)
                )
                reached.add(point)
                progress = True

            while True:
                x_progress = False
                for point in range(x.degree):
                    if point in reached:
                        continue
                    previous_point = x.apply_power(point, -1)
                    if previous_point not in reached:
                        continue
                    previous = words[previous_point]
                    if previous is None:
                        raise RuntimeError("assigned point has no word")
                    words[point] = (
                        previous + (1,)
                        if len(previous) % 2 == 0
                        else previous + (0, 1)
                    )
                    reached.add(point)
                    progress = x_progress = True
                if not x_progress:
                    break
            if not progress:
                raise RuntimeError("fundamental-domain traversal stalled")

        complete_words = [word for word in words if word is not None]
        if len(complete_words) != x.degree:
            raise RuntimeError("not every sheet received a word")
        padded_length = max(len(word) for word in complete_words) + 1
        padded_words = [
            word + (0,) * (padded_length - len(word))
            for word in complete_words
        ]
        domain: list[tuple[int, ...] | None] = [None] * x.degree
        for word in padded_words:
            domain[calculate_word(word, x, y, start)] = word
        if any(word is None for word in domain):
            raise RuntimeError("fundamental-domain words are not bijective")
        final_domain = tuple(word for word in domain if word is not None)
        if tuple(
            calculate_word(word, x, y, start) for word in final_domain
        ) != tuple(range(x.degree)):
            raise RuntimeError("fundamental-domain indexing invariant failed")
        domains.append((start, final_domain))
    return domains


def matrix_multiply(
    left: tuple[tuple[float, float], tuple[float, float]],
    right: tuple[tuple[float, float], tuple[float, float]],
) -> tuple[tuple[float, float], tuple[float, float]]:
    return (
        (
            left[0][0] * right[0][0] + left[0][1] * right[1][0],
            left[0][0] * right[0][1] + left[0][1] * right[1][1],
        ),
        (
            left[1][0] * right[0][0] + left[1][1] * right[1][0],
            left[1][0] * right[0][1] + left[1][1] * right[1][1],
        ),
    )


def matrix_power(
    matrix: tuple[tuple[float, float], tuple[float, float]],
    exponent: int,
) -> tuple[tuple[float, float], tuple[float, float]]:
    result = ((1.0, 0.0), (0.0, 1.0))
    for _ in range(exponent):
        result = matrix_multiply(result, matrix)
    return result


def kite_center_function(x: Permutation, y: Permutation):
    a = x.order()
    b = y.order()
    c = x.then(y).order()
    lambda_value = (
        math.cos(math.pi / a) * math.cos(math.pi / b)
        + math.cos(math.pi / c)
    ) / (math.sin(math.pi / a) * math.sin(math.pi / b))
    mu = lambda_value + math.sqrt(lambda_value**2 - 1)
    da = (
        (math.cos(math.pi / a), math.sin(math.pi / a)),
        (-math.sin(math.pi / a), math.cos(math.pi / a)),
    )
    db = (
        (math.cos(math.pi / b), mu * math.sin(math.pi / b)),
        (-math.sin(math.pi / b) / mu, math.cos(math.pi / b)),
    )

    def center(word: tuple[int, ...]) -> complex:
        padded = word if len(word) % 2 == 0 else word + (0,)
        matrix = ((1.0, 0.0), (0.0, 1.0))
        for index in range(0, len(padded), 2):
            matrix = matrix_multiply(matrix, matrix_power(da, padded[index]))
            matrix = matrix_multiply(matrix, matrix_power(db, padded[index + 1]))
        point = 1j * (1 + mu) / 2
        image = (
            matrix[0][0] * point + matrix[0][1]
        ) / (
            matrix[1][0] * point + matrix[1][1]
        )
        return (image - 1j) / (image + 1j)

    return center


def compute_border_and_gluing(
    domain: tuple[tuple[int, ...], ...],
    x: Permutation,
    y: Permutation,
    start: int,
    tolerance: float = 1e-10,
) -> tuple[tuple[int, int, int, int, int], ...]:
    a, b = x.order(), y.order()
    center = kite_center_function(x, y)
    centers = tuple(center(word) for word in domain)
    domain_set = set(domain)
    border: list[tuple[int, int, int, int]] = []

    def consider(
        source_word: tuple[int, ...],
        neighbour_word: tuple[int, ...],
        edge_type: int,
        orientation: int,
    ) -> None:
        neighbour = calculate_word(neighbour_word, x, y, start)
        if (
            neighbour_word not in domain_set
            and abs(center(neighbour_word) - centers[neighbour]) > tolerance
        ):
            source = calculate_word(source_word, x, y, start)
            border.append((source, neighbour, edge_type, orientation))

    for word in domain:
        max_position = max(
            [1] + [index + 1 for index, value in enumerate(word) if value != 0]
        )
        index = max_position - 1
        neighbours = [list(word) for _ in range(4)]
        if max_position % 2 == 1:
            neighbours[0][index] = (word[index] + 1) % a
            neighbours[1][index] = (word[index] - 1) % a
            neighbours[2][index + 1] = (word[index + 1] + 1) % b
            neighbours[3][index + 1] = (word[index + 1] - 1) % b
        else:
            neighbours[0][index] = (word[index] + 1) % b
            neighbours[1][index] = (word[index] - 1) % b
            neighbours[2][index + 1] = (word[index + 1] + 1) % a
            neighbours[3][index + 1] = (word[index + 1] - 1) % a

        consider(
            word,
            tuple(neighbours[0]),
            max_position % 2,
            (-1) ** (max_position + 1),
        )
        consider(
            word,
            tuple(neighbours[1]),
            max_position % 2,
            -((-1) ** (max_position + 1)),
        )
        consider(
            word,
            tuple(neighbours[2]),
            (max_position + 1) % 2,
            (-1) ** max_position,
        )
        consider(
            word,
            tuple(neighbours[3]),
            (max_position + 1) % 2,
            -((-1) ** max_position),
        )

    remaining = list(border)
    result = []
    gluing_id = 1
    while remaining:
        edge = remaining.pop(0)
        target = (edge[1], edge[0], edge[2], -edge[3])
        try:
            remaining.remove(target)
        except ValueError as error:
            raise RuntimeError(f"unpaired border edge {edge}") from error
        result.append(tuple(value + 1 if index < 2 else value
                            for index, value in enumerate(edge)) + (gluing_id,))
        result.append(tuple(value + 1 if index < 2 else value
                            for index, value in enumerate(target)) + (gluing_id,))
        gluing_id += 1
    return tuple(result)


def cycle_lengths(permutation: Permutation) -> tuple[int, ...]:
    return tuple(sorted((len(cycle) for cycle in permutation.cycles()), reverse=True))


def genus(x: Permutation, y: Permutation, z: Permutation) -> int:
    index_sum = sum(
        permutation.degree - len(permutation.cycles())
        for permutation in (x, y, z)
    )
    return 1 - x.degree + index_sum // 2


def matlab_list(values: Iterable[int]) -> str:
    return "[" + ",".join(str(value) for value in values) + "]"


def matlab_cycles(permutation: Permutation) -> str:
    cycles = ",".join(
        matlab_list(point + 1 for point in cycle)
        for cycle in permutation.cycles()
    )
    return "{" + cycles + "}"


def emit_matlab(
    output: Path,
    x: Permutation,
    y: Permutation,
    domains: list[tuple[int, tuple[tuple[int, ...], ...]]],
    gluing_data: list[tuple[tuple[int, int, int, int, int], ...]],
    provenance: str,
    source_sha256: str,
) -> None:
    z = inverse_product(x, y)
    lines = [
        f"% Generated by scripts/barth_wenz_preprocess.py ({provenance})",
        "% Open port of Barth--Wenz Step1_ComputeFundamentalDomains.txt",
        f"% Input source SHA-256: {source_sha256}",
        f"% Upstream code bundle SHA-256: {BARTH_WENZ_CODE_SHA256}",
        f"permx = {matlab_list(image + 1 for image in x.images)};",
        f"permy = {matlab_list(image + 1 for image in y.images)};",
        f"permz = {matlab_list(image + 1 for image in z.images)};",
        "",
        f"permx_cycles = {matlab_cycles(x)};",
        f"permy_cycles = {matlab_cycles(y)};",
        f"permz_cycles = {matlab_cycles(z)};",
        "",
        f"a = {x.order()};",
        f"b = {y.order()};",
        f"c = {z.order()};",
        "",
        "% Optional normalizer-based symmetrization is not part of this port.",
        "ConjugateEdges = [];",
        "",
    ]
    for index, ((_, domain), gluing) in enumerate(
        zip(domains, gluing_data),
        start=1,
    ):
        rows = ";".join(",".join(str(value) for value in word) for word in domain)
        gluing_rows = ";".join(
            ",".join(str(value) for value in edge) for edge in gluing
        )
        lines.append(f"FDList{{{index}}}=[{rows}];")
        lines.append(f"GluingDataList{{{index}}}=[{gluing_rows}];")
        lines.append("")
    output.write_text("\n".join(lines), encoding="utf-8")


def published_52_fixture() -> tuple[Permutation, Permutation, str, str]:
    x = permutation_from_cycles(52, (
        (1, 41, 8, 9, 45, 32, 39, 44),
        (2, 13, 29, 21, 50, 26, 34, 6),
        (3, 35, 52, 30),
        (4, 7, 22, 18, 33, 43, 10, 38),
        (5, 37, 27, 42, 25, 15, 12, 24),
        (11, 51, 17, 47, 36, 31, 49, 40),
        (14, 20, 28, 48),
        (16, 19, 23, 46),
    ))
    y = permutation_from_cycles(52, (
        (1, 20), (2, 34), (3, 7), (4, 16), (5, 17), (8, 41),
        (9, 13), (10, 52), (11, 40), (12, 23), (14, 29), (15, 25),
        (18, 33), (19, 47), (21, 35), (22, 43), (26, 42),
        (27, 45), (28, 36), (31, 39), (32, 49), (37, 51),
        (38, 48), (46, 50),
    ))
    return (
        x,
        y,
        "Barth-Wenz ancillary 52.txt",
        BARTH_WENZ_FIXTURES_SHA256,
    )


def m23_target(class_id: int) -> tuple[Permutation, Permutation, str, str]:
    lines = [
        line for line in M23_CLASSES.read_text(encoding="utf-8").splitlines()
        if not line.startswith("#")
    ]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    if not 1 <= class_id <= len(rows):
        raise ValueError(f"target class must be in 1..{len(rows)}")
    row = rows[class_id - 1]
    first = parse_images(row["first_images"])
    second = parse_images(row["second_images"])
    involution = parse_images(row["third_images"])
    z = inverse_product(first, involution)
    if cycle_lengths(z) != cycle_lengths(second):
        raise RuntimeError("reordered target no longer has the 8A cycle structure")
    source_sha256 = hashlib.sha256(M23_CLASSES.read_bytes()).hexdigest()
    return first, involution, f"M23 target class {class_id}", source_sha256


def summarize(
    x: Permutation,
    y: Permutation,
    domains: list[tuple[int, tuple[tuple[int, ...], ...]]],
    gluing_data: list[tuple[tuple[int, int, int, int, int], ...]],
) -> str:
    z = inverse_product(x, y)
    digest = hashlib.sha256()
    for start, domain in domains:
        digest.update(f"start={start + 1}\n".encode())
        for word in domain:
            digest.update((",".join(map(str, word)) + "\n").encode())
    for gluing in gluing_data:
        for edge in gluing:
            digest.update((",".join(map(str, edge)) + "\n").encode())
    return (
        f"degree={x.degree} orders={x.order()},{y.order()},{z.order()} "
        f"genus={genus(x, y, z)} domains={len(domains)} "
        f"border_edges={','.join(str(len(edges)) for edges in gluing_data)} "
        f"sha256={digest.hexdigest()}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--published-52", action="store_true")
    source.add_argument("--target-class", type=int)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    if args.published_52:
        x, y, provenance, source_sha256 = published_52_fixture()
    else:
        x, y, provenance, source_sha256 = m23_target(args.target_class)
    z = inverse_product(x, y)
    if 1 / x.order() + 1 / y.order() + 1 / z.order() >= 1:
        parser.error("the reordered triple is not hyperbolic")

    domains = compute_fundamental_domains(x, y)
    gluing_data = [
        compute_border_and_gluing(domain, x, y, start)
        for start, domain in domains
    ]
    emit_matlab(
        args.output,
        x,
        y,
        domains,
        gluing_data,
        provenance,
        source_sha256,
    )
    print(summarize(x, y, domains, gluing_data))


if __name__ == "__main__":
    main()
