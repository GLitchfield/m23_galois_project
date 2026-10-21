# Test 0022: transactional pipeline recovery

## Question

Does a pipelined quotient wave recover without lost or duplicated coverage when
the operating system kills every scan worker and every certificate replay
worker under memory pressure?

## Method

Freeze the completed 150,000-block candidate relative to the verified
100,000-block base. Start four certificate replay segments, four block
reconciliation segments, and eight speculative scan workers targeting 200,000
blocks. An overlapping full regression suite unintentionally exhausts memory;
the kernel kills all eight scan workers and all four certificate replay workers.

Retain the immutable candidate and the transactional live ledger. Restart the
same replay plan from the candidate and restart eight dynamic workers against
the live ledger. Require exact replay and audit before promoting 150,000, and
require the resumed live ledger to reach exactly 200,000 with no leases and a
passing SQLite integrity check.

## Result

- the live ledger retained 151,572 committed blocks at restart;
- all eight scan workers resumed through the lease protocol and reached exactly
  200,000 blocks without manual database repair;
- the completed live ledger contains 2,254,107 vertices in 253,831
  certificates, has zero leases, and passes SQLite `quick_check`;
- restarted replay verifies the 100,000-to-150,000 delta exactly;
- the promoted 150,000-block base contains 1,984,032 vertices in 197,992
  certificates;
- its delta contains 317,899 vertices in 57,808 certificates, all linked and
  with no new closed or overflow certificate;
- its 50,000 blocks contain 134,582 refined vertices, 112,947 generating
  vertices, and 55,139 ledger hits;
- base preservation, deterministic ownership, segment composition, exact
  replay, database hash, and immutable snapshot creation all pass.

The recovery validates the durability design under a stronger interruption
than an ordinary graceful stop. The observed 11,783-second 150,000-to-200,000
wall interval includes the memory failure, restart, and competing regression
work, so its 4.243 blocks/second is not used as a clean throughput benchmark.
The incident also establishes an operational constraint: the 32 GB production
pipeline must not overlap the memory-heavy full regression suite.

## Reproducibility record

- prior 100,000-block base SHA-256:
  `fb9fd0f70c09e304adef331569c3780a019721135261f210f90ce184f8edf414`;
- promoted 150,000-block base SHA-256:
  `0a71fe882568dffbf615fe9107b1913cd76b5166c069096b506ac276f4df125d`;
- frozen candidate: `runs/4a-db-candidate-150000/`;
- immutable base: `runs/4a-db-base-150000/`;
- recovered live ledger: `runs/4a-db-pipeline-live/`;
- recovery terminal output: unified execution session recorded on 2026-07-12;
- 4A schema-2 pair checkpoint; proof limit 2,500; walk limit 25,000;
- deterministic nonidentity range 2 through 7,928,185.
