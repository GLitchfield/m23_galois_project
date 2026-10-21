# Test 0001: M23 class atlas and Häfner structure constants

## Question

Can the M23 conjugacy-class invariants and normalized structure-constant floors
reported in Häfner's principal length-3/4 table be reproduced from the installed
GAP character table without assuming a labeling of computed permutation classes?

## Environment

- GAP 4.12.1
- CTblLib 1.3.7
- AtlasRep 2.1.8
- TransGrp 3.6.5

## Method

Run:

```sh
make reference-data
make test
```

The generator uses `CharacterTable("M23")` for canonical names, sizes, orders,
power maps, and irreducible characters. A separate Python checker validates
group-order, centralizer, cycle-shape, order, inverse-map, and table-shape
invariants. The normalized constants use Häfner's displayed character formula;
their exact rational values are floored and compared with every row reported in
the preprint.

## Result

- All 17 library-table classes were recorded.
- Class sizes sum to `10,200,960` and every size times its centralizer is the
  group order.
- Natural degree-23 cycle shapes agree for every computed class matching each
  library row by order and size.
- All 27 preprint-reported normalized structure-constant floors match exactly.
- GAP exposes 16 possible fusions from the computed natural-action table to the
  library table, so members of paired non-rational classes cannot be named from
  order and cycle shape alone.

The preprint-reported inner Nielsen counts and braid-orbit rows are now
structured fixtures, but remain explicitly classified as reported rather than
reproduced.

## Artifacts

- `data/reference/m23_classes.tsv`
- `data/reference/hafner_2022_class_vectors.tsv`
- `data/reference/hafner_2022_braid_orbits.tsv`
- `data/reference/hafner_2022_search_state.tsv`
- `data/reference/hafner_2022_quadratic_field_orbits.tsv`
- `docs/m23-class-names.md`
