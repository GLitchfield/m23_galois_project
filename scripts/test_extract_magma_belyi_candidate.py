#!/usr/bin/env python3
from __future__ import annotations

import unittest

from extract_magma_belyi_candidate import (
    bracketed_marker_values,
    build_candidate,
    marker_values,
    parse_magma_sequence,
)


class ExtractMagmaBelyiCandidateTest(unittest.TestCase):
    def test_parses_nested_rational_sequences(self) -> None:
        self.assertEqual(
            parse_magma_sequence("[ [ 1, -1/2 ], [ 0, 3 ] ]"),
            [["1", "-1/2"], ["0", "3"]],
        )

    def test_rejects_nonsequence_syntax(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported Magma"):
            parse_magma_sequence("[ a + 1 ]")

    def test_builds_versioned_candidate(self) -> None:
        transcript = "\n".join([
            "M23_EXACT_FIELD_POLYNOMIAL=[ -2, 0, 1 ]",
            "M23_EXACT_NUMERATOR=[",
            "[ 2, 0 ],",
            "[ 0, -2 ],",
            "[ 1, 0 ]",
            "]",
            "M23_EXACT_DENOMINATOR=[",
            "[ 1, 0 ]",
            "]",
            "M23_EXACT_SANITY=true",
        ]) + "\n"
        candidate = build_candidate(
            transcript, package_revision="abc123", magma_version="V2.test",
            configuration={"prec": 145})
        self.assertEqual(candidate["schema_version"], "belyi-candidate-v1")
        self.assertEqual(candidate["field"]["defining_polynomial"], ["-2", "0", "1"])
        self.assertEqual(candidate["provenance"]["source"]["class_id"], 1)
        self.assertEqual(candidate["provenance"]["producer"]["configuration"]["prec"], 145)

    def test_requires_all_markers_once(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing M23_EXACT_FIELD"):
            marker_values("M23_EXACT_SANITY=true\n")
        transcript = "\n".join([
            "M23_EXACT_FIELD_POLYNOMIAL=[]",
            "M23_EXACT_NUMERATOR=[ 1 ]",
            "M23_EXACT_DENOMINATOR=[ 1 ]",
            "M23_EXACT_SANITY=true",
            "M23_EXACT_SANITY=true",
        ])
        with self.assertRaisesRegex(ValueError, "duplicate exact sanity"):
            marker_values(transcript)

    def test_builds_declared_related_start_candidate(self) -> None:
        transcript = "\n".join([
            "M23_EXACT_FIELD_POLYNOMIAL=[]",
            "M23_EXACT_NUMERATOR=[ 1, 0, 1 ]",
            "M23_EXACT_DENOMINATOR=[ 1 ]",
            "M23_EXACT_SANITY=true",
        ]) + "\n"
        partitions = ((4, 4), (3, 3, 1, 1), (2, 2, 2, 2))
        candidate = build_candidate(
            transcript, package_revision="revision", magma_version="version",
            configuration={}, problem_id="test-related-start",
            expected_partitions=partitions, source_description="fixture source class",
            source_class_id=27, source_dataset_sha256="a" * 64)
        self.assertEqual(candidate["problem"]["id"], "test-related-start")
        self.assertEqual(candidate["problem"]["expected_partitions"], [
            [4, 4], [3, 3, 1, 1], [2, 2, 2, 2]])
        self.assertEqual(candidate["provenance"]["source"]["class_id"], 27)

    def test_rejects_unterminated_wrapped_marker(self) -> None:
        with self.assertRaisesRegex(ValueError, "unterminated"):
            bracketed_marker_values(
                "M23_TEST=[\n[ 1, 2 ]\n", {"test": "M23_TEST="})


if __name__ == "__main__":
    unittest.main()
