# Test 0135: König relation numerator filtration

## Question

After quotienting the 91 exact plane-multiple controls, does the original
monomial-coordinate relation space contain smaller canonical subspaces defined
by numerator degree or support?

## Result

Yes, modulo 19.

The 568-dimensional homogeneous relation space maps to the 9,506 original
numerator monomial coordinates with rank 477. Its 91-dimensional kernel is
exactly the known plane-control sector, so the numerator image realizes the
desired quotient without choosing a complement to those controls.

For a nested set of selected numerator monomials, the audit computes

```text
supported dimension
  = 477 - rank(projection to the complementary monomials).
```

Four filtrations give sharp nonzero onsets:

| filtration | last zero cutoff | first nonzero cutoff | selected columns | first dimension | first full cutoff |
| --- | ---: | ---: | ---: | ---: | ---: |
| alpha degree | 76 | 77 | 7,644 | 21 | 96 |
| beta degree | 76 | 77 | 7,566 | 7 | 97 |
| total degree | 104 | 105 | 5,590 | 56 | 110 |
| square degree `max(i,j)` | 84 | 85 | 7,396 | 23 | 97 |

Thus the quotient image is not an undifferentiated 477-dimensional modular
space. In particular, beta degree at most 77 cuts out a canonical
7-dimensional block, while three independent degree conventions expose
21-, 23-, and 56-dimensional blocks. This is the first positive structural
gate after the scalar, shared-denominator, and annihilator reconstruction
pilots failed.

The result is currently a characteristic-19 support statement. It does not
yet prove that any of these blocks lifts with the same support over
`Z/19^10 Z`, nor that it is defined over the rationals.

## Validation

The Sage producer starts from the complete digit-10 reduced relation artifact,
forms the exact numerator image over `F_19`, and updates complementary ranks
incrementally. A synthetic test compares every incremental result with a
fresh direct rank computation.

The independent Python checker:

- verifies the two input hashes and the complete 97-by-98 monomial rectangle;
- rebuilds the `568 x 9506` numerator image using NumPy integer arithmetic;
- computes rank with a separate modular Gaussian elimination;
- rechecks the full rank 477 and both sides of all four onset boundaries; and
- verifies every row's selected-column count, dimension identity, and
  monotonicity.

The official Sage run took 2 minutes 1.79 seconds with maximum RSS 472,408 KiB
under SageMath 10.9. The independent replay took 18.54 seconds with maximum RSS
255,276 KiB.

## Evidence

Implementation revision:
`ad090a37f1468c9e09241737514b6e7f56d86fa9`.

```text
adbc31cb79b7100bc6212ddf30207e6b1541b11ad7b1c4af66f81c982ac00292
  data/derived/m23_koenig_a_relation_numerator_filtration.tsv
```

Replay:

```sh
make check-koenig-relation-numerator-filtration
```

## Next gate

Start with the smallest block: impose vanishing of numerator coefficients with
beta degree greater than 77 on the complete homogeneous relation module and
test whether its dimension 7 persists through all available 19-adic digits.
Require all fitting and holdout equations at every digit, retain the
21-dimensional alpha block and the 23-dimensional square block as independent
cross-checks, and only attempt rational reconstruction after a canonical
lifted block survives.
