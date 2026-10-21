# Test 0056: complex conjugation on the small `(8A)^4` components

## Question

Which of the 14 full Hurwitz components of length 12 derived in test 0004
survive the necessary complex-conjugation test for definition over `Q`?

## Mathematical scope

The rationality of the conjugacy class `8A` only proves that Galois preserves
the full `(8A)^4` Nielsen space. It does not prove that Galois fixes each braid
component. This distinction matters here because there are 14 full components
with the same size and braid-image order, so the usual rigidity argument based
on uniqueness does not select one of them.

For real ordered branch points and the standard bouquet, complex conjugation
sends a product-one tuple `(g1,...,gr)` to

```text
(g1^-1,
 g1 g2^-1 g1^-1,
 (g1 g2) g3^-1 (g1 g2)^-1,
 ...).
```

Each image entry is conjugate to the inverse of the corresponding entry, as
required by the branch-cycle lemma, and the prefix conjugations make the image
again product one. A different bouquet changes the result by a braid, so this
gives a well-defined involution on full Hurwitz components.

This computation determines one explicit element of the absolute Galois
action. It does **not** replace the unknown action of all of
`Gal(Qbar/Q)`. In particular, a component fixed by complex conjugation is only
a survivor of a necessary test, not a component proved to be defined over
`Q`. Seguin's branch-cycle formulation makes the same logical distinction:
cyclotomic power data controls the multidiscriminant, while the action on an
individual nonabelian component can contain more information.

## Method

The implementation and result are at the commit containing this note. The
artifact records GAP, AtlasRep, and CTblLib versions; constructs the group as
`MathieuGroup(23)`; and records the 28 generating `(8A,8A,2A)` inner classes as
the input construction.

Test 0004 is rerun, after which both the 28 six-element symmetry orbits and the
14 twelve-element full Hurwitz orbits are sorted lexicographically by their
canonical inner Nielsen tuples. These deterministic indices are the component
IDs in the artifact.

For every symmetry-orbit representative, the GAP computation:

1. applies the prefix-conjugated inverse formula above;
2. independently rechecks product one, generation of `M23`, and membership of
   every entry in `8A`;
3. re-enumerates the image under the symmetry moves and under the full Hurwitz
   generators;
4. records the resulting component IDs; and
5. recomputes degree 6, genus 0, and symmetry monodromy order 24.

It also checks directly that all four unit powers modulo 8 preserve `8A`.
The Python verifier checks both recorded permutations are involutions, every
full component has exactly two symmetry halves, and conjugation respects that
pairing.

Run:

```sh
make reproduce-8a-small-orbits
make test
```

## Result

On the 14 full components, complex conjugation has cycle structure

```text
(1 12)(2 11)(3)(4 13)(5 9)(6)(7 10)(8 14).
```

Consequently:

- 12 full components are not defined over `R`, hence not over `Q`;
- full components 3 and 6 survive this necessary test;
- complex conjugation swaps all 28 genus-zero symmetry halves in 14 pairs;
- within survivor 3 it swaps halves 4 and 10, and within survivor 6 it swaps
  halves 7 and 24.

The `8A` power test supplies no further separation: exponents `1,3,5,7`
all preserve the class. The ATLAS M23 page records `Mult = 1` for
`M23`, so the ordinary Schur multiplier and any quotient used as a reduced
lifting invariant cannot distinguish the two survivors either.

## Verdict and next gate

Passed as a necessary descent filter. It is a substantial narrowing, but not a
proof that either survivor is defined over `Q`.

Do not begin a conic or rational-point computation for an individual
six-element genus-zero symmetry piece: none is stable even under complex
conjugation. The next arithmetic task is restricted to full components 3 and
6 and must determine their remaining absolute-Galois descent data (or produce
an independent rigidity/descent theorem that fixes them). Only after one full
component is proved to descend should explicit genus-zero quotient geometry be
treated as an `M23/Q` route.

## Artifact

`data/derived/m23_8a_small_component_descent.tsv`
