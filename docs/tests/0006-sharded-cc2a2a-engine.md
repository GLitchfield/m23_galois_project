# Test 0006: sharded `(C,C,2A,2A)` engine

## Question

Can the fixed-first enumeration be partitioned into independently valid,
resumable shards and merged without changing the complete 4A braid action?

## Method

Partition the 144 orbits of `C_M23(s1)` on the involution class into four
deterministically balanced shards. Enumerate each shard independently and save
one representative per generating inner class in a GAP-readable checkpoint.

An independent verification pass checks exact assignment coverage, tuple
classes, product-one, generation, centralizer-orbit size, and global uniqueness.
It then independently repeats the full assigned-pair enumeration and quotient,
checking every shard's product and generating counts against the checkpoint.
The merger then rebuilds the complete class dictionary and braid action without
using the monolithic artifact. A Python comparison checks every count, orbit
size, genus, and generator cycle shape against test 0005.

Finally, invoke the same run again. It must retain all four checkpoints and
produce byte-identical certificate and result files.

Run:

```sh
make check-sharded-engine
```

## Result

- 4 shard indices covered exactly once;
- all 144 centralizer-orbits covered exactly once;
- balanced assignments covered all 3,795 involutions;
- shard totals recovered 609,553 product tuples and 19,609 product inner classes;
- 2,456 independently verified generating representatives were globally unique;
- merge recovered one pure orbit of size 2,456 and genera 447/169;
- all five generator cycle shapes matched the monolithic computation;
- a second invocation reused all four checkpoints and reproduced identical files.

A separate order-5 smoke shard (`1/16`) also completed successfully, exercising
the generalized exact-order filter beyond the 4A regression.

## Artifacts

- `data/derived/m23_4a_sharded_certificate.tsv`
- `data/derived/m23_4a_sharded_orbit.tsv`
- operational checkpoint files under ignored `runs/`
