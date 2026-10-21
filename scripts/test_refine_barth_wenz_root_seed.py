#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys
import unittest

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import refine_barth_wenz_root_seed as refine  # noqa: E402


class RefineBarthWenzRootSeedTest(unittest.TestCase):
    def test_all_cross_fibre_collisions_are_rejected(self) -> None:
        point = np.array([
            0.7, 2, 3, 4, 5, 6, 7, 8,
            *range(9, 24),
        ], dtype=complex)
        point[8] = point[3]
        result = refine.metrics(point, (4, 2, 1))
        self.assertEqual(result["fq_chordal_separation"], 0)
        self.assertEqual(result["minimum_chordal_separation"], 0)
        self.assertFalse(refine.accepted(point, result))

    def test_nonfinite_endpoint_is_rejected(self) -> None:
        point = np.array([
            0.7, 2, 3, 4, 5, 6, 7, 8,
            *range(9, 24),
        ], dtype=complex)
        result = refine.metrics(point, (4, 2, 1))
        point[0] = complex("nan")
        self.assertFalse(refine.accepted(point, result))


if __name__ == "__main__":
    unittest.main()
