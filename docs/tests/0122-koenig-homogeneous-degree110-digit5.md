# Test 0122: König homogeneous degree-110 digit 5

## Question

Does the complete 568-dimensional degree-110 relation subspace from Test 0121
continue from modulo `19^4` to modulo `19^5`?

## Result

Yes. The projected profile is

```text
precision   surviving directions   numerator-projection rank   plane controls
19                         571                         480               91
19^2                       571                         480               91
19^3                       571                         480               91
19^4                       568                         477               91
19^5                       568                         477               91
```

The fifth-digit obstruction has rank zero on the 568 directions that survived
Test 0121. Training-only and training-plus-holdout calculations give the same
projected subspace. A canonically selected witness, normalized by
`P[0,1]=1`, vanishes on all 16,000 fitting rows and all 384 holdouts modulo
`19^5 = 2,476,099`.

## Carry-aware continuation

The reduced Schur complement has forced valuation two. Test 0121 needed only
its first nonzero digit, whose rank-three kernel is unambiguous. A direct
extension of the earlier block-lower-triangular encoding is not valid at the
next digit: ordinary base-19 matrix products carry between digits.

The new solver instead keeps concrete lifted representatives. For every
surviving direction it:

1. evaluates the exact residual at the next modulus;
2. divides by the already certified power of 19;
3. eliminates the residual through a fixed rank-three unit block;
4. computes the remaining cokernel obstruction over `F_19`; and
5. constructs and directly verifies a corrected representative.

All large products are evaluated by exact base-19 digit convolution. This
avoids the binary64 exactness bound exceeded by a direct product at `19^5`.
The independent checker separately reconstructs the carries, obstruction,
projected basis, numerator rank, witness digest, and the old Test 0120
obstruction counts.

## Evidence

Implementation revision:
`44192e7ed40ff99db6257a82fccadbdac2c4eade`.

```text
3a1195122289fa5c639e2890e30f1aa50cee14fff1e22832a0a12366103a2f5c
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits5.tsv
fd0cdc65d42f119a6cdbc1e97a376635675d7868cc722418ad63d5aa83f59866
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits5_reduced.npz
9bcfd3264f40eae8e3329bf79ca7a74c6e71be527185de11f8c296b628b4bb46
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod2476099.tsv
```

The production run used Sage 10.9, took 12 minutes 0.32 seconds wall time, and
reached 13,280,488 KiB maximum RSS. These timings are operational
observations, not mathematical claims.

Replay:

```sh
make check-koenig-relation-homogeneous-degree110-digits5
```

## Next gate

Continue the complete 568-dimensional subspace through `19^6` with the same
carry-aware obstruction certificate. Rational reconstruction and global
characteristic-zero verification remain deferred until enough stable digits
have accumulated.

Follow-up: Test 0123 passes this gate. The sixth-digit obstruction also has
rank zero, so the same 568-dimensional subspace survives through `19^6`.
