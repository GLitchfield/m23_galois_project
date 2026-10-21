#!/usr/bin/env python3
from __future__ import annotations

import csv
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data" / "derived" / "m23_8a_component_witnesses.tsv"
DESCENT = ROOT / "data" / "derived" / "m23_8a_small_component_descent.tsv"
SIGNATURES = ROOT / "data" / "derived" / "m23_8a_component_signatures.tsv"
DEGREE = 23

Permutation = tuple[int, ...]
Tuple4 = tuple[Permutation, Permutation, Permutation, Permutation]


def parse_permutation(text: str) -> Permutation:
    values = tuple(int(value) - 1 for value in text.split(","))
    if len(values) != DEGREE or set(values) != set(range(DEGREE)):
        raise ValueError(f"not a degree-{DEGREE} permutation: {text}")
    return values


def inverse(permutation: Permutation) -> Permutation:
    result = [0] * DEGREE
    for source, target in enumerate(permutation):
        result[target] = source
    return tuple(result)


def multiply(left: Permutation, right: Permutation) -> Permutation:
    """GAP right action: i^(left*right) = (i^left)^right."""
    return tuple(right[left[point]] for point in range(DEGREE))


IDENTITY = tuple(range(DEGREE))


def power(permutation: Permutation, exponent: int) -> Permutation:
    result = IDENTITY
    for _ in range(exponent):
        result = multiply(result, permutation)
    return result


def conjugate(element: Permutation, conjugator: Permutation) -> Permutation:
    return multiply(multiply(inverse(conjugator), element), conjugator)


def simultaneous_conjugate(tuple_: Tuple4, conjugator: Permutation) -> Tuple4:
    return tuple(conjugate(entry, conjugator) for entry in tuple_)  # type: ignore[return-value]


def hurwitz_move(tuple_: Tuple4, generator: int) -> Tuple4:
    index = generator - 2
    result = list(tuple_)
    left = tuple_[index]
    right = tuple_[index + 1]
    result[index] = multiply(multiply(left, right), inverse(left))
    result[index + 1] = left
    return tuple(result)  # type: ignore[return-value]


def complex_conjugate(tuple_: Tuple4) -> Tuple4:
    accumulator = IDENTITY
    result = []
    for entry in tuple_:
        result.append(multiply(multiply(accumulator, inverse(entry)),
                               inverse(accumulator)))
        accumulator = multiply(accumulator, entry)
    return tuple(result)  # type: ignore[return-value]


def parse_source():
    tuples: dict[tuple[int, int], Tuple4] = {}
    edges: dict[tuple[int, int, int], tuple[int, Permutation]] = {}
    conjugates: dict[tuple[int, int], tuple[int, int, Permutation]] = {}
    for raw_line in SOURCE.read_text().splitlines():
        if not raw_line or raw_line.startswith("#"):
            continue
        fields = raw_line.split("\t")
        record_type = fields[0]
        if record_type == "T" and len(fields) == 7:
            key = (int(fields[1]) - 1, int(fields[2]) - 1)
            if key in tuples:
                raise ValueError(f"duplicate tuple record {key}")
            tuples[key] = tuple(parse_permutation(value) for value in fields[3:7])  # type: ignore[assignment]
        elif record_type == "E" and len(fields) == 6:
            key = (int(fields[1]) - 1, int(fields[2]) - 1,
                   int(fields[3]) - 2)
            if key in edges:
                raise ValueError(f"duplicate edge record {key}")
            edges[key] = (int(fields[4]) - 1, parse_permutation(fields[5]))
        elif record_type == "C" and len(fields) == 6:
            key = (int(fields[1]) - 1, int(fields[2]) - 1)
            if key in conjugates:
                raise ValueError(f"duplicate conjugation record {key}")
            conjugates[key] = (int(fields[3]) - 1, int(fields[4]) - 1,
                               parse_permutation(fields[5]))
        else:
            raise ValueError(f"malformed witness line: {raw_line}")
    return tuples, edges, conjugates


def expected_descent_map() -> list[int]:
    images: dict[int, int] = {}
    for raw_line in DESCENT.read_text().splitlines():
        if not raw_line or raw_line.startswith("#") or raw_line.startswith("full_"):
            continue
        fields = raw_line.split("\t")
        source = int(fields[0]) - 1
        target = int(fields[1]) - 1
        previous = images.setdefault(source, target)
        if previous != target:
            raise ValueError(f"inconsistent descent image for component {source + 1}")
    if set(images) != set(range(14)):
        raise ValueError("descent artifact does not contain all 14 components")
    return [images[index] for index in range(14)]


PAIR_POSITIONS = ((0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3))


def pair_product_orders(tuple_: Tuple4) -> tuple[int, ...]:
    result = []
    for left, right in PAIR_POSITIONS:
        product = multiply(tuple_[left], tuple_[right])
        if product == IDENTITY or power(product, 4) != IDENTITY:
            raise ValueError("pair product does not have exact order two or four")
        result.append(2 if power(product, 2) == IDENTITY else 4)
    return tuple(result)


def has_two_inverse_pairs(tuple_: Tuple4) -> bool:
    pairings = (((0, 1), (2, 3)), ((0, 2), (1, 3)), ((0, 3), (1, 2)))
    return any(all(tuple_[right] == inverse(tuple_[left])
                       for left, right in pairing)
               for pairing in pairings)


def signature_transporters(edges, tuples) -> list[tuple[int, ...]]:
    lines = [line for line in SIGNATURES.read_text().splitlines()
             if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    if len(rows) != 14:
        raise ValueError("signature artifact does not contain 14 components")
    transporters: list[tuple[int, ...] | None] = [None] * 14
    for row in rows:
        component = int(row["component_id"]) - 1
        transporter = tuple(int(value) - 1 for value in
                            row["ordered_generator_transporter"].split(","))
        if len(transporter) != 12 or set(transporter) != set(range(12)):
            raise ValueError(f"invalid degree-12 transporter for {component + 1}")
        if row["image_group_id"] != "96.227" or \
                row["ordered_generator_triple_class"] != "1" or \
                row["permutation_subgroup_class"] != "1" or \
                row["pair_product_order_profile"] != "2^48 4^24" or \
                row["ordered_transporter_preserves_pair_product_orders"] != \
                "true" or row["contains_two_inverse_pairs"] != "false":
            raise ValueError(f"unexpected braid signature for {component + 1}")
        if row["pair_subgroup_order_profile"] != "8^12 10200960^60" or \
                row["ordered_transporter_preserves_pair_subgroup_orders"] != \
                "true" or int(row["pair_inner_labeled_action_class"]) != \
                component + 1 or \
                (row["ordered_transporter_preserves_pair_inner_classes"] ==
                 "true") != (component == 0):
            raise ValueError(
                f"unexpected boundary signature for {component + 1}")
        if transporters[component] is not None:
            raise ValueError(f"duplicate signature for {component + 1}")
        transporters[component] = transporter

    if any(transporter is None for transporter in transporters):
        raise ValueError("signature artifact omits a component")
    if any(has_two_inverse_pairs(tuple_) for tuple_ in tuples.values()):
        raise ValueError("a small component contains two inverse pairs")
    result = [transporter for transporter in transporters
              if transporter is not None]
    for component, transporter in enumerate(result):
        for vertex in range(12):
            for generator in range(3):
                source_target = edges[0, vertex, generator][0]
                transported_vertex = transporter[vertex]
                transported_target = edges[
                    component, transported_vertex, generator][0]
                if transporter[source_target] != transported_target:
                    raise ValueError(
                        f"bad ordered braid transporter {(component, vertex, generator)}")
            if pair_product_orders(tuples[0, vertex]) != pair_product_orders(
                    tuples[component, transported_vertex]):
                raise ValueError(
                    f"pair-product labels are not transported {(component, vertex)}")
    return result


def validate(tuples, edges, conjugates) -> None:
    expected_tuples = {(component, vertex)
                       for component in range(14) for vertex in range(12)}
    expected_edges = {(component, vertex, generator)
                      for component in range(14) for vertex in range(12)
                      for generator in range(3)}
    if set(tuples) != expected_tuples:
        raise ValueError("witness does not contain exactly 14*12 tuple records")
    if set(edges) != expected_edges:
        raise ValueError("witness does not contain exactly 14*12*3 edge records")
    if set(conjugates) != expected_tuples:
        raise ValueError("witness does not contain exactly 14*12 conjugation records")
    if len(set(tuples.values())) != 168:
        raise ValueError("canonical tuples are not globally distinct")

    descent_map = expected_descent_map()
    for component in range(14):
        reached = {0}
        queue = deque([0])
        while queue:
            source = queue.popleft()
            for generator in range(3):
                target, conjugator = edges[component, source, generator]
                moved = hurwitz_move(tuples[component, source], generator + 2)
                if simultaneous_conjugate(moved, conjugator) != tuples[component, target]:
                    raise ValueError(f"bad edge witness {(component, source, generator)}")
                if target not in reached:
                    reached.add(target)
                    queue.append(target)
        if reached != set(range(12)):
            raise ValueError(f"component {component + 1} edge graph is disconnected")

        targets = set()
        for vertex in range(12):
            target_component, target_vertex, conjugator = conjugates[component, vertex]
            image = complex_conjugate(tuples[component, vertex])
            if simultaneous_conjugate(image, conjugator) != \
                    tuples[target_component, target_vertex]:
                raise ValueError(f"bad complex-conjugation witness {(component, vertex)}")
            targets.add(target_component)
        if targets != {descent_map[component]}:
            raise ValueError(f"wrong conjugate component for {component + 1}")

    for tuple_ in tuples.values():
        product = IDENTITY
        for entry in tuple_:
            product = multiply(product, entry)
            if power(entry, 8) != IDENTITY or power(entry, 4) == IDENTITY:
                raise ValueError("tuple entry does not have exact order eight")
        if product != IDENTITY:
            raise ValueError("tuple is not product one")


def lean_vector(items: list[str], indent: int = 0) -> str:
    if not items:
        return "![]"
    padding = " " * indent
    inner_padding = " " * (indent + 2)
    return "![\n" + inner_padding + (",\n" + inner_padding).join(items) + \
        "\n" + padding + "]"


def lean_fin_vector(values: Permutation) -> str:
    return "![" + ", ".join(str(value) for value in values) + "]"


def lean_permutation(permutation: Permutation) -> str:
    return f"⟨{lean_fin_vector(permutation)}, {lean_fin_vector(inverse(permutation))}⟩"


def lean_tuple(tuple_: Tuple4) -> str:
    return lean_vector([lean_permutation(entry) for entry in tuple_], 6)


def nested_table(rows: list[list[str]], outer_indent: int = 2) -> str:
    rendered_rows = [lean_vector(row, outer_indent + 2) for row in rows]
    return lean_vector(rendered_rows, outer_indent)


def main() -> None:
    tuples, edges, conjugates = parse_source()
    validate(tuples, edges, conjugates)
    transporters = signature_transporters(edges, tuples)

    tuple_rows = [[lean_tuple(tuples[component, vertex])
                   for vertex in range(12)] for component in range(14)]
    edge_target_rows = [[lean_vector([
        str(edges[component, vertex, generator][0]) for generator in range(3)
    ], 6) for vertex in range(12)] for component in range(14)]
    edge_conjugator_rows = [[lean_vector([
        lean_permutation(edges[component, vertex, generator][1])
        for generator in range(3)
    ], 6) for vertex in range(12)] for component in range(14)]
    conjugate_component_rows = [[str(conjugates[component, vertex][0])
                                 for vertex in range(12)] for component in range(14)]
    conjugate_vertex_rows = [[str(conjugates[component, vertex][1])
                              for vertex in range(12)] for component in range(14)]
    conjugator_rows = [[lean_permutation(conjugates[component, vertex][2])
                        for vertex in range(12)] for component in range(14)]

    print("import M23Formal.Permutations.Degree23")
    print()
    print("/-!")
    print("Generated by `scripts/generate_8a_tuple_lean_certificate.py` from")
    print("`data/derived/m23_8a_component_witnesses.tsv` and")
    print("`data/derived/m23_8a_component_signatures.tsv`. Do not edit by hand.")
    print("-/")
    print()
    print("namespace M23Formal.Certificates.Test0058")
    print()
    print("open M23Formal.Permutations")
    print()
    print("set_option maxRecDepth 100000")
    print()
    print("def componentTuples : Fin 14 → Fin 12 → Tuple4 :=")
    print(nested_table(tuple_rows))
    print()
    print("def edgeTargets : Fin 14 → Fin 12 → Fin 3 → Fin 12 :=")
    print(nested_table(edge_target_rows))
    print()
    print("def edgeConjugators : Fin 14 → Fin 12 → Fin 3 → Perm23 :=")
    print(nested_table(edge_conjugator_rows))
    print()
    print("def orderedGeneratorTransporters : Fin 14 → Fin 12 → Fin 12 :=")
    print(lean_vector([lean_fin_vector(transporter)
                       for transporter in transporters], 2))
    print()
    print("def conjugateTargetComponents : Fin 14 → Fin 12 → Fin 14 :=")
    print(nested_table(conjugate_component_rows))
    print()
    print("def conjugateTargetVertices : Fin 14 → Fin 12 → Fin 12 :=")
    print(nested_table(conjugate_vertex_rows))
    print()
    print("def conjugateConjugators : Fin 14 → Fin 12 → Perm23 :=")
    print(nested_table(conjugator_rows))
    print()
    print("end M23Formal.Certificates.Test0058")


if __name__ == "__main__":
    main()
