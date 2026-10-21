# Test 0030: preliminary 5A end-to-end runtime model

## Question

How long would an exhaustive, independently replayed `(5A)^4` bounded search
take on the current 32 GiB workstation, and does the current implementation fit
in memory?

## Inputs and provenance

- implementation under test: `c209e47422fb5e5f4976c6cfda86d12689a92d95` plus
  the uncommitted benchmark script recorded with this note;
- schema-v2 5A pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- 5A macroblocks: 161,177,452;
- exact ambient generating inner classes: 1,811,840,784;
- proof and pilot walk limits: 30,400;
- GAP 4.12.1 on the 32 GiB workstation.

The cold benchmark used ten deterministic midpoint samples in each of the 17
product-class segments, resetting the two block-local caches after every
sample. It is reproduced by:

```bash
M23_PAIR_CHECKPOINT=runs/5a-pair-orbits-v2.g \
M23_OUTPUT=runs/5a-refinement-profile/stratified.tsv \
gap -q scripts/gap/benchmark_direct_pair_refinements.g

M23_PAIR_CHECKPOINT=runs/4a-pair-orbits-v2.g \
M23_OUTPUT=runs/5a-refinement-profile/stratified-4a.tsv \
gap -q scripts/gap/benchmark_direct_pair_refinements.g

python3 scripts/summarize_direct_pair_refinements.py \
  runs/5a-refinement-profile/stratified-4a.tsv \
  runs/5a-refinement-profile/stratified.tsv
```

A separate exact 5A database pilot began at certified bridge block 71,532,995.
Its first certificate closed the known 30,400-class component with 5,498
quotient vertices. The continuation was stopped after entering the unusually
dense order-2 block 840. The durable stopping state passed SQLite `quick_check`,
had zero leases, and contained 26 completed blocks, 45 certificates, and 75,496
vertices. Excluding the seed certificate, 44 traversals discovered 69,998
vertices representing 698,173 weighted classes in about 804 post-locator
seconds.

A read-only replay spot check then reconstructed the first closed certificate
in 134 seconds, compared with 131.60 seconds for the original one-block scan.
The following overflow certificate required another 31 seconds, compared with
about 30 seconds in the scan continuation after locator startup. Replay thus
repeats essentially the full traversal cost; it is not a cheap metadata audit.
The spot check was stopped after those two exact matches because completing all
45 certificates would add no new scale information.

## Measured phase sizes

| quantity | 4A | 5A |
| --- | ---: | ---: |
| macroblocks | 7,928,185 | 161,177,452 |
| weighted cold refinement + generation | 9.549 ms/block | 11.739 ms/block |
| estimated refined quotient vertices | 13,526,582 | 278,854,119 |
| estimated generating quotient vertices | 10,491,726 | 242,509,289 |
| isolated single-CPU kernel time | 0.88 days | 21.90 days |

The 5A cold block kernel is only 1.229 times the 4A cost per block. The dominant
scale increase is the 20.33-times-larger block census, not radically more
expensive individual generic blocks. Dense low-order segments are expensive
but occupy a small fraction of the census.

The live pilot covered about 868 weighted classes per second on one core. If
that deliberately productive frontier sample were representative and had no
duplicate work, traversing the full ambient mass would require about 24.2 CPU
days. It is an optimistic traversal throughput, not a standalone wall-clock
prediction: the early frontier was seeded from a known component, future
component structure is unknown, and multiple workers contend on ledger writes.

## Wall-clock model

The most defensible calibration is the mature 4A implementation rather than
the isolated kernel. The final bounded-cache four-worker 4A wave sustained
45.76 blocks/second. Dividing by the measured 1.229 block-cost ratio projects
37.23 5A blocks/second, or 50.1 days for the scan with four workers. The best
observed 12-worker 4A wave sustained about 87.4 blocks/second; the same
calibration gives 71.1 5A blocks/second, or 26.2 days before extra 5A traversal,
recovery, and replay margin.

These measurements support the following planning range with the GAP scanner:

| configuration | exhaustive scan | independently replayed result |
| --- | ---: | ---: |
| 4 workers | roughly 7--9 weeks | roughly 9--12 weeks |
| 8--12 workers, streamed replay | roughly 4--5 weeks | roughly 5--7 weeks |
| 8--12 workers, sequential replay | roughly 4--5 weeks | roughly 8--10 weeks |

The middle row is the recommended planning target: scan and replay immutable
waves concurrently so the wall time is governed mostly by the slower side.
The ranges intentionally include traversal uncertainty, contention, recovery,
and final audit. The matched certificate spot check supports treating replay as
a second scan-like workload. The ranges do not bank an unmeasured C++ speedup.

## Memory and storage gate

The verifier at the time of this estimate loaded every prefix quotient vertex
into a GAP dictionary. During 4A replay, 4,221,352 prefix vertices used about
1.04 GiB RSS, or at most roughly 250 bytes per loaded vertex including process
overhead. Scaling that representation to the estimated 242.5 million 5A
generating vertices gives about 60 GiB for one prefix dictionary before locator
state, the operating system, scan workers, or parallel replay. That design
could not complete on 32 GiB and would have been uncomfortably tight even on
64 GiB.

The SQLite ledger itself scales more favorably. At the current 4A density,
242.5 million vertices suggest roughly 20--25 GB on disk, with working space
needed for WAL files, frozen candidates, and replay reports.

Test 0031 subsequently implemented database-backed prefix lookup and streaming
block replay. Four cold 5A certificate segments exactly replayed a 52,546-vertex
pilot with 651--781 MiB RSS per process; block replay used 554 MiB. The
five-to-seven-week estimate is no longer memory-blocked, although a sustained
mixed scan/replay wave is still needed to choose the production worker split.

## Verdict

The current evidence supports a preliminary **five-to-seven-week wall-clock
budget** for a pipelined 8--12-worker GAP search and independent streamed replay
on this workstation. The scan itself is likely around four to five weeks. Test
0031 removes the original verifier memory blocker; the range remains a planning
estimate pending a sustained mixed scan/replay benchmark.

Test 0037 subsequently makes a full known 5A component roughly 26 times faster
than its earlier production GAP traversal, including the identity block. That
result motivates a one-to-two-week native integration target, but does not
replace this GAP baseline until native block scheduling, ownership lookup,
certificate commits, and independent replay are measured together.
