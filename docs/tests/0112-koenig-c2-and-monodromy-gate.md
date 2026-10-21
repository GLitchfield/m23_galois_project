# Test 0112: König `C2` bridge and monodromy gate

## Question

Do the recovered mod-19 functions use the same `C2`-symmetrized component
convention as König's genus-43 plane curve, and how far can the published
finite-field anchor independently distinguish `M23` from `A23`?

## Exact `C2` convention bridge

König's dissertation, Theorem 2.5 and Chapter 5.3, treats the two equal `2A`
branch points as a partially ordered pair. In the normalized universal family
they occur at

```text
t = 1/2 + lambda,  t = 1/2 - lambda,
```

and the quotient parameter is `a=lambda^2`. The corresponding factorizations
are

```text
(t-1/2-lambda) G = C f3^2 f4,
(t-1/2+lambda) G = C f5^2 f6.
```

The independent GAP calculation stores the reordered class vector
`(3A,5A,2A,2A)`. Test 0112 checks the missing convention seam exactly:

- `eta34` exchanges the last two equal classes, has cycle shape `2^490`, and
  has order two;
- the symmetric branch permutations satisfy
  `beta13 * eta34 * beta4 = 1`;
- the pure and symmetric actions both have degree 980, while their genera are
  119 and 43; and
- the symbolic involution
  `lambda -> -lambda`, `(f3,f4) <-> (f5,f6)` exchanges the two displayed
  identities and fixes `a`, `alpha`, and `beta`.

The degree remains 980: this is a partially ordered branch-point
symmetrization and change of configuration parameter, not a division of the
980 cover classes into 490 points.

The Test 0109 artifact contains exactly the invariant coefficient sector

```text
a, C, f1, f2, g1, g2,
```

including all thirteen unfixed coefficients of the four factors. It contains
neither `lambda` nor coefficients of `f3,...,f6`, which live only after the
quadratic branch-labeling extension. Thus our mod-19 reconstruction is
precisely at the quotient level claimed for the genus-43 plane equation.

This pins the conventions; it does not by itself lift the coefficient map to
characteristic zero or prove that the plane curve is the desired component.

## Exact monodromy candidates

For the published degree-23 anchor, `P(X)-tQ(X)` is irreducible over
`F_19(t)`, so its geometric monodromy is transitive. All four inertia
permutations are even. An exhaustive check of the seven degree-23 transitive
groups then shows that the three required finite inertia shapes

```text
1^7 2^8,  1^5 3^6,  1^3 5^4
```

occur together in an even transitive group only for `23T5=M23` and
`23T6=A23`. This gives the exact dichotomy

```text
G_geom is M23 or A23.
```

The complete unramified `F_19` census has sixteen values. Every factorization
shape occurs in the independently generated `M23` class atlas:

| Shape | Number of values |
| --- | ---: |
| `2 7 14` | 5 |
| `1 11 11` | 3 |
| `1^3 5^4` | 1 |
| `1^2 7^3` | 3 |
| `1 2 4 8^2` | 2 |
| `3 5 15` | 2 |

That is clean positive evidence and rejects no `M23` possibility. Absence of
an `A23`-only shape in sixteen samples is not an upper-bound proof.

## Elkies--Hasse--Weil feasibility

Elkies' published method distinguishes `M23` from `A23` by counting rational
points on the cover induced on 5-element subsets and contradicting the
Hasse--Weil bound under the `A23` hypothesis. Barth and Wenz give the general
rational-function formulation.

For this four-branch passport, exact induced-cycle and Riemann--Hurwitz
calculation gives

```text
degree(C5) = binomial(23,5) = 33,649,
genus(C5)  = 7,582.
```

`A23` is 5-transitive, whereas `M23` has two orbits on 5-subsets. The first
asymptotic separation scale is therefore

```text
4*g(C5)^2 = 229,946,896.
```

Since

```text
19^6 = 47,045,881 < 229,946,896 < 19^7 = 893,871,739,
```

the first extension above that scale is `F_(19^7)`. An actual proof would
still require the exact point count; the inequality is a planning threshold,
not a substitute for the census. Directly factoring almost 894 million
degree-23 specializations is not a sensible next computation. Tests for
subset sizes 6 through 11 have no better extension-field threshold.

A brute-force `F_(19^7)` census was therefore not scheduled. The project
instead pursued the characteristic-zero tautological family, which would also
close the component-map gate (tests 0113--0145); that reconstruction did not
succeed, so the `M23`-versus-`A23` question for this family is left
unresolved here.

## Evidence and replay

Implementation revision:
`e0c872961ebfe260e20f1728efbff9d3717d9627`.

Compact artifacts:

```text
98ca736de385c8cc8d59140c3b2f65c8a742166192a568e90011bdb0455d39fb
  data/derived/m23_koenig_c2_bridge.tsv
5592c63e0a5b970f35a291f4541467ad5c615ccd387f5f9ca081076bf2f1ff37
  data/derived/m23_koenig_f19_monodromy_candidates.tsv
7f8b7fcdbf592317d27289025d7e008eac91a36dd28c5acbe31786e33a15ccb9
  data/derived/m23_koenig_f19_frobenius.tsv
0407aa9ebce7ee7384076c8985a9d3d212e251f3fd9fdfd5356465b0eaead401
  data/derived/m23_koenig_f19_transitivity_gate.tsv
```

Replay with:

```sh
make check-koenig-c2-bridge
make check-koenig-f19-monodromy
```

Primary method sources:

- J. König, dissertation, Theorem 2.5 and Chapter 5.3, pages 73--74.
- N. Elkies, [*The complex polynomials P(x) with
  Gal(P(x)-t) ≅ M23*](https://doi.org/10.2140/obs.2013.1.359),
  ANTS X (2013), Section 3.
- D. Barth and A. Wenz, [*On Elkies' method for bounding the transitivity
  degree of Galois groups*](https://doi.org/10.1016/j.jsc.2021.05.001),
  J. Symbolic Computation 108 (2022), 17--22.
