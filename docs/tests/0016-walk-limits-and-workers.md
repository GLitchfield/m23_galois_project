# Test 0016: walk limits and worker leases

## Question

Which coverage-walk limit grows reusable certified coverage fastest at proof
bound 2,500, and can multiple block workers safely improve throughput?

## Method

Run matched 20-block database frontier scans from ordinal 1,633,430 with walk
limits 2,500, 10,000, and 25,000. Compare ledger vertices per elapsed second,
certificate status, coverage, and database size.

Add renewable SQLite block leases, automatic expired-lease reclamation, and an
atomic `try-add` transaction. On a vertex conflict, discard the stale proposed
certificate and rerun the seed against the now-current ledger. Prevent workers
from taking new ordinal seeds while another live worker is constructing a
frontier. Run two real GAP processes with equal ten-block budgets and replay the
shared result exactly.

## Result

- walk 2,500: 2,796 vertices in 41 seconds (68.2/sec), 11 overflow;
- walk 10,000: 7,698 in 106 seconds (72.6/sec), 5 overflow and 6 linked;
- walk 25,000: 12,533 in 141 seconds (88.9/sec), 3 overflow and 8 linked;
- two-worker 25,000 run: identical mathematical state in about 150 seconds;
- shared database integrity and exact 11-certificate replay pass;
- lease restart, expiry, and conflict/retry behavior pass unit tests.

The 25,000 limit wins this sample. Equal block-level parallelism does not: dense
walks dominate while another worker consumes cheap covered blocks. The safe
lease implementation is retained for later cost-aware scheduling.

## Reproducibility record

- baseline revision: `65042d0`; implementation is the commit containing this
  note;
- matched runs: `runs/4a-db-walk-limits-20/`;
- worker run: `runs/4a-db-workers2-25k-pilot/`;
- summary command: `scripts/summarize_db_walk_limits.py`;
- worker command: `scripts/run-db-quotient-workers.sh`.
