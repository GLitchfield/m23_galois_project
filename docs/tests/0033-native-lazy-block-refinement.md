# Test 0033: native lazy block refinement

## Question

Can C++ reconstruct one non-identity macroblock's exact key-v2 relative
double-coset partition and pair-twist refinement using only the compact global
coordinate checkpoint, without GAP or a precomputed per-block table?

## Inputs and provenance

- implementation: the commit containing this note;
- 4A pair checkpoint SHA-256
  `add26b95401d74fbaf29167782667080275d848b8cddabceecef40c2051c75c4`;
- 5A pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- 5A global checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- GAP 4.12.1 and g++ 13.3.0.

The global binary is an operational artifact under `runs/`, not a committed
result. `make check-native-kernel` regenerates the 4A differential input from
the committed GAP code and pair checkpoint.

## Method

For a requested block, C++ decodes its product class and left/right pair IDs
from the symbolic segment. A free right-pair orbit exposes every element of the
small product centralizer. C++ filters the left and right pair stabilizers,
partitions the centralizer into `S_right \\ C(product) / S_left`, chooses the
least degree-23 permutation in every double coset, and numbers those minima in
increasing order exactly as GAP key-v2 does.

One canonical tuple is materialized for each relative class. The existing
native pure-braid and coordinate-normalization kernels compute beta12 and
beta34 on these classes. Beta12 cycles define pair-twist vertices; beta34 is
required not to enlarge them. The result is returned as disposable relative
and refinement rows for one block, so memory does not scale with the 161
million-block 5A census.

Native twist IDs use a new stable convention: orbits are ordered by their least
key-v2 relative index. GAP's historical twist numbers inherit an internal
double-coset representative order. Tests therefore require exact relative
indices, exact orbit membership and weight, and exact translated neighbors;
they do not pretend the two arbitrary numeric labels are interchangeable.

## Differential result

The generating production fixture reconstructed all destination block tables
natively and reproduced its 22 GAP neighbors after the stable-ID translation.
The collision fixture reconstructed the same 179th relative coordinate and
collapsed four beta13/beta14 images to the same single quotient neighbor of
weight two. Every GAP-exposed relative index and orbit weight agreed.

The complete 131,381,583-byte 5A global checkpoint then reconstructed the
first block of all 16 non-identity product classes. The structural check built
3,089 relative rows and 3,089 refinement rows, verified product-one
representatives, complete centralizer partitions, beta12 cycles, and the beta34
non-enlargement condition. Including C++ compilation, full checkpoint load,
hash-index construction, and those 16 refinements took 7.19 wall seconds and
324,640 KiB maximum RSS while the eight-worker 4A scan remained active.

Reproduce the full 5A structural check with:

```bash
scripts/check-native-coordinate-checkpoint.sh \
  runs/5a-coordinate-tables-cbb8ab9.bin
```

## Limits and next gate

Test 0037 subsequently adds the identity-product coordinate without changing
this non-identity builder. The production scanner still runs in GAP: this test
does not measure a sustained native block census, and native IDs cannot be
appended to an existing GAP ledger.

The next gate is a small fresh-ledger native quotient walk whose vertices and
certificates are independently replayed in GAP by orbit membership.

## Verdict

Passed the native key-v2 relative-map, stable pair-twist partition,
differential-neighbor, collision, and all-non-identity-5A-class structural
gates.
