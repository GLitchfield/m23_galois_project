#!/usr/bin/env python3
"""Check provenance and structural invariants of the committed 8A census."""
from __future__ import annotations

import csv
import hashlib
import math
from pathlib import Path
import re
import statistics
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/derived/m23_8a_8a_2a_inner_classes.tsv'
DEFAULT_CENSUS = ROOT / 'data/derived/m23_8a_belyi_conditioning_census.tsv'
DEFAULT_DETAIL = ROOT / 'data/derived/m23_8a_belyi_conditioning_seeds.tsv'


def read_table(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
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


def close(actual: str, expected: float, label: str) -> None:
    if not math.isclose(float(actual), expected, rel_tol=5e-15, abs_tol=0.0):
        fail(f'{label} does not reconstruct from detail rows')


def check(path: Path, detail_path: Path | None = None) -> None:
    metadata, rows = read_table(path)
    required_metadata = {
        'generated_by', 'code_revision', 'source', 'source_sha256',
        'python_version', 'numpy_version', 'sampling', 'interpretation',
    }
    if set(metadata) != required_metadata:
        fail('metadata keys differ from the versioned census contract')
    if metadata['generated_by'] != 'scripts/census_8a_belyi_conditioning.py':
        fail('unexpected generator')
    if not re.fullmatch(r'[0-9a-f]{40}', metadata['code_revision']):
        fail('code_revision must be a full Git object ID')
    if metadata['source'] != 'data/derived/m23_8a_8a_2a_inner_classes.tsv':
        fail('unexpected source path')
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if metadata['source_sha256'] != source_hash:
        fail('source hash mismatch')

    _, source_rows = read_table(SOURCE)
    source_by_id = {int(row['class_id']): row for row in source_rows}
    by_id = {int(row['class_id']): row for row in rows}
    if len(rows) != 28 or set(by_id) != set(range(1, 29)):
        fail('census must contain every class ID exactly once')
    positive_fields = (
        'minimum_relative_residual', 'median_relative_residual',
        'selected_equilibrated_jacobian_condition',
        'minimum_equilibrated_jacobian_condition',
        'selected_normalized_root_separation',
        'maximum_normalized_root_separation',
        'median_normalized_root_separation',
    )
    for class_id, row in by_id.items():
        if int(row['complex_conjugate_class_id']) != int(
                source_by_id[class_id]['complex_conjugate_class_id']):
            fail(f'class {class_id} conjugate ID mismatch')
        if (row['samples'], row['vertices'], row['edges'], row['triangles']) != (
                '18', '140', '414', '276'):
            fail(f'class {class_id} sampling or mesh counts mismatch')
        if row['selected_rotation'] not in {'0', '1', '2'}:
            fail(f'class {class_id} rotation is invalid')
        if row['selected_normalization'] not in {
                ','.join(map(str, permutation)) for permutation in (
                    (4, 2, 1), (4, 1, 2), (2, 4, 1),
                    (2, 1, 4), (1, 4, 2), (1, 2, 4))}:
            fail(f'class {class_id} normalization is invalid')
        values = {field: float(row[field]) for field in positive_fields}
        if any(not math.isfinite(value) or value <= 0
               for value in values.values()):
            fail(f'class {class_id} has nonpositive or nonfinite metrics')
        if (values['minimum_relative_residual'] >
                values['median_relative_residual']):
            fail(f'class {class_id} residual ordering is invalid')
        if (values['minimum_equilibrated_jacobian_condition'] >
                values['selected_equilibrated_jacobian_condition']):
            fail(f'class {class_id} condition ordering is invalid')
        if (values['selected_normalized_root_separation'] >
                values['maximum_normalized_root_separation']):
            fail(f'class {class_id} separation ordering is invalid')

    if detail_path is None:
        return
    detail_metadata, details = read_table(detail_path)
    if set(detail_metadata) != required_metadata | {'rows'}:
        fail('detail metadata keys differ from the versioned contract')
    for field in required_metadata:
        if detail_metadata[field] != metadata[field]:
            fail(f'detail metadata differs for {field}')
    if detail_metadata['rows'] != (
            'one row per class, rotation, and normalization chart'):
        fail('unexpected detail row description')
    keys = {(int(row['class_id']), int(row['rotation']), row['normalization'])
            for row in details}
    if len(details) != 504 or len(keys) != 504:
        fail('detail ledger must contain 504 unique chart rows')
    normalizations = {
        '4,2,1', '4,1,2', '2,4,1', '2,1,4', '1,4,2', '1,2,4'}
    for class_id in range(1, 29):
        group = [row for row in details if int(row['class_id']) == class_id]
        if len(group) != 18:
            fail(f'class {class_id} does not have 18 detail rows')
        for row in group:
            if row['seed_method'] != 'tutte' or row['refinements'] != '0':
                fail(f'class {class_id} has an unexpected seed method')
            if (row['vertices'], row['edges'], row['triangles']) != (
                    '140', '414', '276'):
                fail(f'class {class_id} detail mesh counts mismatch')
            if int(row['rotation']) not in range(3) or row['normalization'] not in normalizations:
                fail(f'class {class_id} has an invalid chart key')
            if int(row['complex_conjugate_class_id']) != int(
                    source_by_id[class_id]['complex_conjugate_class_id']):
                fail(f'class {class_id} detail conjugate ID mismatch')
            metrics = [float(row[field]) for field in (
                'relative_residual', 'equilibrated_jacobian_condition',
                'normalized_root_separation')]
            if any(not math.isfinite(value) or value <= 0 for value in metrics):
                fail(f'class {class_id} detail metrics are invalid')
        ordered = sorted(group, key=lambda row: (
            float(row['relative_residual']),
            -float(row['normalized_root_separation']),
            float(row['equilibrated_jacobian_condition'])))
        best = ordered[0]
        aggregate = by_id[class_id]
        if (aggregate['selected_rotation'], aggregate['selected_normalization']) != (
                best['rotation'], best['normalization']):
            fail(f'class {class_id} selected chart does not reconstruct')
        close(aggregate['minimum_relative_residual'],
              float(best['relative_residual']), f'class {class_id} minimum residual')
        close(aggregate['median_relative_residual'], statistics.median(
            float(row['relative_residual']) for row in group),
            f'class {class_id} median residual')
        close(aggregate['selected_equilibrated_jacobian_condition'],
              float(best['equilibrated_jacobian_condition']),
              f'class {class_id} selected condition')
        close(aggregate['minimum_equilibrated_jacobian_condition'], min(
            float(row['equilibrated_jacobian_condition']) for row in group),
            f'class {class_id} minimum condition')
        close(aggregate['selected_normalized_root_separation'],
              float(best['normalized_root_separation']),
              f'class {class_id} selected separation')
        close(aggregate['maximum_normalized_root_separation'], max(
            float(row['normalized_root_separation']) for row in group),
            f'class {class_id} maximum separation')
        close(aggregate['median_normalized_root_separation'], statistics.median(
            float(row['normalized_root_separation']) for row in group),
            f'class {class_id} median separation')


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) >= 2 else DEFAULT_CENSUS
    detail = Path(sys.argv[2]) if len(sys.argv) == 3 else None
    if len(sys.argv) > 3:
        raise SystemExit(f'usage: {sys.argv[0]} [CENSUS_TSV [DETAIL_TSV]]')
    try:
        check(path, detail)
    except (OSError, ValueError) as error:
        print(f'conditioning census check failed: {error}', file=sys.stderr)
        raise SystemExit(1) from error
    suffix = ' and 504 chart rows' if detail else ''
    print(f'verified all 28 heuristic 8A Belyi conditioning rows{suffix}')


if __name__ == '__main__':
    main()
