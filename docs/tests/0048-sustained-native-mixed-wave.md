# Test 0048: sustained native mixed scan and replay wave

## Question

Can the fixed-shard native 5A pipeline sustain a materially larger no-fault
scan, replay an immutable prefix while work continues, and then exactly replay
the complete final ledger within the machine's memory budget? What does the
result say about the end-to-end production budget?

## Inputs and provenance

- clean implementation revision at launch: `7a7e702`;
- 8,000 deterministic blocks, 500 from each of the 16 nonidentity
  product-class strata and exactly 2,000 assigned to each of four fixed shards;
- work-plan SHA-256
  `987f0eb5194636e4c081d1a04741fa1092e1152c3efb51aa73aeae325cbd0514`;
- native coordinate checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`,
  exported at source revision
  `cbb8ab95ba90b8bcdf7fb6bbe455ab0672bcd0b1`;
- proof and walk cutoffs 30,400, traversal convention `native-v1`;
- four scan workers and four cost-balanced replay workers;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3.45.1 on the 24-thread,
  64-GiB WSL2 host;
- ignored operational artifacts under `runs/5a-native-mixed-8000/`.

The final 1,088,413,696-byte ledger has SHA-256
`1f28d54483564e5320990a2e87236629823df7887faa8f2a1b42116990c4d469`.
The immutable snapshot has SHA-256
`ae700331f1f31b3245b98c0d82a2ffbca8f4fd24f7d9dc1444170d15b6ce73d5`.
The large databases, transcripts, and machine-local samples remain
intentionally uncommitted. `summarize_native_mixed_wave.py` deterministically
reconstructs the figures below from those artifacts.

## Result

The scan completed all 8,000 planned blocks in 2,145 wall seconds and
8,438.953 aggregate block CPU-seconds. The final ledger contains 449,118
certificates and 13,931,530 unique owned vertices. Certificate statuses are
449,079 linked, 36 overflow, and three closed. The planned and actual
four-shard counts agree exactly at 2,000 each; there are no leases, unplanned
blocks, foreign-key violations, or SQLite integrity errors.

The four immutable final-replay ranges contained 6,013,184, 3,231,286,
2,530,437, and 2,156,623 vertices. They completed in 921.543, 1,199.990,
1,165.160, and 1,188.810 seconds. Thus the complete exact replay wall time was
1,207 seconds and its aggregate rate was 11,542 owned vertices per wall
second. The whole mixed run took 3,358 seconds. Peak sampled process-tree RSS
was 3,211,896 KiB; available host memory never fell below 28,111,236 KiB and
swap-free space was unchanged.

The sample is intentionally stratified rather than population-proportional.
The small class-2 stratum alone produced 417,833 certificates (93.0 percent of
the total) from 500 sampled blocks and averaged 15.151 seconds per block.
Several much larger strata averaged well below one second per sampled block.
Consequently the observed raw 8,000-block rate must not be multiplied by the
161-million-block census. Component ownership is amortized globally, while a
sparse sample repeatedly pays to rediscover live components.

Using the current independent weighted projection of 255,977,929 final owned
vertices only for the approximately linear persistence and replay stages gives
a provisional 19,998,512,999-byte database (18.6 GiB) and 22,177 replay
seconds (6.16 hours). Combined with the existing 15--20-hour scan model, the
present native production envelope is approximately 21--26 hours before a
separately implemented mathematical verification pass. This remains a sizing
model, not a certified completion time.

Test 0051 later measures the population cursor directly and retires this
stratified 21--26-hour envelope. Its resumed four-worker interval projects a
39.4-day scan if sustained, consistent with the more cautious four-to-five-week
scan model.

## Snapshot/WAL finding

The original online backup began after the requested 2,000-block trigger, but
SQLite's backup had to keep recopying pages modified by the active writers. It
therefore captured 7,504 blocks rather than an exact 2,000-block prefix and
overlapped only the last 356 scan seconds. Its long-lived reader also prevented
WAL recycling while writes continued; the WAL and WSL page cache grew far
beyond the final database's size. The captured snapshot is internally valid
and its replay passed, but it is not the boundary the harness intended.

Test 0049 changes the lifecycle to stop at an exact deterministic prefix,
checkpoint and truncate the WAL, take the immutable backup while quiescent,
then start prefix replay and the second scan wave together. This preserves
useful overlap without allowing the backup reader to chase writes.

## Verdict

Passed the sustained fixed-shard scan, bounded-memory, final exact replay, and
ledger-integrity gates. No new closed or overflow component was found in this
sample beyond the already known statuses; this is not an exhaustive 5A result.
The run exposed and quantified a snapshot/WAL engineering defect, which is
corrected and regression-tested in test 0049.
