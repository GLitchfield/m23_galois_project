#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest

import numpy as np


from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import pilot_8a_belyi_numeric as pilot  # noqa: E402
import prepare_barth_wenz_root_seed as prepare  # noqa: E402


class BarthWenzRootSeedTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.metadata, rows = prepare.read_dessin(prepare.DEFAULT_DESSIN)
        cls.grouped = prepare.grouped_roots(rows)

    def test_all_six_charts_are_finite_and_distinct(self) -> None:
        seeds = [
            prepare.transform_seed(self.grouped, normalization)
            for normalization in prepare.NORMALIZATIONS
        ]
        self.assertEqual(len(seeds), 6)
        for seed in seeds:
            self.assertEqual(seed.shape, (23,))
            self.assertTrue(np.all(np.isfinite(seed)))
        signatures = {
            tuple(np.round(np.r_[seed.real, seed.imag], 12))
            for seed in seeds
        }
        self.assertEqual(len(signatures), 6)

    def test_alpha_is_the_chart_aware_least_squares_fit(self) -> None:
        for normalization in prepare.NORMALIZATIONS:
            seed = prepare.transform_seed(self.grouped, normalization)
            residual, jacobian, _ = pilot.residual_jac(seed, normalization)
            normal_equation = np.vdot(jacobian[:, 0], residual)
            scale = np.linalg.norm(jacobian[:, 0]) * np.linalg.norm(residual)
            self.assertLess(abs(normal_equation), 2e-13 * max(scale, 1.0))

    def test_ranking_is_complete_and_selects_one_viable_chart(self) -> None:
        rows, seeds = prepare.rank_charts(self.grouped)
        self.assertEqual(len(rows), 6)
        self.assertEqual({row["rank"] for row in rows}, set(range(1, 7)))
        selected = [row for row in rows if row["selected"] == 1]
        self.assertEqual(len(selected), 1)
        normalization = tuple(
            int(value)
            for value in selected[0]["normalization"].split(",")
        )
        self.assertIn(normalization, seeds)
        self.assertEqual(selected[0]["viable"], 1)

    def test_unexpected_partition_is_rejected(self) -> None:
        _, rows = prepare.read_dessin(prepare.DEFAULT_DESSIN)
        with self.assertRaisesRegex(RuntimeError, "root partitions"):
            prepare.grouped_roots(rows[:-1])


if __name__ == "__main__":
    unittest.main()
