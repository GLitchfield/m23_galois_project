# Test 0049: exact production boundaries and compact full-plan cursors

## Question

Can the native mixed harness hold snapshots to an exact requested prefix,
bound the SQLite WAL lifecycle, and schedule the complete 161,177,452-block 5A
census without materializing one frontier row and one ownership row per block?
Can completion still have an independently checkable exhaustiveness
certificate?

## Implementation

The mixed harness is now two deterministic scan waves. It waits for the first
wave to finish at the snapshot target, runs `wal_checkpoint(TRUNCATE)`, copies
and validates that quiescent database, and only then starts immutable prefix
replay alongside the second scan wave. After the second wave it checkpoints
again before hashing and final replay. The result records the runner revision,
dirty state, active scan time, checkpoint pause, and actual overlap.

The production work plan uses schema `m23-native-full-cursor-plan-v1`. A
canonical descriptor freezes the coordinate-checkpoint hash, macroblock count,
start ordinal, shard count, and ownership rule `ordinal-modulo-v1`, then stores
its SHA-256 in ledger metadata. Worker `s` of `S` owns exactly the ordinals
whose `1 + (ordinal - 1) mod S` equals `s`. Each shard's next/wrapped cursor is
durable metadata already updated in the same claim transaction as its lease;
resume therefore needs no materialized plan table. The configured shard count
is immutable.

The final auditor requires:

- the descriptor hash and all frozen metadata to agree;
- every completed ordinal to lie in `1..N` and have the prescribed shard;
- no live leases and no explicit `planned_work` rows;
- SQLite integrity and foreign keys to pass; and
- for a completion certificate, exactly `N` primary-key-distinct block rows
  and the exact arithmetic count for every shard.

Range membership plus primary-key uniqueness and a count of `N` proves that no
ordinal in `1..N` is missing. The audit is independent of worker cursor state.

## Reproducible gates

The Python regression seeds a ten-block, three-shard compact plan, verifies
zero materialized plan rows, fills every ordinal, and requires the complete
audit with shard counts 4, 3, and 3. The C++ ledger regression claims from the
same metadata-only schema, checks deterministic ownership, and rejects a
worker that changes the frozen shard count.

An operational two-scan/two-replay smoke used a 16-block stratified plan with
the reduced proof/walk limit 100 solely to test lifecycle behavior. Its
snapshot contains exactly the requested four blocks, its final ledger contains
exactly 16, prefix and final replay pass, both checkpoint records report zero
WAL bytes afterward, and both databases pass integrity and foreign-key checks.
The prefix replay overlapped eight seconds of the second scan wave. These
temporary artifacts are not a mathematical runtime sample and are not
committed.

A second operational smoke seeded the real 161,177,452-block census with four
shards and zero scheduling rows. Four native workers each claimed and
completed one ordinal under the compact schema; the post-run audit remained
valid with exact one-per-shard ownership.

## Storage benchmark

`benchmark_native_work_plan_storage.py` inserted the first 1,000,000 ordinals
into both the old `frontier` and `planned_work` tables in one SQLite
transaction. The explicit database occupied 72,749,056 bytes versus 77,824
bytes for the empty compact ledger: 72.671 marginal bytes per ordinal. A
linear full-census projection is 11,712,964,007 bytes (10.9 GiB) and about 562
seconds of up-front insertion on this host. The timing is secondary; avoiding
roughly 12 GB of redundant scheduling state is the material result. The
benchmark script makes the extrapolation assumptions explicit.

## Verdict

Passed exact snapshot-boundary, prefix/final checkpoint, concurrent replay,
compact full-cursor claim, resume-schema, ownership, integrity, and complete
exhaustiveness-audit regression gates. The production ledger now needs space
for mathematical results rather than 161 million predeclared work rows. A
full production launch still requires a separately implemented mathematical
verifier and a deliberate worker/replay allocation.
