#!/usr/bin/env sage
"""Audit normalization freedom in König's recovered mod-19 a-relation."""

from __future__ import annotations

import argparse
import hashlib
import importlib.machinery
import importlib.util
import subprocess
from pathlib import Path

import numpy as np

from sage.all import GF, PolynomialRing, matrix, vector

SCHEMA = "m23-koenig-relation-lift-space-v1"


def load_module(name, filename):
    path = Path(__file__).with_name(filename)
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError(f"could not load {filename}")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def parse_candidate(path, numerator_specs, denominator_specs, field):
    numerator_indices = {spec: index for index, spec in enumerate(numerator_specs)}
    denominator_indices = {
        spec: index for index, spec in enumerate(denominator_specs)
    }
    numerator = [field.zero()] * len(numerator_specs)
    denominator = [field.zero()] * len(denominator_specs)
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        kind, i_text, j_text, value_text = line.split("\t")
        spec = (int(i_text), int(j_text))
        if kind == "P":
            numerator[numerator_indices[spec]] = field(value_text)
        elif kind == "Q":
            denominator[denominator_indices[spec]] = field(value_text)
        else:
            raise ValueError(kind)
    return vector(field, numerator + denominator)


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repository, text=True
    ).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument(
        "--basis",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation_basis.npz"),
    )
    parser.add_argument(
        "--candidate",
        type=Path,
        default=Path("data/derived/m23_koenig_f19_a_relation.tsv"),
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    args = parser.parse_args()

    field = GF(19)
    with np.load(args.basis) as stored:
        numerator_specs = [
            (int(i), int(j)) for i, j in stored["numerator_specs"]
        ]
        denominator_specs = [
            (int(i), int(j)) for i, j in stored["denominator_specs"]
        ]
        recovered = matrix(
            field, np.asarray(stored["relations"], dtype=np.int16)
        )
        cutoff = int(stored["selected_cutoff"])
    assert recovered.nrows() == 50
    candidate = parse_candidate(
        args.candidate, numerator_specs, denominator_specs, field
    )
    split = len(numerator_specs)
    normalization_index = numerator_specs.index((0, 1))
    assert candidate[normalization_index] == 1

    verifier = load_module(
        "koenig_relation_space_verifier",
        "verify_koenig_hurwitz_curve.sage",
    )
    _, alpha, beta, relation = verifier.load_polynomial(args.archive)
    polynomial_ring = PolynomialRing(field, names=("u", "v"))
    u, v = polynomial_ring.gens()
    shifted_relation = polynomial_ring(
        relation.change_ring(field)(
            **{str(alpha): u + 7, str(beta): v + 14}
        )
    )
    multiplier_degree = cutoff - shifted_relation.total_degree()
    assert multiplier_degree >= 0
    denominator_index = {
        spec: index for index, spec in enumerate(denominator_specs)
    }
    plane_rows = []
    for i in range(multiplier_degree + 1):
        for j in range(multiplier_degree + 1 - i):
            product = u**i * v**j * shifted_relation
            row = [field.zero()] * (split + len(denominator_specs))
            for spec, coefficient in product.dict().items():
                normalized_spec = tuple(int(exponent) for exponent in spec)
                row[split + denominator_index[normalized_spec]] = coefficient
            plane_rows.append(row)
    plane_relations = matrix(field, plane_rows)
    assert plane_relations.nrows() == 36
    assert plane_relations.rank() == 36

    full_space = recovered.stack(plane_relations)
    assert full_space.rank() == 86
    combination = full_space.transpose().solve_right(candidate)
    assert combination * full_space == candidate

    numerator_zero_columns = [
        index for index in range(split) if candidate[index] == 0
    ]
    full_zero_columns = [
        index for index in range(len(candidate)) if candidate[index] == 0
    ]
    numerator_support_space = (
        full_space.matrix_from_columns(numerator_zero_columns)
        .transpose()
        .right_kernel()
    )
    full_support_space = (
        full_space.matrix_from_columns(full_zero_columns)
        .transpose()
        .right_kernel()
    )
    numerator_restricted = (
        numerator_support_space.basis_matrix() * full_space
    )
    full_restricted = full_support_space.basis_matrix() * full_space
    numerator_support = sum(entry != 0 for entry in candidate[:split])
    denominator_support = sum(entry != 0 for entry in candidate[split:])
    numerator_restricted_dimension = numerator_restricted.rank()
    full_restricted_dimension = full_restricted.rank()
    full_support_numerator_rank = full_restricted.matrix_from_columns(
        range(split)
    ).rank()
    assert numerator_support == 5252
    assert denominator_support == 5322
    assert numerator_restricted_dimension == 37
    assert full_restricted_dimension == 1
    assert full_support_numerator_rank == 1
    normalized_support_rank = numerator_support + denominator_support - 1

    archive_hash = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    candidate_hash = hashlib.sha256(args.candidate.read_bytes()).hexdigest()
    basis_hash = hashlib.sha256(args.basis.read_bytes()).hexdigest()
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# archive_sha256\t{archive_hash}",
        f"# candidate_sha256\t{candidate_hash}",
        f"# basis_sha256\t{basis_hash}",
        f"# numerator_columns\t{split}",
        f"# denominator_columns\t{len(denominator_specs)}",
        f"# recovered_relation_dimension\t{recovered.nrows()}",
        f"# plane_multiple_dimension\t{plane_relations.nrows()}",
        f"# full_cutoff_relation_dimension\t{full_space.rank()}",
        f"# numerator_support\t{numerator_support}",
        f"# denominator_support\t{denominator_support}",
        (
            "# numerator_support_restricted_dimension\t"
            f"{numerator_restricted_dimension}"
        ),
        f"# full_support_restricted_dimension\t{full_restricted_dimension}",
        f"# full_support_numerator_rank\t{full_support_numerator_rank}",
        f"# normalized_support_rank_inferred\t{normalized_support_rank}",
        "# normalization\tP[0,1]=1",
    ]
    text = "\n".join(lines) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    if args.check_summary is not None:
        expected = [
            line
            for line in args.check_summary.read_text().splitlines()
            if not line.startswith("# code_revision\t")
        ]
        actual = [
            line
            for line in text.splitlines()
            if not line.startswith("# code_revision\t")
        ]
        assert actual == expected
    print(text, end="")


if __name__ == "__main__":
    main()
