#!/usr/bin/env sage
"""Deterministic resumable shards for the M24 genus-11 (-2,0) corridor."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import subprocess
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path

from sage.all import Infinity, PolynomialRing, QQ, valuation
from sage.env import SAGE_VERSION


SCHEMA = "m23-m24-genus11-minus2-shards-v1"
CHECKPOINT_SCHEMA = "m23-m24-genus11-minus2-shard-checkpoint-v2"
BASE_DEPTH = 13
DEFAULT_EXTRA_DEPTH = 4
DEFAULT_SHARDS = 4
DEFAULT_PREFIX_BITS = 4


def load_unit_module():
    path = Path(__file__).with_name(
        "audit_m24_genus11_unit_charts.sage"
    )
    loader = SourceFileLoader("m24_genus11_unit_charts_shards", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


unit = load_unit_module()


def git_revision():
    repository = Path(__file__).resolve().parents[1]
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"],
        cwd=repository,
        text=True,
    ).strip()


def sha256_path(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def shard_owner(residue, modulus, prefix_bits, shard_count):
    exponent = modulus.bit_length() - 1
    assert modulus == 1 << exponent
    assert 0 < prefix_bits <= exponent
    mask = (1 << prefix_bits) - 1
    shift = exponent - prefix_bits
    prefix = (
        ((residue[0] >> shift) & mask) << prefix_bits
    ) | ((residue[1] >> shift) & mask)
    return prefix % shard_count


def encoded_valuation(value):
    if not value:
        return "infinity"
    return int(valuation(value, 2))


def advance_box(chart, residue, modulus, depth):
    t, x = chart.parent().gens()
    active = {tuple(residue): chart}
    current_modulus = modulus
    levels = []
    simple = []
    for _ in range(depth):
        next_active = {}
        dead = 0
        for current_residue, current_chart in active.items():
            derivative_t = current_chart.derivative(t)
            derivative_x = current_chart.derivative(x)
            roots = []
            for t_bit in (0, 1):
                for x_bit in (0, 1):
                    if int(
                        current_chart(t=t_bit, x=x_bit)
                    ) % 2:
                        continue
                    gradient = (
                        int(
                            derivative_t(t=t_bit, x=x_bit)
                        )
                        % 2,
                        int(
                            derivative_x(t=t_bit, x=x_bit)
                        )
                        % 2,
                    )
                    roots.append((t_bit, x_bit, gradient))
            if not roots:
                dead += 1
            for t_bit, x_bit, gradient in roots:
                child_residue = (
                    current_residue[0] + t_bit * current_modulus,
                    current_residue[1] + x_bit * current_modulus,
                )
                if gradient != (0, 0):
                    simple.append(
                        [
                            int(child_residue[0]),
                            int(child_residue[1]),
                            int(gradient[0]),
                            int(gradient[1]),
                        ]
                    )
                    continue
                child = current_chart(
                    t=t_bit + 2 * t,
                    x=x_bit + 2 * x,
                )
                child, _ = unit.boundary.normalize_two_adic(child)
                assert child_residue not in next_active
                next_active[child_residue] = child
        levels.append(
            {
                "input": len(active),
                "dead": dead,
                "simple": len(simple),
                "unresolved": len(next_active),
            }
        )
        active = next_active
        current_modulus *= 2
        if not active:
            for _ in range(len(levels), depth):
                levels.append(
                    {
                        "input": 0,
                        "dead": 0,
                        "simple": len(simple),
                        "unresolved": 0,
                    }
                )
            break

    strong = []
    singular = []
    for terminal_residue, terminal_chart in active.items():
        value = terminal_chart(t=0, x=0)
        derivative_values = (
            terminal_chart.derivative(t)(t=0, x=0),
            terminal_chart.derivative(x)(t=0, x=0),
        )
        if not value:
            singular.append(
                [
                    int(terminal_residue[0]),
                    int(terminal_residue[1]),
                    encoded_valuation(derivative_values[0]),
                    encoded_valuation(derivative_values[1]),
                ]
            )
            continue
        value_valuation = valuation(value, 2)
        derivative_valuations = [
            valuation(entry, 2) if entry else Infinity
            for entry in derivative_values
        ]
        if value_valuation > 2 * min(derivative_valuations):
            strong.append(
                [
                    int(terminal_residue[0]),
                    int(terminal_residue[1]),
                    int(value_valuation),
                    encoded_valuation(derivative_values[0]),
                    encoded_valuation(derivative_values[1]),
                ]
            )

    terminals = [
        [int(left), int(right)]
        for left, right in sorted(active)
    ]
    result = {
        "levels": levels,
        "simple": simple,
        "strong": strong,
        "terminals": terminals,
        "terminal_sha256": unit.residue_digest(
            [tuple(row) for row in terminals]
        ),
    }
    if singular:
        result["singular"] = singular
    return result


def checkpoint_metadata(
    base,
    shard_index,
    shard_count,
    prefix_bits,
    extra_depth,
):
    return {
        "created_code_revision": git_revision(),
        "runner_sha256": sha256_path(Path(__file__)),
        "unit_audit_sha256": sha256_path(
            Path(__file__).with_name(
                "audit_m24_genus11_unit_charts.sage"
            )
        ),
        "archive_sha256": unit.boundary.ARCHIVE_SHA256,
        "model_sha256": unit.boundary.MODEL_SHA256,
        "base_modulus": int(base["modulus"]),
        "base_terminal_sha256": unit.residue_digest(
            base["residues"]
        ),
        "shard_index": shard_index,
        "shard_count": shard_count,
        "prefix_bits": prefix_bits,
        "extra_depth": extra_depth,
    }


def atomic_write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, sort_keys=True, separators=(",", ":"))
        + "\n"
    )
    temporary.replace(path)


def load_checkpoint(path, metadata):
    if not path.exists():
        return {
            "schema": CHECKPOINT_SCHEMA,
            "metadata": metadata,
            "records": {},
        }
    payload = json.loads(path.read_text())
    if payload.get("schema") != CHECKPOINT_SCHEMA:
        raise ValueError(f"unexpected checkpoint schema in {path}")
    existing_metadata = payload.get("metadata")
    comparable_existing = {
        key: value
        for key, value in existing_metadata.items()
        if key != "created_code_revision"
    }
    comparable_expected = {
        key: value
        for key, value in metadata.items()
        if key != "created_code_revision"
    }
    if comparable_existing != comparable_expected:
        raise ValueError(f"checkpoint metadata mismatch in {path}")
    if not isinstance(payload.get("records"), dict):
        raise ValueError(f"invalid checkpoint records in {path}")
    return payload


def record_key(residue):
    return f"{residue[0]},{residue[1]}"


def canonical_transcript(records):
    rows = [
        [key, records[key]]
        for key in sorted(
            records,
            key=lambda value: tuple(
                int(entry) for entry in value.split(",")
            ),
        )
    ]
    return json.dumps(
        rows,
        sort_keys=True,
        separators=(",", ":"),
    )


def aggregate_records(
    base,
    checkpoints,
    shard_count,
    prefix_bits,
    extra_depth,
):
    records = {}
    ownership_counts = []
    for shard_index, checkpoint in enumerate(checkpoints):
        shard_records = checkpoint["records"]
        ownership_counts.append(len(shard_records))
        for key, record in shard_records.items():
            residue = tuple(int(entry) for entry in key.split(","))
            assert shard_owner(
                residue,
                base["modulus"],
                prefix_bits,
                shard_count,
            ) == shard_index
            assert key not in records
            records[key] = record
    expected_keys = {
        record_key(residue) for residue in base["residues"]
    }
    assert set(records) == expected_keys

    levels = []
    for level_index in range(extra_depth):
        levels.append(
            {
                field: sum(
                    record["levels"][level_index][field]
                    for record in records.values()
                )
                for field in (
                    "input",
                    "dead",
                    "simple",
                    "unresolved",
                )
            }
        )
    terminals = sorted(
        tuple(terminal)
        for record in records.values()
        for terminal in record["terminals"]
    )
    assert len(terminals) == len(set(terminals))
    simple = [
        witness
        for record in records.values()
        for witness in record["simple"]
    ]
    strong = [
        witness
        for record in records.values()
        for witness in record["strong"]
    ]
    singular = [
        witness
        for record in records.values()
        for witness in record.get("singular", [])
    ]
    transcript = canonical_transcript(records)
    return {
        "records": records,
        "ownership_counts": ownership_counts,
        "levels": levels,
        "terminals": terminals,
        "simple": simple,
        "strong": strong,
        "singular": singular,
        "transcript_sha256": hashlib.sha256(
            transcript.encode("ascii")
        ).hexdigest(),
    }


def summary_text(
    base,
    aggregate,
    shard_count,
    prefix_bits,
    extra_depth,
):
    levels = aggregate["levels"]
    final_modulus = base["modulus"] << extra_depth
    status = (
        "local_point_found"
        if aggregate["simple"] or aggregate["strong"]
        else "sharded_continuation_unresolved"
    )
    lines = [
        f"# schema\t{SCHEMA}",
        f"# code_revision\t{git_revision()}",
        f"# sage_version\t{SAGE_VERSION}",
        "# source\tKönig dissertation Theorem 5.2 and Appendix 5.1.12",
        f"# archive_sha256\t{unit.boundary.ARCHIVE_SHA256}",
        f"# model_sha256\t{unit.boundary.MODEL_SHA256}",
        f"# status\t{status}",
        f"base_depth\t{BASE_DEPTH}",
        f"base_modulus\t{base['modulus']}",
        f"base_terminal_count\t{len(base['residues'])}",
        "base_terminal_sha256\t"
        + unit.residue_digest(base["residues"]),
        f"shard_count\t{shard_count}",
        f"prefix_bits\t{prefix_bits}",
        "shard_owned_counts\t"
        + ",".join(
            str(value) for value in aggregate["ownership_counts"]
        ),
        f"completed_base_boxes\t{len(aggregate['records'])}",
        f"extra_depth\t{extra_depth}",
        "level_inputs\t"
        + ",".join(str(level["input"]) for level in levels),
        "level_dead_parents\t"
        + ",".join(str(level["dead"]) for level in levels),
        "level_simple_totals\t"
        + ",".join(str(level["simple"]) for level in levels),
        "level_unresolved\t"
        + ",".join(str(level["unresolved"]) for level in levels),
        f"final_modulus\t{final_modulus}",
        f"final_terminal_count\t{len(aggregate['terminals'])}",
        "final_terminal_sha256\t"
        + unit.residue_digest(aggregate["terminals"]),
        f"simple_count\t{len(aggregate['simple'])}",
        f"strong_hensel_count\t{len(aggregate['strong'])}",
        "exact_singular_center_count\t"
        + str(len(aggregate["singular"])),
        "checkpoint_transcript_sha256\t"
        + aggregate["transcript_sha256"],
    ]
    return "\n".join(lines) + "\n"


def self_test():
    residues = [
        (left, right)
        for left in range(1, 16, 2)
        for right in range(1, 16, 2)
    ]
    owned = [
        [
            residue
            for residue in residues
            if shard_owner(residue, 16, 2, 4) == index
        ]
        for index in range(4)
    ]
    assert sorted(
        residue for shard in owned for residue in shard
    ) == residues

    ring = PolynomialRing(QQ, names=("t", "x"))
    t, x = ring.gens()
    first = advance_box(t**2 + x**2, (0, 0), 2, 2)
    second = advance_box(t**2 + x**2, (0, 0), 2, 2)
    assert first == second

    metadata = {
        "fixture": "deterministic-resume",
        "shard_index": 0,
    }
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "shard.json"
        payload = {
            "schema": CHECKPOINT_SCHEMA,
            "metadata": metadata,
            "records": {"0,0": first},
        }
        atomic_write_json(path, payload)
        assert load_checkpoint(path, metadata) == payload
    print(
        "M24 genus-11 minus-two shard self-test passed: "
        "prefix ownership, deterministic continuation, and atomic resume"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--shards", type=int, default=DEFAULT_SHARDS)
    parser.add_argument(
        "--prefix-bits",
        type=int,
        default=DEFAULT_PREFIX_BITS,
    )
    parser.add_argument(
        "--extra-depth",
        type=int,
        default=DEFAULT_EXTRA_DEPTH,
    )
    parser.add_argument("--stop-after-roots", type=int)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-summary", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        if args.archive is None:
            return
    if args.archive is None:
        parser.error("archive is required outside --self-test")
    if args.run_dir is None:
        parser.error("--run-dir is required outside --self-test")
    if args.shards <= 0:
        parser.error("--shards must be positive")
    if args.extra_depth <= 0:
        parser.error("--extra-depth must be positive")

    _, polynomial = unit.boundary.load_model(args.archive)
    base = unit.canonical_unit_audit(
        polynomial,
        -2,
        0,
        BASE_DEPTH,
    )
    assert len(base["residues"]) == 580

    checkpoints = []
    newly_completed = 0
    reused = 0
    for shard_index in range(args.shards):
        metadata = checkpoint_metadata(
            base,
            shard_index,
            args.shards,
            args.prefix_bits,
            args.extra_depth,
        )
        path = args.run_dir / (
            f"shard-{shard_index:03d}-of-{args.shards:03d}.json"
        )
        checkpoint = load_checkpoint(path, metadata)
        owned = [
            residue
            for residue in base["residues"]
            if shard_owner(
                residue,
                base["modulus"],
                args.prefix_bits,
                args.shards,
            )
            == shard_index
        ]
        expected = {record_key(residue) for residue in owned}
        if not set(checkpoint["records"]).issubset(expected):
            raise ValueError(f"foreign record in {path}")
        for residue in owned:
            key = record_key(residue)
            if key in checkpoint["records"]:
                reused += 1
                continue
            checkpoint["records"][key] = advance_box(
                base["active"][residue],
                residue,
                base["modulus"],
                args.extra_depth,
            )
            newly_completed += 1
            atomic_write_json(path, checkpoint)
            if (
                args.stop_after_roots is not None
                and newly_completed >= args.stop_after_roots
            ):
                print(
                    f"stopped after {newly_completed} new base boxes; "
                    f"reused {reused}"
                )
                return
        checkpoints.append(checkpoint)
        print(
            f"completed shard {shard_index + 1}/{args.shards}: "
            f"{len(owned)} base boxes"
        )

    aggregate = aggregate_records(
        base,
        checkpoints,
        args.shards,
        args.prefix_bits,
        args.extra_depth,
    )
    text = summary_text(
        base,
        aggregate,
        args.shards,
        args.prefix_bits,
        args.extra_depth,
    )
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
    print(
        f"resume statistics: {newly_completed} new, {reused} reused"
    )
    print(text, end="")


if __name__ == "__main__":
    main()
