#!/usr/bin/env python3
"""Describe which projective coordinates carry saturated endpoint escape."""
from __future__ import annotations

import argparse
import csv
import hashlib
import math
import platform
from pathlib import Path
import subprocess


ROOT_NAMES = (
    'alpha', 'ar1', 'ar2', 'br1', 'br2', 'cr4', 'cr2', 'cr1',
    *(f'ur{i}' for i in range(1, 9)), *(f'vr{i}' for i in range(1, 8)))
INVERSE_NAMES = (
    'inverse_alpha', 'inverse_p', 'inverse_f', 'inverse_q', 'inverse_pf')


def read_endpoint(path: Path) -> tuple[dict[str, str], dict[str, complex]]:
    lines = path.read_text().splitlines()
    metadata = {}
    for line in lines:
        if line.startswith('# '):
            key, value = line[2:].split('=', 1)
            metadata[key] = value
    rows = list(csv.DictReader(
        (line for line in lines if not line.startswith('#')), delimiter='\t'))
    values = {row['name']: complex(float(row['real']), float(row['imag']))
              for row in rows}
    expected = {*ROOT_NAMES, *INVERSE_NAMES}
    if set(values) != expected or len(rows) != 28:
        raise ValueError(f'{path}: expected exactly the 28 saturated coordinates')
    if any(not math.isfinite(value.real) or not math.isfinite(value.imag)
           for value in values.values()):
        raise ValueError(f'{path}: nonfinite endpoint coordinate')
    return metadata, values


def classify(path: Path) -> dict[str, object]:
    metadata, values = read_endpoint(path)
    magnitudes = {name: abs(value) for name, value in values.items()}
    scale = max(magnitudes.values())
    if scale == 0:
        raise ValueError(f'{path}: zero endpoint cannot define a projective direction')
    ordered = sorted(magnitudes, key=lambda name: (-magnitudes[name], name))
    root_max = max(magnitudes[name] for name in ROOT_NAMES)
    inverse_max = max(magnitudes[name] for name in INVERSE_NAMES)
    support = ','.join(
        f'{name}:{magnitudes[name]/scale:.6g}' for name in ordered
        if magnitudes[name]/scale >= 0.01)
    if (ordered[0] == 'inverse_q' and root_max/scale < 0.01):
        escape_type = 'inverse_q_dominated'
    elif (ordered[0] == 'alpha'
          and magnitudes['inverse_q']/scale >= 0.1):
        escape_type = 'mixed_alpha_inverse_q'
    else:
        escape_type = 'other'
    return {
        'gamma_angle': float(metadata['gamma_angle']),
        'regularization': float(metadata['regularization']),
        'endpoint_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'dominant_coordinate': ordered[0],
        'escape_type': escape_type,
        'root_maximum_abs': root_max,
        'inverse_maximum_abs': inverse_max,
        'inverse_to_root_ratio': inverse_max/root_max,
        'alpha_projective_abs': magnitudes['alpha']/scale,
        'inverse_q_projective_abs': magnitudes['inverse_q']/scale,
        'projective_support_1pct': support,
    }


def revision() -> str:
    return subprocess.run(
        ['git', 'rev-parse', 'HEAD'], cwd=Path(__file__).resolve().parents[1],
        check=True, text=True, capture_output=True).stdout.strip()


def render(rows: list[dict[str, object]]) -> str:
    headers = [
        '# generated_by\tscripts/analyze_8a_infinity_endpoints.py',
        f'# code_revision\t{revision()}',
        f'# python_version\t{platform.python_version()}',
        '# projectivization\tall 28 saturated affine coordinates divided by their maximum absolute value',
        '# support_threshold\tcoordinates at least 0.01 of the maximum absolute value',
        '# interpretation\tdescriptive escape-direction audit; not a compactification proof or finite solution',
    ]
    fields = list(rows[0])
    body = ['\t'.join(fields)]
    for row in sorted(rows, key=lambda item: (
            item['regularization'], item['gamma_angle'])):
        body.append('\t'.join(
            format(row[field], '.17g') if isinstance(row[field], float)
            else str(row[field]) for field in fields))
    return '\n'.join([*headers, *body, ''])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('endpoints', type=Path, nargs='+')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        output = render([classify(path) for path in args.endpoints])
    except (KeyError, OSError, ValueError) as error:
        parser.error(str(error))
    if args.output:
        args.output.write_text(output)
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
