# Test 0098: ramified-node Galois transfer for the small 8A components

## Question

Does the exact order-2 boundary bijection from Test 0097 commute with the
whole absolute-Galois action, rather than only with complex conjugation?

## Result

Yes.  The required boundary is the standard gluing-trees boundary in the
stack of pointed admissible `M23`-covers.  It is not covered by the
unramified-node specialization of Cau used in Test 0097, but it is covered
directly by the general ramified-node construction of
Abramovich--Corti--Vistoli and Jarvis--Kaufmann--Kimura.

The incidence relation

```text
small full (8A)^4 component
    <-> unordered q2-pair of generating (8A,8A,2A) inner classes
```

is therefore defined over `Q` and absolute-Galois equivariant.  Tests 0095
and 0097 prove that the right-hand set is one Galois orbit and that the
relation is a bijection.  Hence the fourteen small full-Hurwitz components
form one absolute-Galois orbit.  None is defined over `Q`.

This closes the small `(8A)^4` route negatively.  The `S14` calculation in
Test 0097 strengthens the arithmetic description of the fourteen labels but
is not needed for the transitivity transfer.

## The ramified gluing morphism

Abramovich--Corti--Vistoli work over a fixed noetherian base scheme and allow
a finite étale group scheme whose order is invertible on the base.  Taking
the constant group scheme `M23` over `Spec Q` satisfies these hypotheses.
Their Definition 4.3.1 defines admissible `G`-covers over a scheme, including
balanced ramification at nodes, and Theorem 4.3.2 identifies their stack with
the stack of balanced twisted `G`-covers.

Jarvis--Kaufmann--Kimura add a chosen point over each marked branch point.
Their Definition 2.1 again allows ramification over nodes and requires inverse
eigenvalues on the two tangent branches.  In their equations (7)--(8), the
gluing-trees morphism is

```text
M^G_(g1,n1+1)(m, mu) x M^G_(g2,n2+1)(mu^-1, m')
    -> M^G_(g1+g2,n1+n2)(m, m').
```

It is constructed by gluing the two universal curves at the selected
sections and simultaneously gluing every `G`-translate in the covers.
Inverse monodromies `mu` and `mu^-1` make the resulting node admissible.
Their Definition 2.28 specializes this exactly to a product-one four-tuple:

```text
mu  = (g1*g2)^-1
mu' = mu^-1 = g1*g2

M^G_(0,3)(g1,g2,mu) x M^G_(0,3)(mu',g3,g4)
    -> M^G_(0,4)(g1,g2,g3,g4).
```

Thus the order-2 entry in our three-point tuple is the node monodromy in the
published construction, not an unramified substitute.

The source-to-claim audit is:

| Source location | Claim used here |
| --- | --- |
| Abramovich--Corti--Vistoli §1.3 and Definition 4.3.1 | the moduli problem is over a noetherian base scheme, accepts a constant finite group with invertible order, and allows balanced node stabilizers |
| Abramovich--Corti--Vistoli Theorem 4.3.2 | admissible `G`-covers are base-preservingly equivalent to balanced twisted `G`-covers |
| Jarvis--Kaufmann--Kimura Definition 2.1 | their pointed covers allow ramification at nodes and impose inverse tangent eigenvalues |
| Jarvis--Kaufmann--Kimura equations (7)--(8) | inverse node monodromies define the gluing-trees morphism for any partition of the markings |
| Jarvis--Kaufmann--Kimura §2.2 and the introduction | the forgetful maps, symmetric-group action, `G^n` action, braid action, and gluing equivariance are part of the same construction |
| Jarvis--Kaufmann--Kimura Proposition 2.27 | the three-point component is independent of the chosen standard paths |
| Jarvis--Kaufmann--Kimura Definition 2.28 | the four-point component contains the exact gluing image with factors `(g1,g2,(g1*g2)^-1)` and `(g1*g2,g3,g4)` |
| Magaard--Shpectorov--Völklein, introduction | braid orbits of product-one generating systems correspond to irreducible families of sphere covers |

In particular, the JKK construction states that inverse monodromies make the
glued cover admissible; it does not impose trivial node monodromy.  This is
the point at which the present argument is more general than the
unramified-node Cau specialization audited in Test 0097.

## Why the construction is over `Q`

The stack and the gluing construction are moduli-functor constructions: they
use the constant group scheme, universal sections, fibre products, and
identifications of those sections.  They commute with base change.
Abramovich--Corti--Vistoli's base-scheme formulation therefore supplies the
construction over `Q`, not only after embedding into `C`.

For the only case needed here, this descent can also be seen directly.  Over
any `Q`-scheme `T`, glue the two marked base curves along their node sections,
and glue the two covers by identifying the corresponding marked lift and all
of its `M23`-translates.  This is exactly the JKK universal construction and
uses only fibre products and pushouts along sections.  At an order-2 node its
local boundary equations can be written

```text
base:   x*y = 0
cover:  z*w = 0,  x = z^2,  y = w^2,
action: (z,w) -> (-z,-w).
```

All coefficients and the balanced action are defined over `Q`; the same
construction after any extension of `T` is its base change.  No chosen
primitive eighth root at an external branch point enters the conjugacy-class
boundary relation.  This gives the needed `Q`-morphism directly, while ACV
supplies the ambient algebraic stack and JKK supplies its universal gluing
interpretation.

The relevant monodromy conditions are also Galois-stable:

- `8A` and `2A` are rational conjugacy classes in `M23`;
- the four external branch classes are all `8A`, so permutation of their
  markings preserves the class vector; and
- an order-2 node has `mu = mu^-1`, and every cyclotomic exponent is odd
  modulo 2, so no choice of a primitive root or orientation splits the `2A`
  boundary over a cyclotomic extension.

Consequently the union of the three `2+2` boundary partitions with node class
`2A` is a closed Galois-stable incidence correspondence over `Q`.

## Quotient and convention audit

The published gluing morphism is initially stated for pointed covers with
exact monodromy elements.  Each quotient used by the project preserves it:

1. The diagonal subgroup of the `G^n` action changes every monodromy element
   by the same element of `M23`.  The gluing construction is
   `G`-equivariant, so it descends to simultaneous-conjugacy, or inner,
   Nielsen classes.
2. Changing one chosen lift acts on its own exact monodromy label.  Rather
   than identifying that with simultaneous conjugation, the argument uses
   JKK's proper forgetful morphism from pointed covers to the
   admissible-cover stack.  Their construction supplies the `G^n` action and
   the forgetful map together, and gluing commutes with that map.
3. Permuting marked points is an algebraic symmetric-group action, and
   Jarvis--Kaufmann--Kimura explicitly make the gluing equivariant for these
   actions.  The verifier does not need to assign a literal product to
   nonadjacent bouquet generators: it uses only the standard adjacent split
   `(1,2)|(3,4)` across every vertex of each complete full-braid orbit.
4. On a three-point factor, the only repeated external classes are the two
   `8A` entries.  Their transposition is the adjacent Hurwitz move `q2`.
   Passing to the unlabelled factor is therefore exactly the unordered
   `q2` quotient in Tests 0064, 0095, and 0097.
5. For a product-one tuple, the complementary ledger pair supplies the second
   three-point factor at the ordered level.  If the first side is
   `(g1,g2,(g1*g2)^-1)`, the complementary ledger triple is
   `(g3,g4,(g3*g4)^-1)`.  This is a cyclic reordering of
   `((g1*g2),g3,g4)`, the second factor in Definition 2.28.

The verifier now treats the standard adjacent split as the proof subset.
Across the twelve vertices of each full component, eight `(1,2)` collisions
have order 2.  Their two ordered three-point IDs occur four times each and
form one unordered `q2` pair.  Every one of these 112 rows has an order-2
`(3,4)` complement in the same unordered pair.  All fourteen pairs occur
once.  The wider 1,008-row table remains useful diagnostic evidence and gives
the same answer, but nonadjacent literal products are not used in the Galois
transfer.

For these 112 rows the verifier also reads the independently committed
four-tuple witnesses, multiplies the degree-23 permutations, and checks the
ordered identity

```text
cyclic_shift((g1*g2), g3, g4)
    = (g3, g4, (g3*g4)^-1).
```

The second factor is therefore not inferred only after taking the unordered
`q2` quotient.

## From braid sheets to geometric boundary incidence

Fix an ordered four-point configuration.  The Riemann-existence statement is
not a new assumption here: Magaard--Shpectorov--Völklein explicitly state that
braid orbits of product-one generating systems correspond to irreducible
families of sphere covers.  In inner convention, the geometric fibre is the
finite set of those tuples modulo simultaneous `M23` conjugation, and its
configuration-space monodromy is the Hurwitz action.  Thus the twelve tuples
in each committed full orbit are exactly the sheets in one geometric
component after the equal-class branch permutations are allowed.

The stable-base divisor `(1,2)|(3,4)` is defined over `Q`.  JKK Proposition
2.27 removes dependence on the standard three-point paths, and their
Definition 2.28 defines the four-point component to be the component
containing the image of precisely the two gluing factors used here.  The
balanced local node has the standard smoothing, so that image lies in the
closure of the corresponding smooth braid component.  Conversely, a
standard-split boundary point has compatible bouquets on its two normalized
components; reading its nearby smooth fibre gives one of the sheets in the
complete braid orbit.  Its two factors therefore occur among the retained
rows.

This proves both directions needed to identify the geometric relation with
the adjacent-split ledger relation:

- every retained ledger row is realized by a genuine ramified-node boundary
  point in the indicated component closure; and
- every such standard-split boundary incidence is represented by a retained
  row.

Every component has eight retained rows, so nonemptiness is checked rather
than assumed.  Smoothness of the balanced admissible-cover stack ensures that
the local smoothing branches do not introduce an additional unidentified
four-point component.

Finally, Test 0095 describes degree-23 covers while the gluing stack describes
`M23`-covers.  Taking the Galois closure is functorial under
`Gal(Qbar/Q)`.  In its natural degree-23 action `M23` is self-normalizing in
`S23` (equivalently here, `Out(M23)=1` and the transitive centralizer is
trivial), so absolute permutation equivalence of the degree-23 covers is
exactly inner equivalence of their `M23` branch cycles.  The fourteen
unlabelled objects in Test 0095 are therefore the same Galois set `P3` used
by the boundary relation, not merely another set of the same cardinality.
The GAP producer now asserts directly that
`Normalizer(SymmetricGroup(23), M23) = M23`; the standard small-orbit
reproduction reruns this check before comparing all committed ledgers.

## Equivariance argument

Let `C4` be the finite set of fourteen geometric full-Hurwitz components and
let `P3` be the finite set of fourteen unordered `q2` pairs.  Let
`R subset C4 x P3` mean that the closures meet through the order-2 gluing
boundary above.

Because the compactification, gluing maps, node condition, and all quotient
maps are defined over `Q`, `R` is invariant under
`Gal(Qbar/Q)`.  The finite certificate proves that `R` is the graph of a
bijection `f : C4 -> P3`.  Hence, for every `sigma`,

```text
(c, f(c)) in R
    => (sigma*c, sigma*f(c)) in R
    => f(sigma*c) = sigma*f(c).
```

So `f` is Galois equivariant.  Test 0095 proves that `P3` is one orbit;
therefore `C4` is one orbit.  A geometric component defined over `Q` would be
a fixed point of this action, and there are none.

## Scope and trust boundary

This result proves a statement about fields of definition of the fourteen
geometric Hurwitz components.  It does not produce a rational point on a
component, a regular `M23/Q(t)` cover, or an `M23` polynomial over `Q`.

The literature supplies the algebraic and Galois-equivariant gluing
construction.  The project computation supplies the exhaustive finite
incidence and identifies it with the exact Nielsen conventions.  Neither
part alone proves the conclusion.

## Adversarial review

The first side-by-side packet had SHA-256
`a95c29cd971aa30636c5e2b56317426d400eb093b76c0a91abcc0a2c04ccc69f`.
Claude Fable 5 and GPT-5.4 both accepted the formal orbit-transfer skeleton
and finite bijection, but withheld the unconditional conclusion pending:

- primary text establishing ramified gluing over `Q`;
- an ordered, rather than only unordered, second-factor witness;
- removal of nonadjacent literal pair products from the proof; and
- explicit geometric and degree-23-to-inner identification lemmas.

The revised packet added extracted ACV/JKK primary pages and had SHA-256
`1d4c177605866cb0e2c029fded8d4abfe79c73ca00071a5e03d571ba555f2fa0`.
GPT-5.4 then accepted the ramified-node and over-`Q` source claims and the
ordered adjacent-split cleanup, while requesting the precise
braid-orbit/component source and an internal self-normalizer check.  Those
last requests produced the Magaard--Shpectorov--Völklein and JKK citations
above and the new GAP assertion.  Fable could not run on the revised packet
because the local Max session limit had been reached; the first Fable review
was nevertheless directly responsible for the base-change proof and
geometric-bridge hardening.

The reviews are advisory and are not counted as mathematical evidence.  The
final note intentionally postdates both packets and records how every
actionable objection was resolved.

## Reproduction

```bash
python3 scripts/verify_8a_small_orbits.py
make test
```

## Primary references

- Dan Abramovich, Alessio Corti, and Angelo Vistoli,
  [*Twisted bundles and admissible covers*](https://arxiv.org/pdf/math/0106211),
  Section 1.3, Definition 4.3.1, and Theorem 4.3.2.
- Tyler J. Jarvis, Ralph Kaufmann, and Takashi Kimura,
  [*Pointed admissible G-covers and G-equivariant cohomological field
  theories*](https://www.math.purdue.edu/~rkaufman/pubfiles/JKK1.pdf),
  Definition 2.1, equations (7)--(8), Proposition 2.27, and Definition 2.28.
- Kay Magaard, Sergey Shpectorov, and Helmut Völklein,
  [*A GAP package for braid orbit computation and
  applications*](https://doi.org/10.1080/10586458.2003.10504507),
  especially the Riemann-existence interpretation in the introduction.
- Johannes Schmitt and Jason van Zelm,
  [*Intersections of loci of admissible covers with tautological
  classes*](https://link.springer.com/article/10.1007/s00029-020-00603-4),
  Definition 3.2 and Section 3.4, for a modern formulation using balanced
  ramified nodes and admissible `G`-graphs.

## Evidence

- `data/derived/m23_8a_boundary_incidence.tsv`;
- `data/derived/m23_8a_8a_2a_inner_classes.tsv`;
- `data/derived/m23_8a_belyi_absolute_orbit.tsv`;
- `data/derived/m23_8a_component_witnesses.tsv`;
- `scripts/gap/reproduce_8A_small_orbits.g`; and
- `scripts/verify_8a_small_orbits.py`.
