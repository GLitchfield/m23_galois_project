# Test 0008: the `(6A,6A,2A,2A)` bridge

## Question

Does the certified engine reproduce Häfner's 72,528-class 6A bridge and its
complete pure and symmetric braid actions?

## Method

Run 32 invariant centralizer-orbit shards with four local workers, then perform
the independent deep recount and direct-normalized merge. The higher shard count
keeps checkpoint sizes and worker candidate sets balanced as the number of
generating classes grows.

Run the full reproduction with:

```sh
make check-6a-bridge
```

## Result

- 32 shards and 345 centralizer-orbits covered exactly once;
- all 3,795 involutions assigned;
- 1,221,743 product-one fixed-first tuples;
- 102,465 product-one inner classes;
- 72,528 generating inner Nielsen classes;
- one pure orbit of size 72,528 and genus 15,125;
- one symmetric orbit of size 72,528 and genus 6,065;
- complete cycle shapes recorded for all five actions;
- all 72,528 representatives and every shard count independently reverified.

The count, orbit sizes, and both genera match Häfner exactly. The complete
certified run took 6m43s on the current machine, including shard production,
deep recount, and merge.

## Artifacts

- `data/derived/m23_6a_6a_2a_2a_sharded_certificate.tsv`
- `data/derived/m23_6a_6a_2a_2a_sharded_orbit.tsv`
- operational checkpoints and manifest under ignored `runs/6a-bridge/`
