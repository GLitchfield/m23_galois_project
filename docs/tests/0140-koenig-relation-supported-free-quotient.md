# Test 0140: König supported free quotient

## Question

After removing the three bounded transient digits identified in Test 0139,
does the supported numerator image define a coherent rank-seven 19-adic chart,
and is the available precision sufficient for rational reconstruction?

## Result

The chart is perfectly coherent, but the available precision is not yet
sufficient for rational reconstruction.

At supported stage precision `19^d`, the three transient factors begin at
valuation `d - 3`. Reducing the complete image modulo `19^(d - 3)` therefore
kills them exactly while retaining the free rank-seven image. Stages 4 through
10 give effective chart precisions 1 through 7.

All six adjacent transitions agree exactly:

| stage digits | effective digits | transition mismatches | reconstructed entries | stable from previous |
| ---: | ---: | ---: | ---: | ---: |
| 4 | 1 | - | 44,803 / 52,913 | - |
| 5 | 2 | 0 | 38,892 / 52,913 | 15,684 |
| 6 | 3 | 0 | 36,154 / 52,913 | 15,398 |
| 7 | 4 | 0 | 36,569 / 52,913 | 15,272 |
| 8 | 5 | 0 | 36,507 / 52,913 | 15,280 |
| 9 | 6 | 0 | 36,467 / 52,913 | 15,285 |
| 10 | 7 | 0 | 36,524 / 52,913 | 15,287 |

Thus the 232,764 mismatches in Test 0137 were entirely caused by retaining
the bounded transient factors. After quotienting them out, the same seven
pivot columns, positions 1 through 7 in the selected numerator block, give a
canonical compatible chart through `19^7`.

Rational reconstruction is not yet trustworthy. At the final effective
precision, 36,524 entries formally reconstruct and 16,389 fail. Only 14,112
entries are stable across all effective digits, or 14,115 across the last
four. The reconstructed numerators and denominators reach the generic
reconstruction bound, 21,139 and 21,140 respectively, another indication that
most successful scalar reconstructions are precision accidents rather than
settled rational coefficients.

The structural quotient gate is therefore passed, while the rational
reconstruction gate remains open.

## Method

For each exact stage image `I_d` from Test 0139, the Sage producer:

1. reduces `I_d` modulo `19^(d - 3)`, killing its
   `(Z/19^3 Z)^3` transient summand;
2. selects the canonical seven-row unit basis modulo 19;
3. normalizes the same seven pivot coordinates over
   `Z/19^(d - 3) Z`; and
4. archives the resulting `7 x 7559` chart.

The independent Python checker reconstructs every normalized chart directly
from the complete Test 0139 images using its own digitwise unit inverse and
exact base-19 product. It recomputes all transitions and repeats scalar
rational reconstruction with an extended-Euclidean implementation.

The official SageMath 10.9 run took 3.94 seconds with maximum RSS 335,896 KiB.
The independent replay took 0.74 seconds with maximum RSS 138,388 KiB.

## Evidence

Production code revision:
`a8a7ca83d0c9953591eedff63ec84b27334b1534`.

```text
f95ee93d8593658974119e1cdfe9c0a4ade78dcfee39b54eb023ad10d6aafde9
  data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_digits7.tsv
d40323c920111f8d4e8a9412742b18a4dba0fd94437a01daac2d0d24000337e6
  data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_chart_digits7.npz
```

Replay:

```sh
make check-koenig-relation-supported-free-quotient
```

## Next gate

Test 0141 passes this gate: carry-normalized base-19 convolution extends the
complete lift through digit 13, giving effective chart digits 8--10 with zero
transition mismatches. The all-stage stable reconstruction set remains exactly
14,112 entries, so more scalar precision alone is not resolving the chart.
The next gate is a planted and full-chart-validated blockwise lattice search
for short rational vectors in the rank-seven free supported module.
