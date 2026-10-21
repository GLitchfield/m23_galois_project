#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from m23_adversarial_review import (
    ReviewError,
    build_evidence_packet,
    critique_prompt,
    load_result,
    parse_claude_result,
    repository_metadata,
    resolve_evidence,
    sha256_bytes,
    validate_citations,
    validate_review,
)


def sample_review(verdict: str = "unclear") -> dict[str, object]:
    return {
        "verdict": verdict,
        "summary": "The packet does not settle the claim.",
        "findings": [{
            "id": "F1",
            "kind": "concern",
            "severity": "major",
            "claim": "A condition is not checked.",
            "evidence": [{
                "source": "docs/example.md",
                "lines": "000001-000002",
                "explanation": "Those lines state only a numerical observation.",
            }],
            "reasoning": "The conclusion requires an additional exact check.",
            "falsification_test": "Run the exact verifier.",
        }],
        "unanswered_questions": ["Does the exact verifier pass?"],
        "confidence": "high",
    }


class M23AdversarialReviewTest(unittest.TestCase):
    def test_evidence_packet_has_hashes_and_stable_line_numbers(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            source = repo / "docs" / "example.md"
            source.parent.mkdir()
            source.write_text("first\nsecond\n")
            evidence = resolve_evidence(repo, ["docs/example.md"])
            packet, records = build_evidence_packet(
                repo,
                "What follows?",
                evidence,
                {"revision": "abc123"},
                max_bytes=100,
            )
            self.assertIn("000001: first", packet)
            self.assertIn("000002: second", packet)
            self.assertEqual(records[0]["path"], "docs/example.md")
            self.assertEqual(records[0]["lines"], 2)
            self.assertEqual(
                records[0]["sha256"], sha256_bytes(b"first\nsecond\n"))

    def test_rejects_evidence_outside_repository(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            repo = parent / "repo"
            repo.mkdir()
            outside = parent / "outside.md"
            outside.write_text("secret")
            with self.assertRaisesRegex(ReviewError, "escapes"):
                resolve_evidence(repo, ["../outside.md"])

    def test_dirty_repository_metadata_fingerprints_contents(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(
                ["git", "config", "user.email", "test@example.invalid"],
                cwd=repo, check=True)
            subprocess.run(
                ["git", "config", "user.name", "Test User"], cwd=repo, check=True)
            tracked = repo / "tracked.txt"
            tracked.write_text("initial\n")
            subprocess.run(["git", "add", "tracked.txt"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-qm", "initial"], cwd=repo, check=True)
            tracked.write_text("changed once\n")
            first = repository_metadata(repo)
            tracked.write_text("changed twice\n")
            second = repository_metadata(repo)
            self.assertTrue(first["dirty"])
            self.assertNotEqual(first["workspace_sha256"], second["workspace_sha256"])

    def test_rejects_oversized_packet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            source = repo / "large.txt"
            source.write_text("abcdef")
            with self.assertRaisesRegex(ReviewError, "exceeding"):
                build_evidence_packet(
                    repo,
                    "Question",
                    [source],
                    {"revision": "abc123"},
                    max_bytes=5,
                )

    def test_parses_claude_structured_output(self) -> None:
        review = sample_review()
        envelope = json.dumps({"structured_output": review, "cost_usd": 0})
        self.assertEqual(parse_claude_result(envelope), review)

    def test_validation_rejects_missing_fields(self) -> None:
        with self.assertRaisesRegex(ReviewError, "missing fields"):
            validate_review({"verdict": "unclear"})

    def test_citation_validation_rejects_unseen_files_and_bad_ranges(self) -> None:
        records = [{"path": "docs/example.md", "lines": 2}]
        valid = sample_review()
        valid["findings"][0]["evidence"][0]["lines"] = "000001-000002"
        self.assertEqual(validate_citations(valid, records), valid)

        outside = sample_review()
        outside["findings"][0]["evidence"][0]["source"] = "docs/unseen.md"
        with self.assertRaisesRegex(ReviewError, "outside the packet"):
            validate_citations(outside, records)

        out_of_range = sample_review()
        out_of_range["findings"][0]["evidence"][0]["lines"] = "000002-000003"
        with self.assertRaisesRegex(ReviewError, "outside docs/example.md"):
            validate_citations(out_of_range, records)

    def test_invalid_partial_result_is_not_resumed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "result.json"
            path.write_text('{"verdict":"unclear"}\n')
            self.assertIsNone(load_result(path))

    def test_critique_preserves_both_blind_reviews_as_quoted_data(self) -> None:
        own = sample_review("supported")
        peer = sample_review("not_supported")
        prompt = critique_prompt("PACKET", own, peer)
        self.assertIn("BEGIN OWN REVIEW", prompt)
        self.assertIn("BEGIN PEER REVIEW", prompt)
        self.assertIn("Model consensus is not", prompt)
        self.assertLess(prompt.index('"supported"'), prompt.index('"not_supported"'))


if __name__ == "__main__":
    unittest.main()
