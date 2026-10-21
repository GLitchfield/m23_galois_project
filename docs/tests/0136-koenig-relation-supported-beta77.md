# Test 0136: König relation supported beta-degree block

## Question

Does the seven-dimensional mod-19 numerator block with beta degree at most 77
from Test 0135 lift with the same exact support through all ten available
19-adic digits?

## Result

Yes.

The support condition is imposed inside the complete homogeneous relation
module, rather than on a chosen complement to its plane controls. Before the
known fourth-digit relation obstruction, its numerator projection has ambient
dimension 10. The fourth digit removes three numerator directions and leaves
the target dimension 7. That dimension then remains unchanged through
`19^10`:

| digits | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| numerator projection | 10 | 10 | 10 | 7 | 7 | 7 | 7 | 7 | 7 | 7 |
| plane-control kernel | 91 | 91 | 91 | 91 | 88 | 85 | 82 | 79 | 76 | 73 |
| complete supported module | 101 | 101 | 101 | 98 | 95 | 92 | 89 | 86 | 83 | 80 |

The fitting rows and the independent holdout rows give the same profile at
every digit. The declining plane-control kernel is genuine diagnostic
information: from digit 5 onward, each new support obstruction constrains
three control directions, while the seven numerator-bearing directions
survive. Thus persistence is a statement about the canonical numerator
quotient, not about keeping all 91 control directions inside the supported
module.

This establishes an exact `Z/19^10 Z` support lift of the smallest block found
in Test 0135 at the level of its mod-19 numerator projection. Test 0137 shows
that this rank statement does not yet identify a free seven-dimensional
19-adic quotient: the control lifts can have 19-divisible numerator data. It
does not yet identify a rational relation subspace.

## Method

The Sage audit turns exact vanishing of every numerator coefficient with beta
degree greater than 77 into constraints on the free coordinates of the
homogeneous relation system. It incorporates those constraints into the
carry-aware Hensel lift, recording at every digit:

- the full supported-module dimension;
- the rank of its numerator projection; and
- the dimension of its plane-control kernel.

Both the 849 fitting-reduction rows and all 384 held-out rows are replayed.
Synthetic gates separately force the numerator quotient and the
plane-control kernel to lose a direction, so the audit distinguishes the two
phenomena.

The independent Python checker validates input and output hashes, all
dimension identities and monotonicity conditions, and the compact final
80-vector basis. Using a separate exact base-19 product, it verifies that all
1,233 relation rows vanish modulo `19^10`; it also independently rechecks the
rank-seven mod-19 numerator image and its forbidden high-beta coordinates.

## Evidence

Production code revision:
`eeff483799c1be8d75be4fc4eb25292b5a6dfaca`.

SageMath version: 10.9.

```text
f756fd9d418192ec1bb80c0f342d0b3d359123428c388baf5263606b682c4784
  data/derived/m23_koenig_a_relation_supported_beta77_digits10.tsv
07a5b07681eafca6061f7bfde3906a06666b27a5d9333f2edc6d842c6e4ab50a
  data/derived/m23_koenig_a_relation_supported_beta77_digits10_representatives.npz
```

Replay:

```sh
make check-koenig-relation-supported-subspace
```

## Next gate

Test 0137 attempts the canonical quotient chart and finds it incoherent.
Compute the local Smith/Howell invariant-factor filtration of the exact
supported numerator image to distinguish unit directions from 19-divisible
control leakage. Resume rational reconstruction only if that audit isolates a
saturated free rank-seven summand.
