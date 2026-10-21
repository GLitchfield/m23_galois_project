#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import select_8a_belyi_seed as selector  # noqa: E402


def fixtures() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    tutte = []
    circle = []
    normalizations = ('4,2,1','4,1,2','2,4,1','2,1,4','1,4,2','1,2,4')
    for rotation in range(3):
        for index, normalization in enumerate(normalizations):
            chart = rotation*6+index+1
            common = {'class_id':'22', 'rotation':str(rotation),
                      'normalization':normalization}
            tutte.append({**common, 'relative_residual':str(0.1+chart/100),
                          'equilibrated_jacobian_condition':str(1e8+chart),
                          'normalized_root_separation':str(1e-3-chart/1e5)})
            circle.append({**common, 'relative_residual':str(0.2+chart/100),
                           'equilibrated_jacobian_condition':str(1e9+chart),
                           'normalized_root_separation':str(2e-3-chart/1e5)})
    return tutte, circle


class SelectSeedTest(unittest.TestCase):
    def test_predeclared_rule_is_deterministic_and_admissible(self) -> None:
        tutte, circle = fixtures()
        first = selector.select(tutte, circle)
        second = selector.select(list(reversed(tutte)), list(reversed(circle)))
        self.assertEqual(first, second)
        self.assertTrue(first['joint_pareto'])
        self.assertTrue(first['admissible'])
        self.assertEqual(first['failed_gates'], 'none')

    def test_circle_gate_fails_closed(self) -> None:
        tutte, circle = fixtures()
        for row in circle:
            row['equilibrated_jacobian_condition'] = '1e15'
        choice = selector.select(tutte, circle)
        self.assertFalse(choice['admissible'])
        self.assertIn('circle_condition_gate', choice['failed_gates'])

    def test_requires_complete_matching_chart_sets(self) -> None:
        tutte, circle = fixtures()
        with self.assertRaisesRegex(ValueError, 'exactly 18'):
            selector.select(tutte[:-1], circle)


if __name__ == '__main__':
    unittest.main()
