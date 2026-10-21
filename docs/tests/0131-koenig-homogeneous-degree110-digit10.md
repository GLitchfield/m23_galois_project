# Test 0131: König homogeneous degree-110 digit 10

## Question

Does the complete 568-dimensional degree-110 relation subspace continue from
modulo `19^9` to modulo `19^10`?

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
19^9                       568                         477               91
19^10                      568                         477               91
```

The tenth-digit obstruction has rank zero on all 568 directions surviving
Test 0128. Training-only and training-plus-holdout calculations give the same
projected subspace. A canonically selected witness, normalized by
`P[0,1]=1`, vanishes on all 16,000 fitting rows and all 384 holdouts modulo
`19^10 = 6,131,066,257,801`.

## Exact continuation

The full matrix and witnesses remain within `uint64`, while all large modular
products are evaluated by exact base-19 digit convolution. The implementation
now checks the scaled accumulator bound explicitly; digit 10 is the final
precision supported safely by this representation. A dedicated
`19^10`-scale self-test exercises both the unit-block solve and normalized
scalar product before production.

The independent checker separately reconstructs every carry through digit
ten, the projected training and full-row bases, the numerator rank, the
witness digest, and the old Test 0120 obstruction counts. Its independent
digit-convolution path verifies the full normalized witness.

## Evidence

Production revision:
`8228f1c80e8b4a0931010c0e3815d50a923be05d`.

```text
2026fc077b971b133e2f7256b0af47b9eedd86f623c900b0153d354729ee3aa7
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv
92546aefe9498fd2ac933797b45d34828841fb478bc8f6b92ae492f642d319c9
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10_reduced.npz
67b09070849ec0e03be553f40a819707b2b52262052e47263a07c260042fa763
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod6131066257801.tsv
```

The production run used Sage 10.9, took 32 minutes 34.21 seconds wall time,
and reached 13,716,792 KiB maximum RSS without swap. These timings are
operational observations, not mathematical claims. The independent replay
took 28.31 seconds and reached 474,676 KiB maximum RSS.

Replay:

```sh
make check-koenig-relation-homogeneous-degree110-digits10
```

## Next gate

Repeat the canonical-chart reconstruction at effective precision
`19^7 = 893,871,739`, where the symmetric rational-reconstruction uniqueness
bound is 21,140. Then repeat the simultaneous lattice audit with the new
precision and compare its stability distribution against Test 0130.
