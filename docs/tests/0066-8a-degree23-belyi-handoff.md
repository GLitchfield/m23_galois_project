# Test 0066: degree-23 Belyi handoff for the 8A three-point classes

## Question

Can the complete 28-class `(8A,8A,2A)` certificate be converted into a
standard, immediately usable input for explicit Belyi-map computation, with
the arithmetic consequences and remaining boundary stated precisely?

## Method

The Python exporter reads every canonical permutation triple in
`m23_8a_8a_2a_inner_classes.tsv`.  Independently of GAP, it checks:

- that all three entries are permutations of 23 letters;
- product one using the GAP/Magma right-action convention;
- the cycle partitions of both `8A` entries and the `2A` entry; and
- that the class IDs are exactly `1,...,28`.

It then writes the 28 triples in Magma cycle notation, together with Magma
assertions for product one and generated-group order.  The output format is
the direct input accepted by the public
[Belyi Magma package](https://github.com/michaelmusty/Belyi):

```magma
AttachSpec("Code/spec");
X, phi := BelyiMap(triples[1]);
```

Run:

```sh
make reproduce-8a-small-orbits
```

## Result

All 28 classes have natural degree-23 passport

```text
(8,8,4,2,1), (8,8,4,2,1), (2^8,1^7).
```

The permutation indices are `18`, `18`, and `8`, so Riemann--Hurwitz gives

```text
g = 1 - 23 + (18 + 18 + 8)/2 = 0.
```

By the classical Riemann existence/branch-cycle theorem, every class therefore
represents a degree-23 Belyi rational function. This theorem-level passage
from permutation data to a complex cover is external established mathematics;
it is not currently formalized in the project's Lean layer. The Magma handoff
is only 6 KB and contains all 28 exact triples.

Sijsling--Voight, Example 7.9, already demonstrates that working inside `M23`
is an efficient way to count degree-23 Belyi maps.  They also record that
`M23` equals its normalizer in `S23`.  Consequently, simultaneous conjugacy
inside `M23` is the ordinary degree-23 equivalence here: the 28 inner classes
do not collapse further when regarded as unmarked Belyi maps.

The centralizer in `S23` of the monodromy group is trivial, so these Belyi maps
have no automorphisms. By the standard Weil descent theorem for covers, each
field of moduli is therefore a field of definition. This descent implication
is also theorem-level external input, not a finite calculation or current Lean
result. Test 0064 shows that complex conjugation fixes
none of the 28 maps.  Their unknown Galois orbits consequently have even size,
their fields of moduli have degree at most 28, and no field of moduli is fixed
by the chosen complex conjugation.  In particular, none of the maps is defined
over `Q`.

## Boundary

This test supplies exact Belyi inputs, not equations.  The public numerical
package requires Magma, which is not installed in the current environment,
and a search of the associated public database and LMFDB found no copy of this
degree-23 passport.  Absence from those searches is not proof that the maps
have never been computed privately or under another convention.

The Magma pilot proposed at this point was never run. The exact class-1 map
was later obtained without Magma (tests 0086--0091).

## Evidence

- `data/derived/m23_8a_8a_2a_belyi_input.m`;
- `data/derived/m23_8a_8a_2a_inner_classes.tsv`;
- `scripts/export_8a_three_point_belyi_magma.py`;
- `scripts/check-8a-small-orbits.sh`; and
- Jeroen Sijsling and John Voight,
  [*On computing Belyi maps*](https://doi.org/10.5802/pmb.5), especially
  Section 7 and Example 7.9.
