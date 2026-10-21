# Test 0064: a complete three-point Galois target for the small 8A components

## Question

Are the 28 generating `(8A,8A,4A)` boundary labels observed in test 0063 a
complete three-point Nielsen class?  If not, can the complete
`(8A,8A,2A)` class alone still distinguish all fourteen small `(8A)^4`
components?

## Method

GAP fixes one representative `a` of `8A` and scans the complete `8A`
conjugacy class for second entries `b`.  For product class `4A` it counts both
all product-one triples

```text
(a, b, (a*b)^-1)
```

and the triples for which `<a,b> = M23`.  The centralizer of `a` has order 8
and acts freely on the generating pairs: an element stabilizing a generating
pair centralizes all of `M23`, whose center is trivial.  Division by 8 therefore
gives the exact number of generating inner classes.

The labeled degree-12 action comparison from test 0063 is then repeated while
ignoring every boundary pair whose product is not in `2A`.  As before, GAP
examines every transporter between the ordered braid actions, including the
full action centralizer, rather than accepting its first transporter.

Finally, GAP emits a standalone certificate for all 28 generating
`(8A,8A,2A)` inner classes.  IDs are assigned by lexicographically sorting
canonical degree-23 representatives.  For every class the certificate records
the adjacent Hurwitz generator `q2` and prefix-conjugated inversion, the chosen
complex-conjugation action.

Run:

```sh
make reproduce-8a-small-orbits
make test
```

## Result

The global `(8A,8A,4A)` census is:

```text
fixed-first product-one tuples                 41,220
fixed-first tuples generating M23              33,664
generating inner classes (= 33,664 / 8)         4,208
```

Thus the 28 `4A` classes occurring on the small components are only a tiny
subset of the full 4,208-class Nielsen set.  There is no basis for assuming
that subset is stable under absolute Galois.

The `2A` restriction succeeds: the complete 28-element
`(8A,8A,2A)` class by itself puts the fourteen small components in fourteen
distinct labeled-action classes.  This removes the 4,208-class set from the
minimum arithmetic problem.

On the complete 28-class certificate, both `q2` and complex conjugation are
fixed-point-free involutions.  They commute in the computed permutation
action.  Together they have six orbits of size 4 and two orbits of size 2.
These statements are exact finite checks, not claims that the remaining
Galois action has been determined.

## Arithmetic interpretation and boundary

The classes `8A` and `2A` are rational, so the full 28-element
`(8A,8A,2A)` inner Nielsen class is Galois-stable.  The incidence artifact now
maps every `2A` boundary occurrence directly to its ID in that complete set.
Consequently, determining the Galois permutation action on these 28 classes is
sufficient to propagate the boundary action back to the fourteen small
four-branch components.

This is an instance of the finite permutation viewpoint developed for regular
dessins and finite groups by Pierre Guillot: the Galois action factors through
a finite permutation action on generating triples.  Guillot gives an explicit
framework for nonabelian simple groups, but does not compute the case `M23`.
The present certificate supplies one rational-passport slice of the input; it
does **not** compute `GT(M23)`, fields of moduli, or a `Q`-defined component.

Test 0065 evaluates the first proposed route.  Guillot's full finite
`GT_1(M23)` upper bound permits the wreath-product factor `C2 wr S14` on this
passport, so it does not determine the actual Galois image.  The next exact
arithmetic task is therefore to obtain equations, fields of moduli, Frobenius
data, or a specialist computation for the corresponding three-point covers
and recover the permutation action directly.

The relevant primary framework is Pierre Guillot,
[*The Grothendieck-Teichmüller group of a finite group and G-dessins
d'enfants*](https://arxiv.org/abs/1407.3112), especially the explicit
permutation description for nonabelian simple groups.  Cau's degeneration
compatibility remains the bridge from the three-point action to the
four-branch components.

## Evidence

- `data/derived/m23_8a_8a_2a_inner_classes.tsv`;
- `data/derived/m23_8a_boundary_incidence.tsv`;
- `data/derived/m23_8a_component_signatures.tsv`;
- `scripts/gap/reproduce_8A_small_orbits.g`; and
- `scripts/verify_8a_small_orbits.py`.
