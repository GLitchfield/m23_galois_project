# Test 0021: pipelined candidate handoff

## Question

Can a completed live ledger be frozen and independently verified against the
previous immutable base while the writable ledger speculatively advances to the
next boundary, then be promoted without losing the speculative work?

## Method

Start from the audited 50,000-block base. Scan the writable ledger to 100,000
blocks with eight physical workers and eight deterministic virtual shards.
Create an online, read-only candidate snapshot at exactly 100,000 blocks. Replay
its 50,000-block delta in four certificate and four block segments against the
50,000-block base while the writable ledger continues to 150,000 blocks.

Compose the replay totals and audit base preservation, deterministic ownership,
leases, SQLite integrity, and the final database hash. Promote the candidate to
an immutable 100,000-block base only after that audit succeeds, then retarget
the completed live ledger so its next verification delta is relative to the new
base.

## Result

- the 50,000-to-100,000 scan took 5,149 seconds, or 9.711 blocks/second;
- parallel replay took 3,545 seconds, or 14.104 verified blocks/second;
- the promoted 100,000-block base contains 1,666,133 vertices in 140,184
  certificates;
- the delta contains 428,852 vertices in 62,246 certificates, all linked and
  with no new closed or overflow certificate;
- its 50,000 blocks contain 139,135 refined vertices, 116,386 generating
  vertices, and 54,140 ledger hits;
- exact replay, segment composition, base preservation, deterministic shard
  ownership, zero leases, and SQLite integrity all pass;
- the writable ledger simultaneously reached 150,000 blocks in 6,875 seconds,
  or 7.273 blocks/second, with 1,984,032 vertices and 197,992 certificates;
- the completed 150,000-block ledger was retargeted relative to the verified
  100,000-block base without rescanning its speculative delta.

The experiment validates the candidate-snapshot pipeline. Verification finished
well before the speculative scan, so it did not accumulate a backlog. The
slower 100,000-to-150,000 scan overlapped replay and additional regression
workloads; its 7.273 blocks/second is therefore retained as a conservative
observed rate rather than attributed to a single cause.

## Reproducibility record

- prior 50,000-block base SHA-256:
  `864baeee5c24d35c4d077d29c756c2555d5bb558f8d16e874c1b815ca2396b6d`;
- promoted 100,000-block base SHA-256:
  `fb9fd0f70c09e304adef331569c3780a019721135261f210f90ce184f8edf414`;
- frozen 150,000-block candidate SHA-256:
  `0a71fe882568dffbf615fe9107b1913cd76b5166c069096b506ac276f4df125d`;
- pipeline implementation revision: `562a17c`;
- 100,000-block candidate: `runs/4a-db-candidate-100000/`;
- immutable base: `runs/4a-db-base-100000/`;
- live ledger at the handoff: `runs/4a-db-pipeline-live/`;
- 4A schema-2 pair checkpoint; proof limit 2,500; walk limit 25,000;
- deterministic nonidentity range 2 through 7,928,185.
