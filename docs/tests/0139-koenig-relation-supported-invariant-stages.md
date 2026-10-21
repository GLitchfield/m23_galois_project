# Test 0139: König supported invariant stages

## Question

Do the three short invariant factors found at precision `19^10` in Test 0138
remain bounded as the precision grows, so that they disappear in the
`Z_19` inverse limit?

## Result

Yes.

The exact supported numerator image has the following invariant factors at
every available stage:

| digits `d` | supported generators | invariant profile |
| ---: | ---: | --- |
| 4 | 98 | `v0^7, v1^3` |
| 5 | 95 | `v0^7, v2^3` |
| 6 | 92 | `v0^7, v3^3` |
| 7 | 89 | `v0^7, v4^3` |
| 8 | 86 | `v0^7, v5^3` |
| 9 | 83 | `v0^7, v6^3` |
| 10 | 80 | `v0^7, v7^3` |

Equivalently, at precision `19^d` the image is

```text
(Z/19^d Z)^7  +  (Z/19^3 Z)^3.
```

The seven unit factors grow with the available precision. The three short
factors always have annihilator exponent 3: their valuations are `d - 3`.
They therefore retreat arbitrarily deeply into the 19-adic filtration and
have zero inverse limit. At the supported numerator-image level, the inverse
limit is a free rank-seven `Z_19` module.

This resolves the finite-precision ambiguity from Tests 0137 and 0138. The
incoherent seven-row charts were being shifted by a bounded transient
`(Z/19^3 Z)^3` contribution. They were not evidence that the seven numerator
directions themselves fail to lift.

This still does not produce rational relation coefficients. It certifies the
free 19-adic image on which a coherent quotient chart and rational
reconstruction can now be built.

## Method

The stage audit uses the actual nested Hensel history from the complete
supported-subspace computation. At digits 4 through 10 its supported
generator dimensions are respectively 98, 95, 92, 89, 86, 83, and 80.

For each stage, the Sage producer:

1. reconstructs the exact selected numerator image modulo `19^d`;
2. verifies exact vanishing of all numerator coordinates above beta degree
   77;
3. computes its local Smith profile by exact Schur reduction; and
4. stores both the supported lifts and the complete `7566`-column image.

The independent Python checker:

- replays every local Smith profile with a separate implementation;
- verifies every saved lift against all 849 fitting and 384 holdout relation
  rows at its stated precision;
- ties each image modulo 19 to the committed numerator map;
- verifies that consecutive supported row spaces are nested modulo 19; and
- requires the digit-10 lifts and numerator image to equal the independently
  committed Test 0138 endpoints byte for byte.

The official SageMath 10.9 run took 27 minutes 9.20 seconds with maximum RSS
13,912,500 KiB. The independent replay took 5.32 seconds with maximum RSS
211,116 KiB.

## Evidence

Production code revision:
`eae24582c904de13fcda75565d04426b68276b07`.

```text
a9718d21e4d466e56aaa22b91bbf6b05690b78314031312aaf8461ed01aaf85b
  data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to10.tsv
9157fb9f3ea16cf7eccf86e1ade69200c9cf962db749799473846e0cf92a2887
  data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to10.npz
```

Replay:

```sh
make check-koenig-relation-supported-invariant-stages
```

## Next gate

Test 0140 quotients by the three bounded transient digits and obtains a
perfectly coherent rank-seven chart with zero mismatches through seven
effective digits. Rational reconstruction is still incomplete and unstable.
Next extend the exact supported lift beyond digit 10 to gain additional
transient-free chart digits before accepting coefficient candidates.
