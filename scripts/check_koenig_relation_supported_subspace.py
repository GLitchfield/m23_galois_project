#!/usr/bin/env python3
"""Independently validate the König supported-subspace audit."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np

PRIME = 19
WIDTH = 571
PLANE_DIMENSION = 91
INITIAL_AMBIENT_QUOTIENT_DIMENSION = 10
TARGET_QUOTIENT_DIMENSION = 7
TARGET_BASE_DIGITS = 4
SCHEMA = "m23-koenig-a-relation-supported-subspace-v1"
REPRESENTATIVE_SCHEMA = (
    "m23-koenig-a-relation-supported-subspace-representatives-v1"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path: Path) -> dict[str, str]:
    return dict(
        line[2:].split("\t", 1)
        for line in path.read_text().splitlines()
        if line.startswith("# ")
    )


def result_rows(path: Path) -> list[dict[str, int | str]]:
    lines = [
        line
        for line in path.read_text().splitlines()
        if line and not line.startswith("#")
    ]
    header = lines[0].split("\t")
    rows = []
    for line in lines[1:]:
        fields: dict[str, int | str] = dict(
            zip(header, line.split("\t"), strict=True)
        )
        for name in header[1:]:
            fields[name] = int(fields[name])
        rows.append(fields)
    return rows


def rank_mod19(values: np.ndarray) -> int:
    work = np.asarray(values, dtype=np.int64).copy() % PRIME
    rank = 0
    for column in range(work.shape[1]):
        candidates = np.flatnonzero(work[rank:, column])
        if not len(candidates):
            continue
        selected = rank + int(candidates[0])
        work[[rank, selected]] = work[[selected, rank]]
        pivot = work[rank, column:]
        pivot = (
            pivot * pow(int(pivot[0]), -1, PRIME)
        ) % PRIME
        work[rank, column:] = pivot
        factors = work[rank + 1 :, column].copy()
        work[rank + 1 :, column:] = (
            work[rank + 1 :, column:]
            - factors[:, None] * pivot[None, :]
        ) % PRIME
        rank += 1
        if rank == work.shape[0]:
            break
    return rank


def exact_digit_product(
    left: np.ndarray, right: np.ndarray, digits: int
) -> np.ndarray:
    modulus = PRIME**digits
    left_values = np.asarray(left, dtype=np.uint64)
    right_values = np.asarray(right, dtype=np.uint64)
    result = np.zeros(
        (left.shape[0], right.shape[1]), dtype=np.uint64
    )
    coefficients = [np.zeros_like(result) for _ in range(digits)]
    right_digits = [
        ((right_values // PRIME**digit) % PRIME).astype(np.float64)
        for digit in range(digits)
    ]
    for left_digit in range(digits):
        left_part = (
            (left_values // PRIME**left_digit) % PRIME
        ).astype(np.float64)
        for right_digit in range(digits - left_digit):
            product = left_part @ right_digits[right_digit]
            rounded = np.rint(product)
            assert np.array_equal(product, rounded)
            coefficients[left_digit + right_digit] += (
                rounded.astype(np.uint64)
            )
    carry = np.zeros_like(result)
    place = 1
    for total_digit, coefficient in enumerate(coefficients):
        coefficient += carry
        digit_values = coefficient % PRIME
        result += digit_values * place
        carry = coefficient // PRIME
        place *= PRIME
    assert np.all(result < modulus)
    return result


def arrays_sha256(lifts: np.ndarray, free_columns: np.ndarray) -> str:
    digest = hashlib.sha256()
    digest.update(np.asarray(lifts, dtype=np.uint64).tobytes())
    digest.update(np.asarray(free_columns, dtype=np.int32).tobytes())
    return digest.hexdigest()


def self_test() -> None:
    values = np.array(
        [[1, 2, 3], [2, 4, 6], [0, 1, 0]],
        dtype=np.uint64,
    )
    assert rank_mod19(values) == 2
    left = np.array([[1, 20], [19, 2]], dtype=np.uint64)
    right = np.array([[3], [18]], dtype=np.uint64)
    expected = (left @ right) % PRIME**3
    assert np.array_equal(
        exact_digit_product(left, right, 3), expected
    )
    print("independent supported-subspace self-test passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_digits10.tsv"
        ),
    )
    parser.add_argument(
        "--representatives",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_supported_beta77_"
            "digits10_representatives.npz"
        ),
    )
    parser.add_argument(
        "--reduced",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_homogeneous_degree110_"
            "digits10_reduced.npz"
        ),
    )
    parser.add_argument(
        "--basis",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation_basis.npz"),
    )
    parser.add_argument(
        "--profiles",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_degree110_profiles.tsv"
        ),
    )
    parser.add_argument(
        "--family",
        type=Path,
        default=Path(
            "data/derived/m23_koenig_19adic_family_16384.tsv"
        ),
    )
    parser.add_argument(
        "--filtration",
        type=Path,
        default=Path(
            "data/derived/"
            "m23_koenig_a_relation_numerator_filtration.tsv"
        ),
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    certificate = metadata(args.summary)
    assert certificate["schema"] == SCHEMA
    assert int(certificate["prime"]) == PRIME
    digits = int(certificate["digits"])
    modulus = PRIME**digits
    assert int(certificate["modulus"]) == modulus
    cutoff = int(certificate["beta_degree_cutoff"])
    assert cutoff == 77
    assert int(certificate["selected_numerator_columns"]) == 7566
    assert int(certificate["complementary_numerator_columns"]) == 1940
    assert int(certificate["mod19_support_constraint_rank"]) == 470
    assert int(certificate["initial_ambient_quotient_dimension"]) == (
        INITIAL_AMBIENT_QUOTIENT_DIMENSION
    )
    assert int(certificate["target_base_digits"]) == TARGET_BASE_DIGITS
    assert int(certificate["target_quotient_dimension"]) == (
        TARGET_QUOTIENT_DIMENSION
    )
    assert certificate["basis_sha256"] == sha256(args.basis)
    assert certificate["profiles_sha256"] == sha256(args.profiles)
    assert certificate["family_certificate_sha256"] == sha256(args.family)
    assert certificate["filtration_sha256"] == sha256(args.filtration)

    rows = result_rows(args.summary)
    assert len(rows) == 2 * digits
    by_scope = {
        scope: [row for row in rows if row["scope"] == scope]
        for scope in ("training", "all")
    }
    for scope, scope_rows in by_scope.items():
        assert [int(row["digits"]) for row in scope_rows] == list(
            range(1, digits + 1)
        )
        previous_dimension = WIDTH + 1
        previous_plane_dimension = PLANE_DIMENSION + 1
        for row in scope_rows:
            projected = int(row["projected_dimension"])
            numerator_rank = int(row["numerator_projection_rank"])
            plane_dimension = int(row["plane_control_dimension"])
            assert projected <= previous_dimension
            assert projected - numerator_rank == plane_dimension
            assert 0 <= plane_dimension <= PLANE_DIMENSION
            assert plane_dimension <= previous_plane_dimension
            previous_dimension = projected
            previous_plane_dimension = plane_dimension
        assert int(scope_rows[0]["numerator_projection_rank"]) == (
            INITIAL_AMBIENT_QUOTIENT_DIMENSION
        )
        assert int(scope_rows[0]["plane_control_dimension"]) == (
            PLANE_DIMENSION
        )

    all_rows = by_scope["all"]
    first_changed = next(
        (
            int(row["digits"])
            for row in all_rows
            if int(row["digits"]) >= TARGET_BASE_DIGITS
            and int(row["numerator_projection_rank"])
            != TARGET_QUOTIENT_DIMENSION
        ),
        0,
    )
    final_quotient = int(
        all_rows[-1]["numerator_projection_rank"]
    )
    assert int(certificate["first_changed_digit"]) == first_changed
    assert int(certificate["final_quotient_dimension"]) == final_quotient
    expected_status = (
        "beta_degree_block_persists"
        if first_changed == 0
        else f"beta_degree_block_changes_at_digit_{first_changed}"
    )
    assert certificate["status"] == expected_status

    with np.load(args.representatives) as stored:
        assert str(stored["schema"]) == REPRESENTATIVE_SCHEMA
        assert str(stored["code_revision"]) == certificate["code_revision"]
        assert int(stored["prime"]) == PRIME
        assert int(stored["digits"]) == digits
        assert int(stored["modulus"]) == modulus
        assert int(stored["beta_cutoff"]) == cutoff
        lifts = np.asarray(stored["free_lifts"], dtype=np.uint64)
        free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    assert lifts.shape == (
        int(all_rows[-1]["projected_dimension"]),
        WIDTH,
    )
    assert np.all(lifts < modulus)
    assert rank_mod19(lifts) == lifts.shape[0]
    assert certificate["final_representatives_arrays_sha256"] == (
        arrays_sha256(lifts, free_columns)
    )

    with np.load(args.reduced) as stored:
        raw_training = np.asarray(stored["reduced_training"])
        raw_holdout = np.asarray(stored["reduced_holdout"])
        raw_numerator_map = np.asarray(stored["numerator_map"])
        stored_free_columns = np.asarray(
            stored["free_columns"], dtype=np.int32
        )
    training = raw_training.astype(np.uint64)
    holdout = raw_holdout.astype(np.uint64)
    numerator_map = raw_numerator_map.astype(np.uint64)
    assert np.array_equal(free_columns, stored_free_columns)
    reduced_all = np.vstack((training, holdout))
    raw_reduced_all = np.vstack((raw_training, raw_holdout))
    reduced_digest = hashlib.sha256(
        raw_training.tobytes()
        + raw_reduced_all.tobytes()
        + raw_numerator_map.tobytes()
        + free_columns.tobytes()
    ).hexdigest()
    assert certificate["reduced_support_inputs_sha256"] == reduced_digest

    relation_system = (PRIME * reduced_all) % modulus
    relation_residual = exact_digit_product(
        relation_system, lifts.transpose(), digits
    )
    assert np.count_nonzero(relation_residual) == 0

    with np.load(args.basis) as stored:
        specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
    numerator_values = (
        numerator_map @ (lifts % PRIME).transpose()
    ) % PRIME
    assert rank_mod19(numerator_values.transpose()) == final_quotient
    complement = [
        index for index, (_, beta) in enumerate(specs) if beta > cutoff
    ]
    assert len(complement) == 1940
    assert np.count_nonzero(numerator_values[complement, :]) == 0

    print(
        "verified supported beta-degree block: quotient dimensions "
        + ",".join(
            str(int(row["numerator_projection_rank"]))
            for row in all_rows
        )
        + f"; {training.shape[0]} fitting-reduction and "
        f"{holdout.shape[0]} holdout rows vanish"
    )


if __name__ == "__main__":
    main()
