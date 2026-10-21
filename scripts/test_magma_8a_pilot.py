#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "magma" / "8a_belyi" / "run-class1-pilot.sh"


class Magma8APilotTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.belyi = self.root / "Belyi"
        self.belyi.mkdir()
        subprocess.run(["git", "init", "-q", str(self.belyi)], check=True)
        subprocess.run(["git", "-C", str(self.belyi), "config", "user.name", "Test"], check=True)
        subprocess.run(["git", "-C", str(self.belyi), "config", "user.email", "test@example.invalid"], check=True)
        (self.belyi / "README.md").write_text("fixture\n")
        subprocess.run(["git", "-C", str(self.belyi), "add", "README.md"], check=True)
        subprocess.run(["git", "-C", str(self.belyi), "commit", "-q", "-m", "fixture"], check=True)
        self.fake_magma = self.root / "fake-magma"
        self.fake_magma.write_text(
            "#!/usr/bin/env bash\n"
            "if [[ ${1:-} == --version ]]; then\n"
            "  if [[ ${M23_FAKE_MODE:-} == version_hang ]]; then\n"
            "    trap '' TERM; exec sleep 30\n"
            "  fi\n"
            "  echo 'fake-1'; exit 0\n"
            "fi\n"
            "case ${M23_FAKE_MODE:-success} in\n"
            "  hang) trap '' TERM; exec sleep 30;;\n"
            "  timeout) exec sleep 30;;\n"
            "  no_marker) exit 0;;\n"
            "  marker_nonzero)\n"
            "    echo 'M23_NUMERICAL_SUCCESS=true'\n"
            "    echo 'M23_PILOT_COMPLETE=true'\n"
            "    exit 7;;\n"
            "  bad_exact)\n"
            "    echo 'M23_EXACT_SANITY=true'\n"
            "    echo 'M23_PILOT_COMPLETE=true'\n"
            "    exit 0;;\n"
            "esac\n"
            "if [[ $M23_BELYI_STAGE == numerical ]]; then\n"
            "  echo 'M23_NUMERICAL_SUCCESS=true'\n"
            "else\n"
            "  echo 'M23_EXACT_FIELD_POLYNOMIAL=[ -2, 0, 1 ]'\n"
            "  echo 'M23_EXACT_NUMERATOR=[ [ 0, 0 ], [ 0, 0 ], [ 1, 0 ] ]'\n"
            "  echo 'M23_EXACT_DENOMINATOR=[ [ 1, 0 ] ]'\n"
            "  echo 'M23_EXACT_SANITY=true'\n"
            "fi\n"
            "echo 'M23_PILOT_COMPLETE=true'\n"
        )
        self.fake_magma.chmod(0o755)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_pilot(self, name: str, stage: str = "numerical", **overrides: str
                  ) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment.update({
            "M23_MAGMA_BIN": str(self.fake_magma),
            "M23_ALLOW_UNPINNED_BELYI": "1",
            "M23_BELYI_STAGE": stage,
            "M23_BELYI_WALL_SECONDS": "5",
            "M23_BELYI_KILL_AFTER_SECONDS": "1",
        })
        environment.update(overrides)
        return subprocess.run(
            [str(RUNNER), str(self.belyi), str(self.root / name)],
            cwd=ROOT, env=environment, text=True, capture_output=True, check=False)

    def test_numerical_success_records_provenance(self) -> None:
        completed = self.run_pilot("numerical")
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), "numerical_stage_completed")
        config = (self.root / "numerical" / "config.tsv").read_text()
        status = (self.root / "numerical" / "status.tsv").read_text()
        self.assertIn("input_sha256\t9321892c", config)
        self.assertIn("stage\tnumerical", config)
        self.assertIn("class_id\t1", config)
        self.assertIn("pilot_sha256\t", config)
        self.assertIn("belyi_submodules_sha256\t", config)
        self.assertIn("outcome\tnumerical_stage_completed", status)
        self.assertIn("magma_exit_code\t0", status)
        self.assertIn("runner_exit_code\t0", status)
        self.assertTrue((self.root / "numerical" / "driver.m").is_file())

    def test_exact_output_must_pass_local_verifier(self) -> None:
        completed = self.run_pilot("exact", stage="exact")
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(completed.stdout.strip(), "exact_output_rejected_locally")
        self.assertTrue((self.root / "exact" / "candidate.json").is_file())
        self.assertFalse((self.root / "exact" / "verification.json").exists())
        self.assertEqual(list((self.root / "exact").glob("*.tmp")), [])
        self.assertTrue((self.root / "exact" / "extraction.log").is_file())
        self.assertTrue((self.root / "exact" / "verification.log").is_file())
        status = (self.root / "exact" / "status.tsv").read_text()
        self.assertIn("outcome\texact_output_rejected_locally", status)
        self.assertIn("magma_exit_code\t0", status)
        self.assertIn("extraction_exit_code\t0", status)
        self.assertIn("verification_exit_code\t1", status)

    def test_exit_zero_without_completion_markers_fails(self) -> None:
        completed = self.run_pilot("missing-marker", M23_FAKE_MODE="no_marker")
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(completed.stdout.strip(), "failed")
        status = (self.root / "missing-marker" / "status.tsv").read_text()
        self.assertIn("magma_exit_code\t0", status)
        self.assertIn("runner_exit_code\t1", status)

    def test_success_markers_cannot_hide_nonzero_magma_exit(self) -> None:
        completed = self.run_pilot("nonzero", M23_FAKE_MODE="marker_nonzero")
        self.assertEqual(completed.returncode, 7)
        self.assertEqual(completed.stdout.strip(), "failed")
        status = (self.root / "nonzero" / "status.tsv").read_text()
        self.assertIn("magma_exit_code\t7", status)
        self.assertIn("runner_exit_code\t7", status)

    def test_forced_timeout_is_classified(self) -> None:
        completed = self.run_pilot(
            "timeout", M23_FAKE_MODE="hang", M23_BELYI_WALL_SECONDS="1")
        self.assertEqual(completed.returncode, 137)
        self.assertEqual(completed.stdout.strip(), "timeout_killed")
        status = (self.root / "timeout" / "status.tsv").read_text()
        self.assertIn("magma_exit_code\t137", status)
        self.assertIn("outcome\ttimeout_killed", status)

    def test_cooperative_timeout_is_classified(self) -> None:
        completed = self.run_pilot(
            "timeout-term", M23_FAKE_MODE="timeout", M23_BELYI_WALL_SECONDS="1")
        self.assertEqual(completed.returncode, 124)
        self.assertEqual(completed.stdout.strip(), "timeout")
        status = (self.root / "timeout-term" / "status.tsv").read_text()
        self.assertIn("magma_exit_code\t124", status)
        self.assertIn("outcome\ttimeout", status)

    def test_extraction_failure_is_logged_without_candidate(self) -> None:
        completed = self.run_pilot(
            "bad-exact", stage="exact", M23_FAKE_MODE="bad_exact")
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(completed.stdout.strip(), "exact_output_rejected_locally")
        directory = self.root / "bad-exact"
        self.assertFalse((directory / "candidate.json").exists())
        self.assertFalse((directory / "verification.json").exists())
        self.assertEqual(list(directory.glob("*.tmp")), [])
        self.assertIn("missing M23_EXACT_FIELD", (directory / "extraction.log").read_text())
        status = (directory / "status.tsv").read_text()
        self.assertIn("extraction_exit_code\t1", status)
        self.assertIn("verification_exit_code\tnot_run", status)

    def test_version_preflight_is_bounded(self) -> None:
        completed = self.run_pilot(
            "version-timeout", M23_FAKE_MODE="version_hang",
            M23_BELYI_VERSION_SECONDS="1")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("version preflight failed", completed.stderr)
        self.assertFalse((self.root / "version-timeout").exists())

    def test_pinned_revision_is_enforced(self) -> None:
        environment = os.environ.copy()
        environment["M23_MAGMA_BIN"] = str(self.fake_magma)
        completed = subprocess.run(
            [str(RUNNER), str(self.belyi), str(self.root / "rejected")],
            cwd=ROOT, env=environment, text=True, capture_output=True, check=False)
        self.assertEqual(completed.returncode, 2)
        self.assertIn("revision mismatch", completed.stderr)
        self.assertFalse((self.root / "rejected").exists())

    def test_class_id_must_be_in_certified_range(self) -> None:
        completed = self.run_pilot("bad-class", M23_BELYI_CLASS_ID="29")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("class ID", completed.stderr)
        self.assertFalse((self.root / "bad-class").exists())

    def test_exact_selected_class_is_preserved_in_candidate(self) -> None:
        completed = self.run_pilot(
            "exact-class22", stage="exact", M23_BELYI_CLASS_ID="22")
        self.assertEqual(completed.returncode, 1)
        candidate = json.loads(
            (self.root / "exact-class22" / "candidate.json").read_text())
        self.assertEqual(candidate["provenance"]["source"]["class_id"], 22)


if __name__ == "__main__":
    unittest.main()
