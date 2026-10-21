# Test 0017: sustained 25,000-class frontier

## Question

Does the coverage-throughput advantage of 25,000-class walks persist through
100 processed frontier macroblocks, including dense noncyclic blocks?

## Method

Resume the verified 20-block, proof-limit-2,500, walk-limit-25,000 SQLite run for
80 more blocks with one GAP worker. Measure incremental and total ledger growth,
certificate status, database size, and elapsed event timestamps. Run SQLite
integrity checking and exact certificate-order replay.

Separately replace equal worker quotas with a transactional global target and
repeat the matched 20-block workload with two workers. Require conflict/retry
handling and exact replay.

## Result

- 100 blocks, 240 refined vertices, and 213 generating vertices;
- 47,102 ledger vertices in 114 certificates;
- 110 linked certificates and four overflow certificates;
- 323 seconds for the 80-block extension and about 464 seconds total;
- about 107 incremental and 101.5 total ledger vertices per second;
- roughly 45 percent higher sustained coverage throughput than minimal walks;
- 3.0 MB database; SQLite integrity and exact replay pass;
- replay reconstructs all 47,102 vertices in about 434 seconds;
- balanced two-worker run: one real conflict/retry, identical 12,533-vertex
  result, exact replay, and only a marginal improvement from 141 to 136 seconds.

The 25,000 limit is confirmed as the production pilot setting. Block-level
parallelism is correct but not worthwhile by default at this scale.

## Reproducibility record

- baseline revision: `a1970c4`; implementation is the commit containing this
  note;
- sustained database: `runs/4a-db-walk-limits-20/walk-25000/`;
- balanced worker database: `runs/4a-db-workers2-balanced-25k-pilot/`;
- 4A schema-2 pair checkpoint; proof limit 2,500; walk limit 25,000;
- deterministic nonidentity range and start ordinal 1,633,430.
