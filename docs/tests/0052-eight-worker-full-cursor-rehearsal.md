# Test 0052: eight-worker full-cursor rehearsal

## Question

Does doubling the compact `5A` cursor from four to eight deterministic scan
shards improve production throughput without creating SQLite or memory
pressure? Can the resumed ledger still pass exact prefix/final replay and the
production-default independent GAP audit?

## Inputs and provenance

- clean launch revision `ef61acef64a405b9c0a47cc959571e80dfe48ebc`;
- the same native coordinate, generation-mask, GAP pair-checkpoint, 30,400
  proof/walk cutoff, and `native-v1` convention as test 0051;
- a fresh eight-shard compact plan with SHA-256
  `de47950d607f6c0a259490a61d9a4e96884393f509febb0f3e79d04f8e0eced1`;
- eight scan workers and two cost-balanced native replay workers;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3.45.1 on the 24-thread WSL2 host,
  which exposed 32 GiB;
- ignored operational artifacts under
  `runs/5a-full-cursor-rehearsal-8worker-10000-20260717/`.

The run repeated test 0051's two boundaries: a fresh zero-to-2,000 wave,
followed by a resumed 2,000-to-10,000 wave with immutable-prefix replay.

## Result

The first 2,000 blocks scanned in 51 seconds, versus 89 seconds with four
workers, an apparent 1.75-fold speedup. Final replay took 62 seconds. The
boundary contained 3,475 certificates, 1,198,512 vertices, one closed
certificate, 32 overflows, and 3,442 linked certificates.

The resumed 8,000-block interval took 346 seconds, versus 169 seconds in the
four-worker ledger. Its complete 70-second prefix replay overlapped the scan.
Final exact replay took 269 seconds. The final ledger contains 52,183
certificates and 4,620,003 vertices: three closed, 32 overflow, and 52,148
linked certificates. It has SHA-256
`a6a0f2199c9c3580ca6af72833d66e5dd6948780e0a5cc555e64455400577503`
and size 349,310,976 bytes. SQLite integrity, foreign keys, arithmetic shard
ownership, checkpoints, exact replay, and zero-WAL gates all passed.

The raw second-wave comparison is dominated by one deterministic outlier. The
eight-shard cursor reached ordinal 1, the identity-product macroblock, as its
10,000th committed block. That block has 45,344 refined vertices and 28,252
generating vertices. It took 329.599 seconds, emitted 28,012 new certificates,
and found 240 existing owners. The four-shard 10,000-block ledger had not yet
reached ordinal 1. The slow identity block ran concurrently with the other
seven workers, but remained alone on the critical tail after they exited.

Changing the frozen shard count changes the order in which the partial cursor
interleaves sequential and discovered-frontier work. The two 10,000-block
ledgers therefore do not contain the same ordinals or the same component
discovery history. Even excluding ordinal 1, the eight-worker second wave used
1,091.120 aggregate block CPU-seconds, versus 581.679 for the four-worker wave;
it performed about 1.88 times as much measured nonidentity block work. Resource
samples suggest that eight workers delivered roughly 1.5--1.6 times the
aggregate compute throughput of four while the nonidentity workers remained
active, but this normalization is an inference across different workloads,
not a controlled speedup.

Peak process-tree RSS was 3,088,360 KiB in the first wave and 3,765,560 KiB in
the overlapped second wave, versus 1,564,160 and 2,248,584 KiB respectively
with four workers. Available memory never fell below 27,100,988 KiB during the
second wave, and swap-free space was unchanged. Eight scan workers are
therefore comfortably memory-feasible on the current 32-GiB WSL2 allocation.

## Independent GAP result

The balanced production-default audit plan has SHA-256
`96f4e91fb39b7744ef9a8f6bae3a5d9a5fbcfe2e46d6ed427b308d9258995d3c`.
Its estimated four-segment costs were 42,070, 41,972, 42,070, and 41,998 units;
the three closed components were assigned to three different segments. In 368
wall seconds, four independent GAP processes verified:

- all three closed and all 32 overflow certificates;
- 256 systematic linked certificates;
- 140,174 ordered certificate vertices;
- 64 systematic blocks with 103 refined and 93 generating vertices; and
- final ownership for every sampled generating vertex.

The four segments verified 35,062, 34,964, 35,062, and 35,086 certificate
vertices, confirming that the new audit scheduler balanced actual work well.
All mathematical and database checks agreed. Audit peak RSS was 4,837,444 KiB,
available memory remained above 26,150,036 KiB, and swap-free space was
unchanged.

## Verdict and next gate

Passed eight-shard scan/resume, exact prefix/final replay, memory, checkpoint,
zero-WAL, partial arithmetic exhaustiveness, and balanced production-default
independent GAP audit gates. Eight workers are safe in memory and do increase
aggregate CPU utilization, but this experiment cannot choose the production
worker count from raw block wall time because the partial full-cursor workloads
differ sharply.

The next controlled experiment should run the exact same committed 8,000-block
stratified ordinal plan used by the four-worker test 0048 with eight workers.
Holding the ordinal set fixed will isolate parallel scaling and SQLite
contention. The full-cursor shard count should not be frozen until that matched
workload comparison is complete.
