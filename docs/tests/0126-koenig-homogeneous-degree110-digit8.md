# Test 0126: König homogeneous degree-110 digit 8

## Question

Does the complete 568-dimensional degree-110 relation subspace continue from
modulo `19^7` to modulo `19^8` after widening the solver's coefficient
storage and exact-product paths?

## Result

Yes. The projected profile is

```text
precision   surviving directions   numerator-projection rank   plane controls
19                         571                         480               91
19^2                       571                         480               91
19^3                       571                         480               91
19^4                       568                         477               91
19^5                       568                         477               91
19^6                       568                         477               91
19^7                       568                         477               91
19^8                       568                         477               91
```

The eighth-digit obstruction has rank zero on the 568 directions surviving
Test 0124. Training-only and training-plus-holdout calculations give the same
projected subspace. A canonically selected witness, normalized by
`P[0,1]=1`, vanishes on all 16,000 fitting rows and all 384 holdouts modulo
`19^8 = 16,983,563,041`.

## Wide exact arithmetic

Because `19^8` exceeds `uint32`, the production solver selects `uint64`
storage for the full matrix while retaining the narrower type at smaller
precisions. Exact pivot solves and modular products are evaluated through
base-19 digit convolution, including witness normalization; this avoids raw
`uint64` dot-product overflow.

The independent checker separately reconstructs every carry through digit
eight, the projected training and full-row bases, the numerator rank, the
witness digest, and the old Test 0120 obstruction counts. Its own
digit-convolution implementation verifies the normalized witness without
using an overflowing raw matrix-vector product.

## Evidence

Production revision:
`515202c178b942e6a534c4f4252e219f6901e5c4`.

```text
79cc4a0086ea5f6a81900676e067faa2bd8be8e86196239712e4b49b8e952eb8
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits8.tsv
f426aad255eecb8044f54127e4cb9fad911ef6e766a897ff1e5d655860a4bf21
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits8_reduced.npz
12870db1de1a59fb2221ebf3193c6e7176dacaecb3af0eac27b3c10fe96a3e57
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod16983563041.tsv
```

The production run used Sage 10.9, took 33 minutes 26.95 seconds wall time,
and reached 13,592,188 KiB maximum RSS without swap. These timings are
operational observations, not mathematical claims.

Replay:

```sh
make check-koenig-relation-homogeneous-degree110-digits8
```

## Next gate

Repeat Test 0125's canonical-chart reconstruction at effective precision
`19^5 = 2,476,099`, where the symmetric rational-reconstruction uniqueness
bound rises from 255 to 1,112. If a complete stable characteristic-zero chart
emerges, verify the resulting identities globally; otherwise obtain the next
19-adic digit.

Follow-up: Test 0127 finds that the chart remains exactly coherent but
incomplete: 1,001 of 1,704 entries reconstruct, 703 remain unresolved, and
only 46 fractions agree with the preceding level. Continue through `19^9`.
