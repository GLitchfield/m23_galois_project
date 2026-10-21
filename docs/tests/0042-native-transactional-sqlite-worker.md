# Test 0042: native transactional SQLite worker

## Question

Can native 5A workers replace the in-memory ownership map with direct indexed
SQLite reads, commit certificates atomically under contention, resume the same
deterministic shards, and recover if a process exits after committing a
certificate but before completing its leased block?

## Design and provenance

- implementation: the commit containing this note;
- database schema: the existing quotient-ledger schema used by Python and GAP,
  with traversal convention `native-v1`;
- 5A coordinate source SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- coordinate checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- generation-mask checkpoint SHA-256
  `0e39a410106cb5f18dc6f8fca24b702109e4614a35345a3200e2edd519b1fe7b`;
- proof and walk cutoff 30,400;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3 on the 24-thread, 32 GiB WSL2
  host.

`src/native/m23_native_sqlite.*` opens or validates the shared WAL ledger. A
worker claims only blocks in its fixed modular shard. Ownership lookup is a
primary-key query. Before inserting a certificate it acquires the writer lock
with `BEGIN IMMEDIATE`, validates its unexpired block lease, and rechecks every
proposed vertex. Any overlap rolls back the whole certificate; otherwise the
certificate, ownership rows, ordered replay rows, and frontier rows commit
together.

Block completion is a separate atomic transaction. A process exit can leave a
durable certificate and an expiring lease, but never a partial certificate. A
replacement reclaims the block, observes the committed owners, and completes
its accounting.

The checked-in synthetic regression runs with:

```bash
make check-native-sqlite-ledger
```

It checks two disjoint deterministic shard claims, atomic rejection of an
overlapping second certificate, an exit between certificate and block commit,
expired-lease reclamation, final counts, `quick_check`, and foreign keys.

## Exact known-component gate

A fresh one-worker ledger at block 71,532,995 committed the known component in
1.326 seconds of block work. Including checkpoint loading, the process used
2.50 wall seconds and 421,108 KiB peak RSS. The result has one block, one
certificate, and 5,498 vertices. Certificate order, checked count, weighted
30,400-class size, status, and every native block/twist ID agree with the
independent GAP fixture.

The operational database remains under `runs/` and is not committed.

## Two-worker and resume gate

Two fixed shards first committed four blocks in 2.55 wall seconds. Their shared
ledger had three certificates and 11,609 vertices; the known component was
certificate 3 and again matched the complete ordered GAP fixture.

The same database then resumed to 20 blocks in 3.22 seconds, ending with 23
certificates and 56,932 vertices. A second resume from 20 to 100 blocks took
5.08 seconds and ended with:

- 100 completed blocks, exactly 50 in each deterministic shard;
- 106 certificates and 140,773 uniquely owned vertices;
- zero leases;
- 9,990,144 logical database bytes;
- `quick_check = ok` and no foreign-key violations;
- approximately 380 MiB RSS per worker, about 0.75 GiB aggregate.

This workload is frontier-heavy and contains many immediate ledger hits. Its
roughly 15.7 incremental blocks/second is evidence that live FULL-synchronous
SQLite transactions are viable, not a new whole-search extrapolation.

## Real forced-exit gate

The worker has an explicit test hook,
`M23_NATIVE_EXIT_AFTER_CERTIFICATE=1`, which calls `_Exit(86)` immediately
after its first successful durable certificate commit. On the real known block
the interrupted state was exactly:

```text
blocks=0 certificates=1 vertices=5498 leases=1
```

After expiring that lease and starting a replacement, the final state was:

```text
blocks=1 certificates=1 vertices=5498 leases=0
```

The replacement reported both generating seeds as ledger hits and did not
duplicate the component. The surviving certificate still matched the complete
GAP fixture, and both SQLite integrity checks passed.

## Limits and verdict

Passed the live ownership, atomic overlap, deterministic shard, real resume,
and crash-recovery gates. This removes the projected 256-million-key in-memory
ownership map as a production blocker.

It is not yet an exhaustiveness result. Only the known certificate in the
100-block database has independent GAP replay; the other 105 are performance
and structural evidence. Certificate ownership between shards is serialized
correctly but may depend on commit order, so a candidate must record that
order and undergo exact replay. Test 0043 subsequently passes a wider
class-stratified live SQLite census with four workers and resource sampling.
Prefix-aware replay of that parallel certificate order remains open.
