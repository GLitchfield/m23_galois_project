# Test 0047: fixed-shard native interruption and replay pilot

## Question

Does the deterministic four-shard 5A work plan survive a real post-certificate
worker exit, resume to the exact planned boundary without shard escape, and
support a complete parallel strict-prefix replay within bounded memory? Can
the immutable replay ranges be balanced by actual stored work rather than by
certificate count alone?

## Inputs and provenance

- implementation baseline: `aa0f8fb`; the replay-balancing implementation and
  this note are in the commit containing this file;
- 800 deterministic blocks, 50 from each of the 16 nonidentity product-class
  strata and exactly 200 assigned to each of four fixed shards;
- work-plan SHA-256
  `1e1b4b1fa1ead37058570841f68d1b7b0712e7b9e1355e55660a2a241bd6c156`;
- native coordinate checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`,
  exported at source revision `cbb8ab95ba90b8bcdf7fb6bbe455ab0672bcd0b1`;
- proof and walk cutoffs 30,400, traversal convention `native-v1`;
- GAP 4.12.1 with AtlasRep 2.1.8, CTblLib 1.3.7, and TransGrp 3.6.5;
  g++ 13.3.0 and SQLite 3.45.1 on the 24-thread WSL2 host;
- ignored operational artifacts under `runs/5a-native-fixed-shards-800/`.

The 325,509,120-byte operational ledger has SHA-256
`ce5459232f79b03a91511cfb5d14c1c0af6870591772db3f3dcf674b5839de3a`.
The large ledger, logs, and machine-local samples remain intentionally
uncommitted.

## Interruption and exact resume

Shard 1 intentionally exited immediately after a durable certificate. The
other three fixed shards completed their 600 assigned blocks in 284 seconds.
The interrupted ledger had 36,232 certificates, no live leases, and no partial
certificate. Restarting all four workers caused only shard 1 to do additional
work; it completed its remaining planned rows in 110 seconds while the other
workers exited cleanly.

The resumed ledger contains exactly 800 blocks and exactly 200 from every
shard, with no unplanned frontier escape and no leases. It contains 45,606
certificates and 4,314,069 ordered certificate vertices. Certificate statuses
are 45,565 linked, 38 overflow, and three closed. SQLite integrity and the
complete strict-prefix replay both pass. Peak sampled aggregate pilot RSS was
1,410,072 KiB; available host memory remained above 29 GiB and swap-free space
did not change.

The artificial pause means the 394 combined scan seconds are a recovery cost,
not a four-worker production-throughput measurement. The result certifies the
fixed ownership and restart boundary that the smaller test 0046 could only
exercise synthetically.

## Replay imbalance and optimization

The original replay harness divided the 45,606 immutable certificate IDs into
four equal-count contiguous ranges. Those ranges held 2,109,366, 913,439,
703,223, and 588,041 vertices, and took 263.170, 172.318, 156.310, and 142.319
seconds respectively. Equal certificate counts were therefore not equal
replay work.

`partition_native_replay.py` now uses the ledger's exact
`discovered_vertices` count plus a measured fixed cost of 96 vertex-equivalents
per certificate. It chooses deterministic, nonempty, contiguous ranges, so
each process retains the same immutable earlier-ID prefix semantics. On this
ledger the four ranges contain certificate IDs 1--6,219, 6,220--17,647,
17,648--31,006, and 31,007--45,606. Their modeled costs differ by only 402 out
of roughly 2.173 million units.

All four cost-balanced ranges replayed exactly in 147.074, 158.014, 156.962,
and 152.091 seconds. The slowest worker improved from 263.170 to 158.014
seconds, a 40-percent reduction. The coefficient is an operational scheduling
parameter, not part of certificate validity; the replay itself still checks
every ordered vertex exactly.

## Verdict and next gate

Passed the fixed-shard, forced-interruption, exact-resume, anti-escape,
bounded-memory, and complete native prefix-replay gates. The cost-balanced
range planner materially improves certification latency without changing any
mathematical output.

The next engineering gate is a longer no-fault mixed scan/replay wave to
measure steady-state throughput and select the production CPU split. A
separately implemented mathematical verifier remains necessary before a
native exhaustive result can be treated as independently certified.
