# Test 0100: complete `(3A)^4` inner Nielsen exhaustiveness

## Question

Can the global total of 37,296 generating inner classes used in test 0099 be
certified independently, rather than imported from Häfner's table?

## Exact pair partition

Fix the unique natural-action class `3A` and an element `a` in it.  GAP
enumerates the double cosets

```text
C_M23(a) \ M23 / C_M23(a).
```

Each of the resulting 356 double cosets represents one simultaneous-conjugacy
orbit of ordered `3A` pairs.  The generator records the pair product class,
normalizes the product to a fixed class representative, and records the pair
stabilizer.  Summing the exact orbit weights gives

```text
3,211,715,584 = 56,672^2,
```

so the pair partition covers the complete class square.

Matching pair-product classes with inverse product classes gives 11,474
symbolic pair-pair macroblocks.  Relative-centralizer double cosets then
materialize one representative of every inner product-one `(3A)^4` class.
This produces exactly 156,693 inner classes before the generation filter.

For every relative double coset, its exact size determines the simultaneous
stabilizer order of the resulting tuple.  Summing the reciprocal stabilizer
orders over all 156,693 materialized classes agrees exactly with the
independent Frobenius character formula for the number of product-one
`(3A)^4` tuples, divided by `|M23|`.  This global mass identity checks the
macroblock parametrization across block boundaries, rather than only checking
the pair partition within each block.

## Independent generation checks

Every materialized tuple is checked in two ways.

1. GAP constructs `Group(tuple)` and compares it directly with the natural
   `M23`.
2. After fixing the first entry to `a`, the program tests containment in all
   62 maximal subgroups of `M23` that contain `a`.  A tuple generates `M23`
   exactly when its four incidence masks have no common bit.

The 62 subgroups are themselves obtained from all seven maximal-subgroup
classes.  Explicit subgroup containment is checked against the independent
double-counting formula for the number of conjugates containing `a`.

The two generation criteria agree on all 156,693 inner classes, with zero
disagreements.  Exactly 37,296 classes generate `M23`; the other 119,397 do
not.

The pair-product-order breakdown provides an additional seam with test 0099.
The order-1 slice contains 356 inner classes, of which exactly 40 generate.
These are precisely the inverse-pair forms
`(a,a^-1,b,b^-1)` classified by the separate fixed-first centralizer census
in test 0099.

## Consequence

The two full adjacent-braid orbits constructed in test 0099 have sizes
8,316 and 28,980, whose sum is the independently certified total 37,296.
They therefore exhaust the complete generating inner Nielsen class.  The
two-component premise in the Galois argument no longer depends on Häfner's
reported global count.  Häfner remains the published comparison for the
matching orbit sizes and genera.

## Reproduction and provenance

The implementation and result are in the commit containing this note.

```bash
make reproduce-seguin-3a-total
make check-seguin-3a-total
```

The wrapper deterministically regenerates the complete 3A pair-orbit
checkpoint, records its SHA-256, materializes all macroblocks, and writes
`data/derived/m23_3a_inner_nielsen_total.tsv`.  That artifact records GAP
4.12.1, the generating code revision and package versions, the group and
class data, pair coverage, the independent character-table mass, all totals,
generation agreement, nongenerating subgroup orders, and the product-order
breakdown.

The general pair decomposition and inner Nielsen conventions follow the
standard braid-orbit framework cited in `docs/literature-basis.md`; no
published M23 orbit total is used by the certificate.
