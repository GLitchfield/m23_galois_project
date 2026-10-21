#!/usr/bin/env python3
from __future__ import annotations

import csv
from collections import Counter
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data" / "derived" / "m23_8a_small_orbits.tsv"
DESCENT_PATH = ROOT / "data" / "derived" / "m23_8a_small_component_descent.tsv"
SIGNATURE_PATH = ROOT / "data" / "derived" / "m23_8a_component_signatures.tsv"
BOUNDARY_PATH = ROOT / "data" / "derived" / "m23_8a_boundary_incidence.tsv"
WITNESS_PATH = (
    ROOT / "data" / "derived" / "m23_8a_component_witnesses.tsv"
)
THREE_POINT_PATH = (
    ROOT / "data" / "derived" / "m23_8a_8a_2a_inner_classes.tsv"
)


def metadata(path: Path) -> dict[str, str]:
    result = {}
    for line in path.read_text().splitlines():
        if not line.startswith("# "):
            continue
        key, value = line[2:].split("\t", 1)
        result[key] = value
    return result


def parse_permutation(encoded: str) -> tuple[int, ...]:
    images = tuple(int(value) - 1 for value in encoded.split(","))
    assert sorted(images) == list(range(23))
    return images


def multiply_permutations(
    left: tuple[int, ...], right: tuple[int, ...]
) -> tuple[int, ...]:
    # GAP's right action has point^(left*right) = (point^left)^right.
    return tuple(right[left[point]] for point in range(23))


def inverse_permutation(permutation: tuple[int, ...]) -> tuple[int, ...]:
    result = [0] * 23
    for point, image in enumerate(permutation):
        result[image] = point
    return tuple(result)


def main() -> None:
    lines = [line for line in PATH.read_text().splitlines() if not line.startswith("#")]
    rows = list(csv.DictReader(lines, delimiter="\t"))
    assert len(rows) == 1
    row = rows[0]
    assert row["base_class_vector"] == "8A,8A,2A"
    assert int(row["product_one_fixed_first_tuples"]) == 491
    assert int(row["product_one_inner_classes"]) == 64
    assert int(row["generating_inner_nielsen_classes"]) == 28
    assert row["derived_class_vector"] == "8A,8A,8A,8A"
    assert (int(row["pure_orbit_count"]), int(row["pure_orbit_size"]),
            int(row["pure_genus"])) == (84, 2, 0)
    assert (int(row["symmetric_orbit_count"]), int(row["symmetric_orbit_size"]),
            int(row["symmetric_genus"])) == (28, 6, 0)
    assert (int(row["full_hurwitz_orbit_count"]),
            int(row["full_hurwitz_orbit_size"]),
            int(row["full_hurwitz_image_order"])) == (14, 12, 96)

    descent_lines = [line for line in DESCENT_PATH.read_text().splitlines()
                     if not line.startswith("#")]
    descent_rows = list(csv.DictReader(descent_lines, delimiter="\t"))
    assert len(descent_rows) == 28
    full_images: dict[int, int] = {}
    full_halves: dict[int, list[int]] = {}
    symmetric_images: dict[int, int] = {}
    for descent_row in descent_rows:
        full_id = int(descent_row["full_component_id"])
        full_image = int(descent_row["complex_conjugate_full_component_id"])
        symmetric_id = int(descent_row["symmetric_half_id"])
        symmetric_image = int(
            descent_row["complex_conjugate_symmetric_half_id"])
        assert descent_row["complex_conjugation_fixed"] == str(
            full_id == full_image).lower()
        assert descent_row["symmetric_half_complex_conjugation_fixed"] == "false"
        assert (int(descent_row["symmetric_degree"]),
                int(descent_row["symmetric_genus"]),
                int(descent_row["symmetric_monodromy_order"])) == (6, 0, 24)
        if full_id in full_images:
            assert full_images[full_id] == full_image
        full_images[full_id] = full_image
        full_halves.setdefault(full_id, []).append(symmetric_id)
        symmetric_images[symmetric_id] = symmetric_image

    assert set(full_images) == set(range(1, 15))
    assert set(symmetric_images) == set(range(1, 29))
    assert all(full_images[full_images[index]] == index for index in full_images)
    assert all(symmetric_images[symmetric_images[index]] == index
               for index in symmetric_images)
    assert {index for index, image in full_images.items() if index == image} == {3, 6}
    assert all(len(halves) == 2 for halves in full_halves.values())
    assert all(symmetric_images[half] in full_halves[full_images[full_id]]
               for full_id, halves in full_halves.items() for half in halves)

    signature_lines = [line for line in SIGNATURE_PATH.read_text().splitlines()
                       if not line.startswith("#")]
    signature_rows = list(csv.DictReader(signature_lines, delimiter="\t"))
    assert len(signature_rows) == 14
    assert [int(row["component_id"]) for row in signature_rows] == list(
        range(1, 15))
    assert {row["image_group_id"] for row in signature_rows} == {"96.227"}
    assert {row["ordered_generator_triple_class"]
            for row in signature_rows} == {"1"}
    assert {row["permutation_subgroup_class"]
            for row in signature_rows} == {"1"}
    assert {row["pair_product_order_profile"]
            for row in signature_rows} == {"2^48 4^24"}
    assert {row["ordered_transporter_preserves_pair_product_orders"]
            for row in signature_rows} == {"true"}
    assert {row["contains_two_inverse_pairs"]
            for row in signature_rows} == {"false"}
    assert {row["pair_subgroup_order_profile"]
            for row in signature_rows} == {"8^12 10200960^60"}
    assert {row["ordered_transporter_preserves_pair_subgroup_orders"]
            for row in signature_rows} == {"true"}
    assert [int(row["pair_inner_labeled_action_class"])
            for row in signature_rows] == list(range(1, 15))
    assert [int(row["pair_inner_2a_labeled_action_class"])
            for row in signature_rows] == list(range(1, 15))
    assert [row["ordered_transporter_preserves_pair_inner_classes"]
            for row in signature_rows] == ["true"] + ["false"] * 13
    signature_columns = (
        "q2_cycles", "q3_cycles", "q4_cycles", "q2q3_cycles",
        "q2q4_cycles", "q3q4_cycles", "q2q3q4_cycles",
    )
    assert all(len({row[column] for row in signature_rows}) == 1
               for column in signature_columns)
    assert all(sorted(int(value) for value in
                      row["ordered_generator_transporter"].split(",")) ==
               list(range(1, 13)) for row in signature_rows)

    boundary_lines = [line for line in BOUNDARY_PATH.read_text().splitlines()
                      if not line.startswith("#")]
    boundary_rows = list(csv.DictReader(boundary_lines, delimiter="\t"))
    assert len(boundary_rows) == 14 * 12 * 6
    pair_positions = ((1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4))
    keys = set()
    boundary_by_key: dict[tuple[int, int, int], dict[str, str]] = {}
    conjugate_pair_classes: dict[int, int] = {}
    occurring_three_point_2a_classes = set()
    component_three_point_2a_classes: dict[int, Counter[int]] = defaultdict(
        Counter
    )
    clutching_three_point_2a_classes: dict[int, Counter[int]] = defaultdict(
        Counter
    )
    for boundary_row in boundary_rows:
        component = int(boundary_row["component_id"])
        vertex = int(boundary_row["vertex_id"])
        pair_id = int(boundary_row["pair_id"])
        assert 1 <= component <= 14 and 1 <= vertex <= 12 and 1 <= pair_id <= 6
        assert (int(boundary_row["left_position"]),
                int(boundary_row["right_position"])) == pair_positions[pair_id - 1]
        assert int(boundary_row["pair_product_order"]) in {2, 4}
        assert int(boundary_row["pair_subgroup_order"]) in {8, 10200960}
        pair_class = int(boundary_row["pair_inner_class_id"])
        conjugate_class = int(
            boundary_row["complex_conjugate_pair_inner_class_id"])
        assert pair_class > 0 and conjugate_class > 0
        previous = conjugate_pair_classes.setdefault(pair_class, conjugate_class)
        assert previous == conjugate_class
        three_point_2a_class = int(boundary_row["three_point_2a_class_id"])
        if int(boundary_row["pair_product_order"]) == 2:
            assert 1 <= three_point_2a_class <= 28
            occurring_three_point_2a_classes.add(three_point_2a_class)
            component_three_point_2a_classes[component][
                three_point_2a_class
            ] += 1
            if pair_id == 1:
                clutching_three_point_2a_classes[component][
                    three_point_2a_class
                ] += 1
        else:
            assert three_point_2a_class == 0
        key = (component, vertex, pair_id)
        keys.add(key)
        boundary_by_key[key] = boundary_row
    assert len(keys) == 14 * 12 * 6
    assert set(conjugate_pair_classes) == set(range(1, 58))
    assert set(conjugate_pair_classes.values()) == set(range(1, 58))
    assert all(conjugate_pair_classes[conjugate_pair_classes[index]] == index
               for index in conjugate_pair_classes)
    assert occurring_three_point_2a_classes == set(range(1, 29))

    boundary_metadata = metadata(BOUNDARY_PATH)
    assert int(boundary_metadata[
        "global_8a_8a_4a_fixed_first_tuple_count"]) == 41220
    assert int(boundary_metadata[
        "global_generating_8a_8a_4a_fixed_first_tuple_count"]) == 33664
    assert int(boundary_metadata[
        "global_generating_8a_8a_4a_inner_class_count"]) == 4208

    three_point_lines = [
        line for line in THREE_POINT_PATH.read_text().splitlines()
        if not line.startswith("#")
    ]
    three_point_rows = list(csv.DictReader(three_point_lines, delimiter="\t"))
    assert len(three_point_rows) == 28
    assert [int(row["class_id"]) for row in three_point_rows] == list(
        range(1, 29))
    representatives = []
    for three_point_row in three_point_rows:
        entries = tuple(tuple(int(value) for value in
                              three_point_row[column].split(","))
                        for column in
                        ("first_images", "second_images", "third_images"))
        assert all(sorted(entry) == list(range(1, 24)) for entry in entries)
        representatives.append(entries)
    assert representatives == sorted(representatives)
    assert len(set(representatives)) == 28

    q2 = {int(row["class_id"]): int(row["q2_image_class_id"])
          for row in three_point_rows}
    complex_conjugation = {
        int(row["class_id"]): int(row["complex_conjugate_class_id"])
        for row in three_point_rows
    }
    assert set(q2) == set(q2.values()) == set(range(1, 29))
    assert set(complex_conjugation) == set(
        complex_conjugation.values()) == set(range(1, 29))
    assert all(q2[q2[index]] == index and q2[index] != index for index in q2)
    assert all(complex_conjugation[complex_conjugation[index]] == index and
               complex_conjugation[index] != index
               for index in complex_conjugation)
    assert all(q2[complex_conjugation[index]] ==
               complex_conjugation[q2[index]] for index in q2)

    witness_tuples: dict[
        tuple[int, int], tuple[tuple[int, ...], ...]
    ] = {}
    for line in WITNESS_PATH.read_text().splitlines():
        if not line.startswith("T\t"):
            continue
        fields = line.split("\t")
        key = (int(fields[1]), int(fields[2]))
        witness_tuples[key] = tuple(
            parse_permutation(encoded) for encoded in fields[3:7]
        )
    assert len(witness_tuples) == 14 * 12
    identity = tuple(range(23))

    # Use only the standard adjacent split (1,2)|(3,4) for the arithmetic
    # transfer.  This avoids interpreting a literal product of nonadjacent
    # bouquet generators as boundary monodromy without first applying its
    # braid correction.  Check that every order-2 (1,2) collision has an
    # order-2 (3,4) complement and that the two three-point labels represent
    # the same unordered q2 pair.
    complementary_pair = {1: 6, 2: 5, 3: 4, 4: 3, 5: 2, 6: 1}
    for (component, vertex, pair_id), boundary_row in boundary_by_key.items():
        if pair_id != 1 or int(boundary_row["pair_product_order"]) != 2:
            continue
        complement = boundary_by_key[
            (component, vertex, complementary_pair[pair_id])
        ]
        assert int(complement["pair_product_order"]) == 2
        g1, g2, g3, g4 = witness_tuples[(component, vertex)]
        first_product = multiply_permutations(g1, g2)
        second_product = multiply_permutations(g3, g4)
        assert first_product != identity
        assert multiply_permutations(first_product, first_product) == identity
        assert second_product != identity
        assert multiply_permutations(second_product, second_product) == identity
        assert multiply_permutations(
            multiply_permutations(first_product, g3), g4
        ) == identity
        # JKK's ordered second factor is
        #   ((g1*g2), g3, g4).
        # The algebraic cyclic permutation of its markings is exactly the
        # complement triple recorded by the ledger:
        #   (g3, g4, (g3*g4)^-1).
        jkk_second_factor = (first_product, g3, g4)
        cyclic_second_factor = (
            jkk_second_factor[1],
            jkk_second_factor[2],
            jkk_second_factor[0],
        )
        complement_triple = (
            g3,
            g4,
            inverse_permutation(second_product),
        )
        assert cyclic_second_factor == complement_triple
        left_class = int(boundary_row["three_point_2a_class_id"])
        right_class = int(complement["three_point_2a_class_id"])
        assert right_class in {left_class, q2[left_class]}

    unordered_pair_representatives = {
        min(index, q2[index]) for index in q2
    }
    assert len(unordered_pair_representatives) == 14
    for component in range(1, 15):
        counts = component_three_point_2a_classes[component]
        assert sum(counts.values()) == 48
        pair_representatives = {min(index, q2[index]) for index in counts}
        assert len(pair_representatives) == 1
        representative = pair_representatives.pop()
        assert counts == Counter({
            representative: 24,
            q2[representative]: 24,
        })

    component_to_pair: dict[int, int] = {}
    for component in range(1, 15):
        counts = clutching_three_point_2a_classes[component]
        assert sum(counts.values()) == 8
        pair_representatives = {min(index, q2[index]) for index in counts}
        assert len(pair_representatives) == 1
        representative = pair_representatives.pop()
        assert counts == Counter({
            representative: 4,
            q2[representative]: 4,
        })
        component_to_pair[component] = representative
    assert set(component_to_pair.values()) == unordered_pair_representatives

    pair_to_component = {
        pair: component for component, pair in component_to_pair.items()
    }
    assert len(pair_to_component) == 14
    induced_component_conjugation = {}
    for component, representative in component_to_pair.items():
        conjugate_pair = min(
            complex_conjugation[representative],
            complex_conjugation[q2[representative]],
        )
        induced_component_conjugation[component] = pair_to_component[
            conjugate_pair
        ]
    assert induced_component_conjugation == full_images

    three_point_metadata = metadata(THREE_POINT_PATH)
    assert three_point_metadata["class_vector"] == "8A,8A,2A"
    assert int(three_point_metadata["fixed_first_tuple_count"]) == 491
    assert int(three_point_metadata["inner_class_count"]) == 64
    assert int(three_point_metadata["generating_inner_class_count"]) == 28
    print(
        "verified the small (8A)^4 orbits, the 14-pair boundary bijection, "
        "both clutching factors, and complex-conjugation compatibility"
    )


if __name__ == "__main__":
    main()
