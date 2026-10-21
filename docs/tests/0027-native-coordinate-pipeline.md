# Test 0027: native coordinate pipeline

## Question

Can C++ reproduce the complete hot-loop coordinate path used by GAP's 4A
quotient walker, including macroblock arithmetic, pair-twist weights, output
ordering, and genuine duplicate removal?

## Method

GAP regenerates two versioned fixtures from the exact homogeneous 4A pair
checkpoint. The first is production seed block `1633430`, twist `1`: its
source orbit has weight 11 and its beta13/beta14 images yield 22 distinct
neighbors. A deterministic bounded search selected block `2`, twist `1` as a
collision case: its weight-2 source yields four braid images that all map to
one quotient neighbor. GAP records that the collision source is non-generating;
it exercises the coordinate layer but is not a production BFS vertex.

For every image, GAP exports both the final coordinate and the rows it used at
each lookup layer:

- target-pair normalization;
- class-specific right-pair transport;
- macroblock segment arithmetic;
- relative double-coset index;
- pair-twist refinement and weight.

C++ applies its packed degree-23 braid kernel and derives the destination from
those tables. A separate exact moved-tuple dictionary is retained only as an
independent fixture oracle. Regeneration is byte-compared with the checked-in
fixtures before either native test is accepted.

## Result

Both fixtures pass exactly. The seed case reproduces all 22 ordered neighbors.
The collision case reproduces GAP's four-to-one first-seen deduplication. C++
also checks product one, target class order, source weights, and stability when
the source orbit is replayed twice.

The complete global normalization layer is tractable: 318,780 target-pair rows
plus 180,465 right-pair rows, or 45,773,805 raw bytes in the current redundant
fixture layout. Per-block relative maps and refinements are not included in
that estimate and should be built lazily.

## Limitations and next gate

This is a differential micro-checkpoint, not a native production scanner. The
global tables still need a complete immutable binary export, and relative
double-coset maps/refinements need a lazy native construction path. No runtime
projection is made until that end-to-end implementation is measured without
production workers and its certificates pass independent GAP replay.
A naturally colliding generating vertex would strengthen the production-path
coverage beyond the current non-generating coordinate regression.

## Reproduction

```bash
make check-native-kernel
```

The permanent artifacts are:

- `data/reference/native_coordinate_fixture.tsv`
- `data/reference/native_coordinate_collision_fixture.tsv`
- `data/reference/native_4a_coordinate_table_census.tsv`
- `scripts/gap/generate_native_coordinate_fixture.g`
- `scripts/gap/find_native_coordinate_collision.g`
- `tests/native/test_m23_coordinate_fixture.cpp`
