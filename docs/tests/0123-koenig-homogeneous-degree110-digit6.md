# Test 0123: König homogeneous degree-110 digit 6

## Question

Does the complete 568-dimensional degree-110 relation subspace from Test 0122
continue from modulo `19^5` to modulo `19^6`?

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
```

The sixth-digit obstruction has rank zero on the 568 directions that survived
Test 0122. Training-only and training-plus-holdout calculations give the same
projected subspace. A canonically selected witness, normalized by
`P[0,1]=1`, vanishes on all 16,000 fitting rows and all 384 holdouts modulo
`19^6 = 47,045,881`.

## Exact continuation

The carry-aware solver from Test 0122 keeps concrete lifted representatives,
evaluates each next residual exactly, eliminates it through the fixed
rank-three unit block, and computes the remaining cokernel obstruction over
`F_19`. At the sixth digit, products that exceed the binary64 exactness bound
are reduced to the current stage modulus before exact base-19 convolution.
This stage reduction was added as an explicit self-test after the first
production attempt exposed the missing reduction; that attempt stopped at an
assertion and wrote no artifacts.

The independent checker separately reconstructs all carries through digit six,
the projected training and full-row bases, the numerator rank, the witness
digest, and the old Test 0120 obstruction counts. It verifies that the
training and full-row projected subspaces agree.

## Evidence

Implementation revision:
`3e9718d298aa8fccda70720568e53f5eb9bde7c9`.

```text
5e573a0f6c13bca81d4c64440fd8aa0df7c47fec8b11064835bf50dd9935b718
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits6.tsv
f7c160bf5d907ecd54e0e445cfba07ffc7887c117899f0011119d6615cbaf88d
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits6_reduced.npz
86e90701750bd0a1ddda01e0edb888b8f51dec7944482fcb597c36d5d95e2699
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod47045881.tsv
```

The production run used Sage 10.9, took 14 minutes 4.65 seconds wall time, and
reached 14,169,288 KiB maximum RSS. These timings are operational
observations, not mathematical claims.

Replay:

```sh
make check-koenig-relation-homogeneous-degree110-digits6
```

## Next gate

Continue the complete 568-dimensional subspace through `19^7` with the same
carry-aware obstruction certificate. Rational reconstruction and global
characteristic-zero verification remain deferred until enough stable digits
have accumulated.

Follow-up: Test 0124 passes this gate. The seventh-digit obstruction also has
rank zero, so the same 568-dimensional subspace survives through `19^7`.
