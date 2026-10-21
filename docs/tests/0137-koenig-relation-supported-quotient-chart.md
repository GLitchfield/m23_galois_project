# Test 0137: König supported quotient chart

## Question

Does the persistent mod-19 rank-seven numerator block from Test 0136 define a
basis-independent seven-dimensional chart through `19^10`, suitable for
rational reconstruction?

## Result

No.

At each digit from 4 through 10, the audit maps the complete supported module
to the 7,566 allowed numerator coordinates, selects seven rows whose reductions
span the mod-19 image, and normalizes the same seven pivot coordinates to the
identity. If the numerator image were a free rank-seven direct summand, these
normalized charts would agree under reduction between adjacent digits.

None of the six transitions agrees:

| digits | mismatches from preceding digit | reconstructed entries | stable from preceding digit |
| ---: | ---: | ---: | ---: |
| 4 | - | 36,412 / 52,913 | - |
| 5 | 38,797 | 36,592 / 52,913 | 14,112 |
| 6 | 38,789 | 36,635 / 52,913 | 14,113 |
| 7 | 38,796 | 36,573 / 52,913 | 14,112 |
| 8 | 38,795 | 36,591 / 52,913 | 14,112 |
| 9 | 38,791 | 36,398 / 52,913 | 14,112 |
| 10 | 38,796 | 36,489 / 52,913 | 14,112 |

There are 232,764 adjacent-digit mismatches in total. Only 14,112 entries are
unchanged across all seven charts. At `19^10`, 36,489 entries formally pass
scalar rational reconstruction and 16,424 do not, but those fractions are not
a characteristic-zero candidate because the underlying chart is already
incoherent.

The obstruction clarifies Test 0136. Its seven-dimensional
`numerator_projection_rank` and 73-dimensional `plane_control_dimension` are
dimensions after reduction modulo 19. The control-sector lifts can have
numerator coefficients divisible by 19 without being exactly numerator-zero.
Adding such a control lift leaves the mod-19 quotient unchanged while shifting
higher chart digits. Consequently, the persistent rank seven does not by
itself define a free rank-seven quotient over `Z/19^10 Z`.

## Method

The Sage producer reconstructs the exact numerator coefficients of every
supported generator at each digit using the full homogeneous pivot
transformation. It verifies exact beta-degree-at-most-77 support, identifies
the same seven unit pivot columns, normalizes a `7 x 7` unit block, and archives
all seven `7 x 7559` trial charts.

Two planted gates distinguish the cases:

- an invertible change among full-rank generators leaves the normalized chart
  unchanged; and
- adding a 19-divisible torsion generator leaves the mod-19 chart unchanged
  but shifts its higher digits.

The independent Python checker verifies both source-certificate hashes and the
complete chart archive. It independently reconstructs the canonical mod-19
row image from the saved 80-vector supported basis, checks every chart against
that image, recomputes all six mismatch counts, and repeats every scalar
rational reconstruction with an extended-Euclidean implementation.

The official SageMath 10.9 run took 24 minutes 46.30 seconds with maximum RSS
13,870,484 KiB.

## Evidence

Production revision:
`b27102d771a7f566cc93423f222e8f5f7e0e04fb`.

```text
183c84a7dc65d5b9189970be296d8f0aabb34b79468928b4245a98a65176276d
  data/derived/m23_koenig_a_relation_supported_beta77_quotient_reconstruction_digits10.tsv
7f52d93acaaa52b9357eed07495ae67ce13701c1c9e32ac3a78b3f0ac9185336
  data/derived/m23_koenig_a_relation_supported_beta77_quotient_chart_digits10.npz
```

Replay:

```sh
make check-koenig-relation-supported-quotient
```

## Next gate

Compute the basis-independent 19-adic invariant-factor filtration of the exact
supported numerator image. Test 0138 finds seven unit factors and three
valuation-7 factors at precision `19^10`. Test 0139 computes every actual
digit-4--10 supported image and finds that the three short factors retain
order `19^3`, so they disappear in the `Z_19` inverse limit. Next construct a
compatible quotient by that bounded transient part. Test 0140 does so and
finds zero transition mismatches through seven effective digits; the remaining
gate is additional precision for rational reconstruction.
