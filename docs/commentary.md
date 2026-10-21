# Research commentary

## 2026-07-10 — Separate canonical class names from arbitrary representatives

The GAP library character table gives the ATLAS/Häfner names needed for
character computations, but the natural permutation group's computed character
table admits 16 possible fusions to it. This is not cosmetic: selecting the
first order-7 or order-11 permutation class and calling it `A` would silently
embed an unsupported convention. The project will therefore carry canonical
library positions separately from concrete representatives until an
ATLAS-standard word or verified fusion fixes the correspondence.

The historical software review also changed the implementation posture. The
paper source bundles do not preserve the original computation code; MapClass is
the maintained successor, but its generality is not itself evidence that it is
the right engine for the eventual billion-tuple searches. It should first serve
as a small-case comparison implementation while project-owned code makes tuple
representation, canonicalization, and checkpoint costs measurable.

## 2026-07-10 — First complete orbit reproduction

The `(14A,2A,2A,2A)` calculation reproduces cleanly without MapClass: 84 inner
Nielsen classes form one pure braid orbit, with pure genus 1 and symmetric genus
0. All three published symmetry cycle shapes match. The direct pure-braid
formulas also agree with compositions of elementary Hurwitz moves, giving the
engine its first cross-check at the action level rather than only at the final
count level.

The enumeration clarified another distinction worth preserving. Fixing the
order-14 coordinate yields 280 product-one conjugacy orbits before generation,
while the normalized structure constant is 266 and the generating count is 84.
The character formula supplies a weighted bound, not a literal count of all
product-one orbits when nongenerating tuples can have nontrivial stabilizers.

## 2026-07-10 — The companion order-15 orbit

The shared fixed-first-coordinate engine reproduces the second quadratic-field
case without special handling: 90 generating inner classes form one pure braid
orbit, the published symmetry cycle shapes match, and the symmetric genus is
zero. The pure orbit has genus 4. Both natural-action order-15 classes give the
same result, so the computation remains independent of an arbitrary `15A/15B`
fusion choice.

## 2026-07-10 — The first rational bridge and a cycle-count correction

The 28 classes in `(8A,8A,2A)` generate exactly the small orbit families Häfner
describes inside `(8A)^4`: 84 pure length-2 orbits, 28 symmetric length-6
orbits, and 14 full length-12 orbits. Unlike the quadratic-field examples, this
starts from a rational class vector and exercises deduplication across many
distinct braid orbits.

The length-2 genus check exposed a helper error: GAP's `Cycles` already includes
fixed-point cycles on the supplied domain, so the helper had counted fixed
points twice. The earlier genus values are unchanged because their relevant
generators had no fixed points. The shared helper was corrected and the entire
suite rerun rather than grandfathering the earlier results.

## 2026-07-10 — First larger rational orbit

The involution-pair parametrization makes `(4A,4A,2A,2A)` practical without
enumerating `4A x 4A`: fixing the first coordinate and deriving the second from
two involutions reduces the outer scan to about 14.4 million pairs. The 2,456
generating inner classes form one pure orbit, and the published genera 447 and
169 both reproduce.

This calculation also justifies indexed tuple lookup before the larger cases.
The generating fixed-first set contains 78,592 concrete tuples; dictionary
lookup keeps braid-image identification from becoming a repeated linear scan.

## 2026-07-11 — Invariant shards rather than arbitrary ranges

The general engine shards complete centralizer-orbits of the third coordinate,
not arbitrary involution indices. That choice makes every checkpoint closed
under the simultaneous-conjugacy quotient. Consequently product inner classes
cannot straddle files, and the verifier can prove exact global coverage from
the assignment certificate before the braid action is built.

The four-shard 4A regression matches every monolithic count and generator cycle
shape. Atomic writes plus a second resume-only invocation establish that a
completed checkpoint is reusable operational state rather than a fragile log.
Genus is recorded per connected orbit; this avoids silently applying the
connected Riemann-Hurwitz formula to a future disconnected union.

## 2026-07-11 — The certified 5A bridge and direct normalization

Sixteen invariant shards reproduce the complete 5A bridge: 30,400 generating
classes in one pure orbit, with the published genera 5,223 and 2,071. The deep
recount independently recovered 1,258,595 product tuples and 83,919 product
inner classes before accepting the certificate.

The initial merge revealed a scaling mistake rather than a mathematical one:
generic transporter searches were being used even though the braid formulas
explicitly expose the conjugator moving the fixed first coordinate. Directly
undoing that conjugator reduced the 30,400-class merge to seconds-scale tens of
seconds and keeps normalization exact rather than heuristic.

## 2026-07-11 — The certified 6A bridge

Thirty-two shards recover 72,528 generating classes in a single pure orbit and
reproduce the published genera 15,125 and 6,065. The deep verifier found
1,221,743 product tuples and 102,465 product inner classes before generation.

At this scale the independent recount, not shard production or merge, is the
dominant cost. That is acceptable for publication-grade exhaustiveness: the
operational checkpoints finish quickly and remain resumable, while the costly
second path is paid once to certify the result.

## 2026-07-11 — The certified 8A bridge and observable long runs

Sixty-four shards recover 198,488 generating classes in a single pure orbit and
reproduce the published genera 41,277 and 16,617. The independent recount found
1,827,193 product tuples and 228,589 product inner classes, and the recorded
cycle shapes independently recover both genera.

This run crossed an operational threshold: silent verification was long enough
that conversational polling became wasteful. Runners now append durable phase
and per-shard events, while a detached management wrapper reports checkpoints,
verification progress, merge state, and failures without involving an agent.
The mathematical certificate remains separate from those operational logs.

## 2026-07-11 — Translation is construction, not exhaustiveness

Häfner's explicit `g_4,1` translation sends every certified 5A bridge class
into one 30,400-point pure component of `(5A)^4`. Equal-class symmetries then
join it with two conjugate pure components, giving the reported 91,200-point
symmetric component and genera 5,626/2,071.

The initial implementation deliberately used the bridge symmetry generators
and stayed inside one component. That was a useful diagnostic: `beta4` and
`eta34` preserve the two-pair class vector, whereas homogeneous tuples require
the larger equal-class symmetry generated by `beta3`, `eta23`, and `eta234`.
Most importantly, the successful translation accounts for 91,200 classes out
of an ambient 1.81 billion. It supplies seeds and regressions for the bounded
search, not evidence that no other components exist.

## 2026-07-11 — Exact pair blocks before global traversal

Pair products give an exact outer decomposition that is much smaller than the
Nielsen class itself. Double cosets of the target-class centralizer produce
10,099 pair orbits for 4A and 45,344 for 5A; matching inverse product classes
then defines 7,928,185 and 161,177,452 symbolic macroblocks respectively.
Full pair checkpoints remain only megabytes because the Cartesian macroblocks
are ranges, not rows.

The refinement inside a macroblock is also exact: relative double cosets in the
centralizer of the pair product yield its inner classes directly. A capped
pure-braid traversal closes a known 4A component at 2,456 and produces a
2,501-class overflow witness from a generic block. The remaining difficulty is
global reuse: 161 million macroblocks cannot each start an independent orbit
walk. The component ledger must recognize already certified components while
streaming the ranges, without weakening full coverage to random sampling.

The first reuse pilot showed that remembering only the classes exposed by an
overflow witness is too local. Ten adjacent order-11 macroblocks still launched
nine independent overflow traversals and found only three connecting paths.
The production graph therefore has to use complete pair-twist blocks as its
vertices; otherwise the cutoff that makes certificates cheap also prevents the
ledger from recognizing most of a large component.

The pair-twist refinement itself behaves cleanly on small noncyclic examples,
splitting macroblocks into the expected cosets of the subgroup generated by the
pair product. A quotient walk nevertheless reached a much larger noncyclic
block where reconstructing canonical tuple tables became a new bottleneck.
This is a representation issue, not evidence against the block strategy: the
relative double-coset coordinate already contains the needed finite action and
should replace repeated whole-tuple canonicalization.

## 2026-07-11 — Direct coordinates validate the quotient and expose edge cost

The relative-double-coset replacement now handles every product-centralizer
type. Small centralizers use explicit pair transporters; the identity-product
block uses the 10,099 target-centralizer double cosets directly, because
enumerating its product centralizer would mean enumerating M23 itself. The
cyclic cases agree orbit-for-orbit with the older canonical implementation,
and a sampled order-11 vertex has the same 22 outgoing macroblocks by both
methods.

Contracting pair-twist orbits turns the known 2,456-class 4A component into 484
weighted vertices and closes it exactly. The first traversal took about 124
seconds after locator construction, identifying whole-group product
normalization on every outgoing edge as the bottleneck.

Checkpoint schema 2 now preserves the fixed-pair normalizer that was previously
discarded after pair enumeration. A braid edge supplies an explicit conjugator
for its first entry; combining it with the saved normalizer reduces destination
lookup to a target-centralizer orbit. The same 484-vertex traversal now takes
about 14.2 seconds, an 8.7-fold improvement, with schema-1 fallback retained.
The remaining scaling problem is persistent global coverage, not local edge
normalization.

## 2026-07-11 — Resumable refined-vertex coverage pilot

The first coverage scheduler scans deterministic macroblock ordinals and keeps
a persistent map from refined `(macroblock, pair-twist orbit)` vertices to
certificates. A new generating vertex is traversed until its component closes,
its accumulated weight exceeds the bound, or it reaches an earlier certificate.
The checkpoint is replaced atomically after every completed macroblock and an
independent replay reconstructs every traversal and verifies complete coverage
of each scanned block.

Ten adjacent order-11 macroblocks produced ten overflow certificates, each just
over 2,500 classes, covering 2,507 refined vertices in roughly 32 seconds of
incremental scan time. Replay took about 26 seconds. None linked to an earlier
certificate. This is operationally much faster than the class-level pilot, but
it also falsifies the hope that adjacent ordinal order alone would create early
reuse. The next scheduler should prioritize macroblocks reached by a witness,
then return to the deterministic ordinal frontier; otherwise useful ledger
entries are scattered far ahead of the sequential scan.

## 2026-07-11 — Frontier scheduling helps, but does not finish scaling

A resumable frontier scheduler now processes macroblocks named by newly found
vertices before returning to a rotating deterministic ordinal stream. In the
first ten-block comparison, frontier order needed three certificates where the
sequential order needed ten. At 100 processed nonidentity blocks, 67 were fully
covered without a new traversal and 99 of 213 generating vertices hit the
ledger. The run stored 23,078 vertices in 114 certificates: 78 overflow and 36
linked. Exact replay succeeds in the recorded frontier order.

The dense noncyclic blocks are the counterweight. Some contain many unseen
pair-twist vertices, so the 100-block run still took about five and a half
minutes. A naive single-process extrapolation remains measured in months, and
the 792 KB checkpoint after only 100 blocks proves that rewriting one GAP record
after every block cannot be the final persistence format.

A second experiment separated the proof bound from the coverage-walk limit.
Keeping the proof bound at 2,500 while allowing a witness to grow toward 25,000
classes makes later seeds link at roughly 10,000--12,500 classes instead of
forming isolated minimal overflow balls. A 20-block exploratory run covered 15
blocks from the frontier, hit 19 prior vertices, and stored 12,533 vertices in
11 certificates, eight of them linked. The larger walks grow the reusable
ledger about three times faster per wall-clock second in this small sample.

## 2026-07-11 — Transactional quotient ledger

The frontier state now has a SQLite implementation behind a persistent
GAP-to-Python pipe. Certificates and all their vertices commit in one
transaction; vertex ownership is unique; frontier insertion is indexed; and an
active-block lease survives process death. If a process stops after committing
some certificates but before finishing its macroblock, the next invocation
receives the same block, recognizes the committed vertices, and completes the
block counters without duplicating evidence.

The database-backed ten-block pilot reproduces the in-memory state exactly:
three certificates, seven fully covered blocks, nine ledger hits, and 765
vertices. A fair single-invocation run took about 14 seconds versus roughly 13
seconds in memory, so individual indexed lookups currently cost only about 15
percent. After resuming to 20 blocks the database holds 11 overflow
certificates and 2,796 vertices in about 228 KB. Independent replay verifies
the certificate order, exact vertex sets, generation counts, block counters,
and SQLite integrity.

This removes the catastrophic write amplification of serializing the complete
GAP ledger after every block. The database is somewhat larger than a compact
GAP record at this tiny scale, but updates touch only transactional pages and
restart no longer reconstructs the full ledger in GAP. A cache should be added
only if larger pilots show database lookup overhead growing materially.

## 2026-07-11 — Walk-limit tuning and a negative parallel result

A matched 20-block database benchmark held the proof bound at 2,500 and varied
only the coverage-walk limit. Minimal walks stored 2,796 vertices in 41 seconds
(68.2 vertices/second) with eleven overflow certificates and no links. A limit
of 10,000 stored 7,698 vertices in 106 seconds (72.6/second), changing six of
the eleven certificates into links. A limit of 25,000 stored 12,533 vertices in
141 seconds (88.9/second), with three overflow and eight linked certificates.
The 25,000 limit is the provisional operating point: about 30 percent more
reusable vertices per second than minimal overflow.

The database service now also supports renewable worker leases, expired-lease
reclamation, and atomic conflict detection. A worker whose proposed certificate
overlaps a concurrently committed vertex must rerun against the updated ledger.
A wavefront barrier prevents idle workers from opening unrelated sequential
seeds while another worker is still constructing the frontier.

That correctness mechanism passes real two-process execution and exact replay,
but block-level concurrency is not yet a speed improvement. Two workers on the
same 20-block, 25,000-limit workload took about 150 seconds versus 141 seconds
for one worker and produced the identical 11 certificates and 12,533 vertices.
Cheap covered blocks exhausted one worker's budget while the other remained in
dense traversals. Parallel work should therefore target load balancing or the
inside of dense block traversals, not simply assign equal block counts.

## 2026-07-11 — Sustained 25,000-class frontier

Extending the single-worker database from 20 to 100 processed macroblocks
strengthens the walk-limit result. The ledger contains 47,102 vertices in 114
certificates: 110 linked and only four overflow. Total scan time across the two
invocations was about 464 seconds, or 101.5 vertices/second; the 80-block
extension alone added 34,569 vertices in 323 seconds, about 107/second. By
comparison, the 2,500-limit 100-block pilot stored 23,078 vertices in about 330
seconds, roughly 70/second. Larger walks therefore improved sustained certified
coverage throughput by about 45 percent, not merely the initial 20-block sample.

The database grew to about 3.0 MB and passed integrity checks. Full replay
reconstructed all 114 certificates and 47,102 vertices in about 434 seconds.
Dense noncyclic blocks still cause bursts of work, but most of their later seeds
now terminate as short links into the accumulated ledger.

A global block target corrected the earlier two-worker load imbalance. The
balanced 20-block run exercised a real overlapping-certificate conflict: SQLite
rejected the stale certificate, the worker reran, and committed a link. Exact
replay passed with the same 12,533 vertices. Wall time improved only from about
141 to 136 seconds, so safe block parallelism remains available but is not the
default optimization.

## 2026-07-12 — Ten thousand replayed blocks

The managed ledger reached 10,000 processed 4A macroblocks and passed complete
certificate-order replay. It stores 597,298 vertices in 18,593 certificates:
18,586 linked, four overflow, and three closed. Of 28,921 generating refined
vertices, 10,328 were already ledger hits, and 6,332 processed blocks required
no new certificate.

The 9,000-block extension took 5,378 seconds, about 1.67 blocks/second, while
adding 402,293 vertices at about 74.8/second. This is roughly 3.6 times the
block throughput of the preceding 900-block extension even though vertex
throughput stayed comparable: accumulated coverage is converting later work
into many small linked certificates. Full replay reconstructed all 597,298
vertices in 6,291 seconds.

An online SQLite backup froze the verified 40 MB base with quick and
foreign-key checks. Its SHA-256 is
`ac00ff206275edcd628623c020a18f822f6e2e7b35f89806e2572d2bbe457128`.
This immutable base supports parallel experiments without modifying either the
production ledger or the evidence that precedes them.

## 2026-07-12 — Parallel scan and replay are inside budget

Virtual shard identity is now independent of physical worker identity. Every
ordinal has a deterministic modular owner recorded in its block row, but idle
workers dynamically claim available transactions. This removes the dense-tail
penalty of assigning one physical worker permanently to one shard while the
auditor still proves the exact partition.

Eight workers extended an exactly replayed 11,000-block base to 20,000 in 767
seconds, 11.73 blocks/second. The final lease added only five seconds. The
result contains 817,722 vertices in 34,670 certificates; all 14,221 new
certificates linked into prior coverage. Base preservation, ownership, leases,
SQLite integrity, and the final database hash all pass independent audit.

Replay is also composable. Contiguous certificate-ID segments load their
recorded prefix ownership, replay independently, and compose in certificate
order; block materialization and generation checks form separate deterministic
segments. Four certificate and four block workers reduced a 1,000-block delta
replay from 447 to 146 seconds. Eight certificate and four block segments
verified the 9,000-block delta in 748 seconds. Eight replay dictionaries can
pressure 32 GB of RAM. A matched four-segment replay of the same delta took
1,154 seconds, equivalent to 7.80 verified blocks/second, and stayed comfortable
alongside the live verifier. The expected 32 GB production balance is therefore
eight scan workers and four concurrent replay workers.

At the measured rates, enumeration projects to about 7.8 days and pipelined
four-worker replay to roughly 11.8 days. Eight replay workers would reduce the
projection to about 7.6 days if sufficient memory permits full overlap. The
two-week 4A budget is therefore a measured engineering target rather than an
optimistic concurrency estimate.

## 2026-07-12 — Fifty thousand blocks balance scan and replay

The selected 32 GB configuration passed a production-scale wave. Eight workers
extended the verified 10,000-block base to 50,000 in 3,978 seconds, 10.055
blocks/second. Four certificate and four block segments replayed the complete
delta in 3,907 seconds, 10.238 verified blocks/second. Verification is therefore
slightly faster than scanning and will not accumulate a backlog when the two
phases overlap.

The database contains 1,237,281 vertices in 77,938 certificates: 77,931 linked,
four overflow, and three closed. Every one of the 59,345 delta certificates
linked into prior coverage. The composition and ownership audit passes with
operational database SHA-256
`d3046288113d356267597b3b2fa0b08f13b362f559895cf9a61d33911d589fb1`.
The separately backed-up 50,000-block base has SHA-256
`864baeee5c24d35c4d077d29c756c2555d5bb558f8d16e874c1b815ca2396b6d`.

At the slower measured scan rate, complete 4A enumeration projects to about
9.1 days. The current four-replay/eight-scan balance fits 32 GB and removes the
performance argument for a memory upgrade before the next scaling gate.

## 2026-07-12 — Candidate pipelining preserves speculative progress

The first pipelined handoff worked end to end. Eight workers extended the
50,000-block base to 100,000 in 5,149 seconds, 9.711 blocks/second. An online
snapshot then isolated that boundary while the writable ledger immediately
continued toward 150,000. Four certificate and four block segments replayed the
snapshot in 3,545 seconds, 14.104 verified blocks/second, and the independent
audit promoted it to the immutable base with SHA-256
`fb9fd0f70c09e304adef331569c3780a019721135261f210f90ce184f8edf414`.

The promoted base contains 1,666,133 vertices in 140,184 certificates. Every
one of the 62,246 delta certificates linked into prior coverage; there were no
new closed or overflow certificates. While that replay ran, the writable ledger
reached 150,000 blocks and 1,984,032 vertices without waiting for promotion.
It was then retargeted relative to the verified 100,000-block base.

The speculative scan took 6,875 seconds, 7.273 blocks/second. It overlapped
replay and other full regression workloads, so the slowdown is real operational
data but not yet evidence of a particular bottleneck. Replay still completed
well ahead of scanning. The pipeline therefore removes verification from the
critical path at this scale while preserving a conservative rate measurement
for the remaining runtime estimate.

## 2026-07-12 — Memory overcommit becomes a recovery test

The next wave suffered an avoidable operational failure: a full regression
suite was started on top of eight scan workers, four certificate replay workers,
and four block workers. Linux exhausted usable memory and killed every GAP scan
and certificate process. The normal production pipeline had previously fit;
the additional verifier caused the overcommit.

The failure nevertheless exercised the durability boundary more strongly than
a planned stop. The 150,000-block candidate was already an immutable SQLite
backup. The writable ledger retained 151,572 committed blocks, and expired
leases allowed all eight workers to resume without repair. Replay restarted
from the frozen candidate, passed exactly, and promoted the 150,000-block base
with SHA-256
`0a71fe882568dffbf615fe9107b1913cd76b5166c069096b506ac276f4df125d`.
The live ledger then reached exactly 200,000 blocks, 2,254,107 vertices, and
253,831 certificates with zero leases and a clean SQLite integrity check.

The recovery proves that committed progress survives abrupt whole-wave process
loss. It does not make the overcommit acceptable: full mathematical regression
checks are now excluded while the scan/replay production pair is resident.
