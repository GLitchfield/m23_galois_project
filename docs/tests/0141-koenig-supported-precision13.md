# Test 0141: König supported precision 13

## Question

Can carry-normalized exact arithmetic extend the complete homogeneous and
supported relation lift through `19^13`, and do the resulting effective
free-chart digits 8 through 10 make rational reconstruction converge?

## Result

The exact lift and all structural gates pass through digit 13, but scalar
rational reconstruction still does not converge.

The complete degree-110 relation computation has zero fitting and holdout
residuals at modulus
`19^13 = 42,052,983,462,257,059`. Its projected kernel retains dimension 568,
with 477 numerator-bearing directions and all 91 plane controls, at every
stage from digit 4 through digit 13. The supported beta-degree-at-most-77
image retains the same seven free directions.

The basis-independent supported-image profile also continues without change:
at every stage `d = 4,...,13` it is

```text
v0:7, v(d-3):3.
```

Thus the three short factors still have order exactly `19^3`; their bounded
behavior was not an artifact of stopping at digit 10.

After removing those transient factors, all nine adjacent transitions in the
canonical rank-seven chart agree exactly:

| stage digits | effective digits | transition mismatches | reconstructed entries | stable from previous |
| ---: | ---: | ---: | ---: | ---: |
| 4 | 1 | - | 44,803 / 52,913 | - |
| 5 | 2 | 0 | 38,892 / 52,913 | 15,684 |
| 6 | 3 | 0 | 36,154 / 52,913 | 15,398 |
| 7 | 4 | 0 | 36,569 / 52,913 | 15,272 |
| 8 | 5 | 0 | 36,507 / 52,913 | 15,280 |
| 9 | 6 | 0 | 36,467 / 52,913 | 15,285 |
| 10 | 7 | 0 | 36,524 / 52,913 | 15,287 |
| 11 | 8 | 0 | 36,667 / 52,913 | 15,237 |
| 12 | 9 | 0 | 36,627 / 52,913 | 15,260 |
| 13 | 10 | 0 | 36,396 / 52,913 | 15,284 |

At final effective modulus `19^10`, 36,396 entries formally reconstruct and
16,517 fail. Exactly 14,112 entries are stable across all ten effective
precisions, unchanged from Test 0140; 14,117 are stable across the final four.
The largest reconstructed numerator and denominator are 1,750,748 and
1,750,863, essentially the generic uniqueness bound. The changing raw success
count and fixed all-stage stable set show that most entrywise reconstructions
remain precision accidents.

The precision-extension gate therefore passes, while the hypothesis that
three more digits would settle the rational chart is rejected. Further blind
precision extension is not the next gate.

## Method

The old exact products accumulated base-19 convolution coefficients after
multiplying them by their place values. That representation reached a
`uint64` overflow guard at digit 11. The revised producer:

1. accumulates each unscaled convolution coefficient in its own `uint64`
   layer;
2. propagates carries one base-19 digit at a time;
3. stores only the normalized digit times its place value; and
4. selects an unsigned storage type from the actual effective modulus after
   removing the forced `19^2` valuation.

The 15,151-column pivot solve, complete 16,384-row witness, supported-subspace
audit, and every supported invariant stage were produced in one deterministic
SageMath 10.9 run. The independent homogeneous checker uses a separately
implemented carry-propagating convolution. Independent Python checkers replay
the complete reduced support constraints, all stage images, the local
invariant profiles, every canonical chart, and rational reconstruction.

The official run took 30 minutes 50.31 seconds, used at most 14,694,540 KiB
RSS, and did not swap.

## Evidence

Production code revision:
`3f0aa32bd6c8ebf924fbf29a7c76d747ef884369`.

```text
e65cd8750be2d75b3b09f5ebfeb5ce59e3d09f42d0c5a628cd15773d55e42dfe
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13.tsv
d386e2605d4488fee580b3f537a5922a29e77dbcec9ebd658ce6049a7a16be03
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13_reduced.npz
136cf2ffc357af5643cda21e1b124c0ef7a7055005bf351d6ff60b04e6407f11
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod42052983462257059.tsv
ce2e639b88ba19ba711821d594adb9468b01dc5eb8d3f876adb6739a3b011501
  data/derived/m23_koenig_a_relation_supported_beta77_digits13.tsv
0d4b95b6382ee20024b77beecaee8e0dabf72d07cc55d597d4a3194506404e72
  data/derived/m23_koenig_a_relation_supported_beta77_digits13_representatives.npz
7e875dc336274e79e0b5d8e435cade2123db3c40bc4cbc4a19739244c8935c25
  data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv
c2bfc3fb914700a4b7e3d568941ca0720c9a38253fc55aeda41e086549c50aed
  data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to13.npz
e3fc33d029f7a7b07121779211e619a03a75c02018b2d522e1c4ac4aa8233a0b
  data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_digits10.tsv
d053c407546d8e6b612d554982122fccfd3530d933655d1bbe05dcd0e9bb05f6
  data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_chart_digits10.npz
```

Full lift and invariant-stage replay:

```sh
make check-koenig-relation-supported-invariant-stages-digits13
```

Free-quotient replay:

```sh
make check-koenig-relation-supported-free-quotient-digits10
```

## Next gate

Test 0142 runs this pilot. It recovers the planted rank-seven module after a
non-unimodular `GL_7(Q)` basis change, but none of 127 recurrent real
candidates passes the complete cross-precision stability gate; best stability
is only 2,377 of 7,566 coordinates. The next bounded gate is to select larger,
non-nested lattice blocks from the columns with the greatest scalar
instability, while retaining the planted recovery and full-vector validation.
