# Test 0124: König homogeneous degree-110 digit 7

## Question

Does the complete 568-dimensional degree-110 relation subspace from Test 0123
continue from modulo `19^6` to modulo `19^7`?

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
```

The seventh-digit obstruction has rank zero on the 568 directions that
survived Test 0123. Training-only and training-plus-holdout calculations give
the same projected subspace. A canonically selected witness, normalized by
`P[0,1]=1`, vanishes on all 16,000 fitting rows and all 384 holdouts modulo
`19^7 = 893,871,739`.

## Exact continuation

The carry-aware solver keeps concrete lifted representatives, evaluates each
next residual exactly, eliminates it through the fixed rank-three unit block,
and computes the remaining cokernel obstruction over `F_19`. Products beyond
the binary64 exactness bound are reduced to the current stage modulus and
evaluated by exact base-19 convolution.

The independent checker separately reconstructs all carries through digit
seven, the projected training and full-row bases, the numerator rank, the
witness digest, and the old Test 0120 obstruction counts. It verifies that
the training and full-row projected subspaces agree.

## Evidence

Implementation revision:
`3e1e40caeaf8853de9b39439c09be254e546dfc2`.

```text
8c7c339a27cdc60cd47077936c0eead187c26994d695445af54a14c35dc9abe9
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits7.tsv
0e60ccf9994ff2f72ddedc21c3334bd3e03b4ea9784d7041a0eeb7183c41a11f
  data/derived/m23_koenig_a_relation_homogeneous_degree110_digits7_reduced.npz
48710437b84246f7210592d7e57d3aa597b7b1e518e535e813f9989e10f4a009
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod893871739.tsv
```

The production run used Sage 10.9, took 15 minutes 26.55 seconds wall time,
and reached 14,313,800 KiB maximum RSS. These timings are operational
observations, not mathematical claims.

Replay:

```sh
make check-koenig-relation-homogeneous-degree110-digits7
```

## Next gate

Attempt rational reconstruction of the normalized witness and relation
subspace from the stable digits through `19^7`, followed by exact global
verification of any recovered characteristic-zero relation. If more 19-adic
precision is needed, first widen the solver's `uint32` storage path because
`19^8 = 16,983,563,041` exceeds that range.

Follow-up: Test 0125 constructs the canonical `568 x 3` subspace chart. It is
exactly coherent across the effective precisions `19^2`, `19^3`, and `19^4`,
but 710 of 1,704 entries do not yet rationally reconstruct at the final
precision. More 19-adic precision is therefore required.
