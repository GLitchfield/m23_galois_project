# Test 0151: König M24 genus-11 tropical exhaustion

## Question

Do Tests 0146--0150 cover every possible `2`-adic valuation of the
authenticated plane equation, including the unbounded tails, and therefore
prove that its smooth projective normalization has no `Q_2`-point?

## Exact lower Newton complex

For every one of the 633 monomials, the audit forms the lifted support point

```text
(degree_t, degree_x, v_2(coefficient)).
```

Its exact three-dimensional Newton polytope has 12 lower facets and 21 support
points on the lower hull. Pairwise lower-face normal cones give 26
one-dimensional tropical regions, 11 of them unbounded.

Over the integer valuation lattice, cancellation modulo two is possible only
on six rays and one shared vertex:

```text
(0,1)   + n(1,0)
(-4,-1) + n(-2,-1)
(-4,1)  + n(-2,-1)
(-3,2)  + n(0,1)
(-2,-1) + n(0,-1)
(-2,3)  + n(0,1)

vertex: (-2,0)
```

Here `n >= 0`. The calculation includes every lower face, checks all compact
integer points, and proves that no other integer valuation pair can support a
zero.

## Finite core and four negative tails

The bounded Test 0147 window contains exactly 100 candidate pairs. Ninety-two
die by its finite modular audit. Test 0149 excludes `(-6,0)`, and Test 0150
excludes `(-2,0)`.

Four remaining unbounded directions are represented by stable lower-face
polynomials. At the initial point of each ray, the off-face 2-adic margin is
strictly larger than the total normalization budget needed for the face audit:

| Ray start | Direction | Off-face margin | Audit budget |
| ---: | ---: | ---: | ---: |
| `(-42,-20)` | `(-2,-1)` | 23 | 5 |
| `(-42,-18)` | `(-2,-1)` | 22 | 7 |
| `(-3,13)` | `(0,1)` | 14 | 2 |
| `(-2,-41)` | `(0,-1)` | 43 | 8 |

The face audits die after respectively three, four, one, and one normalized
levels. Since every off-face margin increases along its ray, these are
certificates for the entire infinite tails, not samples at large bounds.

## Effective neighborhood of `(1/4,0)`

Write

```text
delta = t - 1/4,  k = v_2(x).
```

For `k >= 7`, the exact local Newton complex leaves only

```text
v_2(delta) = -1
v_2(delta) = 2k - 7.
```

The first ray has a stable face that dies with off-face margin 6 and
normalization budget 1. On the second ray, substitution
`delta = 2^(2k-7)c` and `x=2^k X`, followed by division by `2^(4k+8)`, gives

```text
c^2 + X^4  (mod 8).
```

Both `c` and `X` are odd, so the value is `2 mod 8`, never zero. This gives
the effective open-neighborhood exclusion missing from Test 0147 and resolves
all its `(-2,7)` through `(-2,12)` boxes at once.

## Integral ray

The lower Newton complex also finds the integral ray

```text
(v_2(t),v_2(x)) = (n,1), n >= 0.
```

The cases `0 <= n <= 7` die after one through eight normalized levels. For
`n >= 8`, put `y=x+2`. Since `v_2(x)=1`, one has `v_2(y)>=2`. At `(0,-2)`,
the leading `t^2` and `y^2` coefficient valuations are 32 and 29. Equality
would require

```text
v_2(y) = v_2(t) + 3/2,
```

which is impossible for integer valuations. Exact cone inequalities show
that every other term lies strictly above the appropriate leading term.

## Conclusion

Tests 0147, 0149, and 0150 exclude the coordinate boundaries and every
normalization branch above the surviving singular plane points. The exact
Newton complex and the finite/stable-tail certificates in this test exhaust
every nonzero affine valuation pair. Therefore

```text
C_normalization(Q_2) = empty.
```

Consequently this curve has no rational point over `Q`. The specific König
`(2A,2A,2B,8A)` genus-11 component cannot provide the rational M24 member
needed by this point-stabilizer route to an M23 polynomial. This does not
exclude other M24 components or other approaches to `M23/Q`.

## Provenance and replay

The compact certificate was generated with SageMath 10.9 from the
authenticated external OPUS archive:

```sh
./scripts/run-8a-sage.sh --python \
  scripts/audit_m24_genus11_tropical_exhaustion.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --check-summary \
    data/derived/m24_koenig_genus11_tropical_exhaustion.tsv

make check-m24-genus11-tropical-exhaustion
```

Certificate SHA-256:

```text
e660e59cc39d485f0ceacaee44f914fd04b62359fd4478640e851ae150a13a46
```

The external archive is not committed.

## Outcome

This component is locally obstructed at 2 and is closed.
