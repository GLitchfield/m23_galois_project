#!/usr/bin/env python3
"""Rank deterministic, cheap numerical seeds for all certified 8A classes.

This is a reconnaissance tool, not a Belyi-map solver or a proof.  It uses one
canonical outer flag triangle in each cyclic branch rotation and all six
distinguished-point charts.  The resulting 18 seeds per class are evaluated
against the normalized coefficient equations without taking Newton steps.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import platform
from pathlib import Path
import subprocess
import sys

import numpy as np

import pilot_8a_belyi_numeric as pilot


ROTATIONS = (
    ((0, 1), ('B', 'W', 'F')),
    ((1, 2), ('F', 'B', 'W')),
    ((2, 0), ('W', 'F', 'B')),
)
NORMALIZATIONS = tuple(itertools.permutations((4, 2, 1)))


def source_rows() -> dict[int, dict[str, str]]:
    lines = [line for line in pilot.SOURCE.read_text().splitlines()
             if not line.startswith('#')]
    return {int(row['class_id']): row
            for row in csv.DictReader(lines, delimiter='\t')}


def equilibrated_condition(jacobian: np.ndarray) -> float:
    """Return a simple row/column-equilibrated 2-norm condition estimate."""
    row_norms = np.linalg.norm(jacobian, axis=1)
    if np.any(row_norms == 0):
        return float('inf')
    scaled = jacobian / row_norms[:, None]
    column_norms = np.linalg.norm(scaled, axis=0)
    if np.any(column_norms == 0):
        return float('inf')
    singular = np.linalg.svd(scaled / column_norms[None, :],
                             compute_uv=False)
    if singular[-1] == 0:
        return float('inf')
    return float(singular[0] / singular[-1])


def normalized_root_separation(seed: np.ndarray) -> float:
    """Measure all root collisions represented by the five saturation gates."""
    p = [*seed[1:3], 0 + 0j, 1 + 0j]
    f = list(seed[3:8])
    q = list(seed[8:23])
    distances = []
    for roots in (p, f, q):
        distances.extend(abs(a - b) for i, a in enumerate(roots)
                         for b in roots[i + 1:])
    distances.extend(abs(a - b) for a in p for b in f)
    coordinate_scale = max(1.0, *(abs(root) for root in (*p, *f, *q)))
    alpha_margin = abs(seed[0]) / (1.0 + abs(seed[0]))
    return float(min(alpha_margin, min(distances) / coordinate_scale))


def class_samples(class_id: int, conjugate_id: int) -> list[dict[str, object]]:
    sigmas = pilot.parse(class_id)
    samples = []
    for rotation, ((first, second), roles) in enumerate(ROTATIONS):
        data = pilot.dessin_graph(sigmas[first], sigmas[second])
        vertices = len(data[-2])
        edges = int(np.count_nonzero(data[-2]) // 2)
        triangles = len(data[-1])
        positions = pilot.tutte(data[-2], data[-1][0])
        for normalization in NORMALIZATIONS:
            seed = pilot.initial_from_positions(
                data, positions, roles, normalization=normalization)
            residual, jacobian, parts = pilot.residual_jac(
                seed, normalization)
            relative = float(np.linalg.norm(residual)
                             / max(np.linalg.norm(part) for part in parts))
            samples.append({
                'class_id': class_id,
                'complex_conjugate_class_id': conjugate_id,
                'seed_method': 'tutte',
                'refinements': 0,
                'rotation': rotation,
                'normalization': ','.join(map(str, normalization)),
                'vertices': vertices,
                'edges': edges,
                'triangles': triangles,
                'relative_residual': relative,
                'equilibrated_jacobian_condition': equilibrated_condition(jacobian),
                'normalized_root_separation': normalized_root_separation(seed),
            })
    graph_counts = {(sample['vertices'], sample['edges'], sample['triangles'])
                    for sample in samples}
    if len(graph_counts) != 1:
        raise RuntimeError(f'class {class_id} rotations have unequal mesh sizes')
    return samples


def aggregate_samples(samples: list[dict[str, object]]) -> dict[str, object]:
    if len(samples) != 18:
        raise ValueError('one class aggregate requires exactly 18 samples')
    class_ids = {sample['class_id'] for sample in samples}
    conjugate_ids = {sample['complex_conjugate_class_id'] for sample in samples}
    graph_counts = {(sample['vertices'], sample['edges'], sample['triangles'])
                    for sample in samples}
    if len(class_ids) != 1 or len(conjugate_ids) != 1 or len(graph_counts) != 1:
        raise ValueError('samples do not describe one consistent class')
    vertices, edges, triangles = graph_counts.pop()
    samples.sort(key=lambda sample: (
        sample['relative_residual'], -sample['normalized_root_separation'],
        sample['equilibrated_jacobian_condition']))
    best = samples[0]
    return {
        'class_id': class_ids.pop(),
        'complex_conjugate_class_id': conjugate_ids.pop(),
        'samples': len(samples),
        'vertices': vertices,
        'edges': edges,
        'triangles': triangles,
        'selected_rotation': best['rotation'],
        'selected_normalization': best['normalization'],
        'minimum_relative_residual': best['relative_residual'],
        'median_relative_residual': float(np.median(
            [sample['relative_residual'] for sample in samples])),
        'selected_equilibrated_jacobian_condition': best['equilibrated_jacobian_condition'],
        'minimum_equilibrated_jacobian_condition': min(
            sample['equilibrated_jacobian_condition'] for sample in samples),
        'selected_normalized_root_separation': best['normalized_root_separation'],
        'maximum_normalized_root_separation': max(
            sample['normalized_root_separation'] for sample in samples),
        'median_normalized_root_separation': float(np.median(
            [sample['normalized_root_separation'] for sample in samples])),
    }


def class_census(class_id: int, conjugate_id: int) -> dict[str, object]:
    return aggregate_samples(class_samples(class_id, conjugate_id))


def revision() -> str:
    return subprocess.run(
        ['git', 'rev-parse', 'HEAD'], cwd=pilot.SOURCE.parents[2], check=True,
        text=True, capture_output=True).stdout.strip()


def render(results: list[dict[str, object]], detail: bool = False) -> str:
    source_hash = hashlib.sha256(pilot.SOURCE.read_bytes()).hexdigest()
    headers = [
        '# generated_by\tscripts/census_8a_belyi_conditioning.py',
        f'# code_revision\t{revision()}',
        f'# source\t{pilot.SOURCE.relative_to(pilot.SOURCE.parents[2])}',
        f'# source_sha256\t{source_hash}',
        f'# python_version\t{platform.python_version()}',
        f'# numpy_version\t{np.__version__}',
        '# sampling\t3 cyclic rotations x canonical outer triangle x 6 charts',
        '# interpretation\theuristic seed conditioning only; not a solved or certified Belyi map',
    ]
    if detail:
        headers.append('# rows\tone row per class, rotation, and normalization chart')
    fields = list(results[0])
    body = ['\t'.join(fields)]
    for result in results:
        values = []
        for field in fields:
            value = result[field]
            values.append(format(value, '.17g') if isinstance(value, float)
                          else str(value))
        body.append('\t'.join(values))
    return '\n'.join([*headers, *body, ''])


def parse_class_ids(value: str, available: set[int]) -> list[int]:
    try:
        selected = [int(item) for item in value.split(',')]
    except ValueError as error:
        raise argparse.ArgumentTypeError('class IDs must be comma-separated integers') from error
    if len(selected) != len(set(selected)):
        raise argparse.ArgumentTypeError('class IDs must not repeat')
    unknown = sorted(set(selected) - available)
    if unknown:
        raise argparse.ArgumentTypeError(f'unknown class IDs: {unknown}')
    return selected


def main() -> None:
    rows = source_rows()
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--class-ids', default=','.join(map(str, sorted(rows))),
        help='comma-separated certified class IDs (default: all)')
    parser.add_argument('--output', type=Path,
                        help='write TSV here instead of standard output')
    parser.add_argument('--detail-output', type=Path,
                        help='also write every class/rotation/chart row here')
    args = parser.parse_args()
    try:
        class_ids = parse_class_ids(args.class_ids, set(rows))
    except argparse.ArgumentTypeError as error:
        parser.error(str(error))
    results = []
    details = []
    for class_id in class_ids:
        print(f'conditioning class {class_id}/{class_ids[-1]}',
              file=sys.stderr, flush=True)
        samples = class_samples(
            class_id, int(rows[class_id]['complex_conjugate_class_id']))
        details.extend(samples)
        results.append(aggregate_samples(samples))
    output = render(results)
    if args.output:
        args.output.write_text(output)
    else:
        print(output, end='')
    if args.detail_output:
        args.detail_output.write_text(render(details, detail=True))


if __name__ == '__main__':
    main()
