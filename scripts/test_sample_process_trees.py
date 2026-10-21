#!/usr/bin/env python3
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from sample_process_trees import ProcessRecord, memory_fields, tree_totals


class ProcessTreeTests(unittest.TestCase):
    def test_disjoint_descendant_totals(self) -> None:
        processes = {
            10: ProcessRecord(1, 100),
            11: ProcessRecord(10, 50),
            12: ProcessRecord(11, 25),
            20: ProcessRecord(1, 200),
            21: ProcessRecord(20, 75),
            30: ProcessRecord(1, 999),
        }
        self.assertEqual(tree_totals(processes, [10, 20]),
                         [(3, 175), (2, 275)])

    def test_absent_root_is_empty(self) -> None:
        self.assertEqual(tree_totals({1: ProcessRecord(0, 10)}, [99]),
                         [(0, 0)])

    def test_memory_fields(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "meminfo").write_text(
                "MemTotal: 1000 kB\nMemAvailable: 700 kB\nSwapFree: 80 kB\n"
            )
            self.assertEqual(memory_fields(root), (700, 80))


if __name__ == "__main__":
    unittest.main()
