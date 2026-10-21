#!/usr/bin/env python3
from __future__ import annotations

import unittest

from check_magma_8a_serialization_smoke import check_transcript


GOOD = """\
M23_SMOKE_FIELD_POLYNOMIAL=[ -2, 0, 1 ]
M23_SMOKE_NUMERATOR=[
[ 2, 1 ],
[ 0, 0 ],
[ 3, -1 ]
]
M23_SMOKE_DENOMINATOR=[
[ 1, 0 ],
[ 0, 1 ]
]
M23_SMOKE_COMPLETE=true
"""


class CheckMagma8ASerializationSmokeTest(unittest.TestCase):
    def test_accepts_expected_power_basis_order(self) -> None:
        result = check_transcript(GOOD)
        self.assertEqual(result["status"], "verified")
        self.assertEqual(result["coefficient_order"], "low-to-high")

    def test_rejects_reversed_field_polynomial(self) -> None:
        bad = GOOD.replace("[ -2, 0, 1 ]", "[ 1, 0, -2 ]")
        with self.assertRaisesRegex(ValueError, "FIELD_POLYNOMIAL"):
            check_transcript(bad)

    def test_requires_completion_marker(self) -> None:
        with self.assertRaisesRegex(ValueError, "completion"):
            check_transcript(GOOD.replace("M23_SMOKE_COMPLETE=true\n", ""))


if __name__ == "__main__":
    unittest.main()
