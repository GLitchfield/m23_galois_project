# Test 0040: stratified native-ledger runtime model

## Question

Can the native 5A ledger seam sample every nonidentity product-class segment
deterministically without accumulating unbounded lazy block tables? What
arithmetic runtime floor does that sample support, and which production costs
remain unmeasured?

## Inputs and provenance

- implementation: the commit containing this note;
- 5A coordinate checkpoint source SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- coordinate checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- generation-mask checkpoint SHA-256
  `0e39a410106cb5f18dc6f8fca24b702109e4614a35345a3200e2edd519b1fe7b`;
- proof and walk cutoff 30,400;
- five deterministic midpoint samples in each of 16 nonidentity
  product-class segments, 80 blocks total;
- GAP 4.12.1 and g++ 13.3.0 on the 24-thread, 32 GiB WSL2 host.

The unique identity-product block is excluded from statistical weighting. It
is already covered exactly by the known 5,498-vertex component fixture and
must be charged separately in a production plan.

Regenerate the operational transcript and summary with:

```bash
scripts/run-native-ledger-batch.sh \
  runs/5a-coordinate-tables-cbb8ab9.bin \
  runs/5a-generation-masks-native-ledger.bin \
  --stratified 5 30400 30400 \
  runs/5a-native-stratified-cache-5/transcript.tsv
python3 scripts/summarize_native_stratified_ledger.py \
  runs/5a-native-stratified-cache-5/transcript.tsv
```

The transcript records the complete sample plan, per-block phase timing,
certificate rows, ownership rows, and live progress. Operational transcripts
and databases remain under `runs/` and are not committed.

## Cache policy result

The lazy coordinate index now has an explicit disposable-block-cache reset.
Stable native vertex IDs and durable ownership keys survive a reset, while
relative and refinement rows are rebuilt deterministically on later access.
The bounded-walk regression checks rebuild equality.

On the same one-sample-per-segment workload:

| reset policy | wall time | peak RSS |
|---|---:|---:|
| no reset | 148.20 s | 2,490,952 KiB |
| every 100 certificates | 101.78 s | 1,130,192 KiB |
| every certificate | 58.40 s | 428,432 KiB |

Resetting every certificate is both fastest and smallest in this sample,
because it avoids increasingly expensive global hash tables. It is therefore
the default for stratified runs.

## Five-sample result

The 80 sampled blocks completed in 109.62 seconds at 458,880 KiB peak RSS.
They contained 7,150 refined vertices, 3,743 generating vertices, 3,658 new
certificates, 85 existing-ledger hits, and 1,174,738 newly owned vertices.

Segment-weighting projects 279,009,150 refined and 255,977,929 generating
nonidentity quotient vertices. Separating refinement/generation from sparse
component traversal gives:

- weighted refinement plus generation: 0.954 single-core days;
- observed traversal throughput: 14,578.9 newly owned vertices/second;
- traversal charged once per projected generating vertex: 0.203 days;
- combined arithmetic floor: 1.158 single-core days.

Treating each of the five systematic positions as a separate cross-segment
estimate gives 1.021--1.321 days. This is a sensitivity band, not a statistical
confidence interval: the samples are deterministic, not random.

Directly weighting the full sparse-ledger block times would give 397 days.
That number is invalid because each sampled block starts from a deliberately
sparse ownership map and repeatedly rediscovers components that an exhaustive
ledger traverses only once. The amortized model charges the kernel per block
and each projected generating quotient vertex once.

## SQLite boundary

The one-sample transcript imported 1,041 certificates and 525,571 vertices
into a 37 MB SQLite ledger in 16.09 seconds at 106,764 KiB peak RSS. Combined
native computation plus bulk persistence took about 74.5 seconds, 28 percent
above the native batch alone.

Prepared indexed ownership lookups on that ledger measured approximately
431,000 cold hits, 443,000 warm hits, and 438,000 warm misses per second. Four
concurrent read-only processes sustained 1.16 million warm-hit lookups/second
in aggregate. Reproduce a single lookup pass with:

```bash
scripts/benchmark-native-sqlite-lookups.sh \
  runs/5a-native-stratified-cache-1/ledger.sqlite3 \
  runs/5a-native-stratified-cache-1/transcript.tsv
```

These measurements make indexed reads plausible. They do not measure live
atomic ownership insertion, commit batching, writer contention, or recovery.
The current benchmark still keeps the ownership map in RAM, which cannot scale
to roughly 256 million keys.

## Runtime interpretation and verdict

Passed the deterministic stratification, bounded cache, progress-monitoring,
bulk-import, and indexed-read gates. The arithmetic floor suggests an ideal
four-worker scan of roughly 6--8 hours. A provisional engineering target is
12--24 hours for the native scan after live SQLite ownership and commit
integration; that range is deliberately not a launch promise.

Test 0043 subsequently measures the exact plan through live FULL-synchronous
SQLite at 152.50 seconds for one worker and 65.16 seconds for four, supporting
a 15--20-hour scan-only estimate. An independently certified end-to-end result
remains unestimated. A second
native implementation/replayer could plausibly keep it to days, whereas full
replay through the existing GAP pipeline retains the older multiweek baseline.
The next required experiment was a small, crash-tested multiworker native
ledger with atomic SQLite ownership claims. Test 0042 passes that engineering
gate through 100 blocks; a wider stratified live census and independent GAP
replay of every pilot certificate remain.
