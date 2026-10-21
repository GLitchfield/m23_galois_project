# Test 0044: native prefix certificate replay

## Question

Can every certificate produced by the concurrent native SQLite workers be
recomputed against exactly the ownership prefix that existed when its database
ID was committed? Do status, linkage, walk accounting, and the ordered native
vertex sequence all agree?

## Implementation

`m23_native_sqlite_replay.cpp` opens a completed ledger read-only and validates
its schema, coordinate convention, target order, macroblock count, proof/walk
limits, and source-checkpoint hash. For certificate ID `i`, its prepared
ownership query returns a vertex owner only when that owner's certificate ID is
strictly less than `i`. It then reruns the bounded native braid walk from the
stored seed and compares:

- certificate status and raw walk status;
- linked certificate ID, including the strict earlier-ID condition;
- checked-vertex and discovered-class counts;
- every discovered `(block ordinal, twist ID)` in exact traversal order.

The reader has a synthetic checked-in regression for metadata, certificate
rows, ordered vertices, and the strict prefix boundary. Reproduce an
operational replay with:

```bash
./scripts/run-native-sqlite-replay.sh COORDINATES.bin LEDGER.sqlite3
```

Optional first/last certificate arguments make the immutable replay range
deterministically shardable.

## Inputs and provenance

- implementation: the commit containing this note;
- four-worker live ledger from test 0043, SHA-256
  `4c7c2929a0c233bd202377b60fdee75cd1084484aec6a279c67a399bc53f69b5`;
- native coordinate checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- source stratified work-plan SHA-256
  `3c5de4f92446f50baffc8db61c5456e4e36e8a9c9bf31c30751efb86b0eff6f6`;
- 3,657 certificates and 1,180,560 ownership rows produced by four concurrent
  FULL-synchronous SQLite workers;
- g++ 13.3.0 and SQLite 3 on the 24-thread, 32 GiB WSL2 host;
- the four-worker GAP replay of the active 4A candidate remained active.

The ignored operational transcript and `/usr/bin/time -v` record are under
`runs/5a-native-sqlite-stratified-4worker/replay/`.

## Result

All 3,657 certificates replayed exactly, including all 1,180,560 ordered
vertices. The replay kernel took 133.346 wall seconds. The wrapper, including
an optimized compilation, took 140.76 wall seconds at 99 percent of one CPU,
376,804 KiB maximum RSS, zero major page faults, and zero swaps. Standard error
was empty and the process exited zero.

The replay passed the concurrency-sensitive decomposition from test 0043, not
only the sequential ledger that already matched the imported transcript. This
closes the native prefix-history gate: commit-order-dependent ownership is
reproducible from the immutable ledger.

Linear scaling from 1.18 million to roughly 256 million owners is about eight
hours on one replay core. Since recorded certificate ranges are immutable and
prefix lookup is read-only, several replay ranges can run concurrently; this
must be measured before assigning a production replay estimate.

## Verdict and limits

Passed exact complete native replay of the four-worker pilot. The next
engineering gate is a deterministic planned-work shard table followed by a
wider scan/replay interruption pilot.

This is a strong persistence, concurrency, and deterministic-kernel check, but
it is not an independent mathematical implementation: scanning and replay use
the same native coordinate and braid kernel. Production certification still
requires GAP translation or a separately implemented verifier, at minimum on
all exceptional components and a deterministic audit sample.
