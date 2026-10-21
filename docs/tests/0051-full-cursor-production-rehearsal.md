# Test 0051: full-cursor native production rehearsal

## Question

Can the compact 161,177,452-block `5A` cursor sustain a materially larger
full-cutoff scan with exact resumability, overlapped immutable-prefix replay,
bounded memory, zero-WAL checkpoints, and the production-default independent
GAP audit? What runtime model follows from a population-cursor measurement
rather than the earlier stratified samples?

## Inputs and provenance

- clean launch revision `03f12765d3a0891bfb7b5220dbba62c553f3930f`;
- native coordinate checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- generation-mask checkpoint SHA-256
  `0e39a410106cb5f18dc6f8fca24b702109e4614a35345a3200e2edd519b1fe7b`;
- GAP homogeneous-pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- compact full-cursor plan SHA-256
  `141a777228842c6307dc239dd0493aa83b93f48786f6a72011cba891d93340f0`;
- four deterministic scan shards, two cost-balanced native replay workers,
  proof and walk cutoffs 30,400, and native convention `native-v1`;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3.45.1 on the 24-thread WSL2 host,
  which exposed 32 GiB for this run;
- ignored operational artifacts under
  `runs/5a-full-cursor-rehearsal-2000-20260717/`.

The fresh ledger was seeded with zero materialized work-plan rows. The first
wave advanced it from zero to 2,000 blocks. The second resumed the same ledger
from 2,000 to 10,000 blocks while exactly replaying the immutable 2,000-block
snapshot. Both used `run-native-full-cursor-wave.sh`; the production-default
independent audit then used four GAP jobs, every exceptional certificate, 256
systematic linked certificates, and 64 systematic completed blocks.

## Full-cursor result

The first 2,000 blocks scanned in 89 seconds, or 22.47 blocks/second. Exact
final replay took 112 seconds. The quiescent result contained 6,444
certificates and 1,600,227 owned vertices and passed SQLite integrity, foreign
keys, compact-plan arithmetic, exact replay, checkpoint, and zero-WAL gates.

The resumed wave added 8,000 blocks in 169 seconds, or 47.34 blocks/second.
Its 97-second exact prefix replay overlapped the scan completely. Exact final
replay of the resulting 29,276 certificates and 3,477,384 owned vertices took
257 seconds. The final status counts are two closed, 40 overflow, and 29,234
linked certificates. Both closed certificates have 6,826 quotient vertices
and 30,400 weighted classes. The final ledger has SHA-256
`bb908a051a2d4e2ff46dde98519a07760b903d5620405911260ed5031f2f56a6`
and size 260,456,448 bytes.

Partial-wave shard totals were 1,830, 2,222, 2,247, and 3,701 blocks. This is
expected: block costs differ and a global partial target stops faster shards
after more permanently assigned work. Every stored ordinal has the prescribed
modulo owner. At the final census boundary the arithmetic audit will require
40,294,363 blocks for each shard.

Peak process-tree RSS was 1,564,160 KiB for the first wave and 2,248,584 KiB
for the overlapped second wave. Available memory never fell below 28,517,612
KiB during the second wave, and swap-free space was unchanged. Both final
checkpoints left zero-byte WAL files.

## Independent GAP result

The audit plan SHA-256 is
`a9f0db0ba9b09bb27df7d9d69dea62a5665063e11cb5a7ff652ba7b5c6ca7b3d`.
Four independent GAP processes rebuilt the pair locator without using the
native coordinate or generation-mask checkpoints. In 558 wall seconds they
verified:

- both closed and all 40 overflow certificates;
- 256 systematic linked certificates;
- 165,329 ordered certificate vertices in total;
- 64 systematic blocks containing 185 refined vertices;
- direct GAP generation for all 171 generating vertices; and
- final ledger ownership for every sampled generating vertex.

All status, linkage, strict-prefix ownership, ordered-walk, weighted-class,
block-count, generation, database-hash, and plan-hash checks agreed. Audit
peak RSS was 4,769,872 KiB, available memory remained above 26,363,996 KiB,
and swap-free space was unchanged. Both closed certificates happened to land
in one round-robin audit segment; this is correct but identifies a modest
exceptional-certificate load-balancing improvement for the final audit.

That scheduling improvement was implemented immediately after the rehearsal.
The planner now accepts the frozen GAP job count and assigns selected
certificates longest-estimated-work first, using `discovered_vertices + 96`,
while retaining balanced row counts and contiguous hashed plan indices. On
this ledger the four estimated segment costs are 48,582, 48,581, 48,387, and
48,387 units; the two closed certificates move to separate segments. A fresh
two-worker real-ledger gate independently verified one closed, one overflow,
two linked certificates, 9,862 vertices, and two blocks under the new routing.
Its audit-plan SHA-256 is
`66135b35224df4592bbe63b9046dda1e06a344070eaee6ad57acee4aa0d11772`.

## Runtime interpretation

At the measured resumed-wave rate, a naive four-worker scan of all
161,177,452 blocks takes 3,404,874 seconds, or 39.4 days. This is a conditional
projection from an early 8,000-block population-cursor interval, not a
certified completion time: component ownership and frontier density change as
the ledger matures. It is nevertheless the first direct full-cursor rate and
is consistent with the earlier four-to-five-week scan estimate.

The previous 15--20-hour scan and 21--26-hour native end-to-end estimates came
from sparse stratified samples and are retired. They did not measure the full
161-million-block cursor directly. Final replay and database size also must
not be extrapolated linearly from this early ledger because component
ownership is strongly amortized. The present responsible envelope remains
approximately four to five weeks for four-worker scanning and five to seven
weeks for a pipelined, independently audited result until a larger mature
cursor interval or a higher-worker comparison sharpens it.

## Verdict and next gate

Passed the 10,000-block full-cursor scan, deterministic resume, complete prefix
overlap, exact final replay, bounded-memory, checkpoint/WAL, partial arithmetic
exhaustiveness, and production-default independent GAP audit gates.

The next experiment should compare a fresh eight-worker full-cursor ledger
against this four-worker baseline at the same 10,000-block boundary. That will
measure SQLite contention and CPU scaling directly before choosing the frozen
production shard count.
