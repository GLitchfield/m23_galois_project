# Test 0034: mixed 5A coexistence pilot

## Question

Can a useful 5A scan/replay experiment run beside the active eight-worker 4A
production wave without threatening memory safety, and how much CPU-heavy
research should remain active during production?

## Inputs and provenance

- implementation: the commit containing this note;
- schema-v2 5A pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- key-v2 candidate: 6 blocks, 24 certificates, 52,546 vertices;
- active 4A production ledger: eight workers and twelve virtual shards;
- GAP 4.12.1 on the 32 GiB, 24-thread workstation.

Operational databases, logs, plans, and resource samples live under
`runs/5a-mixed-*` and are not committed results. The reusable launcher is
`scripts/run-mixed-quotient-pilot.sh`.

## Method

The candidate side independently replayed two balanced certificate segments
and one streamed block segment against an exactly empty base. At the same time,
two dynamic 5A scan workers resumed copies of the candidate toward a bounded
16-block target. `scripts/sample_process_trees.py` recorded descendant counts
and aggregate RSS for replay and scan separately every five seconds, together
with system available memory and free swap. The active 4A wave remained
untouched.

The pilot was intentionally stopped after 19.1 minutes once exact replay had
finished and the scan had committed five additional blocks. This avoided
spending further 4A CPU time on the two unusually dense in-progress blocks.
SQLite rollback/recovery semantics preserved committed transactions; the live
database passed `quick_check`, and its two abandoned leases are ordinary
expiring restart leases rather than proof state.

## Results

Exact replay completed all 24 certificates and all 52,546 vertices in 521
seconds. The block segment independently verified all six blocks, 18 refined
vertices, 14 generating vertices, and seven ledger hits in 65 seconds. The
candidate has zero leases and an exact combined replay record.

The speculative scan advanced from 6 to 11 committed blocks and from 52,546 to
212,373 vertices before the bounded stop. It committed 171 total certificates;
the unfinished dense-block transactions were not counted as completed blocks.

Across 230 five-second samples:

| quantity | measured value |
| --- | ---: |
| peak replay-tree RSS | 2,024,616 KiB |
| peak scan-tree RSS | 3,577,980 KiB |
| peak simultaneous replay + scan RSS | 4,001,900 KiB |
| minimum system available memory | 22,035,152 KiB |
| free swap, start / minimum / end | 7,094,332 / 7,094,332 / 7,094,464 KiB |

Memory was therefore not close to the guardrail, even with 4A and the full
repository test suite active. CPU was the real shared constraint: observed 4A
throughput fell from its roughly 80-block/second early-wave rate into roughly
the 50--60 range while all five 5A workers were busy. This comparison is a
coexistence diagnostic, not a controlled throughput benchmark.

## Operational conclusion

The current machine can safely reserve memory for native development and a
small 5A experiment while 4A runs. The sensible daytime allowance is about two
CPU-heavy research workers, not the five used to expose the limit here. More
RAM would improve page-cache residency and reduce operational risk, but this
pilot does not support expecting it to remove the CPU contention or halve 5A
runtime.

An isolated, longer 5A scan/replay wave remains necessary before choosing the
eventual production split. That measurement should run after the current 4A
wave or under an explicit production/research CPU budget.

## Verdict

Passed the mixed-workload memory, exact-replay, transactional-stop, and
monitoring gates. The five-worker research lane is CPU-expensive beside 4A;
cap ordinary concurrent research near two CPU-heavy workers.
