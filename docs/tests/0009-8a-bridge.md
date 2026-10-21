# Test 0009: the `(8A,8A,2A,2A)` bridge

## Question

Does the certified engine reproduce Häfner's 198,488-class 8A bridge and its
complete pure and symmetric braid actions?

## Method

Run 64 invariant centralizer-orbit shards with eight local workers, then perform
the independent deep recount and direct-normalized merge. Monitor and resume the
operational run with `scripts/manage-cc2a2a-run.sh` as described in
`docs/sharded-engine.md`.

Run a complete clean reproduction with:

```sh
make check-8a-bridge
```

## Result

- 64 shards and 489 centralizer-orbits covered exactly once;
- all 3,795 involutions assigned;
- 1,827,193 product-one fixed-first tuples;
- 228,589 product-one inner classes;
- 198,488 generating inner Nielsen classes;
- one pure orbit of size 198,488 and genus 41,277;
- one symmetric orbit of size 198,488 and genus 16,617;
- complete cycle shapes recorded for all five actions;
- all 198,488 representatives and every shard count independently reverified.

The count, orbit sizes, and both genera match Häfner exactly. Certification and
merge from the completed checkpoints took 38m52s on the current machine: the
deep recount completed after 34m48s and merge took 4m04s. Shard production was
interrupted and resumed while the monitoring harness was developed, so no clean
wall-clock time is claimed for that phase.

## Reproducibility record

- shard engine revision: `388df6a`;
- verification, merge, and monitoring revision: `dc262d1`;
- GAP 4.12.1, AtlasRep 2.1.8, CTblLib 1.3.7;
- inputs: M23's natural degree-23 action, class order 8, involution class 2A,
  64 deterministic centralizer-orbit shards;
- provenance: locally generated checkpoints under ignored `runs/8a-bridge/`,
  followed by the committed independent certificate and merged result below.

## Artifacts

- `data/derived/m23_8a_8a_2a_2a_sharded_certificate.tsv`
- `data/derived/m23_8a_8a_2a_2a_sharded_orbit.tsv`
- operational checkpoints and manifest under ignored `runs/8a-bridge/`
