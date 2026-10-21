# Test 0097: the 8A fixed-field Galois group and boundary bijection

## Question

What is the arithmetic Galois group of the degree-14 fixed field from Test
0095, and does the exact order-2 boundary incidence identify its fourteen
embeddings with the fourteen small four-branch components?

## Result

The degree-14 fixed-field polynomial is

```text
x^14 - 12*x^13 + 52*x^12 - 60*x^11 - 248*x^10 + 872*x^9
- 276*x^8 - 3360*x^7 + 7292*x^6 - 5352*x^5 - 1512*x^4
+ 4496*x^3 - 1308*x^2 - 1344*x + 768.
```

Its arithmetic Galois group is `S14`.  Independently, the committed
four-branch incidence table induces a bijection between:

- the fourteen unordered pairs of the 28 generating
  `(8A,8A,2A)` inner classes under the branch swap `q2`; and
- the fourteen small full-Hurwitz components in `(8A)^4`.

This bijection exactly intertwines the already certified
complex-conjugation actions.

These are exact finite results.  They did not, by themselves, prove that the
bijection intertwines the whole absolute-Galois action.  Test 0098
subsequently closes the ramified-node convention gate described below.

The polynomial is the defining polynomial in the descended-cover JSON from
Test 0094.  Test 0095 independently verifies that its branch-symmetric
invariant lies in, has degree 14 over `Q`, and therefore generates this same
fixed field.  Thus the `S14` calculation is attached to the field used in the
absolute-orbit argument rather than merely to an unrelated degree-14
polynomial.

## Independent `S14` certificate

Sage 10.9 checks that the displayed monic polynomial is irreducible over
`Q` and has polynomial discriminant

```text
2^71 * 3^17 * 11^2 * 23^3 * 37^2 * 43^2.
```

The selected primes therefore do not divide this discriminant.  Exact
squarefree factorizations give:

| prime | factor degrees | Frobenius cycle shape |
|---:|---:|---:|
| 7 | `14` | `(14)` |
| 127 | `13,1` | `(13)(1)` |
| 53 | `11,2,1` | `(11)(2)(1)` |

The Dedekind--Frobenius correspondence puts elements of all three cycle
types in the arithmetic Galois group.  A separate GAP 4.12.1 / TransGrp
3.6.5 calculation enumerates all 63 transitive groups of degree 14 and
checks their conjugacy classes.  Only `14T63` contains all three types;
GAP identifies it as `S14`, of order

```text
87178291200 = 14!.
```

There is also a conceptual group-theoretic cross-check.  A transitive
degree-14 group containing a 13-cycle is primitive.  Squaring an element
of shape `(11)(2)(1)` gives an 11-cycle with three fixed points, so
Jordan's prime-cycle theorem forces the group to contain `A14`.  The
14-cycle is odd, forcing `S14`.  The committed certificate uses the
finite TransGrp audit rather than silently relying on this theorem.

## Exact boundary bijection

For every four-branch component, the verifier now collects all 48 boundary
occurrences whose colliding pair has product in `2A`.  In every component:

- exactly two ordered three-point class IDs occur;
- they are exchanged by `q2`;
- each occurs exactly 24 times; and
- no other unordered `q2` pair occurs.

All fourteen unordered pairs occur once, so component-to-pair incidence is
a bijection.  Applying the exact three-point complex-conjugation
permutation and transporting it across the bijection gives

```text
(1 12)(2 11)(4 13)(5 9)(7 10)(8 14),
```

with components 3 and 6 fixed.  This is exactly the independently computed
four-branch action from Test 0056.

Test 0098 strengthens the verifier with a convention-clean proof subset:
the standard adjacent split `(1,2)|(3,4)` alone gives the same bijection.
Each component has eight order-2 `(1,2)` incidences, split four and four
between its two `q2` labels, and each complementary `(3,4)` triple belongs to
the same unordered pair.  Nonadjacent literal pair products are therefore not
needed for the arithmetic transfer.

## Cau--Seguin convention audit

The review gate in Test 0096 correctly required this audit.  The often-cited
theorem does not directly close it:

- Cau's Definition 2.5 builds a degeneration structure from components
  represented by product-one blocks.
- Cau's Definition 3.7 explicitly uses admissible covers unramified at the
  singular nodes for the theorem's `Delta`-covers.
- Seguin's Theorem 3.1 restates the resulting Galois equivariance for the
  corresponding `ni_H` sets of concatenated components.

Our incidence is different.  Starting from a four-tuple
`(g1,g2,g3,g4)`, it collides a selected pair `(gi,gj)` with product in
`2A` and records the three-point tuple

```text
(gi, gj, (gi*gj)^-1).
```

The last entry is a ramified node of order 2; the recorded triple is not a
product-one block already present in the original four-tuple.  Indeed Test
0058 proves that none of the fourteen components contains a partition into
two inverse-pair blocks.  More directly, all 1,008 recorded pair products
have order 2 or 4 and none has product one.  Consequently Cau's
unramified-node theorem and Seguin's direct restatement cannot simply be
cited as the missing equivariance proof.

The required next theorem is narrower: the order-2 boundary relation in
the admissible-cover compactification, including the clutching maps to its
two three-point sides, must be shown to satisfy all of the following:

1. the relevant compactification, order-2 boundary stratum, and clutching
   maps descend to `Q`;
2. the `2A` node has no unresolved cyclotomic twist (`2A` is rational and
   inverse-closed);
3. forgetting the marking and taking the inner quotient preserve this
   incidence relation;
4. the `q2` quotient is exactly the unordered swap of the two colliding
   `8A` branches;
5. passage to the full-braid components preserves the relation; and
6. the geometric boundary components are identified with the exact 28
   three-point inner classes used in the ledger.

General compactification theory makes this plausible, and compatibility with
complex conjugation is now an exact end-to-end check, but this test does not
claim the lemma without a precise source or proof.

If that ramified-node lemma is established, Test 0095's transitivity on the
fourteen unordered pairs and the bijection immediately imply that all
fourteen small four-branch components form one absolute-Galois orbit.  The
stronger `S14` result is not needed for this implication.  In that event no
component is defined over `Q`.  Until then, this is a conditional consequence
rather than a completed descent result; within this test alone the
unconditional result remains that twelve components are excluded and
components 3 and 6 survive.

Test 0098 supplies the missing source and convention proof using the
ramified-node gluing morphism of Abramovich--Corti--Vistoli and
Jarvis--Kaufmann--Kimura.  It discharges this conditional: all fourteen
components form one absolute-Galois orbit and none is defined over `Q`.

## Adversarial review

The side-by-side harness gave Claude Fable 5 and GPT-5.4 the same 111 KB
packet containing this note, the exact producers and checkers, all 1,008
incidence rows, the three-point ledger, and tests 0056, 0058, 0063, and 0095,
then ran one reciprocal critique round.  The packet SHA-256 was
`e1dc17298223eb4708b1a7979c62f0a371e35bc48651f54a1c11b05fd4877509`.

Both reviewers supported the `S14` proof and the finite bijection at their
stated scope, accepted the orbit conclusion only conditionally, rejected an
unconditional no-`Q` conclusion for components 3 and 6, and agreed that the
cited Cau--Seguin theorem does not directly cover this ramified-node
relation.  Fable independently re-derived the bijection from the raw tables.
The review remains advisory rather than mathematical evidence.

## Reproduction

```bash
make check-8a-fixed-field-galois
python3 scripts/verify_8a_small_orbits.py
```

To regenerate both Galois-group artifacts:

```bash
./scripts/reproduce-8a-fixed-field-galois.sh
```

## Evidence

- `data/derived/m23_8a_fixed_field_frobenius.tsv`;
- `data/derived/m23_degree14_transitive_group_audit.tsv`;
- `data/derived/m23_8a_boundary_incidence.tsv`;
- `data/derived/m23_8a_8a_2a_inner_classes.tsv`;
- `scripts/analyze_8a_fixed_field_frobenius.sage`;
- `scripts/gap/audit_degree14_transitive_groups.g`;
- `scripts/check_8a_fixed_field_galois.py`; and
- `scripts/verify_8a_small_orbits.py`.

Primary convention references are Orlando Cau,
[*Delta-composantes des espaces de modules de revêtements*](https://www.numdam.org/item/10.5802/jtnb.811.pdf),
Definitions 2.5 and 3.7, Proposition 3.9, and Theorem 3.2; and Béranger
Seguin,
[*Fields of Definition of Components of Hurwitz Spaces*](https://arxiv.org/pdf/2303.05903),
Paragraph 2.3.4 and Theorem 3.1.
