# Test 0128: König homogeneous degree-110 digit 9

## Question

Does the complete 568-dimensional degree-110 relation subspace continue from
modulo `19^8` to modulo `19^9`?

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
```

The ninth-digit obstruction has rank zero on all 568 directions surviving
Test 0126. Training-only and training-plus-holdout calculations give the same
projected subspace. A canonically selected witness, normalized by
`P[0,1]=1`, vanishes on all 16,000 fitting rows and all 384 holdouts modulo
`19^9 = 322,687,697,779`.

## Exact continuation

The full matrix and witnesses remain within `uint64`, while all large modular
products are evaluated by exact base-19 digit convolution. A dedicated
`19^9`-scale self-test exercises both the unit-block solve and normalized
scalar product before production.

The independent checker separately reconstructs every carry through digit
nine, the projected training and full-row bases, the numerator rank, the
witness digest, and the old Test 0120 obstruction counts. Its independent
digit-convolution path verifies the full normalized witness.

## Evidence

Production revision:
`09c8182df06a44bf49d489de84a35f7f58decfaa`.

```text
3beaf8592cfea3481bcba28c2bae3cd0c44468115beed32ca23fede3a6a623b6
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits9.tsv
558721b2c9b70b5e2969170637033bbc7d58d87bd4b85af248dd55c1584a803d
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits9_reduced.npz
1ff5e26c058091b45cbb54295b0cfba93cb41e7ff7fd42ca52812db0ed26c698
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod322687697779.tsv
```

The production run used Sage 10.9, took 37 minutes 46.91 seconds wall time,
and reached 13,682,372 KiB maximum RSS without swap. These timings are
operational observations, not mathematical claims.

Replay:

```sh
make check-koenig-relation-homogeneous-degree110-digits9
```

## Next gate

Repeat the canonical-chart reconstruction at effective precision
`19^6 = 47,045,881`, where the symmetric rational-reconstruction uniqueness
bound is 4,850. If the chart remains incomplete or unstable, use the measured
trend to choose between another 19-adic digit and a simultaneous
subspace/lattice reconstruction.

Follow-up: Test 0129 finds only 986 of 1,704 entries reconstructing, with 718
unresolved and 64 stable from the preceding level. The entrywise method has
plateaued; test simultaneous lattice reconstruction next.
