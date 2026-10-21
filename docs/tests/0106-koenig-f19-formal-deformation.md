# Test 0106: König finite-field formal deformation

## Question

Does the exact mod-19 anchor from Test 0105 lie on a usable moving branch of
the normalized universal-cover equations, despite being singular on the
reduced plane model?

## Exact system

Implementation revision:
`b75958a432eba593d027df1f8fb31fdcce7452e8`.

The input archive is authenticated as SHA-256
`62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44`;
the verifier prints the SageMath version used for replay.

Run:

```sh
make check-koenig-f19-deformation \
    KOENIG_ARCHIVE=/path/to/archive.zip
```

`scripts/audit_koenig_f19_deformation.sage` authenticates the official
archive, reconstructs all eight normalized factors
`f1,...,f6,g1,g2` over `F_19`, and verifies the two degree-23 universal-family
identities at

```text
alpha=7, beta=14, C=14, lambda=9, a=lambda^2=5.
```

There are 47 free normalized coefficients: all non-leading coefficients of
`f1,...,f6`, two unfixed coefficients of each denominator cubic, `C`, and
`lambda`. Equating the 24 coefficients in each universal-family identity
gives 48 coefficient slots. The degree-23 slot in each identity vanishes
tautologically because the ramification products are monic and the
denominator has degree 18, leaving exactly 46 nontrivial equations.

## Jacobian certificate

The exact `48 x 47` Jacobian over `F_19` has rank `46`, with its two
tautological rows zero. Its right kernel is one-dimensional. After deleting
the `lambda` column, the square minor consisting of all 46 nontrivial rows has
nonzero determinant. The formal implicit-function theorem therefore makes
the normalized cover scheme smooth of dimension one at this point:
`s=lambda-9` is a valid formal local parameter and the other 46 coefficients
lift uniquely to all orders.

The tangent projection to `(alpha,beta,a)` has image

```text
span((0,0,1)).
```

Thus `a` moves to first order while `alpha,beta` begin at higher order. This
is why an ordinary smooth-point lift on the plane equation is unavailable
even though the normalized cover family itself is smooth.

## Plane singularity and formal lift

The authenticated plane equation has multiplicity two at `(7,14)` modulo 19.
Writing `u=alpha-7` and `v=beta-14`, its exact initial form is

```text
8*u^2 - 5*u*v - v^2 = 8*(u+8*v)^2.
```

Recursive exact lifting of the universal-family equations through `s^8`
gives

```text
alpha =
  7 + 11*s^2 + 8*s^3 + 4*s^4 + 13*s^5
    + 18*s^6 + 15*s^7 + 5*s^8,

beta =
  14 + s^2 + 9*s^3 + 11*s^4 + 12*s^5
     + 17*s^6 + 10*s^7 + 9*s^8,

a = (9+s)^2 = 5 + 18*s + s^2
```

modulo `s^9`. The first nonzero plane direction is `(11,1)`, which lies on
the doubled tangent line because `11+8=0` in `F_19`.

Substitution into the full authenticated bidegree-`(97,98)` equation verifies
exactly that

```text
h(alpha(s),beta(s)) = 0 mod (19,s^9).
```

The cover identities are also re-evaluated exactly after every recursive
coefficient correction.

## Consequence and next gate

The published anchor is sufficient to seed an independent moving-family
calculation: the singular plane point is not a dead or intrinsically
non-liftable cover point. This removes the need to wait for the original
mod-19 formulas before beginning reconstruction.

The finite order-eight series is not yet a component-wide identity and does
not close the characteristic-zero gate from Test 0104. The next computational
step is a high-order implementation using truncated power-series arithmetic
and Newton doubling. Its output can be used for Padé/linear-algebra recovery
of the thesis's polynomial coefficient expressions in `alpha,beta`, followed
by exact verification in
`Frac(F_19[alpha,beta]/(h mod 19))`.
