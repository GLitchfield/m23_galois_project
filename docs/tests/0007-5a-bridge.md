# Test 0007: the `(5A,5A,2A,2A)` bridge

## Question

Does the certified sharded engine reproduce Häfner's 30,400-class 5A bridge,
including the complete pure and symmetric braid actions and genera?

## Method

Run 16 invariant centralizer-orbit shards with four local workers. The deep
verifier independently repeats the full assigned-pair enumeration, quotient,
and generation filter. The merger uses the saved representatives to construct
all five braid/symmetry permutations.

During the first merge, generic `RepresentativeAction` calls dominated runtime.
For these fixed-first formulas the conjugator is already explicit: each pure
move records the element that conjugated the first coordinate, `beta4` leaves it
fixed, and `eta34` is normalized by the original fourth coordinate. Replacing
generic transporter searches with those exact conjugators reduced the complete
30,400-class merge to about 27 seconds while preserving the 4A regression.

Run the full reproduction with:

```sh
make check-5a-bridge
```

## Result

- 16 shards and 255 centralizer-orbits covered exactly once;
- all 3,795 involutions assigned;
- 1,258,595 product-one fixed-first tuples;
- 83,919 product-one inner classes;
- 30,400 generating inner Nielsen classes;
- one pure orbit of size 30,400 and genus 5,223;
- one symmetric orbit of size 30,400 and genus 2,071;
- complete cycle shapes recorded for all five actions;
- deep certificate verified all 30,400 saved representatives and independently
  reproduced every shard count.

The count, orbit sizes, and both genera match the table reported in Häfner's
2022 preprint exactly.

## Artifacts

- `data/derived/m23_5a_5a_2a_2a_sharded_certificate.tsv`
- `data/derived/m23_5a_5a_2a_2a_sharded_orbit.tsv`
- operational checkpoints and their manifest under ignored `runs/5a-bridge/`
