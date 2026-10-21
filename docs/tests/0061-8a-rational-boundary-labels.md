# Test 0061: rational boundary labels on the small 8A components

## Question

Does enriching the common degree-12 braid action with the actual `M23`
conjugacy class of each pair product distinguish either component 3 or
component 6?

These labels retain information discarded by test 0059.  When two branch
points collide, the local monodromy at the resulting boundary divisor is,
up to the usual choices of paths and conjugacy, the product of the
corresponding branch cycles.  Thus pair-product labels describe the cusp or
boundary embedding of the abstract braid action into the Nielsen class.

## Arithmetic relevance

The branch-cycle lemma sends a local inertia generator to a cyclotomic power.
Likewise, Cau's boundary-component formalism, restated as Theorem 3.1 in
Seguin's *Fields of Definition of Components of Hurwitz Spaces*, makes the
Galois action compatible with the corresponding degeneration structures.
Consequently the rational power-orbit of a pair-product conjugacy class is a
necessary Galois-stable boundary label.

Only classes `2A` and `4A` occur in this experiment.  Each is the unique
`M23` class of its order and is rational, so recording the order records the
full rational conjugacy-class label; there is no unresolved ATLAS naming
choice.

## Method

For every one of the 14 lexicographically numbered full components and each
of its 12 canonical inner Nielsen tuples, the GAP computation records the
orders of all six products `g_i*g_j`, `i < j`.  It then uses the explicit
simultaneous conjugator of the three ordered braid generators from test 0059
to compare the six labels vertex by vertex with component 1.

The Python certificate generator independently recomputes the products and
their exact orders from the committed degree-23 permutation tables.  Lean
checks directly that every pair product has exact order 2 or 4 and that all
six Boolean order labels are preserved by every recorded degree-12
transporter.

Run:

```sh
make reproduce-8a-small-orbits
make check-lean
```

## Result

Every component has the same aggregate profile:

```text
2A^48 4A^24
```

More strongly, for all 14 components the ordered braid-action transporter
preserves all six pair-product labels at all 12 vertices.  Therefore the
abstract action remains isomorphic after it is enriched by these rational
boundary labels.

## Verdict and boundary

Failed as a discriminator.  Neither ordinary cusp widths nor the finer
`M23` pair-product conjugacy labels can separate components 3 and 6 from the
other small components.

This does not compute the absolute-Galois action.  It rules out invariants of
this labeled finite boundary structure; an arithmetic distinction would have
to use more than the topological cover and its rational node-inertia labels.
Test 0063 adds the exact three-point inner Nielsen class at each boundary;
that finer incidence structure does distinguish all fourteen components.

## Evidence

- `data/derived/m23_8a_component_signatures.tsv`;
- `data/derived/m23_8a_component_witnesses.tsv`;
- `scripts/gap/reproduce_8A_small_orbits.g`;
- `scripts/generate_8a_tuple_lean_certificate.py`; and
- `formal/M23Formal/Certificates/Test0058.lean`.

Primary references are Orlando Cau,
[*Delta-composantes des espaces de modules de revêtements*](https://www.numdam.org/articles/10.5802/jtnb.811/),
Theorem 3.2 and the boundary construction, and Béranger Seguin,
[*Fields of Definition of Components of Hurwitz Spaces*](https://arxiv.org/abs/2303.05903),
Theorem 3.1 and Lemma 2.10.
