#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import analyze_8a_infinity_endpoints as audit  # noqa: E402


def endpoint(path: Path, alpha: float, inverse_q: float) -> None:
    lines = [
        '# format=m23_8a_root_saturated_endpoint_v1',
        '# gamma_angle=0.7', '# regularization=0.0001',
        'name\treal\timag']
    for name in (*audit.ROOT_NAMES, *audit.INVERSE_NAMES):
        value = alpha if name == 'alpha' else inverse_q if name == 'inverse_q' else 1.0
        lines.append(f'{name}\t{value}\t0')
    path.write_text('\n'.join(lines)+'\n')


class InfinityEndpointAuditTest(unittest.TestCase):
    def test_inverse_q_direction(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'endpoint.tsv'
            endpoint(path, 10, 1e9)
            row = audit.classify(path)
            self.assertEqual(row['escape_type'], 'inverse_q_dominated')
            self.assertEqual(row['dominant_coordinate'], 'inverse_q')

    def test_mixed_alpha_inverse_q_direction(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'endpoint.tsv'
            endpoint(path, 1000, 800)
            row = audit.classify(path)
            self.assertEqual(row['escape_type'], 'mixed_alpha_inverse_q')
            self.assertAlmostEqual(row['inverse_q_projective_abs'], 0.8)


if __name__ == '__main__':
    unittest.main()
