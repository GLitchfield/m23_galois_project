#!/usr/bin/env python3
"""Evaluate all class-22 charts after the actual two-refinement circle pack."""
from __future__ import annotations

import argparse
import hashlib
import platform
from pathlib import Path
import subprocess

import numpy as np
import scipy

import census_8a_belyi_conditioning as diagnostic
import pilot_8a_belyi_circle_pack as circle
import pilot_8a_belyi_numeric as pilot


def revision() -> str:
    return subprocess.run(
        ['git', 'rev-parse', 'HEAD'], cwd=pilot.SOURCE.parents[2], check=True,
        text=True, capture_output=True).stdout.strip()


def samples(class_id: int = 22, refinements: int = 2) -> list[dict[str, object]]:
    source = diagnostic.source_rows()
    if class_id not in source:
        raise ValueError(f'unknown class ID: {class_id}')
    sigmas = pilot.parse(class_id)
    results = []
    for rotation, ((first, second), roles) in enumerate(diagnostic.ROTATIONS):
        data = pilot.dessin_graph(sigmas[first], sigmas[second])
        base_vertices = len(data[-2])
        vertices, triangles, outer = base_vertices, data[-1], data[-1][0]
        for _ in range(refinements):
            vertices, triangles, outer = circle.subdivide(vertices, triangles, outer)
        print(f'circle packing class {class_id} rotation {rotation}', flush=True)
        positions, _ = circle.pack(vertices, triangles, outer)
        edges = 3*vertices-6
        for normalization in diagnostic.NORMALIZATIONS:
            seed = pilot.initial_from_positions(
                data, positions[:base_vertices], roles,
                normalization=normalization)
            residual, jacobian, parts = pilot.residual_jac(
                seed, normalization)
            results.append({
                'class_id': class_id,
                'complex_conjugate_class_id': int(
                    source[class_id]['complex_conjugate_class_id']),
                'seed_method': 'circle_packing',
                'refinements': refinements,
                'rotation': rotation,
                'normalization': ','.join(map(str, normalization)),
                'vertices': vertices,
                'edges': edges,
                'triangles': len(triangles),
                'relative_residual': float(
                    np.linalg.norm(residual)
                    / max(np.linalg.norm(part) for part in parts)),
                'equilibrated_jacobian_condition':
                    diagnostic.equilibrated_condition(jacobian),
                'normalized_root_separation':
                    diagnostic.normalized_root_separation(seed),
            })
    return results


def render(results: list[dict[str, object]]) -> str:
    source_hash = hashlib.sha256(pilot.SOURCE.read_bytes()).hexdigest()
    headers = [
        '# generated_by\tscripts/census_8a_belyi_circle_transfer.py',
        f'# code_revision\t{revision()}',
        f'# source\t{pilot.SOURCE.relative_to(pilot.SOURCE.parents[2])}',
        f'# source_sha256\t{source_hash}',
        f'# python_version\t{platform.python_version()}',
        f'# numpy_version\t{np.__version__}',
        f'# scipy_version\t{scipy.__version__}',
        '# sampling\t3 cyclic rotations x 2 barycentric refinements x 6 charts',
        '# rows\tone row per class-22 rotation and normalization chart',
        '# interpretation\theuristic seed transfer only; not a solved or certified Belyi map',
    ]
    fields = list(results[0])
    body = ['\t'.join(fields)]
    for result in results:
        body.append('\t'.join(
            format(result[field], '.17g')
            if isinstance(result[field], float) else str(result[field])
            for field in fields))
    return '\n'.join([*headers, *body, ''])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--class-id', type=int, default=22)
    parser.add_argument('--refinements', type=int, default=2)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.refinements < 0:
        parser.error('--refinements must be nonnegative')
    try:
        output = render(samples(args.class_id, args.refinements))
    except ValueError as error:
        parser.error(str(error))
    if args.output:
        args.output.write_text(output)
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
