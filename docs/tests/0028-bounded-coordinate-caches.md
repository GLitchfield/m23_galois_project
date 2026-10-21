# Test 0028: bounded direct-coordinate caches

## Question

Can a long database quotient wave retain exact deterministic coverage without
allowing GAP's reusable relative-map and pair-twist-refinement caches to grow
for the entire process lifetime?

## Inputs and provenance

- verified base: 985,000 blocks, SHA-256
  `a90d925aaee11281c446df1bb6039ab11b37d693e83d5b7614bc4fbc4512d3ff`;
- pair checkpoint: `runs/4a-pair-orbits-v2.g`, SHA-256
  `add26b95401d74fbaf29167782667080275d848b8cddabceecef40c2051c75c4`;
- initial 12-worker code: `48ec04de60771d0b52391c59b916ccf30e24f32b`;
- bounded-cache implementation: `23434352c1c4063ba431e8f00baa8451a43949e2`;
- GAP 4.12.1, AtlasRep 2.1.8, CTblLib 1.3.7, TransGrp 3.6.5.

## Method

The original 500,000-block extension used 12 long-lived workers. At
1,447,174 blocks the machine had about 222 MiB available and all 8 GiB of swap
was occupied, so the wave was stopped before an uncontrolled OOM. SQLite
retained 1,447,337 committed blocks after in-flight transactions settled.

The direct locator's `relative_cache` and `refinement_cache` are accelerators,
not proof state. The scanner now discards both at a configurable committed-block
interval and requests GAP garbage collection. A two-worker smoke run extended
the 10,000-block base to 10,010 with a deliberately tiny interval of two,
crossing several resets and ending with zero leases. Reconstructing an order-11
refinement after an explicit reset also reproduced the same twist weights and
exact ordered neighbor keys.

The interrupted production ledger then resumed with four physical workers,
12 unchanged virtual shards, a 500-block reset interval, and a 12 GiB startup
reserve. No new speculative wave was queued.

## Result

The resumed scan reached exactly 1,485,000 blocks with zero leases and SQLite
`quick_check = ok`. The frozen candidate has:

- SHA-256 `cf2ea3b58135146e73e2a624b9922c5063aba7c90e44aafe2c6af4b097cbc33d`;
- 1,140,761 certificates;
- 4,902,148 quotient vertices;
- 422,400,000 database bytes.

Each finishing worker reported 18 or 19 cache resets. Repeated probes during
the resumed scan, including overlap with one 5A checkpoint-generation process,
showed about 25 GiB still available. This is an operational memory result, not
a formal peak-RSS bound.

The independent replay subsequently completed. It verified the 500,000-block
delta as 284,604 linked certificates owning 680,796 vertices, rematerialized
944,623 refined and 843,402 generating block vertices with 558,798 ledger hits,
and reproduced the candidate SHA-256 exactly. The ownership audit also proved
that the 985,000-block base was preserved and all new blocks obeyed the declared
12-shard assignment.

## Verdict

Passed for memory control, deterministic scan completion, exact replay, and
ownership.

## Subsequent verified prefix

The same bounded-cache protocol subsequently verified and promoted an immutable
1,985,000-block base with SHA-256
`2388ac8939830b12e49ebe24f6011002eaa0f3945b0dc5f09c25ef749ef1cd63`.
It contains 1,392,128 certificates and 5,437,092 uniquely owned vertices. The
500,000-block delta from the 1,485,000 base contains 251,367 certificates and
534,944 vertices; exact certificate replay, block totals, base preservation,
and deterministic 12-shard ownership all passed. A 2,485,000-block candidate
was subsequently frozen and has now passed exact certificate/block replay,
base preservation, and deterministic 12-shard ownership audit. Its immutable
SHA-256 is
`6e5e60fe69fc35327c52caf863164d18356842840ea9cb5a6ade08a32208020c`;
it contains 1,626,568 certificates and 5,897,611 vertices. The 500,000-block
delta adds 234,440 certificates and 460,519 vertices; every delta certificate
links to prior coverage. Pipeline promotion awaits completion of the
simultaneous speculative scan toward 2,985,000 blocks.
