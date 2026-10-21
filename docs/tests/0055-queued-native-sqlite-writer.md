# Test 0055: queued native SQLite certificate writer

## Question

Can one application-serialized, transaction-batching certificate writer remove
the shared SQLite contention measured in test 0053 without changing the exact
bounded-search certificate semantics?

## Implementation and inputs

- implementation: the commit containing this note;
- operational launch base revision
  `96bd6027b4914ae35dfd2bb6db7f94d7825fd52c`, with the expected dirty flag
  because the queued implementation was under test;
- the same deterministic 80-block plan in every matched run, SHA-256
  `2c1e78a2b2939dd025680953e2f61a2dbc63cf4180f93276c59209113f216447`;
- native coordinate checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- proof and walk cutoff 30,400, snapshot boundary 20, and two replay workers;
- four or eight scan workers, with queued batches capped at 8 or 16;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3.45.1; and
- ignored operational artifacts under `runs/5a-writer-*-80-20260720/`.

The batch primitive resolves requests in input order within one `BEGIN
IMMEDIATE` transaction. Later requests therefore see owners accepted earlier
in the same batch. Workers retain independent read-only ownership connections
and private disposable coordinate caches, while certificate writes pass
through one in-process queue. Claims, lease renewals, and block completion use
the same application mutex as the writer.

## Correctness result

The four matched direct/queued ledgers all completed 80 planned blocks, exact
snapshot replay, exact final strict-prefix replay, `quick_check`, foreign-key
checks, and zero final leases. Concurrent request order changes certificate
counts and total owned vertices, as it does for the existing direct workers.

All four ledgers nevertheless contain the same two closed components of size
6,826. Sorting each component's `(ordinal,twist)` keys gives the same SHA-256
values in every run:

- `1172873ae0533a508192118f594783cdcba593aac79d492f3a53a5245d0a8903`;
- `124bb6d65e3999dee8490a5a6698488937356fd3d499437e3bb26c4bbe0b64ef`.

The committed native ledger regression also verifies that a two-request batch
accepts its first non-overlapping certificate and rejects the second request
when it overlaps the newly accepted owner.

## Performance result

| writer | workers | scan wall seconds | block CPU seconds | class-2 mean seconds | peak RSS KiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| direct | 4 | 57 | 146.493 | 23.540 | 1,981,512 |
| queued, no wait | 4 | 63 | 160.831 | 26.214 | 1,189,252 |
| direct | 8 | 54 | 156.466 | 23.749 | 3,753,144 |
| queued, no wait | 8 | 58 | 166.962 | 26.125 | 2,153,328 |

At four workers, the queued path is 10.5 percent slower; at eight workers it
is 7.4 percent slower. It substantially reduces aggregate RSS because the
threads share the immutable checkpoint, but it does not improve verified scan
throughput. The four-worker second wave naturally grouped 3,635 requests into
3,222 transactions, with maximum batch 3. The eight-worker wave used 3,153
transactions and maximum batch 5.

A preliminary 2-millisecond accumulation window produced larger batches but
made the four-worker scan still slower at 67 seconds. The default is therefore
zero deliberate wait: a request may join a batch only if it accumulates while
the writer is already occupied.

## Verdict

Passed the correctness and implementation gates but failed the performance
gate. The design was not selected, and the optional queued mode is kept only
as a reproducible negative experiment and a lower-memory diagnostic. This was
the last native-ledger experiment; the exhaustive 5A search was not run.
