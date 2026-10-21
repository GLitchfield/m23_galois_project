#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from verify_belyi_candidate import (
    M23_8A_PROBLEM,
    M23_8A_SOURCE_SHA256,
    M23_RELATED_START_PROBLEM,
    M23_RELATED_START_SOURCE_SHA256,
    M23_RELATED_START_TARGET,
    NumberField,
    multiplicity_partition,
    verify_irreducible_with_gap,
    verify_record,
)


SCRIPT = Path(__file__).with_name("verify_belyi_candidate.py")


class VerifyBelyiCandidateTest(unittest.TestCase):
    @staticmethod
    def polynomial_with_roots(roots: list[tuple[int, int]]) -> list[int]:
        polynomial = [1]
        for root, multiplicity in roots:
            for _ in range(multiplicity):
                result = [0] * (len(polynomial) + 1)
                for index, coefficient in enumerate(polynomial):
                    result[index] -= root * coefficient
                    result[index + 1] += coefficient
                polynomial = result
        return polynomial

    def test_x_squared_over_q(self) -> None:
        result = verify_record({
            "numerator": [0, 0, 1],
            "denominator": [1],
            "expected_partitions": [[2], [1, 1], [2]],
        })
        self.assertEqual(result["ramification_sum"], 2)

    def test_polynomial_with_two_finite_zeros(self) -> None:
        result = verify_record({
            "numerator": [0, 4, -4],
            "denominator": [1],
            "expected_partitions": [[1, 1], [2], [2]],
        })
        self.assertEqual(result["partitions"][1], [2])

    def test_power_basis_coefficients(self) -> None:
        result = verify_record({
            "field_polynomial": [-2, 0, 1],
            "numerator": [2, [0, -2], 1],
            "denominator": [1],
            "expected_partitions": [[2], [1, 1], [2]],
        })
        self.assertEqual(result["field_degree"], 2)
        self.assertEqual(result["field_irreducibility"], "verified_by_gap")

    def test_rejects_reducible_field_polynomial(self) -> None:
        with self.assertRaisesRegex(ValueError, "reducible over Q"):
            verify_record({
                "field_polynomial": [-1, 0, 1],
                "numerator": [0, 0, 1],
                "denominator": [1],
                "expected_partitions": [[2], [1, 1], [2]],
            })

    def test_rejects_missing_gap_verdict(self) -> None:
        completed = subprocess.CompletedProcess(
            args=["gap"], returncode=0,
            stdout="M23_GAP_VERSION=fake\n", stderr="")
        with patch("verify_belyi_candidate.shutil.which", return_value="/fake/gap"), \
             patch("verify_belyi_candidate.subprocess.run", return_value=completed):
            with self.assertRaisesRegex(ValueError, "no irreducibility verdict"):
                verify_irreducible_with_gap((-2, 0, 1))

    def test_rejects_malformed_gap_verdict(self) -> None:
        completed = subprocess.CompletedProcess(
            args=["gap"], returncode=0,
            stdout="M23_IRREDUCIBLE=unknown\n", stderr="")
        with patch("verify_belyi_candidate.shutil.which", return_value="/fake/gap"), \
             patch("verify_belyi_candidate.subprocess.run", return_value=completed):
            with self.assertRaisesRegex(ValueError, "malformed irreducibility verdict"):
                verify_irreducible_with_gap((-2, 0, 1))

    def test_diagnostic_skip_has_distinct_nonzero_exit(self) -> None:
        fixture = {
            "field_polynomial": [-2, 0, 1],
            "numerator": [2, [0, -2], 1],
            "denominator": [1],
            "expected_partitions": [[2], [1, 1], [2]],
        }
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "candidate.json"
            candidate.write_text(json.dumps(fixture))
            completed = subprocess.run(
                [str(SCRIPT), str(candidate), "--skip-irreducibility-check"],
                text=True, capture_output=True, check=False)
        self.assertEqual(completed.returncode, 3, completed.stderr)
        result = json.loads(completed.stdout)
        self.assertEqual(result["status"], "diagnostic_field_unchecked")

    def test_versioned_candidate_schema(self) -> None:
        result = verify_record({
            "schema_version": "belyi-candidate-v1",
            "problem": {
                "id": "fixture-x2",
                "expected_partitions": [[2], [1, 1], [2]],
            },
            "field": {"generator": None, "defining_polynomial": None},
            "map": {"numerator": [0, 0, 1], "denominator": [1]},
            "provenance": {
                "source": {"description": "unit-test x^2 fixture"},
                "producer": {"software": "unit test", "revision": "inline"},
            },
        })
        self.assertEqual(result["schema_version"], "belyi-candidate-v1")
        self.assertEqual(result["problem"], "fixture-x2")

    def test_m23_schema_requires_certificate_hash(self) -> None:
        record = {
            "schema_version": "belyi-candidate-v1",
            "problem": {
                "id": M23_8A_PROBLEM,
                "expected_partitions": [list(partition) for partition in (
                    (8, 8, 4, 2, 1), (8, 8, 4, 2, 1),
                    (2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1),
                )],
            },
            "field": {"generator": None, "defining_polynomial": None},
            "map": {"numerator": [0, 1], "denominator": [1]},
            "provenance": {
                "source": {
                    "description": "class 1",
                    "class_id": 1,
                    "dataset_sha256": "wrong",
                },
                "producer": {"software": "unit test", "revision": "inline"},
            },
        }
        with self.assertRaisesRegex(ValueError, "dataset hash"):
            verify_record(record)
        record["provenance"]["source"]["dataset_sha256"] = M23_8A_SOURCE_SHA256
        with self.assertRaisesRegex(ValueError, "ramification mismatch"):
            verify_record(record)

    def test_m23_schema_rejects_boolean_class_id(self) -> None:
        record = {
            "schema_version": "belyi-candidate-v1",
            "problem": {
                "id": M23_8A_PROBLEM,
                "expected_partitions": [list(partition) for partition in (
                    (8, 8, 4, 2, 1), (8, 8, 4, 2, 1),
                    (2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1),
                )],
            },
            "field": {"generator": None, "defining_polynomial": None},
            "map": {"numerator": [0, 1], "denominator": [1]},
            "provenance": {
                "source": {
                    "description": "class 1",
                    "class_id": True,
                    "dataset_sha256": M23_8A_SOURCE_SHA256,
                },
                "producer": {"software": "unit test", "revision": "inline"},
            },
        }
        with self.assertRaisesRegex(ValueError, "class_id"):
            verify_record(record)

    def test_related_start_schema_pins_passport_class_and_hash(self) -> None:
        record = {
            "schema_version": "belyi-candidate-v1",
            "problem": {
                "id": M23_RELATED_START_PROBLEM,
                "expected_partitions": [
                    list(partition) for partition in M23_RELATED_START_TARGET],
            },
            "field": {"generator": None, "defining_polynomial": None},
            "map": {"numerator": [0, 1], "denominator": [1]},
            "provenance": {
                "source": {
                    "description": "fixture related-start source class",
                    "class_id": 27,
                    "dataset_sha256": "wrong",
                },
                "producer": {"software": "unit test", "revision": "inline"},
            },
        }
        with self.assertRaisesRegex(ValueError, "dataset hash"):
            verify_record(record)
        record["provenance"]["source"][
            "dataset_sha256"] = M23_RELATED_START_SOURCE_SHA256
        with self.assertRaisesRegex(ValueError, "ramification mismatch"):
            verify_record(record)
        record["provenance"]["source"]["class_id"] = 55
        with self.assertRaisesRegex(ValueError, "class_id"):
            verify_record(record)

    def test_full_target_multiplicity_patterns(self) -> None:
        field = NumberField()
        first = self.polynomial_with_roots([(0, 8), (1, 8), (2, 4), (3, 2), (4, 1)])
        third = self.polynomial_with_roots(
            [(root, 2 if root < 8 else 1) for root in range(15)])
        self.assertEqual(
            multiplicity_partition(field, [field.parse(value) for value in first], 23),
            (8, 8, 4, 2, 1),
        )
        self.assertEqual(
            multiplicity_partition(field, [field.parse(value) for value in third], 23),
            (2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1),
        )

    def test_rejects_wrong_partition(self) -> None:
        with self.assertRaisesRegex(ValueError, "ramification mismatch"):
            verify_record({
                "numerator": [0, 0, 1],
                "denominator": [1],
                "expected_partitions": [[1, 1], [1, 1], [2]],
            })

    def test_rejects_common_factor(self) -> None:
        with self.assertRaisesRegex(ValueError, "not coprime"):
            verify_record({
                "numerator": [0, 0, 1],
                "denominator": [0, 1],
                "expected_partitions": [[1], [1], [1]],
            })

    def test_rejects_inexact_json_numbers(self) -> None:
        with self.assertRaisesRegex(ValueError, "JSON integers"):
            verify_record({
                "numerator": [0, 0, 1.0],
                "denominator": [1],
                "expected_partitions": [[2], [1, 1], [2]],
            })


if __name__ == "__main__":
    unittest.main()
