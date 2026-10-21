#!/usr/bin/env python3
"""Validate the class-22 circle-transfer ledger and predeclared decision."""
from __future__ import annotations

import csv
import hashlib
import math
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/derived/m23_8a_8a_2a_inner_classes.tsv'
TUTTE = ROOT / 'data/derived/m23_8a_belyi_conditioning_seeds.tsv'
CIRCLE = ROOT / 'data/derived/m23_8a_belyi_circle_transfer.tsv'
DECISION = ROOT / 'data/derived/m23_8a_belyi_seed_selection.tsv'
sys.path.insert(0, str(ROOT / 'scripts'))
import select_8a_belyi_seed as selector  # noqa: E402


def read(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    lines = path.read_text().splitlines()
    metadata = {}
    for line in lines:
        if line.startswith('# '):
            key, value = line[2:].split('\t', 1)
            metadata[key] = value
    rows = list(csv.DictReader(
        (line for line in lines if not line.startswith('#')), delimiter='\t'))
    return metadata, rows


def fail(message: str) -> None:
    raise ValueError(message)


def check() -> None:
    _, source_rows = read(SOURCE)
    conjugate = {int(row['class_id']): int(row['complex_conjugate_class_id'])
                 for row in source_rows}
    metadata, circle_rows = read(CIRCLE)
    required = {
        'generated_by', 'code_revision', 'source', 'source_sha256',
        'python_version', 'numpy_version', 'scipy_version', 'sampling',
        'rows', 'interpretation'}
    if set(metadata) != required:
        fail('circle metadata differs from its versioned contract')
    if metadata['generated_by'] != 'scripts/census_8a_belyi_circle_transfer.py':
        fail('unexpected circle generator')
    if not re.fullmatch(r'[0-9a-f]{40}', metadata['code_revision']):
        fail('circle code revision is not a full Git object ID')
    if metadata['source'] != 'data/derived/m23_8a_8a_2a_inner_classes.tsv':
        fail('unexpected circle source')
    if metadata['source_sha256'] != hashlib.sha256(SOURCE.read_bytes()).hexdigest():
        fail('circle source hash mismatch')
    keys = {(int(row['rotation']), row['normalization']) for row in circle_rows}
    if len(circle_rows) != 18 or len(keys) != 18:
        fail('circle ledger must contain 18 unique class-22 charts')
    normalizations = {
        '4,2,1', '4,1,2', '2,4,1', '2,1,4', '1,4,2', '1,2,4'}
    for row in circle_rows:
        if (row['class_id'], row['complex_conjugate_class_id'],
                row['seed_method'], row['refinements']) != (
                '22', str(conjugate[22]), 'circle_packing', '2'):
            fail('circle class, conjugate, method, or refinement mismatch')
        if (row['vertices'], row['edges'], row['triangles']) != (
                '4970', '14904', '9936'):
            fail('circle refined mesh counts mismatch')
        if int(row['rotation']) not in range(3) or row['normalization'] not in normalizations:
            fail('invalid circle chart key')
        metrics = [float(row[field]) for field, _ in selector.METRICS]
        if any(not math.isfinite(value) or value <= 0 for value in metrics):
            fail('circle metric is nonpositive or nonfinite')

    decision_meta, decision_rows = read(DECISION)
    if len(decision_rows) != 1:
        fail('selection artifact must contain exactly one decision')
    expected_meta = {
        'generated_by': 'scripts/select_8a_belyi_seed.py',
        'tutte_input': 'data/derived/m23_8a_belyi_conditioning_seeds.tsv',
        'circle_input': 'data/derived/m23_8a_belyi_circle_transfer.tsv',
        'rule': 'docs/8a-seed-selection-rule.md',
    }
    for key, value in expected_meta.items():
        if decision_meta.get(key) != value:
            fail(f'unexpected selection metadata: {key}')
    if not re.fullmatch(r'[0-9a-f]{40}', decision_meta.get('code_revision', '')):
        fail('selection code revision is not a full Git object ID')
    if decision_meta.get('tutte_sha256') != hashlib.sha256(TUTTE.read_bytes()).hexdigest():
        fail('selection Tutte input hash mismatch')
    if decision_meta.get('circle_sha256') != hashlib.sha256(CIRCLE.read_bytes()).hexdigest():
        fail('selection circle input hash mismatch')
    _, tutte_rows = read(TUTTE)
    expected = selector.select(tutte_rows, circle_rows, 22)
    expected_row = next(csv.DictReader(
        selector.render(expected).splitlines(), delimiter='\t'))
    if decision_rows[0] != expected_row:
        fail('committed decision does not reproduce from its input ledgers')
    decision = decision_rows[0]
    if (
        decision['rotation'],
        decision['normalization'],
        decision['admissible'],
        decision['failed_gates'],
    ) != ('1', '2,1,4', 'false', 'circle_residual_gate'):
        fail('corrected class-22 decision differs from its frozen verdict')


def main() -> None:
    try:
        check()
    except (OSError, ValueError) as error:
        print(f'8A seed transfer check failed: {error}', file=sys.stderr)
        raise SystemExit(1) from error
    print('verified corrected class-22 transfer rejection')


if __name__ == '__main__':
    main()
