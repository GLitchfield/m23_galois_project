#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import prepare_barth_wenz_matlab as prepare  # noqa: E402


class PrepareBarthWenzMatlabTest(unittest.TestCase):
    def test_pinned_sources_and_input(self) -> None:
        self.assertIn("S0021869320305810-mmc1.zip", prepare.CODE_URL)
        self.assertEqual(
            prepare.CODE_SHA256,
            "0e3202564229dfad668622f77c5d3c5011deac4b83d5ef10c700"
            "c3b9ced080c3",
        )
        self.assertEqual(prepare.SC_VERSION, "3.1.3")
        self.assertEqual(
            prepare.SC_COMMIT,
            "6eb3a8abcda4b2185655b782053cf64e9d90665a",
        )
        self.assertEqual(
            prepare.sha256(prepare.MATLAB_INPUT),
            "1035a6f10819b34faac51db6155c9c682de017034db63d322ccd69"
            "c00f414e4c",
        )

    def test_domain_patch_is_narrow(self) -> None:
        source = "before\nindex = 1;\nafter\n"
        patched = prepare.patch_domain_index(source, 2)
        self.assertIn("index = 2; % pinned by M23 bundle builder", patched)
        with self.assertRaisesRegex(RuntimeError, "marker changed"):
            prepare.patch_domain_index("index=1;", 1)
        with self.assertRaisesRegex(RuntimeError, "marker changed"):
            prepare.patch_domain_index(source + source, 1)

    def test_tar_path_validation(self) -> None:
        self.assertEqual(
            prepare.safe_relative_tar_path("root/@diskmap/diskmap.m"),
            Path("@diskmap/diskmap.m"),
        )
        self.assertIsNone(prepare.safe_relative_tar_path("root"))
        with self.assertRaisesRegex(RuntimeError, "unsafe"):
            prepare.safe_relative_tar_path("root/../../escape")
        with self.assertRaisesRegex(RuntimeError, "unsafe"):
            prepare.safe_relative_tar_path("/absolute")

    def test_zip_is_byte_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = root / "bundle"
            first.mkdir()
            (first / "a.txt").write_text("alpha\n", encoding="utf-8")
            nested = first / "nested"
            nested.mkdir()
            executable = nested / "run"
            executable.write_text("#!/bin/sh\n", encoding="utf-8")
            executable.chmod(0o755)
            one = root / "one.zip"
            prepare.write_zip(first, one)

            (first / "a.txt").touch()
            executable.touch()
            two = root / "two.zip"
            prepare.write_zip(first, two)
            self.assertEqual(
                hashlib.sha256(one.read_bytes()).digest(),
                hashlib.sha256(two.read_bytes()).digest(),
            )

    def test_driver_records_required_outputs(self) -> None:
        driver = prepare.MATLAB_DRIVER.read_text(encoding="utf-8")
        for marker in (
            "accuracy(sc_map)",
            "finite_output",
            "m23_class1_dessin.mat",
            "matlab_summary.tsv",
            "matlab_failure.txt",
            "M23_BARTH_WENZ_STAGE=completed",
        ):
            self.assertIn(marker, driver)


if __name__ == "__main__":
    unittest.main()
