#!/usr/bin/env python3
from __future__ import annotations

from collections import Counter
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import barth_wenz_preprocess as bw  # noqa: E402


TARGET_OUTPUT = (
    ROOT / "data/derived/m23_8a_barth_wenz_class1_matlab_input.m"
)


def compute(loader):
    x, y, provenance, source_sha256 = loader()
    domains = bw.compute_fundamental_domains(x, y)
    gluing = [
        bw.compute_border_and_gluing(domain, x, y, start)
        for start, domain in domains
    ]
    return x, y, provenance, source_sha256, domains, gluing


class BarthWenzPreprocessTest(unittest.TestCase):
    def assert_domains_and_gluing(self, x, y, domains, gluing) -> None:
        self.assertTrue(bw.is_transitive(x, y))
        for (start, domain), edges in zip(domains, gluing):
            self.assertEqual(len(domain), x.degree)
            self.assertEqual(
                tuple(
                    bw.calculate_word(word, x, y, start)
                    for word in domain
                ),
                tuple(range(x.degree)),
            )
            counts = Counter(edge[4] for edge in edges)
            self.assertTrue(counts)
            self.assertEqual(set(counts.values()), {2})
            for gluing_id in counts:
                pair = [edge for edge in edges if edge[4] == gluing_id]
                self.assertEqual(
                    pair[1][:4],
                    (pair[0][1], pair[0][0], pair[0][2], -pair[0][3]),
                )

    def test_published_degree_52_fixture(self) -> None:
        x, y, _, source_sha256, domains, gluing = compute(
            bw.published_52_fixture
        )
        z = bw.inverse_product(x, y)
        self.assertEqual(
            bw.cycle_lengths(x),
            (8, 8, 8, 8, 8, 4, 4, 4),
        )
        self.assertEqual(
            bw.cycle_lengths(y),
            (2,) * 24 + (1,) * 4,
        )
        self.assertEqual(
            bw.cycle_lengths(z),
            (4,) * 10 + (2,) * 4 + (1,) * 4,
        )
        self.assertEqual(bw.genus(x, y, z), 0)
        self.assertEqual(source_sha256, bw.BARTH_WENZ_FIXTURES_SHA256)
        self.assertEqual([start + 1 for start, _ in domains], [1, 2, 5, 11])
        self.assertEqual([len(edges) for edges in gluing], [70] * 4)
        self.assert_domains_and_gluing(x, y, domains, gluing)
        self.assertTrue(
            bw.summarize(x, y, domains, gluing).endswith(
                "sha256=ee01407b8d8df203a2562465e447a8238408b77231b66cd"
                "96505095d639f68d0"
            )
        )

    def test_m23_class1_target_and_committed_output(self) -> None:
        x, y, provenance, source_sha256, domains, gluing = compute(
            lambda: bw.m23_target(1)
        )
        z = bw.inverse_product(x, y)
        self.assertEqual(bw.cycle_lengths(x), (8, 8, 4, 2, 1))
        self.assertEqual(
            bw.cycle_lengths(y),
            (2,) * 8 + (1,) * 7,
        )
        self.assertEqual(bw.cycle_lengths(z), (8, 8, 4, 2, 1))
        self.assertEqual(bw.genus(x, y, z), 0)
        self.assertEqual(
            source_sha256,
            "dc6089e7b9bcf9cb890e01306d286327266c0bf6ba7a7a8e48abb5ca52b3f3e8",
        )
        self.assertEqual([start + 1 for start, _ in domains], [1, 3])
        self.assertEqual([len(edges) for edges in gluing], [34, 34])
        self.assert_domains_and_gluing(x, y, domains, gluing)
        self.assertTrue(
            bw.summarize(x, y, domains, gluing).endswith(
                "sha256=ff1b5044fb061edf47032ed7db3372d4d850bf6ee1bd1018d"
                "58b1f9532222911"
            )
        )

        with tempfile.TemporaryDirectory() as directory:
            generated = Path(directory) / "matlab_input.m"
            bw.emit_matlab(
                generated,
                x,
                y,
                domains,
                gluing,
                provenance,
                source_sha256,
            )
            self.assertEqual(
                generated.read_bytes(),
                TARGET_OUTPUT.read_bytes(),
            )

    def test_all_28_certified_targets_pass_structural_gate(self) -> None:
        for class_id in range(1, 29):
            with self.subTest(class_id=class_id):
                x, y, _, _, domains, gluing = compute(
                    lambda class_id=class_id: bw.m23_target(class_id)
                )
                z = bw.inverse_product(x, y)
                self.assertEqual(bw.cycle_lengths(x), (8, 8, 4, 2, 1))
                self.assertEqual(
                    bw.cycle_lengths(y),
                    (2,) * 8 + (1,) * 7,
                )
                self.assertEqual(
                    bw.cycle_lengths(z),
                    (8, 8, 4, 2, 1),
                )
                self.assertEqual(bw.genus(x, y, z), 0)
                self.assertEqual(len(domains), 2)
                self.assert_domains_and_gluing(x, y, domains, gluing)

    def test_second_permutation_must_be_an_involution(self) -> None:
        x, _, _, _ = bw.m23_target(1)
        with self.assertRaisesRegex(ValueError, "order two"):
            bw.compute_fundamental_domains(x, x)


if __name__ == "__main__":
    unittest.main()
