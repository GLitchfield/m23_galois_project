# Test 0053: matched-ordinal eight-worker native wave

## Question

Does increasing the native `5A` scanner from four to eight workers improve
end-to-end throughput when the mathematical workload is held exactly fixed?
Where does additional concurrency help, and where does shared SQLite
persistence prevent scaling?

## Inputs and provenance

- clean launch revision `2915180a886486116ca859243741cd361ee6f5a3`;
- the exact 8,000 deterministic nonidentity ordinals from test 0048, 500 from
  each of 16 product-class strata;
- work-plan SHA-256
  `987f0eb5194636e4c081d1a04741fa1092e1152c3efb51aa73aeae325cbd0514`,
  identical byte-for-byte to the four-worker plan;
- native coordinate checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- eight scan workers, four cost-balanced replay workers, an exact 2,000-block
  snapshot boundary, and proof/walk cutoff 30,400;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3.45.1 on the 24-thread, 32-GiB WSL2
  instance; and
- ignored operational artifacts under
  `runs/5a-native-mixed-8worker-matched-8000-20260717/`.

The operational command was:

```sh
./scripts/run-native-mixed-wave.sh \
  runs/5a-coordinate-tables-cbb8ab9.bin \
  runs/5a-generation-masks-native-ledger.bin \
  runs/5a-native-mixed-8worker-matched-8000-20260717 \
  500 8 2000 4 30400 30400
```

Only scan ownership changed: test 0048 used four 2,000-block shards, while
this run used eight 1,000-block shards. Replay stayed at four workers.

## Result

The eight-worker scan completed in 1,825 seconds, versus 2,145 seconds for the
four-worker baseline. This is a 1.175-fold speedup, or 14.9 percent less scan
wall time. Exact final replay took 1,139 seconds, versus 1,207 seconds. Total
end-to-end wall time fell from 3,358 to 3,011 seconds, a 10.3 percent
reduction.

The wall-time gain was inefficient. Aggregate measured block time rose from
8,438.953 to 14,123.826 CPU-seconds, a factor of 1.674. Peak process-tree RSS
rose from 3,211,896 to 4,389,624 KiB, while available memory remained above
26,294,784 KiB and swap-free space was unchanged. Eight workers are therefore
memory-safe, but they do not provide proportional compute throughput.

The certificate-heavy class-2 stratum explains the loss. Its 500 blocks
generated 417,889 certificates and 7,457 ledger hits. Mean measured block time
rose from 15.151 to 25.301 seconds, median time from 16.088 to 26.192 seconds,
and the maximum from 30.190 to 48.402 seconds. A live process sample in this
tail found the eight workers using only about 1.8 CPU cores in aggregate;
most were sleeping in SQLite busy-timeout backoff while a few held the
single-writer transaction path. The other 15 strata completed quickly enough
that eight workers still won modestly overall.

The final 1,087,995,904-byte ledger has SHA-256
`9527b9c7ed80b1069e7bdc8e87b506424fa6064506865f8647f7e48dcb6c38cb`.
It contains 449,162 certificates and 13,925,318 unique owned vertices: three
closed, 35 overflow, and 449,124 linked certificates. Exact replay,
`quick_check`, foreign keys, zero leases, the final checkpoint, and zero WAL
all passed.

## Cross-run mathematical comparison

Concurrency changes which certificate first owns a vertex, so certificate
IDs, linked/overflow representatives, and the final database hash are not
expected to match. The eight-worker ledger has 44 more certificates and 6,212
fewer unique owned vertices than the four-worker ledger; its bounded status
partition has 35 rather than 36 overflow certificates.

The order-independent mathematical checks do match:

- both ledgers contain exactly the same 8,000 planned ordinals;
- every ordinal has exactly the same refined-vertex and generating-vertex
  count;
- both have three closed components of sizes 5,498, 6,826, and 6,826; and
- the sorted vertex-set SHA-256 values of all three closed components agree
  exactly between runs.

The bounded overflow-count difference is therefore an ownership-order effect,
not a different closed-component result. Each ledger independently passes
strict-prefix replay.

## Verdict

Passed the controlled matched-ordinal, exact-prefix/final-replay, integrity,
memory, and cross-run mathematical gates. Eight scan workers are 1.18 times
faster on this complete stratified workload, but require 1.67 times the block
CPU and make the decisive class-2 blocks 1.67 times slower individually.

Eight workers may be useful for broad, read/compute-heavy strata, but a single
shared SQLite writer is the wrong scaling seam for certificate-heavy strata.
Test 0055 then tried a simpler single-writer queue; it failed its throughput
gate, and no further persistence redesign was attempted.
