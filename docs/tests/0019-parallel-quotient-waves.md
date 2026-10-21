# Test 0019: deterministic parallel quotient waves

## Question

Can deterministic block sharding, transactional online merge, and composable
parallel replay bring complete 4A coverage within a two-week wall-clock budget
without weakening the exhaustiveness certificate?

## Method

Freeze the exactly replayed 10,000-block database. Assign every ordinal to a
virtual shard by `1 + ((ordinal - first) mod shard_count)`, while allowing
physical workers to claim available shard transactions dynamically. Record the
worker and deterministic shard on every committed block.

Run matched four- and eight-worker extensions from the frozen base. After an
exactly audited 1,000-block wave, freeze an 11,000-block base and extend it by
9,000 blocks with eight workers. Verify the larger delta by splitting contiguous
certificate-ID ranges according to recorded traversal weight and partitioning
block reconciliation separately. Compose segment totals and then audit base-row
preservation, deterministic ownership, leases, database integrity, and hashes.

## Result

- fixed four-worker ownership: 1,000 blocks in 209 seconds (4.78/second), with
  a dense final-worker tail;
- dynamic shared claiming: a comparable four-worker wave in 168 seconds
  (5.95/second);
- eight workers from 10,000 to 11,000: 176 seconds (5.68/second), including a
  90-second final lease after block 10,999;
- eight workers from 11,000 to 20,000: 9,000 blocks in 767 seconds, or
  11.73 blocks/second, with only a five-second completion tail;
- 20,000-block ledger: 817,722 vertices and 34,670 certificates;
- the 9,000-block delta added 191,147 vertices in 14,221 certificates, all of
  which linked to prior coverage;
- four-way replay of the 1,000-block delta took 146 seconds versus 447 seconds
  sequentially, a 3.06-fold speedup;
- eight certificate segments plus four block segments replayed and reconciled
  the 9,000-block delta in 748 seconds;
- a matched four-certificate/four-block replay of the same delta took 1,154
  seconds, equivalent to 7.80 verified blocks/second, while remaining
  comfortable in 32 GB alongside the live verifier;
- the 20,000-block audit passed with database SHA-256
  `1e861fd2e752589795a81ce3c728d8b106e4e45c5bed5004a4f7d6e8638a5347`.

The larger scan rate projects to about 7.8 days for all 7,928,184 nonidentity
blocks if sustained. Eight simultaneous replay segments used too much memory
when redundant full verifiers were also present; four replay workers provide
better headroom alongside eight scan workers. The matched four-way rate projects
to about 11.8 days for pipelined scan and verification, inside the proposed
two-week budget. Eight replay workers project near 7.6 days but require
substantially more memory headroom if they overlap all eight scan workers.

## Reproducibility record

- frozen 10,000-block base SHA-256:
  `ac00ff206275edcd628623c020a18f822f6e2e7b35f89806e2572d2bbe457128`;
- frozen 11,000-block base SHA-256:
  `8c078d6a0b7a9ea0bac16b191fd490faa1b576db317c192743064dfa61bdfdb2`;
- deterministic scheduling revision: `86f02b8`;
- dynamic virtual-shard revision: `25af057`;
- chained replay revision: `71eee0b`;
- parallel composition revision: `af96133`;
- operational runs under `runs/4a-db-dynamic8-*`;
- 4A schema-2 pair checkpoint; proof limit 2,500; walk limit 25,000;
- full repository test suite passed after each implementation breakpoint.
