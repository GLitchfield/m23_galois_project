# Test 0046: deterministic native planned-work shards

## Question

Can a stratified native work plan assign every planned block to a fixed shard
without allowing a faster worker to consume newly discovered frontier blocks
before slower planned shards finish? Can the same ledger still recover a
crashed planned worker transactionally?

## Implementation

The native SQLite schema now includes an append-only `planned_work` table with
plan sequence, block ordinal, shard index, and shard count. The seeder assigns
plan row `i` to `1 + (i mod shard_count)`, records the shard count in metadata,
and validates a fresh empty ledger before inserting either scheduling table.

At worker startup, C++ validates that the recorded plan-row count and every
row's shard count agree with metadata. A worker may claim only its own planned
rows in plan sequence. If that shard has no immediately claimable row while
any planned row remains uncommitted, the worker stops instead of falling
through to discovered frontier or sequential work. This is the planned-work
barrier. Normal frontier scheduling becomes available only after the complete
plan is durable.

`run-native-sqlite-workers.sh` compiles once and launches fixed shard IDs.
`run-native-sqlite-replay-workers.sh` similarly compiles once and partitions an
immutable certificate-ID range among read-only prefix replayers. A plan-only
mode generates arbitrary systematic stratified plans without first executing
the in-memory search.

## Checked regression

The transactional C++ regression seeds two planned blocks on two shards. Both
workers claim the prescribed block. The first block discovers an additional
frontier block and finishes while the second planned block remains leased; the
first shard is then explicitly unable to claim the discovered frontier. Once
the second shard finishes, ordinary frontier scheduling resumes. The existing
durable-certificate/expired-lease recovery and SQLite integrity checks pass on
the same planned ledger.

The Python seeder regression checks exact plan order, fixed `(1,2)` shard
assignment, shard metadata, balanced shard counts, and refusal to modify a
nonfresh ledger. The complete repository `make test` suite passes.

## Wider pilot prepared

An ignored operational plan is staged under
`runs/5a-native-fixed-shards-800/` with:

- 50 deterministic samples in each of 16 nonidentity product-class strata;
- 800 unique planned blocks;
- exactly 200 blocks assigned to each of four shards;
- plan SHA-256
  `1e1b4b1fa1ead37058570841f68d1b7b0712e7b9e1355e55660a2a241bd6c156`;
- a fresh zero-block ledger using the 30,400 proof and walk cutoffs.

The pilot is intentionally queued behind the active 4A replay/scan pipeline so
its throughput and memory measurements are isolated. It will force one shard
to exit after a durable certificate, resume the fixed plan, require exactly the
800 planned ordinals and 200 blocks per shard with no extras, and replay all
certificates through four immutable prefix ranges.

## Verdict

Passed the deterministic planned-work schema, fixed claim, anti-escape barrier,
and transactional recovery regressions. This closes the scheduling-design gap
identified by test 0043. The staged wider interruption/resume/replay
measurement subsequently passed as test 0047. Production readiness still
depends on a sustained no-fault mixed wave and an independently implemented
mathematical audit policy.
