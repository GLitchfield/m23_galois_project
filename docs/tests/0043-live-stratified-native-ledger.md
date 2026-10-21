# Test 0043: live stratified native ledger

## Question

What end-to-end scan time, SQLite cost, memory footprint, and concurrency gain
are observed when the exact 80-block stratified 5A plan is processed through
the live transactional native ledger rather than an in-memory ownership map?
Does a one-worker live database agree row-for-row with the independently
imported transcript from test 0040?

## Inputs and provenance

- implementation: the commit containing this note;
- stratified transcript/work-plan SHA-256
  `3c5de4f92446f50baffc8db61c5456e4e36e8a9c9bf31c30751efb86b0eff6f6`;
- 80 deterministic midpoint blocks: five in each of 16 nonidentity
  product-class segments;
- coordinate source/checkpoints, generation masks, and 30,400 cutoffs as in
  tests 0040 and 0042;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3 on the 24-thread, 32 GiB WSL2 host;
- the eight-worker read-only 4A candidate replay remained active.

`seed_native_stratified_frontier.py` streams only the transcript's `S` rows,
validates source and macroblock metadata, requires a completely fresh ledger,
records the plan hash, and inserts the 80 ordinals before any discovered
frontiers. Its checked-in regression verifies ordering, metadata, and refusal
to seed a nonfresh database.

## Sequential live result

One live SQLite worker completed the plan in 152.50 wall seconds at 413,524
KiB peak RSS. It produced exactly the same aggregate counts as test 0040's
in-memory run:

- 80 blocks;
- 7,150 refined and 3,743 generating seeds;
- 3,658 certificates and 85 ledger hits;
- 1,174,738 unique ownership rows;
- zero leases and clean SQLite integrity checks.

The in-memory run took 109.62 wall seconds, so FULL-synchronous certificate and
block commits add about 39 percent in this sample.

Importing the original transcript into a separate SQLite database took 42.29
seconds and 221,348 KiB peak RSS. `compare_native_ledgers.py` then compared both
directions with SQL `EXCEPT`. There were zero differences across:

- every certificate field and ID;
- all ownership rows;
- every ordered certificate vertex;
- every block sequence, ordinal, refinement/generation count, certificate
  count, and ledger-hit count.

Both databases also passed `quick_check` and foreign-key checks. This is an
exact 1.17-million-row persistence-path differential, not only an aggregate
comparison. Reproduce the final comparison with:

```bash
python3 scripts/compare_native_ledgers.py LIVE.sqlite3 IMPORTED.sqlite3
```

## Four-worker live result

Four workers shared the preseeded global work plan and completed all 80 planned
ordinals with no extras in 65.16 wall seconds, a 2.34-fold speedup over the
one-worker live run. Because this pilot used one global planned frontier, its
worker assignment was dynamic (19, 17, 21, and 23 blocks), not a production
deterministic-shard schedule.

The block mathematics again matched exactly: 7,150 refined and 3,743 generating
seeds. Concurrent commit order changed component ownership decomposition, as
expected:

- 3,657 certificates and 86 ledger hits;
- 3,622 linked, 33 overflow, and 2 closed certificates;
- 1,180,560 unique owners;
- zero leases;
- 87,539,712 logical database bytes;
- WAL mode with FULL synchronous commits;
- `quick_check = ok` and no foreign-key violations.

The sequential decomposition was 3,624 linked, 32 overflow, and 2 closed
certificates with 5,822 fewer owners. Atomic overlap checks make both ledgers
valid, but parallel ownership depends on recorded commit order and therefore
requires prefix-aware replay.

Peak per-worker RSS was 382,492, 414,196, 408,764, and 381,916 KiB. Peak
aggregate worker RSS was 1,586,528 KiB (about 1.51 GiB). Available system
memory never fell below 28,197,348 KiB and swap remained unused by the pilot.

## Runtime and storage interpretation

Applying the measured 39-percent live-commit overhead and 2.34-fold
four-worker speedup to test 0040's systematic model gives a scan-only range of
about 14.6--18.8 hours, centered near 16.5 hours. The current operational
estimate is therefore 15--20 hours for a four-worker native scan on this host.
This excludes independent replay, interruption allowance, final audit, and the
exceptional identity block.

The live database used about 74 bytes per owned vertex including indexes and
certificate tables. Linear projection to roughly 256 million owners is about
19 GB decimal before WAL headroom and operational snapshots. Disk, like RAM,
does not presently appear to be the limiting resource.

## Verdict and next gate

Passed the exact work-plan, sequential persistence differential, four-worker
live-contention, memory, and revised scan-runtime gates. The earlier 12--24
hour engineering target is now narrowed to 15--20 scan hours by an end-to-end
live sample.

This remains computational engineering, not a new M23 result. The parallel
3,657-certificate decomposition was subsequently reproduced exactly by the
native strict-prefix replayer in test 0044. Before a production launch, add a
deterministic planned-work shard table rather than dynamic worker assignment
was required. Test 0046 subsequently implements and regression-tests that
fixed-shard table and barrier; its wider interruption and snapshot pilot
remains. GAP translation or a
separately implemented verifier is still required for genuinely independent
mathematical certification.
