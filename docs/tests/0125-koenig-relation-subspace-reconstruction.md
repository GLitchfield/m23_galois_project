# Test 0125: König relation-subspace reconstruction

## Question

Do the stable homogeneous relations through `19^7` contain enough effective
precision to rationally reconstruct their characteristic-zero subspace?

## Result

Not yet, but the reconstruction target is now small and canonical.

After the 15,151 unit pivots are eliminated, the surviving relation space has
dimension 568 inside 571 free coordinates. The three leading obstruction
columns are `0,1,2`, so solving them in terms of the other 568 coordinates
gives a canonical `568 x 3` chart with only 1,704 nontrivial entries.

The charts derived independently from Tests 0122--0124 agree exactly at every
shared digit:

```text
source precision   effective chart modulus   mismatches from next level
19^5                                  19^2                            0
19^6                                  19^3                            0
19^7                                  19^4                            0
```

The loss of three powers is structural: the Schur reduction removes one
factor of 19 and the reduced matrix has forced valuation two.

At effective modulus `19^4 = 130,321`, standard symmetric rational
reconstruction has uniqueness bound 255. It reconstructs 994 of the 1,704
chart entries, while 710 entries have no reconstruction within that bound.
Only 55 reconstructed values agree between the last two effective
precisions, and only three agree at all three levels. Thus the partial
fractions are not yet a complete or stable characteristic-zero chart.

This is a precision limit, not an obstruction to a characteristic-zero
relation: the modular chart itself is perfectly coherent.

## Method

The Sage implementation independently rebuilds the rank-three leading
obstruction, fixes an identity chart on its 568 complementary coordinates,
and Hensel-lifts the three dependent coordinates. It then applies Sage's
standard rational reconstruction to every chart entry.

The Python checker separately implements:

1. modular row reduction and pivot selection;
2. inversion of the `3 x 3` unit block;
3. the carry-aware chart lift;
4. the extended-Euclidean rational-reconstruction criterion; and
5. all cross-precision and stability counts.

The checker agrees exactly with the Sage certificate.

## Evidence

Implementation revision:
`7e6167ebc189647f34705dfe824dc40a31983d2e`.

```text
e1b766d88bd084f81191e0869d93f1a04e30ae1021c54218e50be82b4a8e5536
  data/derived/m23_koenig_a_relation_subspace_reconstruction.tsv
```

Replay:

```sh
make check-koenig-relation-subspace-reconstruction
```

## Next gate

Widen the homogeneous solver's coefficient storage and exact-product paths
from `uint32` where necessary, then continue the full relation subspace
through `19^8`. That supplies effective chart precision `19^5` and raises the
symmetric reconstruction bound from 255 to 1,112. Repeat the canonical-chart
audit before attempting a global characteristic-zero identity.
