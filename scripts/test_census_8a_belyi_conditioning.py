#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import numpy as np
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import pilot_8a_belyi_numeric as pilot  # noqa: E402

SCRIPT = ROOT / 'scripts' / 'census_8a_belyi_conditioning.py'


class ConditioningCensusTest(unittest.TestCase):
    def run_census(self, class_ids: str) -> list[dict[str, str]]:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), '--class-ids', class_ids],
            cwd=ROOT, text=True, capture_output=True, check=True)
        lines = [line for line in completed.stdout.splitlines()
                 if not line.startswith('#')]
        return list(csv.DictReader(io.StringIO('\n'.join(lines)), delimiter='\t'))

    def test_two_classes_have_complete_finite_metrics(self) -> None:
        rows = self.run_census('1,28')
        self.assertEqual([row['class_id'] for row in rows], ['1', '28'])
        for row in rows:
            self.assertEqual(row['samples'], '18')
            self.assertEqual((row['vertices'], row['edges'], row['triangles']),
                             ('140', '414', '276'))
            self.assertIn(row['selected_rotation'], ('0', '1', '2'))
            self.assertGreater(float(row['minimum_relative_residual']), 0)
            self.assertGreater(float(row['selected_equilibrated_jacobian_condition']), 1)
            self.assertGreater(float(row['selected_normalized_root_separation']), 0)
            self.assertGreaterEqual(
                float(row['selected_equilibrated_jacobian_condition']),
                float(row['minimum_equilibrated_jacobian_condition']))
            self.assertLessEqual(
                float(row['selected_normalized_root_separation']),
                float(row['maximum_normalized_root_separation']))

    def test_detail_output_has_every_chart_and_reconstructs_aggregate(self) -> None:
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            aggregate = Path(directory) / 'aggregate.tsv'
            detail = Path(directory) / 'detail.tsv'
            subprocess.run([
                sys.executable, str(SCRIPT), '--class-ids', '1,28',
                '--output', str(aggregate), '--detail-output', str(detail),
            ], cwd=ROOT, check=True, capture_output=True, text=True)
            detail_rows = [line for line in detail.read_text().splitlines()
                           if not line.startswith('#')]
            parsed = list(csv.DictReader(
                io.StringIO('\n'.join(detail_rows)), delimiter='\t'))
            self.assertEqual(len(parsed), 36)
            self.assertEqual(len({(row['class_id'], row['rotation'],
                                   row['normalization']) for row in parsed}), 36)
            for row in parsed:
                self.assertEqual(row['seed_method'], 'tutte')
                self.assertEqual(row['refinements'], '0')

    def test_unknown_class_is_rejected(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), '--class-ids', '29'], cwd=ROOT,
            text=True, capture_output=True, check=False)
        self.assertEqual(completed.returncode, 2)
        self.assertIn('unknown class IDs', completed.stderr)

    def test_tiny_nonzero_saturation_scale_is_not_a_collision(self) -> None:
        self.assertTrue(pilot.usable_saturation_scales([1, 1e-47 + 0j]))
        self.assertFalse(pilot.usable_saturation_scales([1, 0]))
        self.assertFalse(pilot.usable_saturation_scales([1, complex('nan')]))

    def test_residual_uses_requested_normalization(self) -> None:
        seed = np.array([
            0.7, 2, 3, 4, 5, 6, 7, 8,
            *range(9, 24),
        ], dtype=complex)
        _, jacobian_421, _ = pilot.residual_jac(seed, (4, 2, 1))
        _, jacobian_214, _ = pilot.residual_jac(seed, (2, 1, 4))
        expected_421 = pilot.pad(pilot.product_factors([
            (2, 8), (3, 8), (0, 4), (1, 2),
        ]))[:23]
        expected_214 = pilot.pad(pilot.product_factors([
            (2, 8), (3, 8), (0, 2), (1, 1),
        ]))[:23]
        np.testing.assert_allclose(jacobian_421[:, 0], expected_421)
        np.testing.assert_allclose(jacobian_214[:, 0], expected_214)
        self.assertFalse(np.allclose(
            jacobian_421[:, 0], jacobian_214[:, 0]))


if __name__ == '__main__':
    unittest.main()
